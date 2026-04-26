import 'package:dio/dio.dart';
import 'dart:developer' as developer;
import '../core/network/dio_client.dart';
import '../core/network/api_exception.dart';
import '../constants/api_config.dart';
import '../models/common/paginated_response.dart';
import '../models/device/device.dart';
import '../models/device/sensor_log.dart';
import '../models/device/device_component.dart';

/// Device management service for handling device-related API calls
/// 
/// Based on API_CONTRACT.md Section 3.3: Device Management
/// 
/// Features:
/// - Get paginated list of devices (role-based filtering)
/// - Control device components (kipas, lampu, pompa, pakan_otomatis)
/// - Claim unclaimed devices via QR code
/// - Get paginated sensor logs for a device
/// 
/// All methods follow the same error handling pattern:
/// - Catch DioException and extract custom ApiException
/// - Re-throw ApiException to bubble up to UI layer
/// - Let AuthInterceptor handle 401/403 auto-logout
/// 
/// Usage:
/// ```dart
/// final deviceService = DeviceService();
/// 
/// try {
///   final devices = await deviceService.getDevices();
///   print('Loaded ${devices.itemCount} devices');
/// } on ForbiddenException catch (e) {
///   showErrorDialog('Akses Ditolak', e.message);
/// } on RateLimitException catch (e) {
///   showSnackbar(e.message);
/// }
/// ```
class DeviceService {
  final Dio _dio = DioClient().dio;

