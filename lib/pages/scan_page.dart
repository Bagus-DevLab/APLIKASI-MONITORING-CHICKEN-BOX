import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_colors.dart';
// TODO: Jangan lupa import halaman Bluetooth kamu di sini, sesuaikan path-nya
// import 'home_screen_ble.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with SingleTickerProviderStateMixin {
  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnimation;
  bool _isFlashOn = false;
  bool _isScanning = true;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    super.dispose();
  }

  // ... (KODE _showManualInputDialog TETAP SAMA SEPERTI MILIKMU) ...
  void _showManualInputDialog() {
    final TextEditingController idController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Input ID Manual',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Masukkan Device ID ESP32 kamu secara manual',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: idController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Contoh: 44:1D:64:BE:22:08',
                  hintStyle: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.memory_rounded,
                    color: AppColors.primaryGreen,
                  ),
                  filled: true,
                  fillColor: AppColors.secondaryLight,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primaryGreen,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (idController.text.trim().isNotEmpty) {
                      Navigator.pop(context); // Tutup bottom sheet
                      _processClaimDevice(idController.text.trim()); // Panggil fungsi klaim
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Hubungkan Perangkat',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // --- LOGIKA BARU UNTUK KLAIM API ---
  Future<void> _processClaimDevice(String macAddress) async {
    setState(() => _isScanning = false);

    // 1. Minta user masukin Nama Kandang dulu
    String? kandangName = await _showNameDialog();
    if (kandangName == null || kandangName.isEmpty) {
      setState(() => _isScanning = true);
      return; // Batal kalau nama kosong
    }

    // Tampilkan loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final token = await _secureStorage.read(key: 'jwt_token');

      // 2. Tembak API Claim FastAPI
      final response = await http.post(
        Uri.parse('https://api.pcb.my.id/devices/claim'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'mac_address': macAddress,
          'name': kandangName,
        }),
      );

      Navigator.pop(context); // Tutup loading

      if (response.statusCode == 200) {
        // SUKSES KLAIM -> Tampilkan pop-up sukses dan navigasi ke BLE
        _showSuccessAndNavigateDialog(macAddress, kandangName);
      } else {
        // GAGAL KLAIM (Misal udah diklaim orang, atau format MAC salah)
        final errorData = jsonDecode(response.body);
        _showErrorDialog(errorData['detail'] ?? 'Gagal mengklaim perangkat');
      }
    } catch (e) {
      Navigator.pop(context); // Tutup loading
      _showErrorDialog('Terjadi kesalahan jaringan: $e');
    }
  }

  // Dialog untuk meminta nama kandang
  Future<String?> _showNameDialog() {
    final TextEditingController nameController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Beri Nama Kandang', style: TextStyle(fontSize: 18)),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: 'Misal: Kandang Ayam DOC A',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Dialog Error
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gagal', style: TextStyle(color: AppColors.error)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isScanning = true);
            },
            child: const Text('Tutup', style: TextStyle(color: AppColors.primaryGreen)),
          ),
        ],
      ),
    );
  }

  // Dialog Sukses yang menyambungkan ke Setup WiFi Bluetooth
  void _showSuccessAndNavigateDialog(String macAddress, String name) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.primaryGreen, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'Berhasil Ditambahkan!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              'Kandang "$name" telah terdaftar di akunmu.',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Tombol 1: Setup WiFi via BLE (Ke halaman HomeScreen BLE kamu)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context); // Tutup dialog
                  // TODO: Aktifkan navigasi ke halaman Bluetooth kamu
                  /*
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeScreen()), // Ganti HomeScreen dengan nama class BLE kamu
                  );
                  */
                },
                icon: const Icon(Icons.bluetooth_rounded, size: 20),
                label: const Text('Setup WiFi Perangkat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Tombol 2: Selesai (Langsung balik ke Dashboard utama)
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context); // Tutup dialog
                  Navigator.pop(context); // Kembali ke Dashboard
                },
                style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                child: const Text('Alat sudah terhubung ke WiFi', style: TextStyle(fontSize: 13)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text(
          'Scan Perangkat',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.camera_alt_rounded,
              color: AppColors.textPrimary,
              size: 22,
            ),
            onPressed: () {
              // TODO: Open camera settings or switch camera
            },
          ),
          IconButton(
            icon: Icon(
              _isFlashOn
                  ? Icons.flash_on_rounded
                  : Icons.flash_off_rounded,
              color: _isFlashOn ? Colors.amber : AppColors.textSecondary,
              size: 22,
            ),
            onPressed: () => setState(() => _isFlashOn = !_isFlashOn),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 32),
                  child: Column(
                    children: [
                      // Scanner Box
                      _buildScannerBox(),
                      const SizedBox(height: 28),

                      // Instructions
                      const Text(
                        'Arahkan kamera ke QR Code / Barcode\nyang tertera pada perangkat ESP32 kamu',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Manual Input Button
                      _buildManualInputButton(),

                      const SizedBox(height: 20),

                      // Tip Card
                      _buildTipCard(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerBox() {
    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Camera preview placeholder (grey background)
            Container(
              color: Colors.grey[200],
              child: const Center(
                child: Icon(
                  Icons.camera_alt_outlined,
                  size: 48,
                  color: Colors.grey,
                ),
              ),
            ),

            // Dark overlay with transparent center
            CustomPaint(
              size: const Size(double.infinity, 300),
              painter: _ScanOverlayPainter(),
            ),

            // Corner decorations
            _buildCorners(),

            // Animated scan line
            if (_isScanning)
              AnimatedBuilder(
                animation: _scanLineAnimation,
                builder: (context, child) {
                  return Positioned(
                    top: 75 +
                        (_scanLineAnimation.value * 130),
                    left: 70,
                    right: 70,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.primaryGreen,
                            AppColors.primaryGreen,
                            Colors.transparent,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                },
              ),

            // Scanning label
            Positioned(
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Sedang memindai...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorners() {
    const double cornerSize = 24;
    const double cornerThickness = 3;
    const Color cornerColor = AppColors.primaryGreen;

    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        children: [
          // Top-left
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: cornerSize,
              height: cornerThickness,
              color: cornerColor,
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: cornerThickness,
              height: cornerSize,
              color: cornerColor,
            ),
          ),
          // Top-right
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: cornerSize,
              height: cornerThickness,
              color: cornerColor,
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: cornerThickness,
              height: cornerSize,
              color: cornerColor,
            ),
          ),
          // Bottom-left
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              width: cornerSize,
              height: cornerThickness,
              color: cornerColor,
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              width: cornerThickness,
              height: cornerSize,
              color: cornerColor,
            ),
          ),
          // Bottom-right
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: cornerSize,
              height: cornerThickness,
              color: cornerColor,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: cornerThickness,
              height: cornerSize,
              color: cornerColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualInputButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _showManualInputDialog,
        icon: const Icon(Icons.keyboard_rounded, size: 20),
        label: const Text(
          'Input ID Manual',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(
            color: AppColors.textPrimary,
            width: 1.5,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildTipCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryGreen.withOpacity(0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.primaryGreen,
            size: 20,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Pastikan QR Code terlihat jelas dan berada di dalam kotak pemindai. Jaga jarak 10–20 cm dari perangkat.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============ SCAN OVERLAY PAINTER ============

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.45);

    const double cutoutSize = 180;
    final double left = (size.width - cutoutSize) / 2;
    final double top = (size.height - cutoutSize) / 2;

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, cutoutSize, cutoutSize),
        const Radius.circular(8),
      ))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}