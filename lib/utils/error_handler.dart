import 'package:flutter/material.dart';
import '../core/network/api_exception.dart';
import '../constants/app_colors.dart';

/// Centralized error handling with humanized Indonesian messages.
///
/// Design philosophy: "Ngobrol Santai, Bukan Formal"
/// — Casual Indonesian that feels like a personal assistant, not a robot.
///
/// UI decision matrix:
/// - Dialog (blocking): 401, 500, 503, Unknown — critical, must acknowledge
/// - SnackBar (temporary): 403, 404, 400, 429, Timeout — informational
/// - SnackBar + Retry: Network errors — actionable
class ErrorHandler {
  // ═══════════════════════════════════════════════════════════════
  // HUMANIZED MESSAGE MAPPER
  // ═══════════════════════════════════════════════════════════════

  /// Map a typed [ApiException] to a casual Indonesian title + message.
  ///
  /// Returns a record of (title, body) for use in dialogs/snackbars.
  static ({String title, String body}) getHumanizedMessage(
    ApiException exception,
  ) {
    // Use the backend's detail message when it's specific enough;
    // fall back to our friendly defaults otherwise.
    final backendMsg = exception.message;

    if (exception is UnauthorizedException) {
      return (
        title: 'Sesi Kamu Udah Habis, Bro!',
        body: 'Token login kamu udah expired nih. '
            'Yuk login lagi biar bisa lanjut ngecek kandang!',
      );
    }

    if (exception is ForbiddenException) {
      return (
        title: 'Waduh, Akses Ditolak!',
        body: backendMsg.isNotEmpty
            ? backendMsg
            : 'Kamu belum punya izin buat akses fitur ini. '
                'Coba hubungi admin kandang ya!',
      );
    }

    if (exception is NotFoundException) {
      return (
        title: 'Eh, Nggak Ketemu Nih!',
        body: backendMsg.isNotEmpty
            ? backendMsg
            : 'Data yang kamu cari kayaknya udah dihapus atau nggak ada. '
                'Coba refresh deh!',
      );
    }

    if (exception is BadRequestException) {
      return (
        title: 'Hmm, Ada yang Salah...',
        body: backendMsg.isNotEmpty
            ? backendMsg
            : 'Permintaan kamu nggak bisa diproses. '
                'Coba cek lagi input-nya ya!',
      );
    }

    if (exception is ValidationException) {
      return (
        title: 'Isi Form-nya Belum Lengkap!',
        body: (exception as ValidationException).allMessages,
      );
    }

    if (exception is RateLimitException) {
      return (
        title: 'Wah, Kebanyakan Request Nih!',
        body: 'Santai dulu ya Bro, tunggu 1 menit baru coba lagi. '
            'Server lagi capek.',
      );
    }

    if (exception is ServerException) {
      return (
        title: 'Aduh, Server Lagi Error!',
        body: 'Ada masalah di server kami nih. '
            'Tim teknis udah dikabarin, coba lagi nanti ya!',
      );
    }

    if (exception is ServiceUnavailableException) {
      return (
        title: 'Server Lagi Maintenance, Bro!',
        body: 'Kami lagi upgrade sistem biar makin kenceng. '
            'Balik lagi nanti ya, paling 10-15 menit!',
      );
    }

    if (exception is NetworkException) {
      final msg = exception.message.toLowerCase();
      if (msg.contains('timeout')) {
        return (
          title: 'Sinyal Lagi Lelet Nih!',
          body: 'Koneksi internet kamu lagi lambat. '
              'Coba cek WiFi atau data seluler ya!',
        );
      }
      return (
        title: 'Waduh, Nggak Ada Internet!',
        body: 'Cek koneksi internet kamu dulu ya. '
            'Kandang Pintar butuh online buat kerja.',
      );
    }

    // UnknownException / catch-all
    return (
      title: 'Hmm, Ada Error Aneh...',
      body: backendMsg.isNotEmpty
          ? backendMsg
          : 'Terjadi kesalahan yang nggak terduga. '
              'Coba restart app atau hubungi support ya!',
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // MAIN ENTRY POINT
  // ═══════════════════════════════════════════════════════════════

  /// Handle [ApiException] and show the appropriate UI feedback.
  ///
  /// Decision matrix:
  /// - 401: Dialog (global logout already triggered by interceptor)
  /// - 403: SnackBar (5 s) — user stays logged in
  /// - 404: SnackBar (3 s)
  /// - 400: SnackBar (4 s)
  /// - 422: Dialog with field-level errors
  /// - 429: Orange SnackBar (6 s)
  /// - 500: Dialog with retry
  /// - 503: Dialog (blocking)
  /// - Network: SnackBar with retry button
  /// - Unknown: Dialog
  static void handleApiException(
    BuildContext context,
    ApiException exception, {
    VoidCallback? onRetry,
  }) {
    final msg = getHumanizedMessage(exception);

    if (exception is ValidationException) {
      showValidationErrorDialog(context, exception);
    } else if (exception is ForbiddenException) {
      // 403 — SnackBar, NOT logout
      showErrorSnackbar(context, '${msg.title} ${msg.body}');
    } else if (exception is NotFoundException) {
      showErrorSnackbar(context, '${msg.title} ${msg.body}');
    } else if (exception is BadRequestException) {
      showErrorSnackbar(context, '${msg.title} ${msg.body}');
    } else if (exception is RateLimitException) {
      showRateLimitSnackbar(context, msg.body);
    } else if (exception is NetworkException) {
      if (onRetry != null) {
        showNetworkErrorSnackbar(context, msg.body, onRetry);
      } else {
        showErrorSnackbar(context, '${msg.title} ${msg.body}');
      }
    } else if (exception is ServerException) {
      showErrorDialog(context, msg.title, msg.body, onRetry: onRetry);
    } else if (exception is ServiceUnavailableException) {
      showErrorDialog(context, msg.title, msg.body);
    } else if (exception is UnauthorizedException) {
      // 401 — global logout already triggered by AuthInterceptor;
      // show a brief dialog so the user knows why they were kicked out.
      showErrorDialog(context, msg.title, msg.body);
    } else {
      showErrorDialog(context, msg.title, msg.body);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // DIALOGS
  // ═══════════════════════════════════════════════════════════════

  /// Show error dialog with title, message, and optional retry button.
  static void showErrorDialog(
    BuildContext context,
    String title,
    String message, {
    VoidCallback? onRetry,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 28),
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
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onRetry();
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
              ),
              child: const Text(
                'Coba Lagi',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
            ),
            child: const Text(
              'OK',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// Show validation error dialog with field-level errors.
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
                'Isi Form-nya Belum Lengkap!',
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
              'Coba cek lagi ya:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...exception.errors.map(
              (error) => Padding(
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
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
            ),
            child: const Text(
              'OK, Paham!',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SNACKBARS
  // ═══════════════════════════════════════════════════════════════

  /// Show success snackbar with green background.
  static void showSuccessSnackbar(BuildContext context, String message) {
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

  /// Show error snackbar with red background.
  static void showErrorSnackbar(BuildContext context, String message) {
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
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Show rate limit snackbar with orange background and longer duration.
  static void showRateLimitSnackbar(BuildContext context, String message) {
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
        duration: const Duration(seconds: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  /// Show network error snackbar with retry action.
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

  // ═══════════════════════════════════════════════════════════════
  // LOADING DIALOG
  // ═══════════════════════════════════════════════════════════════

  /// Show loading dialog (for blocking operations).
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

  /// Hide loading dialog.
  static void hideLoadingDialog(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }
}
