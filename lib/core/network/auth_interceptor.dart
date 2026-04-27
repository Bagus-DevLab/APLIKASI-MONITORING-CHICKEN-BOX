import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'api_exception.dart';
import 'token_manager.dart';
import 'dio_client.dart';
import '../../constants/api_config.dart';
import '../../widgets/maintenance_screen.dart';

/// Dio interceptor that handles:
/// 1. Automatic JWT Bearer token injection
/// 2. Global error handling based on API contract
/// 3. Request ID logging
/// 4. Automatic logout on 401 errors (403 stays logged in)
/// 5. Global maintenance mode on 503 errors (blocks entire app)
/// 
/// Based on API_CONTRACT.md Section 2: HTTP Error Dictionary
class AuthInterceptor extends Interceptor {
  final TokenManager _tokenManager = TokenManager();

  /// Global navigator key — set by main.dart so the interceptor can
  /// push the MaintenanceScreen route without a BuildContext.
  static GlobalKey<NavigatorState>? navigatorKey;

  /// Prevents pushing multiple MaintenanceScreen routes simultaneously.
  static bool _isMaintenanceScreenShowing = false;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip token injection for login endpoint (it's unauthenticated)
    final isLoginEndpoint = options.path.contains('/auth/firebase/login');
    final isHealthEndpoint = options.path.contains('/health');

    if (!isLoginEndpoint && !isHealthEndpoint) {
      // Inject JWT Bearer token
      final token = await _tokenManager.getToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
        developer.log(
          '→ Injected Bearer token for ${options.method} ${options.path}',
          name: 'AuthInterceptor',
        );
      } else {
        developer.log(
          '⚠ No token available for ${options.method} ${options.path}',
          name: 'AuthInterceptor',
        );
      }
    }

    handler.next(options);
  }

  @override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    // Log X-Request-ID header for debugging
    final requestId = response.headers.value('x-request-id');
    if (requestId != null) {
      developer.log(
        '← Response [${response.statusCode}] Request-ID: $requestId',
        name: 'AuthInterceptor',
      );
    }

    handler.next(response);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final requestId = err.response?.headers.value('x-request-id');
    final statusCode = err.response?.statusCode;

    developer.log(
      '✗ Error [${statusCode ?? 'N/A'}] ${err.requestOptions.method} ${err.requestOptions.path}',
      name: 'AuthInterceptor',
      error: err.message,
    );

    if (requestId != null) {
      developer.log('  Request-ID: $requestId', name: 'AuthInterceptor');
    }

    // Handle different error types based on API contract
    ApiException exception;

    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout) {
      exception = NetworkException('Koneksi timeout. Periksa jaringan Anda.');
    } else if (err.type == DioExceptionType.connectionError) {
      exception = NetworkException('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } else if (err.response != null) {
      // Server responded with an error
      exception = _handleHttpError(err.response!, requestId);

      // Trigger logout ONLY for 401 (token expired/invalid).
      // 403 means "authenticated but forbidden" — user stays logged in
      // and sees a friendly "Akses Ditolak" snackbar instead.
      if (statusCode == 401) {
        developer.log(
          '⚠ Token expired/invalid (401). Clearing auth and triggering logout.',
          name: 'AuthInterceptor',
        );
        await _tokenManager.clearAuth();
        _tokenManager.triggerLogout();
      }

      // Trigger full-screen maintenance mode for 503 (server down).
      // This blocks the entire app until the server is back online.
      // Offline banner takes precedence: if there's no internet, the
      // user can't even reach the server to get a 503.
      if (statusCode == 503) {
        developer.log(
          '⚠ Server maintenance (503). Showing MaintenanceScreen.',
          name: 'AuthInterceptor',
        );
        _showMaintenanceScreen();
      }
    } else {
      exception = UnknownException(
        err.message ?? 'Terjadi kesalahan yang tidak diketahui',
      );
    }

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        type: err.type,
        error: exception,
      ),
    );
  }

  /// Push a full-screen [MaintenanceScreen] route that traps the user
  /// until the backend health check passes.
  ///
  /// Uses [navigatorKey] (set by main.dart) so we don't need a BuildContext.
  /// The [_isMaintenanceScreenShowing] flag prevents duplicate pushes when
  /// multiple API calls fail with 503 simultaneously.
  void _showMaintenanceScreen() {
    if (_isMaintenanceScreenShowing) return;

    final navigator = navigatorKey?.currentState;
    if (navigator == null) {
      developer.log(
        '✗ navigatorKey is null — cannot show MaintenanceScreen',
        name: 'AuthInterceptor',
      );
      return;
    }

    _isMaintenanceScreenShowing = true;

    navigator.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => PopScope(
          // Trap the user — back button does nothing
          canPop: false,
          child: MaintenanceScreen(
            onRetry: () => _checkHealthAndDismiss(navigator),
          ),
        ),
      ),
    );
  }

  /// Check the backend health endpoint. If the server is back online,
  /// pop the MaintenanceScreen and allow the user to continue.
  Future<void> _checkHealthAndDismiss(NavigatorState navigator) async {
    try {
      // Use a separate Dio instance to avoid triggering this interceptor
      // again (which would cause an infinite loop on 503).
      final probe = Dio(BaseOptions(
        baseUrl: DioClient().dio.options.baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        validateStatus: (status) => status != null && status >= 200 && status < 300,
      ));

      await probe.get(ApiConfig.healthUrl);

      // If we reach here, the server is back online
      developer.log(
        '✓ Server is back online — dismissing MaintenanceScreen',
        name: 'AuthInterceptor',
      );

      _isMaintenanceScreenShowing = false;
      if (navigator.canPop()) {
        navigator.pop();
      }
    } catch (e) {
      developer.log(
        '✗ Server still down: $e',
        name: 'AuthInterceptor',
      );
      // MaintenanceScreen stays — its auto-retry will call us again
    }
  }

  /// Handle HTTP errors based on status code and response format
  /// Follows API_CONTRACT.md Section 2: HTTP Error Dictionary
  ApiException _handleHttpError(Response response, String? requestId) {
    final statusCode = response.statusCode ?? 0;
    final data = response.data;

    // Extract error message from response
    String errorMessage = 'Terjadi kesalahan';

    try {
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];

        // Handle 422 Validation Error (detail is an array)
        if (statusCode == 422 && detail is List) {
          final errors = detail
              .map((e) => ValidationError.fromJson(e as Map<String, dynamic>))
              .toList();
          errorMessage = errors.map((e) => e.msg).join('\n');
          return ValidationException(errorMessage, errors, requestId: requestId);
        }

        // Handle generic errors (detail is a string)
        if (detail is String) {
          errorMessage = detail;
        }
      } else if (data is String) {
        errorMessage = data;
      }
    } catch (e) {
      developer.log(
        '✗ Failed to parse error response: $e',
        name: 'AuthInterceptor',
        error: e,
      );
    }

    // Map status codes to specific exceptions
    switch (statusCode) {
      case 400:
        return BadRequestException(errorMessage, requestId: requestId);
      case 401:
        return UnauthorizedException(errorMessage, requestId: requestId);
      case 403:
        return ForbiddenException(errorMessage, requestId: requestId);
      case 404:
        return NotFoundException(errorMessage, requestId: requestId);
      case 429:
        return RateLimitException(requestId: requestId);
      case 500:
        return ServerException(errorMessage, requestId: requestId);
      case 503:
        return ServiceUnavailableException(errorMessage, requestId: requestId);
      default:
        return UnknownException(
          errorMessage,
          statusCode: statusCode,
          requestId: requestId,
        );
    }
  }
}