  /// Get paginated list of devices accessible to the current user
  /// 
  /// Endpoint: GET /api/devices/
  /// Rate Limit: 30/minute
  /// Auth Required: Yes
  /// Minimum Role: Any authenticated user
  /// 
  /// Role-Based Filtering (handled by backend):
  /// - super_admin: All devices in the system
  /// - admin: Only devices they own
  /// - operator: Only devices assigned to them
  /// - viewer: Only devices assigned to them
  /// - user: Empty list (no device access)
  /// 
  /// Parameters:
  /// - [page]: Page number (default: 1, constraint: ge=1)
  /// - [limit]: Items per page (default: 20, constraint: 1-100)
  /// 
  /// Returns:
  /// - [PaginatedResponse<Device>] containing list of devices
  /// 
  /// Throws:
  /// - [UnauthorizedException] (401) → Auto-logout triggered
  /// - [ForbiddenException] (403) → Permission denied
  /// - [RateLimitException] (429) → Rate limit exceeded (30/minute)
  /// - [NetworkException] → Connection error
  /// 
  /// Example:
  /// ```dart
  /// final response = await deviceService.getDevices(page: 1, limit: 20);
  /// print('Total devices: ${response.total}');
  /// print('Current page: ${response.page}/${response.totalPages}');
  /// 
  /// for (var device in response.data) {
  ///   print('${device.displayName} - ${device.onlineStatusDisplay}');
  /// }
  /// 
  /// if (response.hasNextPage) {
  ///   // Load next page
  /// }
  /// ```
  Future<PaginatedResponse<Device>> getDevices({
    int page = 1,
    int limit = 20,
  }) async {
    developer.log(
      '→ Loading devices (page: $page, limit: $limit)',
      name: 'DeviceService',
    );

    // Validate parameters
    if (page < 1) {
      throw ArgumentError('Page must be >= 1');
    }
    if (limit < 1 || limit > 100) {
      throw ArgumentError('Limit must be between 1 and 100');
    }

    try {
      final response = await _dio.get(
        ApiConfig.devicesUrl,
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );

      // Check if response is successful
      if (response.statusCode != 200) {
        developer.log(
          '✗ Failed to load devices: status ${response.statusCode}',
          name: 'DeviceService',
        );
        throw UnknownException(
          'Gagal memuat daftar device dengan status ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      // Parse paginated response
      final paginatedDevices = PaginatedResponse<Device>.fromJson(
        response.data,
        Device.fromJson,
      );

      developer.log(
        '✓ Loaded ${paginatedDevices.itemCount} devices (page ${paginatedDevices.page}/${paginatedDevices.totalPages})',
        name: 'DeviceService',
      );

      return paginatedDevices;
    } on DioException catch (e) {
      // DioException with custom ApiException in error field
      if (e.error is ApiException) {
        developer.log(
          '✗ Failed to load devices: ${e.error}',
          name: 'DeviceService',
          error: e.error,
        );
        throw e.error as ApiException;
      }

      // Fallback for unexpected errors
      developer.log(
        '✗ Unexpected error loading devices: ${e.message}',
        name: 'DeviceService',
        error: e,
      );
      throw NetworkException('Terjadi kesalahan jaringan: ${e.message}');
    } catch (e) {
      developer.log(
        '✗ Unexpected error loading devices: $e',
        name: 'DeviceService',
        error: e,
      );
      throw UnknownException('Terjadi kesalahan yang tidak diketahui: $e');
    }
  }

  /// Control a device component (turn on/off)
  /// 
  /// Endpoint: POST /api/devices/{device_id}/control
  /// Rate Limit: 30/minute
  /// Auth Required: Yes
  /// Minimum Role: operator (assigned), admin (owner), or super_admin
  /// 
  /// Parameters:
  /// - [deviceId]: Target device UUID
  /// - [component]: Component to control (kipas, lampu, pompa, pakanOtomatis)
  /// - [state]: true = ON, false = OFF
  /// 
  /// Returns:
  /// - void (success returns 200 with message)
  /// 
  /// Throws:
  /// - [ForbiddenException] (403) → Viewer role cannot control devices
  /// - [ForbiddenException] (403) → User role has no device access
  /// - [ServerException] (500) → MQTT broker unreachable
  /// - [RateLimitException] (429) → Rate limit exceeded (30/minute)
  /// - [NetworkException] → Connection error
  /// 
  /// Example:
  /// ```dart
  /// // Turn on fan
  /// await deviceService.controlDevice(
  ///   deviceId: device.id,
  ///   component: DeviceComponent.kipas,
  ///   state: true,
  /// );
  /// 
  /// // Turn off light
  /// await deviceService.controlDevice(
  ///   deviceId: device.id,
  ///   component: DeviceComponent.lampu,
  ///   state: false,
  /// );
  /// ```
  Future<void> controlDevice({
    required String deviceId,
    required DeviceComponent component,
    required bool state,
  }) async {
    final componentValue = component.toApiValue();
    final stateText = state ? 'ON' : 'OFF';

    developer.log(
      '→ Controlling device $deviceId: $componentValue = $stateText',
      name: 'DeviceService',
    );

    try {
      final response = await _dio.post(
        ApiConfig.deviceControlUrl(deviceId),
        data: {
          'component': componentValue,
          'state': state,
        },
      );

      // Check if response is successful
      if (response.statusCode != 200) {
        developer.log(
          '✗ Failed to control device: status ${response.statusCode}',
          name: 'DeviceService',
        );
        throw UnknownException(
          'Gagal mengirim perintah ke device dengan status ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      // Log success message from backend
      final message = response.data['message'] as String?;
      developer.log(
        '✓ Device controlled successfully: $message',
        name: 'DeviceService',
      );
    } on DioException catch (e) {
      // DioException with custom ApiException in error field
      if (e.error is ApiException) {
        developer.log(
          '✗ Failed to control device: ${e.error}',
          name: 'DeviceService',
          error: e.error,
        );
        throw e.error as ApiException;
      }

      // Fallback for unexpected errors
      developer.log(
        '✗ Unexpected error controlling device: ${e.message}',
        name: 'DeviceService',
        error: e,
      );
      throw NetworkException('Terjadi kesalahan jaringan: ${e.message}');
    } catch (e) {
      developer.log(
        '✗ Unexpected error controlling device: $e',
        name: 'DeviceService',
        error: e,
      );
      throw UnknownException('Terjadi kesalahan yang tidak diketahui: $e');
    }
  }

  /// Claim an unclaimed device via QR code scan
  /// 
  /// Endpoint: POST /api/devices/claim
  /// Rate Limit: 10/minute
  /// Auth Required: Yes
  /// Minimum Role: admin
  /// 
  /// Sets the caller as the device owner.
  /// Backend uses SELECT ... FOR UPDATE to prevent race conditions.
  /// 
  /// Parameters:
  /// - [macAddress]: MAC address from QR code (format: XX:XX:XX:XX:XX:XX or XXXXXXXXXXXX)
  /// - [name]: Human-readable name for the coop (1-100 chars, trimmed)
  /// 
  /// Returns:
  /// - [Device] claimed device with user_id and name populated
  /// 
  /// Throws:
  /// - [BadRequestException] (400) → Device already claimed by another user
  /// - [ForbiddenException] (403) → Caller role is below admin
  /// - [NotFoundException] (404) → MAC address not found in system
  /// - [ValidationException] (422) → Invalid MAC format or name constraints
  /// - [RateLimitException] (429) → Rate limit exceeded (10/minute)
  /// - [NetworkException] → Connection error
  /// 
  /// Example:
  /// ```dart
  /// try {
  ///   final device = await deviceService.claimDevice(
  ///     macAddress: '44:1D:64:BE:22:08',
  ///     name: 'Kandang Utara',
  ///   );
  ///   print('Device ${device.displayName} berhasil diklaim!');
  /// } on BadRequestException catch (e) {
  ///   // Already claimed
  ///   showErrorDialog('Gagal Klaim', e.message);
  /// } on NotFoundException catch (e) {
  ///   // MAC not registered
  ///   showErrorDialog('Device Tidak Ditemukan', e.message);
  /// }
  /// ```
  Future<Device> claimDevice({
    required String macAddress,
    required String name,
  }) async {
    developer.log(
      '→ Claiming device: MAC=$macAddress, name=$name',
      name: 'DeviceService',
    );

    // Validate name length (1-100 chars)
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || trimmedName.length > 100) {
      throw ArgumentError(
        'Name must be between 1 and 100 characters (after trimming)',
      );
    }

    try {
      final response = await _dio.post(
        ApiConfig.claimDeviceUrl,
        data: {
          'mac_address': macAddress,
          'name': trimmedName,
        },
      );

      // Check if response is successful
      if (response.statusCode != 200) {
        developer.log(
          '✗ Failed to claim device: status ${response.statusCode}',
          name: 'DeviceService',
        );
        throw UnknownException(
          'Gagal mengklaim device dengan status ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      // Parse device response
      final device = Device.fromJson(response.data);

      developer.log(
        '✓ Device claimed successfully: ${device.displayName} (${device.id})',
        name: 'DeviceService',
      );

      return device;
    } on DioException catch (e) {
      // DioException with custom ApiException in error field
      if (e.error is ApiException) {
        developer.log(
          '✗ Failed to claim device: ${e.error}',
          name: 'DeviceService',
          error: e.error,
        );
        throw e.error as ApiException;
      }

      // Fallback for unexpected errors
      developer.log(
        '✗ Unexpected error claiming device: ${e.message}',
        name: 'DeviceService',
        error: e,
      );
      throw NetworkException('Terjadi kesalahan jaringan: ${e.message}');
    } catch (e) {
      developer.log(
        '✗ Unexpected error claiming device: $e',
        name: 'DeviceService',
        error: e,
      );
      throw UnknownException('Terjadi kesalahan yang tidak diketahui: $e');
    }
  }

  /// Get paginated sensor logs for a device
  /// 
  /// Endpoint: GET /api/devices/{device_id}/logs
  /// Rate Limit: 60/minute
  /// Auth Required: Yes
  /// Minimum Role: Any role with device access
  /// 
  /// Data is sorted by timestamp DESC (newest first) by backend.
  /// 
  /// Parameters:
  /// - [deviceId]: Target device UUID
  /// - [page]: Page number (default: 1, constraint: ge=1)
  /// - [limit]: Items per page (default: 20, constraint: 1-100)
  /// 
  /// Returns:
  /// - [PaginatedResponse<SensorLog>] containing list of sensor logs
  /// 
  /// Throws:
  /// - [NotFoundException] (404) → Device not found or no access
  /// - [RateLimitException] (429) → Rate limit exceeded (60/minute)
  /// - [UnauthorizedException] (401) → Auto-logout triggered
  /// - [NetworkException] → Connection error
  /// 
  /// Example:
  /// ```dart
  /// final response = await deviceService.getDeviceLogs(
  ///   deviceId: device.id,
  ///   page: 1,
  ///   limit: 50,
  /// );
  /// 
  /// for (var log in response.data) {
  ///   print('${log.formattedTimestamp}: ${log.temperatureDisplay}');
  ///   if (log.hasAlert) {
  ///     print('  Alert: ${log.alertMessage}');
  ///   }
  /// }
  /// ```
  Future<PaginatedResponse<SensorLog>> getDeviceLogs({
    required String deviceId,
    int page = 1,
    int limit = 20,
  }) async {
    developer.log(
      '→ Loading logs for device $deviceId (page: $page, limit: $limit)',
      name: 'DeviceService',
    );

    // Validate parameters
    if (page < 1) {
      throw ArgumentError('Page must be >= 1');
    }
    if (limit < 1 || limit > 100) {
      throw ArgumentError('Limit must be between 1 and 100');
    }

    try {
      final response = await _dio.get(
        ApiConfig.deviceLogsUrl(deviceId),
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );

      // Check if response is successful
      if (response.statusCode != 200) {
        developer.log(
          '✗ Failed to load logs: status ${response.statusCode}',
          name: 'DeviceService',
        );
        throw UnknownException(
          'Gagal memuat log sensor dengan status ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }

      // Parse paginated response
      final paginatedLogs = PaginatedResponse<SensorLog>.fromJson(
        response.data,
        SensorLog.fromJson,
      );

      developer.log(
        '✓ Loaded ${paginatedLogs.itemCount} logs (page ${paginatedLogs.page}/${paginatedLogs.totalPages})',
        name: 'DeviceService',
      );

      return paginatedLogs;
    } on DioException catch (e) {
      // DioException with custom ApiException in error field
      if (e.error is ApiException) {
        developer.log(
          '✗ Failed to load logs: ${e.error}',
          name: 'DeviceService',
          error: e.error,
        );
        throw e.error as ApiException;
      }

      // Fallback for unexpected errors
      developer.log(
        '✗ Unexpected error loading logs: ${e.message}',
        name: 'DeviceService',
        error: e,
      );
      throw NetworkException('Terjadi kesalahan jaringan: ${e.message}');
    } catch (e) {
      developer.log(
        '✗ Unexpected error loading logs: $e',
        name: 'DeviceService',
        error: e,
      );
      throw UnknownException('Terjadi kesalahan yang tidak diketahui: $e');
    }
  }
}
