import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import '../constants/api_config.dart';
import '../core/network/dio_client.dart';
import '../core/network/token_manager.dart';
import '../services/auth_service.dart';

import '../constants/floating_navbar.dart';
import '../constants/app_colors.dart';
import 'device_list_page.dart';
import 'devices_page.dart';
import 'scan_page.dart';
import 'history_page.dart';
import 'profile_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  // --- CORE SERVICES ---
  final Dio _dio = DioClient().dio;
  final AuthService _authService = AuthService();
  Timer? _statusTimer;
  String? _activeDeviceId;
  bool _isDeviceOnline = false;
  bool _isCheckingStatus = true;

  // --- VARIABEL PROFIL DINAMIS ---
  String _greeting = 'Halo';
  String _userName = 'Memuat...';
  String _pictureUrl = '';

  // --- VARIABEL NOTIFIKASI ---
  List<dynamic> _notifications = [];
  int _notificationCount = 0;

  @override
  void initState() {
    super.initState();
    _setDynamicGreeting();
    _loadUserProfile();
    _initializeDeviceStatus();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  // --- 1. LOGIKA UCAPAN WAKTU DINAMIS ---
  void _setDynamicGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 11) {
      _greeting = 'Selamat Pagi';
    } else if (hour >= 11 && hour < 15) {
      _greeting = 'Selamat Siang';
    } else if (hour >= 15 && hour < 18) {
      _greeting = 'Selamat Sore';
    } else {
      _greeting = 'Selamat Malam';
    }
  }

  // --- 2. LOGIKA NAMA & FOTO USER API (/users/me) via DioClient ---
  Future<void> _loadUserProfile() async {
    try {
      final response = await _dio.get(ApiConfig.usersUrl);

      final data = response.data;
      String fetchedName = data['full_name'] ?? data['name'] ?? data['email'].toString().split('@')[0] ?? 'Peternak';
      String fetchedPic = data['picture'] ?? '';

      // Backfill user UUID into TokenManager.
      final String? userId = data['id'] as String?;
      if (userId != null && userId.isNotEmpty) {
        final tokenManager = TokenManager();
        final existingId = await tokenManager.getUserId();
        if (existingId == null || existingId.isEmpty) {
          await tokenManager.saveUserInfo(
            id: userId,
            email: data['email'] as String? ?? '',
            role: data['role'] as String? ?? '',
          );
        }
      }

      if (mounted) {
        setState(() {
          _userName = fetchedName;
          _pictureUrl = fetchedPic;
        });
      }
    } on DioException catch (_) {
      // 401 triggers global logout via interceptor; other errors are non-fatal here
      if (mounted) setState(() => _userName = 'Peternak');
    } catch (e) {
      developer.log('✗ Error loading profile: $e', name: 'HomeScreen');
      if (mounted) setState(() => _userName = 'Peternak');
    }
  }

  // --- 3. LOGIKA MENCARI DEVICE & CEK STATUS & CEK NOTIF (via DioClient) ---
  Future<void> _initializeDeviceStatus() async {
    try {
      final response = await _dio.get(ApiConfig.devicesUrl);

      final data = response.data;
      // Backend returns paginated response: { data: [...], total: N, ... }
      final List devices = data is Map ? (data['data'] as List? ?? []) : (data is List ? data : []);
      if (devices.isNotEmpty) {
        _activeDeviceId = devices[0]['id'].toString();

        await _checkOnlineStatus();
        await _fetchNotifications();

        _statusTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
          _checkOnlineStatus();
          _fetchNotifications();
        });
      } else {
        if (mounted) {
          setState(() {
            _isCheckingStatus = false;
            _isDeviceOnline = false;
          });
        }
      }
    } on DioException catch (_) {
      // 401 triggers global logout via interceptor; other errors are non-fatal
      if (mounted) {
        setState(() {
          _isCheckingStatus = false;
          _isDeviceOnline = false;
        });
      }
    } catch (e) {
      developer.log('✗ Error initializing device status: $e', name: 'HomeScreen');
      if (mounted) {
        setState(() {
          _isCheckingStatus = false;
          _isDeviceOnline = false;
        });
      }
    }
  }

  Future<void> _checkOnlineStatus() async {
    if (_activeDeviceId == null) return;
    try {
      final response = await _dio.get(ApiConfig.deviceStatusUrl(_activeDeviceId!));
      final data = response.data;
      if (mounted) {
        setState(() {
          _isDeviceOnline = data['is_online'] ?? false;
          _isCheckingStatus = false;
        });
      }
    } on DioException catch (_) {
      if (mounted) {
        setState(() {
          _isDeviceOnline = false;
          _isCheckingStatus = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDeviceOnline = false;
          _isCheckingStatus = false;
        });
      }
    }
  }

  // --- 4. LOGIKA AMBIL NOTIFIKASI ALERTS (via DioClient) ---
  Future<void> _fetchNotifications() async {
    if (_activeDeviceId == null) return;
    try {
      final response = await _dio.get(ApiConfig.deviceAlertsUrl(_activeDeviceId!));

      final data = response.data;
      // Backend returns paginated response: { data: [...], total: N, ... }
      final List alerts = data is Map ? (data['data'] as List? ?? []) : (data is List ? data : []);
      if (mounted) {
        setState(() {
          _notifications = alerts;
          _notificationCount = alerts.length;
        });
      }
    } on DioException catch (_) {
      // Non-fatal — silently fail for background polling
    } catch (e) {
      developer.log('✗ Error fetching notifications: $e', name: 'HomeScreen');
    }
  }

  // Helper Format Waktu Notifikasi
  String _formatDate(String isoTime) {
    try {
      final date = DateTime.parse(isoTime).toLocal();
      return "${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return "--:--";
    }
  }

  // --- 5. BOTTOM SHEET NOTIFIKASI ---
  void _showNotificationsSheet(BuildContext context) {
    // Kalau mau bikin angka notifnya hilang setelah dibuka, nyalain ini:
    // setState(() => _notificationCount = 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Biar bisa tinggi
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6, // Setinggi 60% layar
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle Bar Atas
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),

              // Header Notifikasi
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Notifikasi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFE74C3C).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Text('${_notifications.length} Bahaya', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFE74C3C))),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.borderLight),

              // Isi Daftar Notifikasi
              Expanded(
                child: _notifications.isEmpty
                    ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_rounded, size: 60, color: AppColors.textTertiary),
                      SizedBox(height: 16),
                      Text('Belum ada notifikasi baru', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      SizedBox(height: 4),
                      Text('Kondisi kandang aman terkendali.', style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _notifications.length,
                  itemBuilder: (context, index) {
                    final notif = _notifications[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderLight, width: 1),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(color: const Color(0xFFE74C3C).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.warning_rounded, color: Color(0xFFE74C3C), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Peringatan Kondisi Kandang', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                const SizedBox(height: 4),
                                Text(
                                  notif['alert_message'] ?? 'Ada parameter sensor yang tidak normal.',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary, height: 1.4),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _formatDate(notif['timestamp']),
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textTertiary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- BUILDER UTAMA ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _currentIndex == 0 ? _buildAppBar() : null,
      body: Column(
        children: [
          Expanded(child: _buildPageContent()),

          FloatingNavBar(
            currentIndex: _currentIndex,
            onItemSelected: (index) {
              setState(() => _currentIndex = index);
            },
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    Color badgeColor = _isCheckingStatus
        ? Colors.grey
        : (_isDeviceOnline ? const Color(0xFF4CAF50) : const Color(0xFFE74C3C));

    String badgeText = _isCheckingStatus
        ? 'CEK STATUS'
        : (_isDeviceOnline ? 'ONLINE' : 'OFFLINE');

    return AppBar(
      backgroundColor: const Color(0xFF4A3728),
      elevation: 0,
      toolbarHeight: 80,
      automaticallyImplyLeading: false,
      flexibleSpace: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFD4A574).withOpacity(0.5),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: ClipOval(
                child: _pictureUrl.isNotEmpty
                    ? Image.network(_pictureUrl, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, color: Colors.white, size: 30))
                    : const Icon(Icons.person, color: Colors.white, size: 30),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_greeting, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFFD4A574), height: 1.0)),
                  Text('Hai, $_userName', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white, height: 1.0)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(13)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(badgeText, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white, height: 1.0)),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // --- TOMBOL NOTIFIKASI YANG BISA DI-KLIK ---
            GestureDetector(
              onTap: () => _showNotificationsSheet(context), // Panggil Bottom Sheet pas diklik
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                    ),
                    child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 22),
                  ),
                  if (_notificationCount > 0)
                    Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(color: Color(0xFFE74C3C), shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(
                        _notificationCount > 9 ? '9+' : _notificationCount.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, height: 1.0),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent() {
    switch (_currentIndex) {
      case 0: return const DeviceListPage();
      case 1: return const DevicesPage();
      case 2: return const ScanPage();
      case 3: return const HistoryPage();
      case 4: return const ProfilePage();
      default: return const DeviceListPage();
    }
  }
}