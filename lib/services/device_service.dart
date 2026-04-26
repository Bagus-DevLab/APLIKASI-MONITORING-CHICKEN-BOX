import 'package:dio/dio.dart';
import 'dart:developer' as developer;
import '../core/network/dio_client.dart';
import '../core/network/api_exception.dart';
import '../constants/api_config.dart';
import '../models/common/paginated_response.dart';
import '../models/device/device.dart';
import '../models/device/device_assignment.dart';
import '../models/device/sensor_log.dart';
import '../models/device/device_component.dart';
import '../models/auth/user_info.dart';

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

      // Non-2xx responses are now routed to onError by DioClient's
      // validateStatus, so AuthInterceptor maps them to typed ApiExceptions.
      // If we reach here, the response is guaranteed to be 2xx.

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

  // ═══════════════════════════════════════════════════════════════
  // DEVICE ASSIGNMENT METHODS
  // ═══════════════════════════════════════════════════════════════

  /// Find a user by email via the admin users endpoint
  ///
  /// Endpoint: GET /api/admin/users
  /// Rate Limit: 30/minute
  /// Auth Required: Yes (admin+)
  ///
  /// Fetches the first page of users and searches for an exact email match.
  /// The backend returns paginated results sorted by created_at DESC.
  ///
  /// Parameters:
  /// - [email]: Email address to search for (case-insensitive match)
  ///
  /// Returns:
  /// - [UserInfo] with `id` populated
  ///
  /// Throws:
  /// - [NotFoundException] → No user found with that email
  /// - [ForbiddenException] (403) → Caller is not admin+
  /// - [RateLimitException] (429)
  /// - [NetworkException] → Connection error
  Future<UserInfo> findUserByEmail(String email) async {
    developer.log(
      '→ Searching for user by email: $email',
      name: 'DeviceService',
    );

    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw ArgumentError('Email tidak boleh kosong');
    }

    try {
      // Fetch users page by page until we find a match or exhaust all pages
      int currentPage = 1;
      const int pageLimit = 100; // Max allowed by backend

      while (true) {
        final response = await _dio.get(
          ApiConfig.adminUsersUrl,
          queryParameters: {
            'page': currentPage,
            'limit': pageLimit,
          },
        );

        final paginated = PaginatedResponse<UserInfo>.fromJson(
          response.data,
          UserInfo.fromJson,
        );

        // Search for exact email match in current page
        for (final user in paginated.data) {
          if (user.email.toLowerCase() == normalizedEmail) {
            developer.log(
              '✓ Found user: ${user.email} (id: ${user.id})',
              name: 'DeviceService',
            );
            return user;
          }
        }

        // If no more pages, user not found
        if (!paginated.hasNextPage) break;
        currentPage++;
      }

      // No match found across all pages
      developer.log(
        '✗ User not found: $email',
        name: 'DeviceService',
      );
      throw NotFoundException('User dengan email "$email" tidak ditemukan.');
    } on ApiException {
      rethrow;
    } on DioException catch (e) {
      if (e.error is ApiException) {
        developer.log(
          '✗ Failed to search user: ${e.error}',
          name: 'DeviceService',
          error: e.error,
        );
        throw e.error as ApiException;
      }
      developer.log(
        '✗ Unexpected error searching user: ${e.message}',
        name: 'DeviceService',
        error: e,
      );
      throw NetworkException('Terjadi kesalahan jaringan: ${e.message}');
    } catch (e) {
      if (e is ArgumentError) rethrow;
      developer.log(
        '✗ Unexpected error searching user: $e',
        name: 'DeviceService',
        error: e,
      );
      throw UnknownException('Terjadi kesalahan yang tidak diketahui: $e');
    }
  }

  /// Assign a user to a device with a specific role
  ///
  /// Endpoint: POST /api/devices/{device_id}/assign
  /// Rate Limit: 20/minute
  /// Auth Required: Yes (owner or super_admin)
  ///
  /// If the target user's current role is "user" (default), they are
  /// automatically promoted to the assigned role by the backend.
  ///
  /// Parameters:
  /// - [deviceId]: Target device UUID
  /// - [userId]: Target user UUID (obtained via [findUserByEmail])
  /// - [role]: Access level — "operator" or "viewer"
  ///
  /// Returns:
  /// - [DeviceAssignment] the newly created assignment
  ///
  /// Throws:
  /// - [BadRequestException] (400) → Self-assign, duplicate, or target is admin+
  /// - [NotFoundException] (404) → User not found
  /// - [ForbiddenException] (403) → Caller is not device owner
  /// - [RateLimitException] (429)
  /// - [NetworkException] → Connection error
  Future<DeviceAssignment> assignUserToDevice({
    required String deviceId,
    required String userId,
    required String role,
  }) async {
    developer.log(
      '→ Assigning user $userId to device $deviceId as $role',
      name: 'DeviceService',
    );

    try {
      final response = await _dio.post(
        ApiConfig.deviceAssignUrl(deviceId),
        data: {
          'user_id': userId,
          'role': role,
        },
      );

      final assignment = DeviceAssignment.fromJson(response.data);

      developer.log(
        '✓ User assigned: ${assignment.userEmail} as ${assignment.role}',
        name: 'DeviceService',
      );

      return assignment;
    } on DioException catch (e) {
      if (e.error is ApiException) {
        developer.log(
          '✗ Failed to assign user: ${e.error}',
          name: 'DeviceService',
          error: e.error,
        );
        throw e.error as ApiException;
      }
      developer.log(
        '✗ Unexpected error assigning user: ${e.message}',
        name: 'DeviceService',
        error: e,
      );
      throw NetworkException('Terjadi kesalahan jaringan: ${e.message}');
    } catch (e) {
      developer.log(
        '✗ Unexpected error assigning user: $e',
        name: 'DeviceService',
        error: e,
      );
      throw UnknownException('Terjadi kesalahan yang tidak diketahui: $e');
    }
  }

  /// Get all users assigned to a device
  ///
  /// Endpoint: GET /api/devices/{device_id}/assignments
  /// Rate Limit: 30/minute
  /// Auth Required: Yes (owner or super_admin)
  /// Response Format: Plain JSON array (NOT paginated)
  ///
  /// Parameters:
  /// - [deviceId]: Target device UUID
  ///
  /// Returns:
  /// - [List<DeviceAssignment>] all assignments for this device
  ///
  /// Throws:
  /// - [ForbiddenException] (403) → Caller is not device owner
  /// - [RateLimitException] (429)
  /// - [NetworkException] → Connection error
  Future<List<DeviceAssignment>> getDeviceAssignments({
    required String deviceId,
  }) async {
    developer.log(
      '→ Loading assignments for device $deviceId',
      name: 'DeviceService',
    );

    try {
      final response = await _dio.get(
        ApiConfig.deviceAssignmentsUrl(deviceId),
      );

      // Response is a plain JSON array, NOT paginated
      final List<dynamic> data = response.data as List<dynamic>;
      final assignments = data
          .map((item) =>
              DeviceAssignment.fromJson(item as Map<String, dynamic>))
          .toList();

      developer.log(
        '✓ Loaded ${assignments.length} assignments',
        name: 'DeviceService',
      );

      return assignments;
    } on DioException catch (e) {
      if (e.error is ApiException) {
        developer.log(
          '✗ Failed to load assignments: ${e.error}',
          name: 'DeviceService',
          error: e.error,
        );
        throw e.error as ApiException;
      }
      developer.log(
        '✗ Unexpected error loading assignments: ${e.message}',
        name: 'DeviceService',
        error: e,
      );
      throw NetworkException('Terjadi kesalahan jaringan: ${e.message}');
    } catch (e) {
      developer.log(
        '✗ Unexpected error loading assignments: $e',
        name: 'DeviceService',
        error: e,
      );
      throw UnknownException('Terjadi kesalahan yang tidak diketahui: $e');
    }
  }

  /// Remove a user's assignment from a device
  ///
  /// Endpoint: DELETE /api/devices/{device_id}/assign/{user_id}
  /// Rate Limit: 20/minute
  /// Auth Required: Yes (owner or super_admin)
  ///
  /// Parameters:
  /// - [deviceId]: Target device UUID
  /// - [userId]: User UUID to unassign
  ///
  /// Throws:
  /// - [NotFoundException] (404) → Assignment not found
  /// - [ForbiddenException] (403) → Caller is not device owner
  /// - [RateLimitException] (429)
  /// - [NetworkException] → Connection error
  Future<void> unassignUserFromDevice({
    required String deviceId,
    required String userId,
  }) async {
    developer.log(
      '→ Unassigning user $userId from device $deviceId',
      name: 'DeviceService',
    );

    try {
      final response = await _dio.delete(
        ApiConfig.deviceUnassignUrl(deviceId, userId),
      );

      developer.log(
        '✓ User unassigned successfully',
        name: 'DeviceService',
      );
    } on DioException catch (e) {
      if (e.error is ApiException) {
        developer.log(
          '✗ Failed to unassign user: ${e.error}',
          name: 'DeviceService',
          error: e.error,
        );
        throw e.error as ApiException;
      }
      developer.log(
        '✗ Unexpected error unassigning user: ${e.message}',
        name: 'DeviceService',
        error: e,
      );
      throw NetworkException('Terjadi kesalahan jaringan: ${e.message}');
    } catch (e) {
      developer.log(
        '✗ Unexpected error unassigning user: $e',
        name: 'DeviceService',
        error: e,
      );
      throw UnknownException('Terjadi kesalahan yang tidak diketahui: $e');
    }
  }
}
