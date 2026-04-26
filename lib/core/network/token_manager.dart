import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:developer' as developer;

/// Manages JWT token storage and provides logout event stream
/// 
/// Uses flutter_secure_storage for secure token persistence.
/// Provides a stream for global logout events (401/403 errors).
class TokenManager {
  static final TokenManager _instance = TokenManager._internal();
  factory TokenManager() => _instance;
  TokenManager._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  static const String _tokenKey = 'jwt_token';
  static const String _userEmailKey = 'user_email';
  static const String _userRoleKey = 'user_role';

  /// Stream controller for logout events
  /// Listen to this stream to handle global logout (e.g., navigate to login screen)
  final StreamController<void> _logoutController = StreamController<void>.broadcast();
  Stream<void> get onLogout => _logoutController.stream;

  /// Save JWT token to secure storage
  Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
      developer.log('✓ JWT token saved to secure storage', name: 'TokenManager');
    } catch (e) {
      developer.log('✗ Failed to save token: $e', name: 'TokenManager', error: e);
      rethrow;
    }
  }

  /// Get JWT token from secure storage
  Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } catch (e) {
      developer.log('✗ Failed to read token: $e', name: 'TokenManager', error: e);
      return null;
    }
  }

  /// Check if user is authenticated (has valid token)
  Future<bool> isAuthenticated() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// Save user info (email and role) to secure storage
  Future<void> saveUserInfo({
    required String email,
    required String role,
  }) async {
    try {
      await _storage.write(key: _userEmailKey, value: email);
      await _storage.write(key: _userRoleKey, value: role);
      developer.log('✓ User info saved: $email ($role)', name: 'TokenManager');
    } catch (e) {
      developer.log('✗ Failed to save user info: $e', name: 'TokenManager', error: e);
    }
  }

  /// Get user email from secure storage
  Future<String?> getUserEmail() async {
    try {
      return await _storage.read(key: _userEmailKey);
    } catch (e) {
      developer.log('✗ Failed to read user email: $e', name: 'TokenManager', error: e);
      return null;
    }
  }

  /// Get user role from secure storage
  Future<String?> getUserRole() async {
    try {
      return await _storage.read(key: _userRoleKey);
    } catch (e) {
      developer.log('✗ Failed to read user role: $e', name: 'TokenManager', error: e);
      return null;
    }
  }

  /// Clear all stored authentication data
  /// Called on logout or when 401/403 errors occur
  Future<void> clearAuth() async {
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _userEmailKey);
      await _storage.delete(key: _userRoleKey);
      developer.log('✓ All auth data cleared', name: 'TokenManager');
    } catch (e) {
      developer.log('✗ Failed to clear auth data: $e', name: 'TokenManager', error: e);
    }
  }

  /// Trigger a global logout event
  /// This will notify all listeners (e.g., main app) to navigate to login screen
  /// Called by AuthInterceptor when 401/403 errors occur
  void triggerLogout() {
    developer.log('⚠ Logout event triggered', name: 'TokenManager');
    _logoutController.add(null);
  }

  /// Dispose the stream controller (call this when app is closing)
  void dispose() {
    _logoutController.close();
  }
}
