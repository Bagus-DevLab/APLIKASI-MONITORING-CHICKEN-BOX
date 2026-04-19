import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/app_colors.dart';


class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key});

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  // --- STATE BLUETOOTH ---
  bool _bluetoothEnabled = false;
  bool _isScanning = false;
  List<ScanResult> _scanResults = [];
  BluetoothDevice? _connectedDevice;

  // UUID dari kodingan ESP32 kamu
  final String serviceUUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String charUUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  @override
  void initState() {
    super.initState();
    // Dengarkan hasil scan dari Bluetooth
    FlutterBluePlus.onScanResults.listen((results) {
      if (mounted) {
        setState(() {
          // Filter hanya nampilin device yang ada namanya (ESP32 kita)
          _scanResults = results.where((r) => r.device.advName.isNotEmpty).toList();
        });
      }
    });

    FlutterBluePlus.isScanning.listen((state) {
      if (mounted) setState(() => _isScanning = state);
    });
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan(); // Pastikan scan mati saat pindah halaman
    super.dispose();
  }

  // --- LOGIKA BLUETOOTH ---
  Future<void> _toggleBluetooth(bool value) async {
    setState(() => _bluetoothEnabled = value);

    if (value) {
      // Minta Izin Dulu
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();

      if (statuses[Permission.bluetoothScan]!.isGranted) {
        if (Platform.isAndroid) await FlutterBluePlus.turnOn();
        _startScan();
      } else {
        setState(() => _bluetoothEnabled = false);
        _showSnackBar('Izin Bluetooth/Lokasi ditolak!', isError: true);
      }
    } else {
      await FlutterBluePlus.stopScan();
      setState(() {
        _scanResults.clear();
        _connectedDevice = null;
      });
    }
  }

  Future<void> _startScan() async {
    try {
      await FlutterBluePlus.stopScan(); // Stop scan sebelumnya kalau ada
      setState(() => _scanResults.clear()); // Bersihkan list
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    } catch (e) {
      debugPrint("Error scan: $e");
    }
  }

  Future<void> _connectAndConfigWifi(BluetoothDevice device) async {
    await FlutterBluePlus.stopScan();

    // Tampilkan loading muter
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)),
      );
    }

    try {
      // Konek ke ESP32 (autoConnect false biar lebih stabil dan mencegah error 133)
      await device.connect(autoConnect: false);

      // ---> FIX ERROR 133 PART 1: Minta ukuran payload yang lebih besar (MTU) <---
      if (Platform.isAndroid) {
        try {
          await device.requestMtu(512);
          await Future.delayed(const Duration(milliseconds: 500)); // Jeda biar settingan masuk
        } catch (mtuError) {
          debugPrint("Gagal request MTU, lanjut dengan default: $mtuError");
        }
      }

      setState(() => _connectedDevice = device);
      if (mounted) Navigator.pop(context); // Tutup loading

      // Buka BottomSheet untuk masukin WiFi
      _showWifiFormBottomSheet(device);

    } catch (e) {
      if (mounted) Navigator.pop(context); // Tutup loading
      _showSnackBar('Gagal terhubung ke ${device.advName}', isError: true);

      // Bersihkan koneksi yang menggantung kalau gagal
      try {
        await device.disconnect();
      } catch (_) {}
    }
  }

  Future<void> _sendWifiData(BluetoothDevice device, String ssid, String password) async {
    try {
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString() == serviceUUID) {
          for (var char in service.characteristics) {
            if (char.uuid.toString() == charUUID) {

              // Format JSON sesuai permintaan ESP32
              String jsonPayload = jsonEncode({"ssid": ssid, "pass": password});

              // ---> FIX ERROR 133 PART 2: Gunakan withoutResponse: true <---
              // Memaksa Flutter kirim data tanpa nunggu struk balasan dari ESP32
              await char.write(utf8.encode(jsonPayload), withoutResponse: true);

              _showSnackBar('Konfigurasi terkirim! ESP32 akan restart.');

              // Beri jeda sedikit agar data benar-benar terbang sebelum diputus
              await Future.delayed(const Duration(milliseconds: 500));
              await device.disconnect();

              setState(() {
                _connectedDevice = null;
                _bluetoothEnabled = false; // Matikan toggle setelah sukses
                _scanResults.clear();
              });
              return;
            }
          }
        }
      }
      _showSnackBar('Karakteristik Bluetooth tidak ditemukan!', isError: true);
      await device.disconnect();
    } catch (e) {
      _showSnackBar('Gagal mengirim data: $e', isError: true);
      await device.disconnect();
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.primaryGreen,
      ),
    );
  }

  // --- BOTTOM SHEET FORM WIFI ---
  void _showWifiFormBottomSheet(BluetoothDevice device) {
    final TextEditingController ssidController = TextEditingController();
    final TextEditingController passController = TextEditingController();

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
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Text('Setup WiFi: ${device.advName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('Masukkan detail WiFi agar perangkat bisa terhubung ke internet.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 20),

              // Input SSID
              TextField(
                controller: ssidController,
                decoration: InputDecoration(
                  hintText: 'Nama WiFi (SSID)',
                  prefixIcon: const Icon(Icons.wifi_rounded, color: AppColors.primaryGreen),
                  filled: true, fillColor: AppColors.secondaryLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),

              // Input Password
              TextField(
                controller: passController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Password WiFi',
                  prefixIcon: const Icon(Icons.lock_rounded, color: AppColors.primaryGreen),
                  filled: true, fillColor: AppColors.secondaryLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (ssidController.text.trim().isEmpty) {
                      _showSnackBar('SSID tidak boleh kosong!', isError: true);
                      return;
                    }
                    Navigator.pop(context); // Tutup form
                    _sendWifiData(device, ssidController.text.trim(), passController.text.trim());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Kirim ke Perangkat', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // --- BUILDER UTAMA ---
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            decoration: const BoxDecoration(
              color: AppColors.darkBackground,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
            ),
            child: const Text(
              'Setup Jaringan',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('BLUETOOTH', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5)),
                const SizedBox(height: 12),
                _buildBluetoothCard(),

                // --- LIST HASIL SCAN BLE ---
                if (_bluetoothEnabled) ...[
                  const SizedBox(height: 32),

                  // HEADER LIST & TOMBOL REFRESH
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                          'PERANGKAT DITEMUKAN',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.5)
                      ),
                      if (!_isScanning)
                        InkWell(
                          onTap: _startScan,
                          borderRadius: BorderRadius.circular(20),
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.refresh_rounded, color: AppColors.primaryGreen, size: 22),
                          ),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(color: AppColors.primaryGreen, strokeWidth: 2)
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // DAFTAR PERANGKAT
                  if (!_isScanning && _scanResults.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.bluetooth_searching_rounded, color: AppColors.textTertiary, size: 40),
                          SizedBox(height: 12),
                          Text('Tidak ada kandang terdekat', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          SizedBox(height: 4),
                          Text('Pastikan alat menyala dan klik tombol refresh.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _scanResults.length,
                      itemBuilder: (context, index) {
                        final data = _scanResults[index];
                        return Card(
                          elevation: 0,
                          color: AppColors.secondaryLight,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: AppColors.borderLight, width: 1),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                  color: AppColors.primaryBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8)
                              ),
                              child: const Icon(Icons.memory_rounded, color: AppColors.primaryBlue),
                            ),
                            title: Text(data.device.advName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text('MAC: ${data.device.remoteId}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            trailing: ElevatedButton(
                              onPressed: () => _connectAndConfigWifi(data.device),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                              child: const Text('Setup', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        );
                      },
                    ),
                ],
                const SizedBox(height: 40), // Jarak aman dari bawah layar
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.bluetooth_rounded, color: AppColors.primaryBlue, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Bluetooth Scanner', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  _isScanning ? 'Mencari kandang terdekat...' : 'Aktifkan untuk mencari dan setup WiFi pada alat.',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: _bluetoothEnabled,
            onChanged: _toggleBluetooth,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primaryGreen,
            inactiveTrackColor: AppColors.textTertiary.withOpacity(0.3),
            inactiveThumbColor: Colors.white,
          ),
        ],
      ),
    );
  }
}