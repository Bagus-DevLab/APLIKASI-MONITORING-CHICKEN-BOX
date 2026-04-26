import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/device_service.dart';
import '../models/device/device.dart';
import '../core/network/api_exception.dart';
import '../utils/error_handler.dart';
import '../routes/app_routes.dart';
import '../constants/app_colors.dart';

/// Scan Page - QR code scanner for claiming devices
/// 
/// Features:
/// - QR code scanning with camera
/// - MAC address validation
/// - Device name input dialog
/// - Integration with DeviceService.claimDevice()
/// - Comprehensive error handling
/// - Manual MAC address input option
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanLineController;
  late Animation<double> _scanLineAnimation;

  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  final DeviceService _deviceService = DeviceService();

  bool _isFlashOn = false;
  bool _isScanning = true;

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

  /// Validate MAC address format
  /// Accepts: XX:XX:XX:XX:XX:XX or XXXXXXXXXXXX
  bool _isValidMacAddress(String mac) {
    mac = mac.trim().toUpperCase();
    final RegExp macRegex = RegExp(
      r'^([0-9A-F]{2}[:-]?){5}([0-9A-F]{2})$|^[0-9A-F]{12}$',
    );
    return macRegex.hasMatch(mac);
  }

  /// Process device claim after QR code scan
  Future<void> _processClaimDevice(String macAddress) async {
    setState(() => _isScanning = false);
    _cameraController.stop();

    developer.log(
      '→ Processing claim for MAC: $macAddress',
      name: 'ScanPage',
    );

    // Show name input dialog
    String? kandangName = await _showNameDialog(macAddress);
    if (kandangName == null || kandangName.isEmpty) {
      developer.log('✗ Claim cancelled by user', name: 'ScanPage');
      setState(() => _isScanning = true);
      _cameraController.start();
      return;
    }

    // Show loading dialog
    if (mounted) {
      ErrorHandler.showLoadingDialog(context, message: 'Mengklaim device...');
    }

    try {
      final device = await _deviceService.claimDevice(
        macAddress: macAddress,
        name: kandangName,
      );

      developer.log(
        '✓ Device claimed successfully: ${device.displayName}',
        name: 'ScanPage',
      );

      // Hide loading dialog
      if (mounted) {
        ErrorHandler.hideLoadingDialog(context);
        _showSuccessAndNavigateDialog(device);
      }
    } on BadRequestException catch (e) {
      // Device already claimed by another user
      developer.log(
        '✗ Device already claimed: ${e.message}',
        name: 'ScanPage',
      );

      if (mounted) {
        ErrorHandler.hideLoadingDialog(context);
        _showErrorDialog('Device Sudah Diklaim', e.message);
      }
    } on ForbiddenException catch (e) {
      // User role is below admin
      developer.log(
        '✗ Access forbidden: ${e.message}',
        name: 'ScanPage',
      );

      if (mounted) {
        ErrorHandler.hideLoadingDialog(context);
        _showErrorDialog('Akses Ditolak', e.message);
      }
    } on NotFoundException catch (e) {
      // MAC address not registered in system
      developer.log(
        '✗ Device not found: ${e.message}',
        name: 'ScanPage',
      );

      if (mounted) {
        ErrorHandler.hideLoadingDialog(context);
        _showErrorDialog('Device Tidak Ditemukan', e.message);
      }
    } on ValidationException catch (e) {
      // Invalid MAC format or name constraints
      developer.log(
        '✗ Validation error: ${e.allMessages}',
        name: 'ScanPage',
      );

      if (mounted) {
        ErrorHandler.hideLoadingDialog(context);
        ErrorHandler.showValidationErrorDialog(context, e);
        setState(() => _isScanning = true);
        _cameraController.start();
      }
    } on RateLimitException catch (e) {
      // Rate limit exceeded (10/minute)
      developer.log(
        '✗ Rate limit exceeded: ${e.message}',
        name: 'ScanPage',
      );

      if (mounted) {
        ErrorHandler.hideLoadingDialog(context);
        ErrorHandler.showRateLimitSnackbar(context, e.message);
        setState(() => _isScanning = true);
        _cameraController.start();
      }
    } on NetworkException catch (e) {
      // Network error
      developer.log(
        '✗ Network error: ${e.message}',
        name: 'ScanPage',
      );

      if (mounted) {
        ErrorHandler.hideLoadingDialog(context);
        _showNetworkErrorDialog(e.message, macAddress, kandangName);
      }
    } catch (e) {
      developer.log(
        '✗ Unexpected error: $e',
        name: 'ScanPage',
        error: e,
      );

      if (mounted) {
        ErrorHandler.hideLoadingDialog(context);
        _showErrorDialog('Kesalahan', 'Terjadi kesalahan: $e');
      }
    }
  }

  /// Show name input dialog
  Future<String?> _showNameDialog(String mac) {
    final TextEditingController nameController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Beri Nama Kandang',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MAC: $mac',
              style: const TextStyle(fontSize: 12, color: AppColors.primaryBlue),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: 'Misal: Kandang Ayam DOC A',
                filled: true,
                fillColor: AppColors.secondaryLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              autofocus: true,
              maxLength: 100,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text(
              'Batal',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  /// Show error dialog with retry option
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isScanning = true);
              _cameraController.start();
            },
            child: const Text(
              'Coba Lagi',
              style: TextStyle(color: AppColors.primaryGreen),
            ),
          ),
        ],
      ),
    );
  }

  /// Show network error dialog with retry option
  void _showNetworkErrorDialog(
    String message,
    String macAddress,
    String name,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.wifi_off, color: AppColors.error, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Kesalahan Jaringan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // CRITICAL-2 FIX: Check mounted before setState/camera
              // after dialog pop — widget may have been disposed.
              if (!mounted) return;
              setState(() => _isScanning = true);
              _cameraController.start();
            },
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // CRITICAL-2 FIX: Check mounted before calling async
              // method that uses context and setState internally.
              if (!mounted) return;
              _processClaimDevice(macAddress);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  /// Show success dialog and navigate
  void _showSuccessAndNavigateDialog(Device device) {
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
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primaryGreen,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Berhasil Ditambahkan!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Kandang "${device.displayName}" telah terdaftar.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'MAC: ${device.macAddress}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.home,
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.bluetooth_rounded, size: 20),
                label: const Text('Setup WiFi Perangkat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                child: const Text(
                  'Alat sudah terhubung ke WiFi',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Show manual input dialog
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
              const Text(
                'Input ID Manual',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Masukkan Device ID / MAC Address ESP32 kamu.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: idController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Contoh: 44:1D:64:BE:22:08',
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
                      // Validate input manual
                      if (_isValidMacAddress(manualInput)) {
                        _processClaimDevice(manualInput);
                      } else {
                        _showErrorDialog(
                          'Format Tidak Valid',
                          'Format MAC Address tidak valid!\nGunakan format XX:XX:XX:XX:XX:XX',
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Hubungkan Perangkat',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
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
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
            size: 20,
          ),
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
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
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
            MobileScanner(
              controller: _cameraController,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty && _isScanning) {
                  final String rawValue = barcodes.first.rawValue ?? "";
                  if (rawValue.isNotEmpty) {
                    // Validate MAC address
                    if (_isValidMacAddress(rawValue)) {
                      _processClaimDevice(rawValue);
                    } else {
                      // Invalid QR code
                      setState(() => _isScanning = false);
                      _cameraController.stop();
                      _showErrorDialog(
                        'QR Code Tidak Valid',
                        'QR Code tidak valid!\nBukan perangkat Kandang Pintar.',
                      );
                    }
                  }
                }
              },
            ),
            CustomPaint(
              size: const Size(double.infinity, 300),
              painter: _ScanOverlayPainter(),
            ),
            if (_isScanning)
              AnimatedBuilder(
                animation: _scanLineAnimation,
                builder: (context, child) {
                  return Positioned(
                    top: 75 + (_scanLineAnimation.value * 130),
                    left: 70,
                    right: 70,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
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
            Positioned(
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.qr_code_scanner,
                      color: AppColors.primaryGreen,
                      size: 16,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Mendeteksi QR Code...',
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
}

/// Scan overlay painter
class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.45);
    const double cutoutSize = 180;
    final double left = (size.width - cutoutSize) / 2;
    final double top = (size.height - cutoutSize) / 2;
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, cutoutSize, cutoutSize),
          const Radius.circular(8),
        ),
      )
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, paint);

    final paintLine = Paint()
      ..color = AppColors.primaryGreen
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    const double lineLen = 20;
    canvas.drawLine(Offset(left, top), Offset(left + lineLen, top), paintLine);
    canvas.drawLine(Offset(left, top), Offset(left, top + lineLen), paintLine);
    canvas.drawLine(
      Offset(left + cutoutSize, top),
      Offset(left + cutoutSize - lineLen, top),
      paintLine,
    );
    canvas.drawLine(
      Offset(left + cutoutSize, top),
      Offset(left + cutoutSize, top + lineLen),
      paintLine,
    );
    canvas.drawLine(
      Offset(left, top + cutoutSize),
      Offset(left + lineLen, top + cutoutSize),
      paintLine,
    );
    canvas.drawLine(
      Offset(left, top + cutoutSize),
      Offset(left, top + cutoutSize - lineLen),
      paintLine,
    );
    canvas.drawLine(
      Offset(left + cutoutSize, top + cutoutSize),
      Offset(left + cutoutSize - lineLen, top + cutoutSize),
      paintLine,
    );
    canvas.drawLine(
      Offset(left + cutoutSize, top + cutoutSize),
      Offset(left + cutoutSize, top + cutoutSize - lineLen),
      paintLine,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
