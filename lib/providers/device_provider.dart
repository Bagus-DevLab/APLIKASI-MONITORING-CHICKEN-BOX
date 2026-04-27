import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../services/device_service.dart';
import '../models/device/device_component.dart';
import '../core/network/api_exception.dart';
import '../utils/error_handler.dart';

/// Global state manager for device component states (toggle switches).
///
/// Solves the "state reset on navigation" problem by lifting toggle state
/// out of individual page widgets into an app-level [ChangeNotifier].
///
/// Architecture:
/// - Backend is the single source of truth (no local cache / shared_preferences)
/// - State persists in-memory across navigation during the app session
/// - On app restart, state is re-fetched from backend via [refreshDeviceStates]
///
/// Data structure:
/// ```
/// _componentStates = {
///   "device-uuid-1": { kipas: true, lampu: false, pompa: false, pakanOtomatis: true },
///   "device-uuid-2": { kipas: false, lampu: true, pompa: false, pakanOtomatis: false },
/// }
/// ```
///
/// Usage:
/// ```dart
/// // Read state
/// final isOn = context.read<DeviceProvider>().getComponentState(deviceId, DeviceComponent.kipas);
///
/// // Toggle with optimistic UI
/// context.read<DeviceProvider>().toggleComponent(context, deviceId, DeviceComponent.kipas, true);
/// ```
class DeviceProvider extends ChangeNotifier {
  final DeviceService _deviceService = DeviceService();

  /// Component ON/OFF states: deviceId -> component -> isEnabled
  final Map<String, Map<DeviceComponent, bool>> _componentStates = {};

  /// Per-switch loading indicators: deviceId -> component -> isLoading
  final Map<String, Map<DeviceComponent, bool>> _loadingStates = {};

  // ═══════════════════════════════════════════════════════════════
  // GETTERS
  // ═══════════════════════════════════════════════════════════════

  /// Get the current ON/OFF state for a specific component on a device.
  ///
  /// Returns `false` if the device or component has not been initialized yet.
  bool getComponentState(String deviceId, DeviceComponent component) {
    final deviceStates = _componentStates[deviceId];
    if (deviceStates == null) return false;
    return deviceStates[component] ?? false;
  }

  /// Check if a specific component is currently processing an API request.
  ///
  /// Used by the UI to show a [CircularProgressIndicator] instead of the
  /// [Switch] widget, and to disable the switch to prevent race conditions.
  bool isComponentLoading(String deviceId, DeviceComponent component) {
    final deviceLoading = _loadingStates[deviceId];
    if (deviceLoading == null) return false;
    return deviceLoading[component] ?? false;
  }

  // ═══════════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════════

  /// Ensure a device has an entry in both state maps.
  ///
  /// Called lazily the first time a device's state is accessed.
  /// All components default to `false` (OFF) and `false` (not loading).
  void _ensureDeviceInitialized(String deviceId) {
    if (!_componentStates.containsKey(deviceId)) {
      _componentStates[deviceId] = {
        for (final component in DeviceComponent.values) component: false,
      };

      developer.log(
        '→ Initialized component states for device $deviceId (all OFF)',
        name: 'DeviceProvider',
      );
    }

    if (!_loadingStates.containsKey(deviceId)) {
      _loadingStates[deviceId] = {
        for (final component in DeviceComponent.values) component: false,
      };
    }
  }

  /// Sync device component states from the backend.
  ///
  /// Called in `initState` of [DeviceDetailPage] via `addPostFrameCallback`
  /// to ensure the UI reflects the actual hardware state.
  ///
  /// NOTE: The current API contract (GET /api/devices/) does not return
  /// per-component ON/OFF states in the device list response. If the backend
  /// adds this field in the future, this method should parse and apply it.
  /// For now, it initializes the device entry so the Provider is ready.
  void refreshDeviceStates(String deviceId) {
    _ensureDeviceInitialized(deviceId);

    developer.log(
      '→ Device states refreshed for $deviceId',
      name: 'DeviceProvider',
    );

    // No notifyListeners() needed here because _ensureDeviceInitialized
    // only sets defaults if the device is new. If the device already has
    // state (from a previous toggle), we preserve it.
  }

  // ═══════════════════════════════════════════════════════════════
  // TOGGLE LOGIC (OPTIMISTIC UI + ROLLBACK)
  // ═══════════════════════════════════════════════════════════════

