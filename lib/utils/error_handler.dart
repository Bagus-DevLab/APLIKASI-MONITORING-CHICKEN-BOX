import 'package:flutter/material.dart';
import '../core/network/api_exception.dart';
import '../constants/app_colors.dart';

/// Centralized error handling utilities for consistent UI feedback
/// 
/// Provides standardized methods for displaying errors, success messages,
/// and handling different types of ApiException with appropriate UI feedback.
/// 
/// Usage:
/// ```dart
/// try {
///   await deviceService.controlDevice(...);
///   ErrorHandler.showSuccessSnackbar(context, 'Kipas berhasil dinyalakan');
/// } on ApiException catch (e) {
///   ErrorHandler.handleApiException(context, e, onRetry: _loadDevices);
/// }
/// ```
class ErrorHandler {
  /// Show error dialog with title and message
  static void showErrorDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
            ),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  /// Show validation error dialog with field-level errors
  /// 
  /// Displays a list of validation errors from a 422 response
  static void showValidationErrorDialog(
    BuildContext context,
    ValidationException exception,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Validasi Gagal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.orange,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Terjadi kesalahan validasi:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...exception.errors.map((error) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.arrow_right,
                    size: 20,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${error.field}: ${error.msg}',
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
            ),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  /// Show success snackbar with green background
  static void showSuccessSnackbar(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primaryGreen,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Show error snackbar with red background
  static void showErrorSnackbar(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Show rate limit snackbar with orange background and longer duration
  static void showRateLimitSnackbar(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.timer, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Show network error snackbar with retry action
  static void showNetworkErrorSnackbar(
    BuildContext context,
    String message,
    VoidCallback onRetry,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.wifi_off, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: SnackBarAction(
          label: 'Coba Lagi',
          textColor: Colors.white,
          onPressed: onRetry,
        ),
      ),
    );
  }

  /// Handle ApiException and show appropriate UI feedback
  /// 
  /// This is the main entry point for error handling.
  /// It automatically determines the error type and shows the appropriate UI.
  /// 
  /// Parameters:
  /// - [context]: BuildContext for showing dialogs/snackbars
  /// - [exception]: The ApiException to handle
  /// - [onRetry]: Optional callback for retry action (used with NetworkException)
  static void handleApiException(
    BuildContext context,
    ApiException exception, {
    VoidCallback? onRetry,
  }) {
    if (exception is ValidationException) {
      // 422 - Show field-level validation errors
      showValidationErrorDialog(context, exception);
    } else if (exception is ForbiddenException) {
      // 403 - Permission denied
      showErrorDialog(context, 'Akses Ditolak', exception.message);
    } else if (exception is NotFoundException) {
      // 404 - Resource not found
      showErrorDialog(context, 'Tidak Ditemukan', exception.message);
    } else if (exception is BadRequestException) {
      // 400 - Bad request
      showErrorDialog(context, 'Permintaan Tidak Valid', exception.message);
    } else if (exception is RateLimitException) {
      // 429 - Rate limit exceeded
      showRateLimitSnackbar(context, exception.message);
    } else if (exception is NetworkException) {
      // Network error - show with retry option
      if (onRetry != null) {
        showNetworkErrorSnackbar(context, exception.message, onRetry);
      } else {
        showErrorSnackbar(context, exception.message);
      }
    } else if (exception is ServerException) {
      // 500 - Server error
      showErrorDialog(
        context,
        'Kesalahan Server',
        '${exception.message}\n\nSilakan coba lagi nanti.',
      );
    } else if (exception is ServiceUnavailableException) {
      // 503 - Service unavailable
      showErrorDialog(
        context,
        'Server Maintenance',
        '${exception.message}\n\nLayanan sedang dalam pemeliharaan.',
      );
    } else {
      // Unknown error
      showErrorDialog(context, 'Kesalahan', exception.message);
    }
  }

  /// Show loading dialog (for blocking operations)
  static void showLoadingDialog(BuildContext context, {String? message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primaryGreen),
                if (message != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Hide loading dialog
  static void hideLoadingDialog(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }
}
