import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_colors.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  Timer? _timer;

  // Variabel Device
  String? _activeDeviceId; // Sekarang dinamis, bukan hardcode lagi
  bool _isDeviceLoading = true;
  String _deviceMessage = 'Mencari kandang...';

  // Variabel Penampung Data Sensor
  String _temperature = '--';
  String _humidity = '--';
  String _ammonia = '--';
  bool _isSensorLoading = true;

  // Data kontrol kandang (Tetap Sama)
  // Data kontrol kandang (Ditambah key 'component' sesuai backend)
  final controlItems = [
    {
      'icon': Icons.water_drop_rounded,
      'title': 'Automation Pump',
      'subtitle': 'Pompa Penyiraman Otomatis',
      'component': 'pompa', // <--- WAJIB SAMA DENGAN BACKEND
      'isEnabled': false,
      'color': const Color(0xFF2196F3),
    },
    {
      'icon': Icons.lightbulb_rounded,
      'title': 'Lampu Penghangat',
      'subtitle': 'Pemanas Kandang',
      'component': 'lampu', // <--- WAJIB SAMA DENGAN BACKEND
      'isEnabled': false,
      'color': const Color(0xFFFFC107),
    },
    {
      'icon': Icons.wind_power_rounded,
      'title': 'Kipas Exhaust',
      'subtitle': 'Ventilasi Udara',
      'component': 'kipas', // <--- WAJIB SAMA DENGAN BACKEND
      'isEnabled': false,
      'color': const Color(0xFF2196F3),
    },
    {
      'icon': Icons.grain_rounded,
      'title': 'Pakan',
      'subtitle': 'Sistem Pakan',
      'component': 'pakan_otomatis', // <--- WAJIB SAMA DENGAN BACKEND
      'isEnabled': false,
      'color': const Color(0xFFFF9800),
    },
  ];

  @override
  void initState() {
    super.initState();
    // 1. Jalankan inisialisasi awal (Cari device dulu)
    _initializeDashboard();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Fungsi Master untuk Setup Awal
  Future<void> _initializeDashboard() async {
    await _fetchClaimedDevices();

    // Kalau device ketemu, baru kita jalankan Timer untuk narik log sensor
    if (_activeDeviceId != null) {
      // Tarik data pertama kali secara instan
      await _fetchSensorData();

      // Bikin timer untuk update data otomatis tiap 5 detik
      _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
        _fetchSensorData();
      });
    }
  }

  // Fungsi 1: Cari Kandang yang Dimiliki User
  Future<void> _fetchClaimedDevices() async {
    try {
      final token = await _secureStorage.read(key: 'jwt_token');
      if (token == null) return;

      final response = await http.get(
        Uri.parse('https://api.pcb.my.id/devices/'), // <-- Endpoint daftar device
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Cek apakah balasan API berupa list dan tidak kosong
        if (data is List && data.isNotEmpty) {
          if (mounted) {
            setState(() {
              // ASUMSI: Mengambil device pertama dari list.
              // Sesuaikan key 'id' dengan respons FastAPI kamu (misal: 'device_id')
              _activeDeviceId = data[0]['id'].toString();
              _isDeviceLoading = false;
            });
          }
        } else {
          // Kalau user belum punya device yang di-klaim
          if (mounted) {
            setState(() {
              _isDeviceLoading = false;
              _deviceMessage = 'Belum ada kandang terdaftar';
            });
          }
        }
      } else {
        debugPrint('Gagal ambil device: ${response.statusCode}');
        if (mounted) {
          setState(() {
            _isDeviceLoading = false;
            _deviceMessage = 'Gagal memuat data kandang';
          });
        }
      }
    } catch (e) {
      debugPrint('Error device: $e');
      if (mounted) {
        setState(() {
          _isDeviceLoading = false;
          _deviceMessage = 'Terjadi kesalahan jaringan';
        });
      }
    }
  }

  // Fungsi untuk mengirim perintah kontrol ke API
  Future<void> _toggleControl(int index, bool newValue) async {
    if (_activeDeviceId == null) return;

    final item = controlItems[index];
    final component = item['component'] as String;
    final originalValue = item['isEnabled'] as bool;

    // 1. Optimistic Update: Ubah UI duluan biar kerasa cepet & responsif di mata user
    setState(() {
      controlItems[index]['isEnabled'] = newValue;
    });

    try {
      final token = await _secureStorage.read(key: 'jwt_token');
      if (token == null) throw Exception("Token tidak ditemukan");

      // 2. Tembak API Kontrol FastAPI
      final response = await http.post(
        Uri.parse('https://api.pcb.my.id/devices/$_activeDeviceId/control'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'component': component,
          'state': newValue,
        }),
      );

      // 3. Cek apakah sukses
      if (response.statusCode == 200) {
        debugPrint('Sukses ngontrol $component ke mode $newValue');
        // Opsional: Tampilkan snackbar sukses
        /* if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Berhasil ${newValue ? "menyalakan" : "mematikan"} $component')),
          );
        }
        */
      } else {
        // Kalau gagal, kembalikan posisi saklar ke semula (Revert UI)
        debugPrint('Gagal ngontrol: ${response.statusCode} - ${response.body}');
        setState(() {
          controlItems[index]['isEnabled'] = originalValue;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal mengirim perintah ke kandang!'), backgroundColor: AppColors.error),
          );
        }
      }
    } catch (e) {
      // Revert UI kalau error jaringan (misal internet putus)
      debugPrint('Error ngontrol: $e');
      setState(() {
        controlItems[index]['isEnabled'] = originalValue;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Terjadi kesalahan jaringan!'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // Fungsi 2: Tarik Data Sensor Berdasarkan ID Kandang
  Future<void> _fetchSensorData() async {
    if (_activeDeviceId == null) return;

    try {
      final token = await _secureStorage.read(key: 'jwt_token');
      if (token == null) return;

      final response = await http.get(
        // Pakai _activeDeviceId yang udah didapat dari fungsi sebelumnya
        Uri.parse('https://api.pcb.my.id/devices/$_activeDeviceId/logs'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is List && data.isNotEmpty) {
          // Ambil log yang paling pertama (index 0)
          // Biasanya kalau query di DB di-order_by desc, data terbaru ada di index 0
          final latestLog = data[0];

          if (mounted) {
            setState(() {
              // UBAH KEY-NYA JADI BAHASA INGGRIS SESUAI DATABASE KAMU
              _temperature = latestLog['temperature']?.toString() ?? '--';
              _humidity = latestLog['humidity']?.toString() ?? '--';
              _ammonia = latestLog['ammonia']?.toString() ?? '--'; // atau 'nh3' kalau di DB kamu namanya nh3

              _isSensorLoading = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetch sensor: $e');
    }
  }

  // Helper status warna (Tetap Sama)
  Map<String, dynamic> _getStatus(double value, String type) {
    if (type == 'Suhu') {
      if (value > 35) return {'status': 'Alert', 'color': AppColors.statusAlert};
      if (value > 30 || value < 25) return {'status': 'Warning', 'color': AppColors.statusWarning};
      return {'status': 'Normal', 'color': AppColors.statusNormal};
    } else if (type == 'Amonia') {
      if (value > 20) return {'status': 'Alert', 'color': AppColors.statusAlert};
      if (value > 10) return {'status': 'Warning', 'color': AppColors.statusWarning};
      return {'status': 'Normal', 'color': AppColors.statusNormal};
    }
    return {'status': 'Normal', 'color': AppColors.statusNormal};
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cek apakah device ada atau sedang loading
            if (_isDeviceLoading || _activeDeviceId == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.secondaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    _isDeviceLoading ? 'Mencari kandang...' : _deviceMessage,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else ...[
              // KONDISI KANDANG Section
              // KONDISI KANDANG Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle('KONDISI KANDANG'),
                  Text(
                    // Menampilkan 8 karakter pertama saja dari UUID
                    'ID: ${_activeDeviceId != null && _activeDeviceId!.length > 8 ? _activeDeviceId!.substring(0, 8).toUpperCase() : _activeDeviceId}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildConditionCards(),
              const SizedBox(height: 20),

              // KONTROL KANDANG Section
              _buildSectionTitle('KONTROL KANDANG'),
              const SizedBox(height: 8),
              _buildControlItems(),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildConditionCards() {
    double tempVal = double.tryParse(_temperature) ?? 0;
    double ammoniaVal = double.tryParse(_ammonia) ?? 0;

    final tempStatus = _getStatus(tempVal, 'Suhu');
    final ammoniaStatus = _getStatus(ammoniaVal, 'Amonia');

    return Row(
      children: [
        Expanded(
          child: _ConditionCard(
            icon: Icons.thermostat,
            label: 'SUHU',
            value: _isSensorLoading ? '...' : _temperature,
            unit: '°C',
            status: tempStatus['status'],
            statusColor: tempStatus['color'],
            iconColor: const Color(0xFFFF6B35),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ConditionCard(
            icon: Icons.opacity_rounded,
            label: 'KELEMBAPAN',
            value: _isSensorLoading ? '...' : _humidity,
            unit: '%',
            status: 'Normal',
            statusColor: AppColors.statusNormal,
            iconColor: const Color(0xFF2196F3),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ConditionCard(
            icon: Icons.air_rounded,
            label: 'AMONIA',
            value: _isSensorLoading ? '...' : _ammonia,
            unit: 'PPM',
            status: ammoniaStatus['status'],
            statusColor: ammoniaStatus['color'],
            iconColor: const Color(0xFF4CAF50),
          ),
        ),
      ],
    );
  }

  Widget _buildControlItems() {
    return Column(
      children: List.generate(
        controlItems.length,
            (index) {
          final item = controlItems[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ControlItem(
              icon: item['icon'] as IconData,
              title: item['title'] as String,
              subtitle: item['subtitle'] as String,
              isEnabled: item['isEnabled'] as bool,
              color: item['color'] as Color,
              onToggle: (value) {
                // Panggil fungsi kontrol yang nembak API
                _toggleControl(index, value);
              },
            ),
          );
        },
      ),
    );
  }
}

// ============ CONDITION CARD WIDGET ============

class _ConditionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final String status;
  final Color statusColor;
  final Color iconColor;

  const _ConditionCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.status,
    required this.statusColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // Padding horizontal dikurangi biar teks punya ruang lebih lebar
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 24, // Icon sedikit dikecilkan
          ),
          const SizedBox(height: 6),

          // FITTEDBOX 1: Untuk Label (Suhu, Kelembapan, Amonia)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.2,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 4),

          // FITTEDBOX 2: Untuk Angka dan Satuan
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22, // Angka default dikecilkan sedikit
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // FITTEDBOX 3: Untuk Status (Normal, Warning, Alert)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============ CONTROL ITEM WIDGET ============

class _ControlItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isEnabled;
  final Color color;
  final Function(bool) onToggle;

  const _ControlItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isEnabled,
    required this.color,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColor,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Icon Container
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),

          // Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Toggle Switch
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: isEnabled,
              onChanged: onToggle,
              activeThumbColor: Colors.white,
              activeTrackColor: color,
              inactiveTrackColor: AppColors.textTertiary.withValues(alpha: 0.3),
              inactiveThumbColor: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}