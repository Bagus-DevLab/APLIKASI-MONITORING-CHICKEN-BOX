import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/floating_navbar.dart';
import 'home_page.dart';
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

  // --- VARIABEL STATUS ALAT ---
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  Timer? _statusTimer;
  String? _activeDeviceId;
  bool _isDeviceOnline = false;
  bool _isCheckingStatus = true;

  // --- VARIABEL PROFIL DINAMIS ---
  String _greeting = 'Halo';
  String _userName = 'Memuat...';
  String _pictureUrl = ''; // Tambahan: Variabel untuk nampung URL foto
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

      // Tembak API /users/me
      final response = await http.get(
        Uri.parse('https://api.pcb.my.id/users/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        String fetchedName = data['full_name'] ?? data['name'] ?? data['email'].toString().split('@')[0] ?? 'Peternak';
        String fetchedPic = data['picture'] ?? ''; // Ambil URL foto

        await _secureStorage.write(key: 'user_name', value: fetchedName);
        await _secureStorage.write(key: 'user_pic', value: fetchedPic); // Save foto ke storage juga

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
      debugPrint("Error load user: $e");
      // Fallback baca dari storage kalau lagi offline
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

  // --- 3. LOGIKA MENCARI DEVICE & CEK STATUS ---
  Future<void> _initializeDeviceStatus() async {
    try {
      final token = await _secureStorage.read(key: 'jwt_token');
      if (token == null) return;

      final response = await http.get(
        Uri.parse('https://api.pcb.my.id/devices/'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          _activeDeviceId = data[0]['id'].toString();

          await _checkOnlineStatus();

          _statusTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
            _checkOnlineStatus();
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
      debugPrint("Error init status: $e");
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
      if (token == null) return;

      final response = await http.get(
        Uri.parse('https://api.pcb.my.id/devices/$_activeDeviceId/status'),
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

  // --- BUILDER UTAMA ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _currentIndex == 0 ? _buildAppBar() : null,
      body: Column(
        children: [
          Expanded(child: _buildPageContent()),

          // Fixed Floating NavBar
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
      backgroundColor: const Color(0xFF4A3728), // Warna dominan tema kamu
      elevation: 0,
      toolbarHeight: 80,
      automaticallyImplyLeading: false,
      flexibleSpace: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // --- FOTO PROFIL DINAMIS ---
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFD4A574).withOpacity(0.5), // Background fallback kalau foto gak ada
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: ClipOval(
                child: _pictureUrl.isNotEmpty
                    ? Image.network(
                  _pictureUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Kalau link fotonya rusak/internet mati, tampilin icon orang
                    return const Icon(Icons.person, color: Colors.white, size: 30);
                  },
                )
                    : const Icon(Icons.person, color: Colors.white, size: 30), // Default icon
              ),
            ),
            const SizedBox(width: 14),

            // Greeting & Name (DINAMIS)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _greeting,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFFD4A574),
                      height: 1.0,
                    ),
                  ),
                  Text(
                    'Hai, $_userName',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),

            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: badgeColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    badgeText,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Notification Icon
            Stack(
              alignment: Alignment.topRight,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.notifications_none_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                // Notification Badge
                if (_notificationCount > 0)
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE74C3C),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _notificationCount > 9 ? '9+' : _notificationCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent() {
    switch (_currentIndex) {
      case 0: return const HomePage();
      case 1: return const DevicesPage();
      case 2: return const ScanPage();
      case 3: return const HistoryPage();
      case 4: return const ProfilePage();
      default: return const HomePage();
    }
  }
}