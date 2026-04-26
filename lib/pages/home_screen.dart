import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_config.dart';

import '../constants/floating_navbar.dart';
import '../constants/app_colors.dart'; // Pastikan ini di-import buat warna Bottom Sheet
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

  // --- VARIABEL STATUS ALAT & NOTIFIKASI ---
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  Timer? _statusTimer;
  String? _activeDeviceId;
  bool _isDeviceOnline = false;
  bool _isCheckingStatus = true;

  // --- VARIABEL PROFIL DINAMIS ---
  String _greeting = 'Halo';
  String _userName = 'Memuat...';
  String _pictureUrl = '';

  // --- VARIABEL NOTIFIKASI ---
  List<dynamic> _notifications = []; // Nampung data notif dari API
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

  // --- 2. LOGIKA NAMA & FOTO USER API (/users/me) ---
  Future<void> _loadUserProfile() async {
    try {
      final token = await _secureStorage.read(key: 'jwt_token');
      if (token == null) {
        if (mounted) setState(() => _userName = 'Peternak');
        return;
      }

      final response = await http.get(
        Uri.parse(ApiConfig.usersUrl),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String fetchedName = data['full_name'] ?? data['name'] ?? data['email'].toString().split('@')[0] ?? 'Peternak';
        String fetchedPic = data['picture'] ?? '';

        await _secureStorage.write(key: 'user_name', value: fetchedName);
        await _secureStorage.write(key: 'user_pic', value: fetchedPic);

        if (mounted) {
          setState(() {
            _userName = fetchedName;
            _pictureUrl = fetchedPic;
          });
        }
      } else {
        if (mounted) setState(() => _userName = 'Peternak');
      }
    } catch (e) {
      String? savedName = await _secureStorage.read(key: 'user_name');
      String? savedPic = await _secureStorage.read(key: 'user_pic');
      if (mounted) {
        setState(() {
          _userName = savedName ?? 'Peternak';
          _pictureUrl = savedPic ?? '';
        });
      }
    }
  }

  // --- 3. LOGIKA MENCARI DEVICE & CEK STATUS & CEK NOTIF ---
  Future<void> _initializeDeviceStatus() async {
    try {
      final token = await _secureStorage.read(key: 'jwt_token');
      if (token == null) return;

      final response = await http.get(
        Uri.parse(ApiConfig.devicesUrl),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          _activeDeviceId = data[0]['id'].toString();

          await _checkOnlineStatus();
          await _fetchNotifications(); // Ambil notifikasi juga di awal

          _statusTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
            _checkOnlineStatus();
            _fetchNotifications(); // Update notif tiap 10 detik bareng heartbeat
          });
        } else {
          if (mounted) {
            setState(() {
              _isCheckingStatus = false;
              _isDeviceOnline = false;
            });
          }
        }
      }
    } catch (e) {
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
      final token = await _secureStorage.read(key: 'jwt_token');
      final response = await http.get(
        Uri.parse(ApiConfig.deviceStatusUrl(_activeDeviceId!)),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _isDeviceOnline = data['is_online'] ?? false;
            _isCheckingStatus = false;
          });
        }
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

  // --- 4. LOGIKA AMBIL NOTIFIKASI ALERTS ---
  Future<void> _fetchNotifications() async {
    if (_activeDeviceId == null) return;
    try {
      final token = await _secureStorage.read(key: 'jwt_token');
      final response = await http.get(
        Uri.parse(ApiConfig.deviceAlertsUrl(_activeDeviceId!)),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _notifications = data;
            _notificationCount = data.length; // Update angka merah di lonceng
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
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