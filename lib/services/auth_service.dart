import 'package:dio/dio.dart';
import 'dart:developer' as developer;
import '../core/network/dio_client.dart';
import '../core/network/token_manager.dart';
import '../core/network/api_exception.dart';
import '../constants/api_config.dart';
import '../models/auth/login_request.dart';
import '../models/auth/login_response.dart';
import '../models/auth/user_info.dart';

/// Authentication service for handling login/logout operations
/// 
/// Based on API_CONTRACT.md Section 3.1: Authentication
/// 
/// Features:
/// - Firebase ID token exchange for JWT
/// - Automatic token storage in secure storage
/// - Token validation (max 4096 chars)
/// - Error handling for all auth-related errors
/// 
/// Usage:
/// ```dart
/// final authService = AuthService();
/// try {
///   final response = await authService.login(firebaseIdToken);
///   print('Logged in as: ${response.userInfo.email}');
/// } on ValidationException catch (e) {
///   print('Validation error: ${e.allMessages}');
/// } on UnauthorizedException catch (e) {
///   print('Auth error: ${e.message}');
/// }
/// ```
class AuthService {
  final Dio _dio = DioClient().dio;
  final TokenManager _tokenManager = TokenManager();

  /// Login with Firebase ID token
  /// 
  /// Endpoint: POST /api/auth/firebase/login
  /// Rate Limit: 10/minute
  /// Auth Required: No
  /// 
  /// Parameters:
  /// - [firebaseIdToken]: Firebase ID token from firebase_auth.currentUser.getIdToken()
  /// 
  /// Returns:
  /// - [LoginResponse] containing JWT access token and user info
  /// 
  /// Throws:
  /// - [ValidationException] if id_token exceeds 4096 chars or is empty
  /// - [UnauthorizedException] if Firebase token is invalid or expired
  /// - [ForbiddenException] if account is deactivated
  /// - [RateLimitException] if rate limit exceeded (10/minute)
  /// - [NetworkException] if network error occurs
  /// 
  /// Side Effects:
  /// - Stores JWT token in secure storage
  /// - Stores user email and role in secure storage
  Future<LoginResponse> login(String firebaseIdToken) async {
    developer.log('→ Attempting login with Firebase token', name: 'AuthService');

    // Validate token length before sending (max 4096 chars per contract)
    final request = LoginRequest(idToken: firebaseIdToken);
    if (!request.isValid()) {
      developer.log(
        '✗ Invalid token: length=${firebaseIdToken.length}',
        name: 'AuthService',
      );
      throw ValidationException(
        'Token Firebase tidak valid (melebihi 4096 karakter)',
        [
          ValidationError(
            loc: ['body', 'id_token'],
            msg: 'Token Firebase tidak valid (melebihi 4096 karakter)',
            type: 'value_error',
          ),
        ],
      );
    }

    try {
      final response = await _dio.post(
        ApiConfig.authFirebaseLoginUrl,
        data: request.toJson(),
      );

      // Parse response (non-2xx are routed to onError by DioClient)
      final loginResponse = LoginResponse.fromJson(response.data);

      // Store token and user info in secure storage
      await _tokenManager.saveToken(loginResponse.accessToken);
      await _tokenManager.saveUserInfo(
        id: loginResponse.userInfo.id ?? '',
        email: loginResponse.userInfo.email,
        role: loginResponse.userInfo.role,
      );

      developer.log(
        '✓ Login successful: ${loginResponse.userInfo.email} (${loginResponse.userInfo.role})',
        name: 'AuthService',
      );

      return loginResponse;
    } on DioException catch (e) {
      // DioException with custom ApiException in error field
      if (e.error is ApiException) {
        developer.log(
          '✗ Login failed: ${e.error}',
          name: 'AuthService',
          error: e.error,
        );
        throw e.error as ApiException;
      }

      // Fallback for unexpected errors
      developer.log(
        '✗ Unexpected error during login: ${e.message}',
        name: 'AuthService',
        error: e,
      );
      throw NetworkException('Terjadi kesalahan jaringan: ${e.message}');
    } catch (e) {
      developer.log(
        '✗ Unexpected error during login: $e',
        name: 'AuthService',
        error: e,
      );
      throw UnknownException('Terjadi kesalahan yang tidak diketahui: $e');
    }
  }

  /// Logout current user
  /// 
  /// Side Effects:
  /// - Clears JWT token from secure storage
  /// - Clears user email and role from secure storage
  /// - Does NOT revoke Firebase session (handle that separately)
  Future<void> logout() async {
    developer.log('→ Logging out user', name: 'AuthService');
    await _tokenManager.clearAuth();
    developer.log('✓ Logout successful', name: 'AuthService');
  }

  /// Check if user is currently authenticated
  /// 
  /// Returns true if JWT token exists in secure storage
  Future<bool> isAuthenticated() async {
    return await _tokenManager.isAuthenticated();
  }

  /// Get current user info from secure storage
  /// 
  /// Returns null if user is not authenticated
  Future<UserInfo?> getCurrentUser() async {
    final id = await _tokenManager.getUserId();
    final email = await _tokenManager.getUserEmail();
    final role = await _tokenManager.getUserRole();

    if (email == null || role == null) {
      return null;
    }

    return UserInfo(
      id: id,
      email: email,
      fullName: email.split('@').first, // Fallback name
      role: role,
    );
  }

  /// Get current JWT token from secure storage
  /// 
  /// Returns null if user is not authenticated
  Future<String?> getToken() async {
    return await _tokenManager.getToken();
  }

  /// Listen to logout events (triggered by 401/403 errors)
  /// 
  /// Usage:
  /// ```dart
  /// authService.onLogout.listen((_) {
  ///   // Navigate to login screen
  ///   Navigator.pushReplacementNamed(context, '/login');
  /// });
  /// ```
  Stream<void> get onLogout => _tokenManager.onLogout;
}
