import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_colors.dart';
import '../constants/api_config.dart';
import '../core/network/dio_client.dart';
import '../core/network/token_manager.dart';
import '../core/network/api_exception.dart';
import '../services/auth_service.dart';
import '../utils/error_handler.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final Dio _dio = DioClient().dio;
  final AuthService _authService = AuthService();
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // State Data Profil
  String _fullName = 'Memuat...';
  String _email = 'Memuat...';
  String _pictureUrl = '';
  bool _isLoadingProfile = true;

  // State Daftar Perangkat
  List<dynamic> _myDevices = [];
  bool _isLoadingDevices = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchUserProfile();
      _fetchMyDevices();
    });
  }

  // --- 1. AMBIL DATA PROFIL DARI BACKEND (via DioClient) ---
  Future<void> _fetchUserProfile() async {
    try {
      final response = await _dio.get(ApiConfig.usersUrl);

      if (response.statusCode == 200) {
        final data = response.data;
        if (mounted) {
          setState(() {
            _fullName = data['full_name'] ?? data['name'] ?? 'Peternak';
            _email = data['email'] ?? 'Email tidak tersedia';
            _pictureUrl = data['picture'] ?? '';
            _isLoadingProfile = false;
          });
        }
      }
    } on DioException catch (e) {
      developer.log('✗ Error loading profile: ${e.error}', name: 'ProfilePage');
      if (mounted) setState(() => _isLoadingProfile = false);
    } catch (e) {
      developer.log('✗ Error loading profile: $e', name: 'ProfilePage');
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  // --- 2. AMBIL DAFTAR KANDANG MILIK USER (via DioClient) ---
  Future<void> _fetchMyDevices() async {
    if (!mounted) return;
    setState(() => _isLoadingDevices = true);

    try {
      final response = await _dio.get(ApiConfig.devicesUrl);

      if (response.statusCode == 200) {
        // Backend returns paginated response: { data: [...], total: N, ... }
        final data = response.data;
        if (mounted) {
          setState(() {
            _myDevices = data is Map ? (data['data'] as List? ?? []) : (data as List? ?? []);
            _isLoadingDevices = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingDevices = false);
      }
    } on DioException catch (e) {
      developer.log('✗ Error fetching devices: ${e.error}', name: 'ProfilePage');
      if (mounted) setState(() => _isLoadingDevices = false);
    } catch (e) {
      developer.log('✗ Error fetching devices: $e', name: 'ProfilePage');
      if (mounted) setState(() => _isLoadingDevices = false);
    }
  }

  // --- 3. FUNGSI UNCLAIM (LEPAS KANDANG) via DioClient ---
  Future<void> _unclaimDevice(String deviceId) async {
    _showLoadingDialog();

    try {
      final response = await _dio.post(ApiConfig.deviceUnclaimUrl(deviceId));

      if (mounted) Navigator.pop(context);

      if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
        _showSnackBar('Kandang berhasil dilepas.', isError: false);
        _fetchMyDevices();
      } else {
        _showSnackBar('Gagal melepas kandang.');
      }
    } on DioException catch (e) {
      if (mounted) Navigator.pop(context);
      if (e.error is ApiException) {
        ErrorHandler.handleApiException(context, e.error as ApiException);
      } else {
        _showSnackBar('Kesalahan jaringan: ${e.message}');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackBar('Kesalahan jaringan: $e');
    }
  }

  // --- 4. FUNGSI RESET/GANTI PASSWORD ---
  Future<void> _handleResetPassword() async {
    if (_email == 'Memuat...' || _email.isEmpty) {
      _showSnackBar('Data email belum siap.');
      return;
    }

    _showLoadingDialog();

    try {
      await _auth.sendPasswordResetEmail(email: _email);
      if (mounted) Navigator.pop(context); // Tutup loading
      _showSnackBar('Link ganti password telah dikirim ke email $_email', isError: false);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackBar('Gagal mengirim link: $e');
    }
  }

  // --- 5. FUNGSI HAPUS AKUN (PERMANEN) via DioClient ---
  Future<void> _handleDeleteAccount() async {
    _showLoadingDialog();

    try {
      final response = await _dio.delete(ApiConfig.usersUrl);

      if (!mounted) return;
      Navigator.pop(context);

      if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
        try { await _auth.currentUser?.delete(); } catch (_) {}
        await _clearLocalDataAndLogout();
      } else {
        _showSnackBar('Gagal menghapus akun. Server menolak. (Kode: ${response.statusCode})');
      }
    } on DioException catch (e) {
      if (mounted) Navigator.pop(context);
      if (e.error is ApiException) {
        ErrorHandler.handleApiException(context, e.error as ApiException);
      } else {
        _showSnackBar('Terjadi kesalahan jaringan: ${e.message}');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackBar('Terjadi kesalahan jaringan: $e');
    }
  }

  // --- 6. LOGIKA CLEANUP & LOGOUT (via AuthService + Global Listener) ---
  Future<void> _clearLocalDataAndLogout() async {
    try {
      // Clear backend JWT via AuthService (clears TokenManager)
      await _authService.logout();
      // Clear Firebase and Google sessions
      try { await _auth.signOut(); } catch (_) {}
      try { await _googleSignIn.signOut(); } catch (_) {}

      developer.log('✓ Logout cleanup complete', name: 'ProfilePage');
    } finally {
      // Trigger the global logout event — the listener in main.dart
      // handles navigation to LoginPage via navigatorKey.
      // This is the SINGLE navigation path for all logout scenarios.
      TokenManager().triggerLogout();
    }
  }

  // --- HELPER UI ---
  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
    );
  }

  void _showSnackBar(String msg, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: isError ? AppColors.error : AppColors.primaryGreen, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 40),
            decoration: const BoxDecoration(
              color: AppColors.darkBackground,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 55,
                  backgroundColor: Colors.white24,
                  child: ClipOval(
                    child: _pictureUrl.isNotEmpty
                        ? Image.network(_pictureUrl, width: 110, height: 110, fit: BoxFit.cover, 
                            errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 60, color: Colors.white))
                        : const Icon(Icons.person, size: 60, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                Text(_fullName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(_email, style: const TextStyle(fontSize: 14, color: Colors.white70)),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('KANDANG SAYA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                const SizedBox(height: 12),

                if (_isLoadingDevices)
                  const Center(child: CircularProgressIndicator())
                else if (_myDevices.isEmpty)
                  _buildEmptyState()
                else
                  ..._myDevices.map((d) => _buildDeviceCard(d)),

                const SizedBox(height: 32),

                // Tombol Ganti Password
                _buildActionButton(
                  label: 'Ganti Password via Email',
                  icon: Icons.lock_reset_rounded,
                  color: AppColors.primaryBlue,
                  onTap: () => _showConfirmDialog(
                    title: 'Ganti Password',
                    msg: 'Sistem akan mengirimkan link pengaturan ulang password ke email Anda ($_email). Lanjutkan?',
                    onConfirm: _handleResetPassword,
                  ),
                ),
                
                const SizedBox(height: 12),

                // Tombol Keluar Akun
                _buildActionButton(
                  label: 'Keluar Akun',
                  icon: Icons.logout_rounded,
                  color: AppColors.statusAlert,
                  onTap: () => _showConfirmDialog(
                    title: 'Konfirmasi Logout',
                    msg: 'Apakah Anda yakin ingin keluar?',
                    onConfirm: _clearLocalDataAndLogout,
                  ),
                ),

                const SizedBox(height: 12),

                Center(
                  child: TextButton(
                    onPressed: () => _showConfirmDialog(
                      title: 'Hapus Akun',
                      msg: 'Tindakan ini permanen. Semua data kandang dan riwayat akan hilang selamanya.',
                      confirmText: 'Hapus Selamanya',
                      onConfirm: _handleDeleteAccount,
                    ),
                    child: const Text('Hapus Akun Selamanya', style: TextStyle(color: Colors.grey, fontSize: 12, decoration: TextDecoration.underline)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: AppColors.borderLight)),
      child: const Text('Belum ada kandang terdaftar.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
    );
  }

  Widget _buildDeviceCard(Map<String, dynamic> d) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: const BorderSide(color: AppColors.borderLight)),
      child: ListTile(
        leading: const Icon(Icons.home_work_rounded, color: AppColors.primaryGreen),
        title: Text(d['name'] ?? 'Kandang Tanpa Nama', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('MAC: ${d['mac_address']}', style: const TextStyle(fontSize: 12)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.statusAlert),
          onPressed: () => _showConfirmDialog(
            title: 'Lepas Kandang',
            msg: 'Lepas "${d['name']}" dari akun Anda?',
            onConfirm: () => _unclaimDevice(d['id'].toString()),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({required String label, required IconData icon, required Color color, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onTap,
        icon: Icon(icon, color: color, size: 20),
        label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showConfirmDialog({required String title, required String msg, String confirmText = 'Ya, Lanjutkan', required VoidCallback onConfirm}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
            onPressed: () { 
              Navigator.pop(context); 
              onConfirm(); 
            },
            child: Text(confirmText, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}