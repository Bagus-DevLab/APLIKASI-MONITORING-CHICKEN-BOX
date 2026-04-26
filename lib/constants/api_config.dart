import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../core/network/dio_client.dart';

/// API Configuration class that manages base URL and endpoint definitions
/// 
/// Based on API_CONTRACT.md Section 1: Base Integration Rules
/// All REST endpoints are prefixed with /api
/// 
/// Usage:
/// ```dart
/// await ApiConfig.initialize(); // Load .env and configure DioClient
/// final loginUrl = ApiConfig.authFirebaseLoginUrl;
/// ```
class ApiConfig {
  /// Initialize .env file and configure DioClient base URL
  static Future<void> initialize() async {
    await dotenv.load(fileName: ".env");
    
    // Get base URL from .env and append /api prefix
    final baseUrl = dotenv.env['BASE_URL'] ?? 'https://api.pcb.my.id';
    final apiBaseUrl = '$baseUrl/api';
    
    // Configure DioClient with the full API base URL
    DioClient().setBaseUrl(apiBaseUrl);
  }

  /// Get base URL with /api prefix
  static String get baseUrl {
    final baseUrl = dotenv.env['BASE_URL'] ?? 'https://api.pcb.my.id';
    return '$baseUrl/api';
  }

  // ═══════════════════════════════════════════════════════════════
  // AUTHENTICATION ENDPOINTS
  // ═══════════════════════════════════════════════════════════════

  /// POST /api/auth/firebase/login
  /// Exchange Firebase ID token for local JWT
  /// Rate Limit: 10/minute
  /// Auth Required: No
  static String get authFirebaseLoginUrl => '/auth/firebase/login';

  // ═══════════════════════════════════════════════════════════════
  // USER MANAGEMENT ENDPOINTS
  // ═══════════════════════════════════════════════════════════════

  /// GET /api/users/me - Get authenticated user profile
  /// PATCH /api/users/me - Update display name
  /// DELETE /api/users/me - Delete account
  /// Rate Limit: 60/minute (GET), 10/minute (PATCH), 5/minute (DELETE)
  /// Auth Required: Yes
  static String get usersUrl => '/users/me';

  /// PATCH /api/users/{user_id}/role - Change user role
  /// Rate Limit: 10/minute
  /// Auth Required: Yes (admin+)
  static String userRoleUrl(String userId) => '/users/$userId/role';

  /// POST /api/users/me/fcm-token - Register FCM token
  /// DELETE /api/users/me/fcm-token - Unregister FCM token
  /// Rate Limit: 20/minute
  /// Auth Required: Yes
  static String get fcmTokenUrl => '/users/me/fcm-token';

  // ═══════════════════════════════════════════════════════════════
  // DEVICE MANAGEMENT ENDPOINTS
  // ═══════════════════════════════════════════════════════════════

  /// GET /api/devices/ - List accessible devices (paginated)
  /// Rate Limit: 30/minute
  /// Auth Required: Yes
  static String get devicesUrl => '/devices/';

  /// GET /api/devices/unclaimed - List unclaimed devices
  /// Rate Limit: 30/minute
  /// Auth Required: Yes (admin+)
  static String get unclaimedDevicesUrl => '/devices/unclaimed';

  /// GET /api/devices/all - List all devices (claimed + unclaimed)
  /// Rate Limit: 30/minute
  /// Auth Required: Yes (admin+)
  static String get allDevicesUrl => '/devices/all';

  /// POST /api/devices/register - Register new device MAC
  /// Rate Limit: 20/minute
  /// Auth Required: Yes (super_admin only)
  static String get registerDeviceUrl => '/devices/register';

  /// POST /api/devices/claim - Claim unclaimed device
  /// Rate Limit: 10/minute
  /// Auth Required: Yes (admin+)
  static String get claimDeviceUrl => '/devices/claim';

  /// PATCH /api/devices/{device_id} - Rename device
  /// Rate Limit: 20/minute
  /// Auth Required: Yes (owner or super_admin)
  static String deviceUpdateUrl(String deviceId) => '/devices/$deviceId';

  /// DELETE /api/devices/{device_id} - Delete device permanently
  /// Rate Limit: 10/minute
  /// Auth Required: Yes (super_admin only)
  static String deviceDeleteUrl(String deviceId) => '/devices/$deviceId';

  /// GET /api/devices/{device_id}/logs - Get sensor logs (paginated)
  /// Rate Limit: 60/minute
  /// Auth Required: Yes
  static String deviceLogsUrl(String deviceId) => '/devices/$deviceId/logs';

