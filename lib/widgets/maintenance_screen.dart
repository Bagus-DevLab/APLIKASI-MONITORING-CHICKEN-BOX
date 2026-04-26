import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Full-screen maintenance overlay shown when the backend returns 503.
///
/// Features:
/// - Blocks all interaction (user cannot navigate away)
/// - Material Icons illustration (chicken + wrench)
/// - Auto-retry every 30 seconds via [onRetry] callback
/// - Manual "Coba Lagi" button
///
/// Usage from a parent widget:
/// ```dart
/// if (_isMaintenanceMode) {
///   return MaintenanceScreen(onRetry: _checkServerHealth);
/// }
/// ```
class MaintenanceScreen extends StatefulWidget {
  /// Callback to check if the server is back online.
  /// Should set maintenance mode to false when successful.
  final VoidCallback onRetry;

  const MaintenanceScreen({super.key, required this.onRetry});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen> {
  Timer? _autoRetryTimer;
  int _secondsUntilRetry = 30;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startAutoRetry();
  }

  @override
  void dispose() {
    _autoRetryTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startAutoRetry() {
    _secondsUntilRetry = 30;

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() => _secondsUntilRetry--);
      }
    });

    _autoRetryTimer?.cancel();
    _autoRetryTimer = Timer(const Duration(seconds: 30), () {
      widget.onRetry();
      if (mounted) _startAutoRetry(); // Reset countdown
    });
  }

  void _handleManualRetry() {
    widget.onRetry();
    _startAutoRetry(); // Reset countdown
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0EB),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Illustration: chicken with wrench
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.accentOrange.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        Icons.egg_rounded,
                        size: 56,
                        color: AppColors.accentOrange.withValues(alpha: 0.6),
                      ),
                      const Positioned(
                        bottom: 20,
                        right: 22,
                        child: Icon(
                          Icons.build_rounded,
                          size: 32,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                const Text(
                  'Server Lagi Maintenance, Bro!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 12),

                // Description
                const Text(
                  'Kami lagi upgrade sistem biar makin kenceng.\n'
                  'Balik lagi nanti ya, paling 10-15 menit!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),

                // Countdown
                Text(
                  'Cek otomatis dalam ${_secondsUntilRetry}s...',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),

                // Manual retry button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _handleManualRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text(
                      'Coba Lagi Sekarang',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
