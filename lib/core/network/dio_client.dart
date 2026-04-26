import 'package:dio/dio.dart';
import 'dart:developer' as developer;
import 'auth_interceptor.dart';

/// Singleton Dio client with pre-configured interceptors and settings
/// 
/// Features:
/// - Automatic JWT Bearer token injection
/// - Global error handling (401/403 triggers logout)
/// - Request ID logging
/// - Timeout configuration
/// - JSON content type headers
/// 
/// Usage:
/// ```dart
/// final dio = DioClient().dio;
/// final response = await dio.get('/devices/');
/// ```
class DioClient {
  static final DioClient _instance = DioClient._internal();
  factory DioClient() => _instance;

  late final Dio _dio;
  Dio get dio => _dio;

  DioClient._internal() {
    _dio = Dio(
      BaseOptions(
        // Base URL will be set by ApiConfig
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        // Only treat 2xx as success — 4xx/5xx are routed to onError
        // so AuthInterceptor can map them to typed ApiExceptions.
        validateStatus: (status) => status != null && status >= 200 && status < 300,
      ),
    );

    // Add interceptors
    _dio.interceptors.add(AuthInterceptor());

    // Add logging interceptor in debug mode
    _dio.interceptors.add(
      LogInterceptor(
        requestHeader: false,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        error: true,
        logPrint: (obj) {
          developer.log(obj.toString(), name: 'DioClient');
        },
      ),
    );

    developer.log('✓ DioClient initialized', name: 'DioClient');
  }

  /// Update base URL (called by ApiConfig after loading .env)
  void setBaseUrl(String baseUrl) {
    _dio.options.baseUrl = baseUrl;
    developer.log('✓ Base URL set to: $baseUrl', name: 'DioClient');
  }

  /// Add custom interceptor (for future extensions)
  void addInterceptor(Interceptor interceptor) {
    _dio.interceptors.add(interceptor);
  }

  /// Clear all interceptors (for testing)
  void clearInterceptors() {
    _dio.interceptors.clear();
  }
}
