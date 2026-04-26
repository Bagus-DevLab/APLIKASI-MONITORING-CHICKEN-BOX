/// Custom exception classes matching the API contract error codes
/// 
/// Based on API_CONTRACT.md Section 2: HTTP Error Dictionary
library;

/// Base exception for all API errors
abstract class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? requestId;

  ApiException(this.message, {this.statusCode, this.requestId});

  @override
  String toString() {
    final buffer = StringBuffer('ApiException: $message');
    if (statusCode != null) buffer.write(' (HTTP $statusCode)');
    if (requestId != null) buffer.write(' [Request ID: $requestId]');
    return buffer.toString();
  }
}

/// 401 Unauthorized - Invalid/expired JWT or account deactivated
/// Client Action: Redirect to login, clear stored token
class UnauthorizedException extends ApiException {
  UnauthorizedException(
    String message, {
    String? requestId,
  }) : super(message, statusCode: 401, requestId: requestId);
}

/// 403 Forbidden - Insufficient permissions or account deactivated on login
/// Client Action: Show message, do NOT retry
class ForbiddenException extends ApiException {
  ForbiddenException(
    String message, {
    String? requestId,
  }) : super(message, statusCode: 403, requestId: requestId);
}

/// 404 Not Found - Resource doesn't exist or user lacks access
/// Client Action: Show "not found" message
class NotFoundException extends ApiException {
  NotFoundException(
    String message, {
    String? requestId,
  }) : super(message, statusCode: 404, requestId: requestId);
}

/// 422 Validation Error - Pydantic constraint violated
/// Client Action: Parse detail array, highlight invalid fields in UI
class ValidationException extends ApiException {
  final List<ValidationError> errors;

  ValidationException(
    String message,
    this.errors, {
    String? requestId,
  }) : super(message, statusCode: 422, requestId: requestId);

  /// Get all error messages as a single string
  String get allMessages => errors.map((e) => e.msg).join('\n');

  /// Get errors for a specific field
  List<ValidationError> getFieldErrors(String fieldName) {
    return errors.where((e) => e.field == fieldName).toList();
  }
}

/// 429 Rate Limit Exceeded - Too many requests from same IP
/// Client Action: Show "please wait" message, implement exponential backoff
class RateLimitException extends ApiException {
  RateLimitException({
    String? requestId,
  }) : super(
          'Terlalu banyak permintaan. Silakan tunggu sebentar.',
          statusCode: 429,
          requestId: requestId,
        );
}

/// 400 Bad Request - Invalid business logic
/// Client Action: Show detail message to user
class BadRequestException extends ApiException {
  BadRequestException(
    String message, {
    String? requestId,
  }) : super(message, statusCode: 400, requestId: requestId);
}

/// 500 Internal Server Error - Unhandled exception on server
/// Client Action: Show generic error, retry once, then fail gracefully
class ServerException extends ApiException {
  ServerException(
    String message, {
    String? requestId,
  }) : super(message, statusCode: 500, requestId: requestId);
}

/// 503 Service Unavailable - Database unreachable
/// Client Action: Show "server maintenance" message
class ServiceUnavailableException extends ApiException {
  ServiceUnavailableException(
    String message, {
    String? requestId,
  }) : super(message, statusCode: 503, requestId: requestId);
}

/// Network error (no internet, timeout, etc.)
class NetworkException extends ApiException {
  NetworkException(String message) : super(message);
}

/// Unknown error (catch-all)
class UnknownException extends ApiException {
  UnknownException(String message, {int? statusCode, String? requestId})
      : super(message, statusCode: statusCode, requestId: requestId);
}

/// Validation error detail from 422 responses
/// Matches the structure from API_CONTRACT.md Section 2
class ValidationError {
  final List<String> loc;
  final String msg;
  final String type;

  ValidationError({
    required this.loc,
    required this.msg,
    required this.type,
  });

  /// Get the field name from the location array
  /// Example: ["body", "id_token"] -> "id_token"
  String get field => loc.length > 1 ? loc[1] : loc.first;

  factory ValidationError.fromJson(Map<String, dynamic> json) {
    return ValidationError(
      loc: List<String>.from(json['loc'] ?? []),
      msg: json['msg'] ?? 'Validation error',
      type: json['type'] ?? 'unknown',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'loc': loc,
      'msg': msg,
      'type': type,
    };
  }

  @override
  String toString() => '$field: $msg';
}