  /// Toggle a device component with optimistic UI update.
  ///
  /// Flow:
  /// 1. Save original state for rollback
  /// 2. Update UI immediately (optimistic)
  /// 3. Set per-switch loading indicator
  /// 4. Call [DeviceService.controlDevice]
  /// 5a. Success → keep state, show success SnackBar
  /// 5b. Failure → rollback to original state, show error feedback
  /// 6. Clear loading indicator
  ///
  /// Parameters:
  /// - [context]: BuildContext for showing SnackBar/Dialog feedback
  /// - [deviceId]: Target device UUID
  /// - [component]: Which component to toggle (kipas, lampu, pompa, pakanOtomatis)
  /// - [newState]: Desired state (true = ON, false = OFF)
  Future<void> toggleComponent(
    BuildContext context,
    String deviceId,
    DeviceComponent component,
    bool newState,
  ) async {
    _ensureDeviceInitialized(deviceId);

    // 1. Save original state for rollback
    final originalState = _componentStates[deviceId]![component] ?? false;

    developer.log(
      '→ Toggling ${component.displayName} on device $deviceId: '
      '${originalState ? "ON" : "OFF"} → ${newState ? "ON" : "OFF"}',
      name: 'DeviceProvider',
    );

    // 2. Optimistic update + 3. Set loading
    _componentStates[deviceId]![component] = newState;
    _loadingStates[deviceId]![component] = true;
    notifyListeners();

    try {
      // 4. API call
      await _deviceService.controlDevice(
        deviceId: deviceId,
        component: component,
        state: newState,
      );

      // 5a. Success — keep the optimistic state
      developer.log(
        '✓ ${component.displayName} toggled successfully to ${newState ? "ON" : "OFF"}',
        name: 'DeviceProvider',
      );

      if (context.mounted) {
        ErrorHandler.showSuccessSnackbar(
          context,
          '${component.displayName} berhasil ${newState ? "dinyalakan" : "dimatikan"}',
        );
      }
    } on ForbiddenException catch (e) {
      // Viewer role cannot control — rollback
      developer.log(
        '✗ Control forbidden: ${e.message}',
        name: 'DeviceProvider',
        error: e,
      );

      _componentStates[deviceId]![component] = originalState;

      if (context.mounted) {
        final msg = ErrorHandler.getHumanizedMessage(e);
        ErrorHandler.showErrorDialog(context, msg.title, msg.body);
      }
    } on RateLimitException catch (e) {
      // Too many requests — rollback
      developer.log(
        '✗ Rate limit exceeded: ${e.message}',
        name: 'DeviceProvider',
        error: e,
      );

      _componentStates[deviceId]![component] = originalState;

      if (context.mounted) {
        final msg = ErrorHandler.getHumanizedMessage(e);
        ErrorHandler.showRateLimitSnackbar(context, msg.body);
      }
    } on NetworkException catch (e) {
      // No internet / timeout — rollback with retry
      developer.log(
        '✗ Network error: ${e.message}',
        name: 'DeviceProvider',
        error: e,
      );

      _componentStates[deviceId]![component] = originalState;

      if (context.mounted) {
        final msg = ErrorHandler.getHumanizedMessage(e);
        ErrorHandler.showNetworkErrorSnackbar(
          context,
          msg.body,
          () => toggleComponent(context, deviceId, component, newState),
        );
      }
    } on ServerException catch (e) {
      // MQTT broker unreachable — rollback
      developer.log(
        '✗ Server error: ${e.message}',
        name: 'DeviceProvider',
        error: e,
      );

      _componentStates[deviceId]![component] = originalState;

      if (context.mounted) {
        final msg = ErrorHandler.getHumanizedMessage(e);
        ErrorHandler.showErrorDialog(context, msg.title, msg.body);
      }
    } on ApiException catch (e) {
      // Catch-all for other API errors — rollback
      developer.log(
        '✗ API error: ${e.message}',
        name: 'DeviceProvider',
        error: e,
      );

      _componentStates[deviceId]![component] = originalState;

      if (context.mounted) {
        final msg = ErrorHandler.getHumanizedMessage(e);
        ErrorHandler.showErrorSnackbar(context, '${msg.title} ${msg.body}');
      }
    } catch (e) {
      // Unexpected error — rollback
      developer.log(
        '✗ Unexpected error: $e',
        name: 'DeviceProvider',
        error: e,
      );

      _componentStates[deviceId]![component] = originalState;

      if (context.mounted) {
        ErrorHandler.showErrorSnackbar(
          context,
          'Waduh, ada error nih Bro: $e',
        );
      }
    } finally {
      // 6. Clear loading state
      _loadingStates[deviceId]![component] = false;
      notifyListeners();
    }
  }
}
