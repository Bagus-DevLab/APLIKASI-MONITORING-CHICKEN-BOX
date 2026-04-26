import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:developer' as developer;
import '../core/network/dio_client.dart';
import '../constants/api_config.dart';
import '../constants/app_colors.dart';

/// Persistent banner that appears at the top of the screen when the device
/// has no internet connectivity.
///
/// Uses a lightweight periodic health check against the backend's base URL
/// to detect connectivity state. The banner slides in/out with animation.
///
/// Wrap your [MaterialApp]'s home widget with this:
/// ```dart
/// home: OfflineBanner(child: startPage)
/// ```
class OfflineBanner extends StatefulWidget {
  final Widget child;

  const OfflineBanner({super.key, required this.child});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _isOffline = false;
  Timer? _connectivityTimer;

  @override
  void initState() {
    super.initState();
    // Start checking connectivity after the first frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkConnectivity();
      // Re-check every 10 seconds
      _connectivityTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _checkConnectivity(),
      );
    });
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    super.dispose();
  }

  /// Lightweight connectivity probe.
  ///
  /// Sends a HEAD request to the backend with a very short timeout.
  /// We only care about whether the network is reachable, not the
  /// response content. Even a 401/403/500 means "we're online".
  Future<void> _checkConnectivity() async {
    try {
      // Use a separate Dio instance with a short timeout so we don't
      // interfere with the main DioClient's interceptor chain.
      final probe = Dio(BaseOptions(
        baseUrl: DioClient().dio.options.baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        // Accept ANY status — we only care about reachability
        validateStatus: (_) => true,
      ));

      await probe.head(ApiConfig.healthUrl);

      // If we reach here, the server responded — we're online
      if (mounted && _isOffline) {
        setState(() => _isOffline = false);
        developer.log('✓ Back online', name: 'OfflineBanner');
      }
    } catch (e) {
      // Any exception means we can't reach the server
      if (mounted && !_isOffline) {
        setState(() => _isOffline = true);
        developer.log('✗ Offline detected', name: 'OfflineBanner');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Animated banner that slides in/out
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _isOffline ? 48 : 0,
          child: _isOffline
              ? Material(
                  color: AppColors.error,
                  child: SafeArea(
                    bottom: false,
                    child: SizedBox(
                      height: 48,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.wifi_off_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Waduh, Nggak Ada Internet!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: _checkConnectivity,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Cek Ulang',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        // Main content
        Expanded(child: widget.child),
      ],
    );
  }
}