  /// GET /api/devices/{device_id}/logs?limit=50 - Get recent logs
  static String deviceLogsHistoryUrl(String deviceId) => 
      '/devices/$deviceId/logs?limit=50';

  /// POST /api/devices/{device_id}/control - Send control command
  /// Rate Limit: 30/minute
  /// Auth Required: Yes (operator+, not viewer)
  static String deviceControlUrl(String deviceId) => '/devices/$deviceId/control';

  /// GET /api/devices/{device_id}/alerts - Get alert history (paginated)
  /// Rate Limit: 60/minute
  /// Auth Required: Yes
  static String deviceAlertsUrl(String deviceId) => '/devices/$deviceId/alerts';

  /// GET /api/devices/{device_id}/stats/daily - Get daily statistics
  /// Rate Limit: 30/minute
  /// Auth Required: Yes
  static String deviceStatsUrl(String deviceId) => '/devices/$deviceId/stats/daily';

  /// POST /api/devices/{device_id}/unclaim - Release device ownership
  /// Rate Limit: 10/minute
  /// Auth Required: Yes (owner or super_admin)
  static String deviceUnclaimUrl(String deviceId) => '/devices/$deviceId/unclaim';

  /// GET /api/devices/{device_id}/status - Check device online status
  /// Rate Limit: 60/minute
  /// Auth Required: Yes
  static String deviceStatusUrl(String deviceId) => '/devices/$deviceId/status';

  /// POST /api/devices/{device_id}/assign - Assign user to device
  /// Rate Limit: 20/minute
  /// Auth Required: Yes (owner or super_admin)
  static String deviceAssignUrl(String deviceId) => '/devices/$deviceId/assign';

  /// DELETE /api/devices/{device_id}/assign/{user_id} - Unassign user
  /// Rate Limit: 20/minute
  /// Auth Required: Yes (owner or super_admin)
  static String deviceUnassignUrl(String deviceId, String userId) => 
      '/devices/$deviceId/assign/$userId';

  /// GET /api/devices/{device_id}/assignments - List device assignments
  /// Rate Limit: 30/minute
  /// Auth Required: Yes (owner or super_admin)
  static String deviceAssignmentsUrl(String deviceId) => 
      '/devices/$deviceId/assignments';

  // ═══════════════════════════════════════════════════════════════
  // ADMIN DASHBOARD ENDPOINTS
  // ═══════════════════════════════════════════════════════════════

  /// GET /api/admin/stats - Dashboard overview
  /// Rate Limit: 30/minute
  /// Auth Required: Yes (admin+)
  static String get adminStatsUrl => '/admin/stats';

  /// GET /api/admin/users - List all users (paginated)
  /// Rate Limit: 30/minute
  /// Auth Required: Yes (admin+)
  static String get adminUsersUrl => '/admin/users';

  /// POST /api/admin/sync-firebase-users - Sync Firebase users to DB
  /// Rate Limit: 5/minute
  /// Auth Required: Yes (super_admin only)
  static String get adminSyncUsersUrl => '/admin/sync-firebase-users';

  /// POST /api/admin/cleanup-logs - Delete old sensor logs
  /// Rate Limit: 5/minute
  /// Auth Required: Yes (super_admin only)
  static String get adminCleanupLogsUrl => '/admin/cleanup-logs';

  // ═══════════════════════════════════════════════════════════════
  // HEALTH CHECK
  // ═══════════════════════════════════════════════════════════════

  /// GET /api/health - Health check (no auth required)
  /// Rate Limit: 60/minute
  /// Auth Required: No
  static String get healthUrl => '/health';

  // ═══════════════════════════════════════════════════════════════
  // WEBSOCKET ENDPOINTS
  // ═══════════════════════════════════════════════════════════════

  /// WebSocket URL for real-time sensor data
  /// ws://{{BASE_URL}}/api/ws/devices/{device_id}?token={jwt_token}
  /// 
  /// Usage:
  /// ```dart
  /// final wsUrl = ApiConfig.deviceWebSocketUrl(deviceId, jwtToken);
  /// final channel = WebSocketChannel.connect(Uri.parse(wsUrl));
  /// ```
  static String deviceWebSocketUrl(String deviceId, String jwtToken) {
    final baseUrl = dotenv.env['BASE_URL'] ?? 'https://api.pcb.my.id';
    final wsProtocol = baseUrl.startsWith('https') ? 'wss' : 'ws';
    final host = baseUrl.replaceAll('https://', '').replaceAll('http://', '');
    return '$wsProtocol://$host/api/ws/devices/$deviceId?token=$jwtToken';
  }
}
