import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../constants/api_config.dart';
import '../routes/app_routes.dart';

import '../constants/app_colors.dart';
// IMPORT halaman Bluetooth kamu di sini:
import 'home_screen.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> with SingleTickerProviderStateMixin {
  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnimation;

  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

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
    _cameraController.dispose();
    super.dispose();
  }

  // --- FUNGSI VALIDASI MAC ADDRESS (FILTER QR NYASAR) ---
  bool _isValidMacAddress(String mac) {
    // Mengecek apakah string berformat XX:XX:XX:XX:XX:XX atau XXXXXXXXXXXX
    mac = mac.trim().toUpperCase();
    final RegExp macRegex = RegExp(r'^([0-9A-F]{2}[:-]?){5}([0-9A-F]{2})$|^[0-9A-F]{12}$');
    return macRegex.hasMatch(mac);
  }

  // --- FUNGSI UNTUK KLAIM API ---
  Future<void> _processClaimDevice(String macAddress) async {
    setState(() => _isScanning = false);
    _cameraController.stop();

    String? kandangName = await _showNameDialog(macAddress);
    if (kandangName == null || kandangName.isEmpty) {
      setState(() => _isScanning = true);
      _cameraController.start();
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
    );

    try {
      final token = await _secureStorage.read(key: 'jwt_token');

      final response = await http.post(
        Uri.parse(ApiConfig.claimDeviceUrl),
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
        _showSuccessAndNavigateDialog(macAddress, kandangName);
      } else {
        // --- PERBAIKAN ERROR HANDLING ANTI-CRASH ---
        String errorMessage = 'Gagal mengklaim perangkat';
        try {
          final errorData = jsonDecode(response.body);
          // Tangani jika error dari Pydantic (berupa List/Array)
          if (errorData['detail'] is List && errorData['detail'].isNotEmpty) {
            errorMessage = errorData['detail'][0]['msg'] ?? errorMessage;
          } else if (errorData['detail'] is String) {
            errorMessage = errorData['detail'];
          }
        } catch (e) {
          errorMessage = 'Terjadi kesalahan server (${response.statusCode})';
        }

        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      Navigator.pop(context);
      _showErrorDialog('Terjadi kesalahan jaringan: $e');
    }
  }

  // --- DIALOG BOX UI ---
  Future<String?> _showNameDialog(String mac) {
    final TextEditingController nameController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Beri Nama Kandang', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MAC: $mac', style: const TextStyle(fontSize: 12, color: Colors.blue)),
            const SizedBox(height: 10),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: 'Misal: Kandang Ayam DOC A',
                filled: true,
                fillColor: AppColors.secondaryLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Perhatian', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isScanning = true);
              _cameraController.start();
            },
            child: const Text('Coba Lagi', style: TextStyle(color: AppColors.primaryGreen)),
          ),
        ],
      ),
    );
  }

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
              width: 64, height: 64,
              decoration: BoxDecoration(color: AppColors.primaryGreen.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.primaryGreen, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('Berhasil Ditambahkan!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Kandang "$name" telah terdaftar.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamedAndRemoveUntil(context, AppRoutes.home, (route) => false);
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

            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('Alat sudah terhubung ke WiFi', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualInputDialog() {
    final TextEditingController idController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
              const Text('Input ID Manual', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('Masukkan Device ID / MAC Address ESP32 kamu.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              TextField(
                controller: idController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Contoh: 44:1D:64:BE:22:08',
                  prefixIcon: const Icon(Icons.memory_rounded, color: AppColors.primaryGreen),
                  filled: true,
                  fillColor: AppColors.secondaryLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    String manualInput = idController.text.trim();
                    if (manualInput.isNotEmpty) {
                      Navigator.pop(context);
                      // Validasi input manual juga
                      if (_isValidMacAddress(manualInput)) {
                        _processClaimDevice(manualInput);
                      } else {
                        _showErrorDialog('Format MAC Address tidak valid!\nGunakan format XX:XX:XX:XX:XX:XX');
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Hubungkan Perangkat', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('Scan Perangkat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _isFlashOn ? Colors.amber : AppColors.textSecondary,
              size: 22,
            ),
            onPressed: () {
              _cameraController.toggleTorch();
              setState(() => _isFlashOn = !_isFlashOn);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                _buildScannerBox(),
                const SizedBox(height: 28),
                const Text(
                  'Arahkan kamera ke QR Code / Barcode\nyang tertera pada perangkat ESP32 kamu',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showManualInputDialog,
                    icon: const Icon(Icons.keyboard_rounded, size: 20),
                    label: const Text('Input ID Manual', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.textPrimary, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Widget _buildScannerBox() {
    return Container(
      width: double.infinity,
      height: 300,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          alignment: Alignment.center,
          children: [
            MobileScanner(
              controller: _cameraController,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty && _isScanning) {
                  final String rawValue = barcodes.first.rawValue ?? "";
                  if (rawValue.isNotEmpty) {

                    // --- PROTEKSI QR CODE NYASAR ---
                    if (_isValidMacAddress(rawValue)) {
                      _processClaimDevice(rawValue); // Gas Klaim API
                    } else {
                      // Hentikan kamera sementara biar gak kedip-kedip trus munculin error
                      setState(() => _isScanning = false);
                      _cameraController.stop();
                      _showErrorDialog('QR Code tidak valid!\nBukan perangkat Kandang Pintar.');
                    }

                  }
                }
              },
            ),

            CustomPaint(size: const Size(double.infinity, 300), painter: _ScanOverlayPainter()),

            if (_isScanning)
              AnimatedBuilder(
                animation: _scanLineAnimation,
                builder: (context, child) {
                  return Positioned(
                    top: 75 + (_scanLineAnimation.value * 130),
                    left: 70, right: 70,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Colors.transparent, AppColors.primaryGreen, AppColors.primaryGreen, Colors.transparent]),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                },
              ),

            Positioned(
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.primaryGreen, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    const Text('Mendeteksi QR Code...', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ],
        ),
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
      ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(left, top, cutoutSize, cutoutSize), const Radius.circular(8)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);

    final paintLine = Paint()..color = AppColors.primaryGreen..strokeWidth = 3..style = PaintingStyle.stroke;
    const double lineLen = 20;
    canvas.drawLine(Offset(left, top), Offset(left + lineLen, top), paintLine);
    canvas.drawLine(Offset(left, top), Offset(left, top + lineLen), paintLine);
    canvas.drawLine(Offset(left + cutoutSize, top), Offset(left + cutoutSize - lineLen, top), paintLine);
    canvas.drawLine(Offset(left + cutoutSize, top), Offset(left + cutoutSize, top + lineLen), paintLine);
    canvas.drawLine(Offset(left, top + cutoutSize), Offset(left + lineLen, top + cutoutSize), paintLine);
    canvas.drawLine(Offset(left, top + cutoutSize), Offset(left, top + cutoutSize - lineLen), paintLine);
    canvas.drawLine(Offset(left + cutoutSize, top + cutoutSize), Offset(left + cutoutSize - lineLen, top + cutoutSize), paintLine);
    canvas.drawLine(Offset(left + cutoutSize, top + cutoutSize), Offset(left + cutoutSize, top + cutoutSize - lineLen), paintLine);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}