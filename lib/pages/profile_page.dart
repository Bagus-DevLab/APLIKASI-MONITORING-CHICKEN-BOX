import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_colors.dart';
import '../routes/app_routes.dart';
import '../constants/api_config.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
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
    _fetchUserProfile();
    _fetchMyDevices();
  }

  // --- 1. AMBIL DATA PROFIL DARI BACKEND ---
  Future<void> _fetchUserProfile() async {
    try {
      final token = await _secureStorage.read(key: 'jwt_token');
      if (token == null) return;

      final response = await http.get(
        Uri.parse(ApiConfig.usersUrl),
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
      }
    } catch (e) {
      debugPrint("Error Load Profile: $e");
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  // --- 2. AMBIL DAFTAR KANDANG MILIK USER ---
  Future<void> _fetchMyDevices() async {
    if (!mounted) return;
    setState(() => _isLoadingDevices = true);

    try {
      final token = await _secureStorage.read(key: 'jwt_token');
      if (token == null) return;

      final response = await http.get(
        Uri.parse(ApiConfig.devicesUrl),
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
      debugPrint("Error Fetch Devices: $e");
      if (mounted) setState(() => _isLoadingDevices = false);
    }
  }

  // --- 3. FUNGSI UNCLAIM (LEPAS KANDANG) ---
  Future<void> _unclaimDevice(String deviceId) async {
    _showLoadingDialog();

    try {
      final token = await _secureStorage.read(key: 'jwt_token');
      final response = await http.post(
        Uri.parse(ApiConfig.deviceUnclaimUrl(deviceId)),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );

      // Pastikan dialog loading ditutup APAPUN HASILNYA
      if (mounted) Navigator.pop(context); 

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _showSnackBar('Kandang berhasil dilepas.', isError: false);
        _fetchMyDevices(); // Refresh list
      } else {
        _showSnackBar('Gagal melepas kandang.');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Tutup loading jika error jaringan
      _showSnackBar('Kesalahan jaringan: $e');
    }
  }

  // --- 4. FUNGSI HAPUS AKUN (PERMANEN) ---
  Future<void> _handleDeleteAccount() async {
    _showLoadingDialog();

    try {
      final token = await _secureStorage.read(key: 'jwt_token');
      final response = await http.delete(
        Uri.parse(ApiConfig.usersUrl),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );

      // WAJIB: Tutup loading spinner DULU sebelum memindahkan halaman
      if (!mounted) return;
      Navigator.pop(context); 

      // Terima status code 200, 202, ataupun 204 dari Backend
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Hapus juga di Firebase jika memungkinkan
        try { await _auth.currentUser?.delete(); } catch (_) {}
        
        // Panggil pembersihan lokal dan tendang ke login
        await _clearLocalDataAndLogout();
      } else {
        _showSnackBar('Gagal menghapus akun. Server menolak. (Kode: ${response.statusCode})');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Tutup loading jika error jaringan
      _showSnackBar('Terjadi kesalahan jaringan: $e');
    }
  }

  // --- 5. LOGIKA CLEANUP & LOGOUT ---
  Future<void> _clearLocalDataAndLogout() async {
    await _secureStorage.deleteAll();
    await _googleSignIn.signOut();
    await _auth.signOut();

    if (mounted) {
      // RESET TOTAL NAVIGASI KE LOGIN (Anti Back Button nyasar)
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
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
          // Header Profile
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

                const SizedBox(height: 40),

                // Action Buttons
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.statusAlert),
            onPressed: () { Navigator.pop(context); onConfirm(); },
            child: Text(confirmText, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}