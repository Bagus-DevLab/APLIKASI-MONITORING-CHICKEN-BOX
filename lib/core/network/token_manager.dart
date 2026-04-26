import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:developer' as developer;

/// Manages JWT token storage and provides logout event stream
///
/// Uses flutter_secure_storage for secure token persistence.
/// Provides a stream for global logout events (401/403 errors).
///
/// Resilience:
/// - `resetOnError: true` tells the plugin to auto-clear corrupted data
///   instead of throwing on Android Keystore / EncryptedSharedPreferences
///   decryption failures.
/// - Every read/write catches `PlatformException` with BadPaddingException
///   detection and calls [detectAndClearCorruption] as a safety net.
/// - Android Auto Backup is disabled in AndroidManifest.xml to prevent
///   the root cause (restored encrypted prefs without the Keystore key).
class TokenManager {
  static final TokenManager _instance = TokenManager._internal();
  factory TokenManager() => _instance;
  TokenManager._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: true,
    ),
  );

  static const String _tokenKey = 'jwt_token';
  static const String _userEmailKey = 'user_email';
  static const String _userRoleKey = 'user_role';

  /// Stream controller for logout events
  /// Listen to this stream to handle global logout (e.g., navigate to login screen)
  final StreamController<void> _logoutController =
      StreamController<void>.broadcast();
  Stream<void> get onLogout => _logoutController.stream;

  // ═══════════════════════════════════════════════════════════════
  // CORRUPTION DETECTION
  // ═══════════════════════════════════════════════════════════════

  /// Check whether a [PlatformException] is caused by Android Keystore
  /// corruption (BadPaddingException / BAD_DECRYPT / InvalidKeyException).
  ///
  /// This happens when Android Auto Backup restores the encrypted
  /// SharedPreferences XML but NOT the hardware-backed Keystore key.
  static bool _isKeystoreCorruption(PlatformException e) {
    final msg = '${e.code} ${e.message} ${e.details}'.toLowerCase();
    return msg.contains('badpaddingexception') ||
        msg.contains('bad_decrypt') ||
        msg.contains('invalidkeyexception') ||
        msg.contains('failed to unwrap key') ||
        msg.contains('data migration failed');
  }

  /// Detect and clear corrupted secure storage.
  ///
  /// Returns `true` if corruption was detected and storage was wiped.
  /// Returns `false` if storage is healthy.
  ///
  /// Call this:
  /// - On app startup (in main.dart) as a proactive health check
  /// - Inside any catch block that encounters a PlatformException
  Future<bool> detectAndClearCorruption() async {
    try {
      // Probe read — if this succeeds, storage is healthy
      await _storage.read(key: _tokenKey);
      return false;
    } on PlatformException catch (e) {
      if (_isKeystoreCorruption(e)) {
        developer.log(
          '⚠ Secure storage corruption detected: ${e.message}',
          name: 'TokenManager',
        );

        try {
          await _storage.deleteAll();
          developer.log(
            '✓ Corrupted storage cleared successfully',
            name: 'TokenManager',
          );
        } catch (clearError) {
          developer.log(
            '✗ Failed to clear corrupted storage: $clearError',
            name: 'TokenManager',
            error: clearError,
          );
        }
        return true;
      }
      // Non-corruption PlatformException — don't wipe
      developer.log(
        '✗ Non-corruption PlatformException in probe: ${e.message}',
        name: 'TokenManager',
        error: e,
      );
      return false;
    } catch (e) {
      developer.log(
        '✗ Unexpected error during corruption check: $e',
        name: 'TokenManager',
        error: e,
      );
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // TOKEN OPERATIONS
  // ═══════════════════════════════════════════════════════════════

  /// Save JWT token to secure storage
  Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
      developer.log('✓ JWT token saved to secure storage', name: 'TokenManager');
    } on PlatformException catch (e) {
      if (_isKeystoreCorruption(e)) {
        developer.log(
          '⚠ Keystore corruption on saveToken — clearing storage',
          name: 'TokenManager',
        );
        await detectAndClearCorruption();
      }
      developer.log('✗ Failed to save token: $e', name: 'TokenManager', error: e);
      rethrow;
    } catch (e) {
      developer.log('✗ Failed to save token: $e', name: 'TokenManager', error: e);
      rethrow;
    }
  }

  /// Get JWT token from secure storage
  ///
  /// Returns `null` if the token doesn't exist or if storage is corrupted.
  /// On corruption, automatically clears all data so the next write succeeds.
  Future<String?> getToken() async {
    try {
      return await _storage.read(key: _tokenKey);
    } on PlatformException catch (e) {
      if (_isKeystoreCorruption(e)) {
        developer.log(
          '⚠ Keystore corruption on getToken — clearing storage',
          name: 'TokenManager',
        );
        await detectAndClearCorruption();
        return null;
      }
      developer.log('✗ Failed to read token: $e', name: 'TokenManager', error: e);
      return null;
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

  // ═══════════════════════════════════════════════════════════════
  // USER INFO OPERATIONS
  // ═══════════════════════════════════════════════════════════════

  /// Save user info (email and role) to secure storage
  Future<void> saveUserInfo({
    required String email,
    required String role,
  }) async {
    try {
      await _storage.write(key: _userEmailKey, value: email);
      await _storage.write(key: _userRoleKey, value: role);
      developer.log('✓ User info saved: $email ($role)', name: 'TokenManager');
    } on PlatformException catch (e) {
      if (_isKeystoreCorruption(e)) {
        developer.log(
          '⚠ Keystore corruption on saveUserInfo — clearing storage',
          name: 'TokenManager',
        );
        await detectAndClearCorruption();
      }
      developer.log(
        '✗ Failed to save user info: $e',
        name: 'TokenManager',
        error: e,
      );
    } catch (e) {
      developer.log(
        '✗ Failed to save user info: $e',
        name: 'TokenManager',
        error: e,
      );
    }
  }

  /// Get user email from secure storage
  Future<String?> getUserEmail() async {
    try {
      return await _storage.read(key: _userEmailKey);
    } on PlatformException catch (e) {
      if (_isKeystoreCorruption(e)) {
        developer.log(
          '⚠ Keystore corruption on getUserEmail — clearing storage',
          name: 'TokenManager',
        );
        await detectAndClearCorruption();
        return null;
      }
      developer.log(
        '✗ Failed to read user email: $e',
        name: 'TokenManager',
        error: e,
      );
      return null;
    } catch (e) {
      developer.log(
        '✗ Failed to read user email: $e',
        name: 'TokenManager',
        error: e,
      );
      return null;
    }
  }

  /// Get user role from secure storage
  Future<String?> getUserRole() async {
    try {
      return await _storage.read(key: _userRoleKey);
    } on PlatformException catch (e) {
      if (_isKeystoreCorruption(e)) {
        developer.log(
          '⚠ Keystore corruption on getUserRole — clearing storage',
          name: 'TokenManager',
        );
        await detectAndClearCorruption();
        return null;
      }
      developer.log(
        '✗ Failed to read user role: $e',
        name: 'TokenManager',
        error: e,
      );
      return null;
    } catch (e) {
      developer.log(
        '✗ Failed to read user role: $e',
        name: 'TokenManager',
        error: e,
      );
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // CLEANUP & LIFECYCLE
  // ═══════════════════════════════════════════════════════════════

  /// Clear all stored authentication data
  /// Called on logout or when 401/403 errors occur
  Future<void> clearAuth() async {
    try {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _userEmailKey);
      await _storage.delete(key: _userRoleKey);
      developer.log('✓ All auth data cleared', name: 'TokenManager');
    } on PlatformException catch (e) {
      if (_isKeystoreCorruption(e)) {
        developer.log(
          '⚠ Keystore corruption on clearAuth — wiping all storage',
          name: 'TokenManager',
        );
        try {
          await _storage.deleteAll();
        } catch (_) {
          // Last resort — nothing more we can do
        }
        return;
      }
      developer.log(
        '✗ Failed to clear auth data: $e',
        name: 'TokenManager',
        error: e,
      );
    } catch (e) {
      developer.log(
        '✗ Failed to clear auth data: $e',
        name: 'TokenManager',
        error: e,
      );
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
