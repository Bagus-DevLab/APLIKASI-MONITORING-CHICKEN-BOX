import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../constants/app_colors.dart';
import '../routes/app_routes.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Variabel untuk menampung data Profil
  String _fullName = 'Memuat...';
  String _email = 'Memuat...';
  String _pictureUrl = '';
  bool _isLoadingProfile = true;

  // Variabel untuk menampung data Device (Kandang Saya)
  List<dynamic> _myDevices = [];
  bool _isLoadingDevices = true;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
    _fetchMyDevices();
  }

  // --- 1. AMBIL DATA PROFIL ---
  Future<void> _fetchUserProfile() async {
    try {
      final token = await _secureStorage.read(key: 'jwt_token');
      if (token == null) throw Exception("Token tidak ditemukan");

      final response = await http.get(
        Uri.parse('https://api.pcb.my.id/users/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _fullName = data['full_name'] ?? data['name'] ?? 'Peternak';
            _email = data['email'] ?? 'Email tidak tersedia';
            _pictureUrl = data['picture'] ?? '';
            _isLoadingProfile = false;
          });
        }
      } else {
        throw Exception("Gagal mengambil data profil");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _fullName = 'Gagal memuat';
          _email = 'Silakan login ulang';
          _isLoadingProfile = false;
        });
      }
    }
  }

  // --- 2. AMBIL DAFTAR KANDANG SAYA ---
  Future<void> _fetchMyDevices() async {
    setState(() => _isLoadingDevices = true);
    try {
      final token = await _secureStorage.read(key: 'jwt_token');
      if (token == null) return;

      final response = await http.get(
        Uri.parse('https://api.pcb.my.id/devices/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _myDevices = jsonDecode(response.body);
            _isLoadingDevices = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingDevices = false);
      }
    } catch (e) {
      debugPrint("Error fetching devices: $e");
      if (mounted) setState(() => _isLoadingDevices = false);
    }
  }

  // --- 3. FUNGSI UNCLAIM (LEPAS PERANGKAT) ---
  Future<void> _unclaimDevice(String deviceId) async {
    // Tampilkan loading screen
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
    );

    try {
      final token = await _secureStorage.read(key: 'jwt_token');

      final response = await http.post(
        Uri.parse('https://api.pcb.my.id/devices/$deviceId/unclaim'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      Navigator.pop(context); // Tutup loading screen

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perangkat berhasil dilepas dari akun.'), backgroundColor: AppColors.primaryGreen),
        );
        // Refresh daftar device biar langsung hilang dari layar
        _fetchMyDevices();
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorData['detail'] ?? 'Gagal melepas perangkat.'), backgroundColor: AppColors.error),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Tutup loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan jaringan: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  // --- 4. FUNGSI LOGOUT ---
  Future<void> _handleLogout(BuildContext context) async {
    try {
      await _secureStorage.delete(key: 'jwt_token');
      await _secureStorage.delete(key: 'user_name');
      await _secureStorage.delete(key: 'user_pic');
      await _googleSignIn.signOut();

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal logout: $e')));
      }
    }
  }

  // --- 5. UI BUILDER ---
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Profile Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            decoration: const BoxDecoration(
              color: AppColors.darkBackground,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Profile Image Dinamis
                Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(color: const Color(0xFFD4A574).withOpacity(0.5), shape: BoxShape.circle),
                  child: ClipOval(
                    child: _isLoadingProfile
                        ? const Center(child: CircularProgressIndicator(color: Colors.white))
                        : _pictureUrl.isNotEmpty
                        ? Image.network(
                      _pictureUrl, fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 60, color: Colors.white),
                    )
                        : const Icon(Icons.person, size: 60, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 12),
                Text(_fullName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3)),
                const SizedBox(height: 24),
                const Text('Profil Akun', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3)),
              ],
            ),
          ),

          // Content Area
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('INFORMASI AKUN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5)),
                const SizedBox(height: 12),

                // Email Field Dinamis
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('EMAIL TERDAFTAR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.3)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 4, offset: const Offset(0, 2))],
                      ),
                      child: Text(_email, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // --- KANDANG SAYA SECTION (DENGAN FITUR UNCLAIM) ---
                const Text('KANDANG SAYA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5)),
                const SizedBox(height: 12),

                if (_isLoadingDevices)
                  const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator(color: AppColors.primaryGreen)))
                else if (_myDevices.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: AppColors.secondaryLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderLight)),
                    child: const Text('Anda belum mengklaim perangkat kandang satupun. Silakan scan QR Code di menu Scan.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
                  )
                else
                  Column(
                    children: _myDevices.map((device) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: AppColors.primaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.home_work_rounded, color: AppColors.primaryGreen),
                          ),
                          title: Text(device['name'] ?? 'Kandang Tanpa Nama', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                          subtitle: Text('MAC: ${device['mac_address']}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.statusAlert),
                            tooltip: 'Lepas Perangkat',
                            onPressed: () => _showUnclaimConfirmation(context, device['id'].toString(), device['name'] ?? 'Kandang ini'),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 32),

                // --- Logout Button ---
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _showLogoutConfirmation(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.statusAlert, width: 2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Keluar dari akun',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.statusAlert, letterSpacing: 0.3),
                    ),
                  ),
                ),
                const SizedBox(height: 40), // Jarak aman bawah
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- DIALOG BOX ---
  void _showUnclaimConfirmation(BuildContext context, String deviceId, String deviceName) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Lepas Perangkat', style: TextStyle(color: AppColors.statusAlert, fontWeight: FontWeight.bold)),
          content: Text('Apakah Anda yakin ingin melepas "$deviceName" dari akun ini? Anda harus melakukan scan QR lagi untuk mengklaimnya kembali.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.statusAlert, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(dialogContext);
                _unclaimDevice(deviceId); // Eksekusi Unclaim
              },
              child: const Text('Ya, Lepas'),
            ),
          ],
        );
      },
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Konfirmasi Logout', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.statusAlert, foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(dialogContext);
                _handleLogout(context);
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }
}