import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_colors.dart';
import '../constants/api_config.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  Timer? _timer;

  // Variabel Device
  String? _activeDeviceId;
  bool _isDeviceLoading = true;
  String _deviceMessage = 'Mencari kandang...';

  // Variabel Penampung Data Sensor
  String _temperature = '--';
  String _humidity = '--';
  String _ammonia = '--';
  bool _isSensorLoading = true;

  // Data kontrol kandang
  final List<Map<String, dynamic>> controlItems = [
    {
      'icon': Icons.water_drop_rounded,
      'title': 'Automation Pump',
      'subtitle': 'Pompa Penyiraman Otomatis',
      'component': 'pompa',
      'isEnabled': false,
      'color': const Color(0xFF2196F3),
    },
    {
      'icon': Icons.lightbulb_rounded,
      'title': 'Lampu Penghangat',
      'subtitle': 'Pemanas Kandang',
      'component': 'lampu',
      'isEnabled': false,
      'color': const Color(0xFFFFC107),
    },
  ];

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- FUNGSI MASTER SETUP AWAL ---
  Future<void> _initializeDashboard() async {
    await _fetchClaimedDevices();

    if (_activeDeviceId != null) {
      await _loadLocalToggleStates(); // 1. Load memori toggle lokal (Biar gak reset pas pindah tab)
      await _fetchSensorData();
      await _fetchControlStatus();    // 2. Sinkronkan state asli dari Backend API

      _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
        _fetchSensorData();
        _fetchControlStatus();        // Terus sinkronisasi
      });
    }
  }

  // --- FUNGSI LOAD STATE TOGGLE DARI MEMORI HP ---
  Future<void> _loadLocalToggleStates() async {
    if (_activeDeviceId == null) return;
    
    for (int i = 0; i < controlItems.length; i++) {
      String comp = controlItems[i]['component'];
      String? savedState = await _secureStorage.read(key: 'toggle_${_activeDeviceId}_$comp');
      
      if (savedState != null && mounted) {
        setState(() {
          controlItems[i]['isEnabled'] = (savedState == 'true');
        });
      }
    }
  }

  // --- FUNGSI CEK STATUS ASLI KE API ---
  Future<void> _fetchControlStatus() async {
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
            for (int i = 0; i < controlItems.length; i++) {
              String comp = controlItems[i]['component'];
              
              // Jika backend membalas dengan status komponen (contoh: "pompa": true)
              if (data.containsKey(comp)) {
                bool isOn = data[comp] == true || data[comp] == 1 || data[comp] == 'ON';
                controlItems[i]['isEnabled'] = isOn;
                _secureStorage.write(key: 'toggle_${_activeDeviceId}_$comp', value: isOn.toString());
              } 
              // Atau jika dalam object "state" (contoh: "state": {"pompa": true})
              else if (data['state'] != null && data['state'].containsKey(comp)) {
                bool isOn = data['state'][comp] == true || data['state'][comp] == 1 || data['state'][comp] == 'ON';
                controlItems[i]['isEnabled'] = isOn;
                _secureStorage.write(key: 'toggle_${_activeDeviceId}_$comp', value: isOn.toString());
              }
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Info: API status alat belum mendukung cek komponen. Menggunakan cache lokal.');
    }
  }

  // --- FUNGSI CEK KANDANG ---
  Future<void> _fetchClaimedDevices() async {
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
          if (mounted) {
            setState(() {
              _activeDeviceId = data[0]['id'].toString();
              _isDeviceLoading = false;
            });
          }
        } else {
          if (mounted) setState(() { _isDeviceLoading = false; _deviceMessage = 'Belum ada kandang terdaftar'; });
        }
      } else {
        if (mounted) setState(() { _isDeviceLoading = false; _deviceMessage = 'Gagal memuat data kandang'; });
      }
    } catch (e) {
      if (mounted) setState(() { _isDeviceLoading = false; _deviceMessage = 'Terjadi kesalahan jaringan'; });
    }
  }

  // --- FUNGSI CEK SENSOR ---
  Future<void> _fetchSensorData() async {
    if (_activeDeviceId == null) return;
    try {
      final token = await _secureStorage.read(key: 'jwt_token');
      if (token == null) return;

      final response = await http.get(
        Uri.parse(ApiConfig.deviceLogsUrl(_activeDeviceId!)),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          final latestLog = data[0];
          if (mounted) {
            setState(() {
              _temperature = latestLog['temperature']?.toString() ?? '--';
              _humidity = latestLog['humidity']?.toString() ?? '--';
              _ammonia = latestLog['ammonia']?.toString() ?? '--';
              _isSensorLoading = false;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetch sensor: $e');
    }
  }

  // --- FUNGSI KIRIM KONTROL KE ALAT ---
  Future<void> _toggleControl(int index, bool newValue) async {
    if (_activeDeviceId == null) return;

    final item = controlItems[index];
    final component = item['component'] as String;
    final originalValue = item['isEnabled'] as bool;

    // Optimistic update UI biar langsung responsif
    setState(() {
      controlItems[index]['isEnabled'] = newValue;
    });

    try {
      final token = await _secureStorage.read(key: 'jwt_token');
      if (token == null) throw Exception("Token tidak ditemukan");

      final response = await http.post(
        Uri.parse(ApiConfig.deviceControlUrl(_activeDeviceId!)),
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

      if (response.statusCode == 200) {
        debugPrint('Sukses ngontrol $component ke mode $newValue');
        // PENTING: Simpan state ke memori lokal jika backend membalas OK
        await _secureStorage.write(key: 'toggle_${_activeDeviceId}_$component', value: newValue.toString());
      } else {
        // Kalau gagal di sisi API, kembalikan posisi Toggle ke semula
        setState(() => controlItems[index]['isEnabled'] = originalValue);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal mengirim perintah ke kandang!'), backgroundColor: AppColors.error),
          );
        }
      }
    } catch (e) {
      // Kalau koneksi internet mati
      setState(() => controlItems[index]['isEnabled'] = originalValue);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Terjadi kesalahan jaringan!'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  // Helper status warna sensor
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
    return Container(
      color: const Color(0xFFEBEBEB),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isDeviceLoading || _activeDeviceId == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: AppColors.secondaryLight, borderRadius: BorderRadius.circular(12)),
                child: Center(
                  child: Text(
                    _isDeviceLoading ? 'Mencari kandang...' : _deviceMessage,
                    style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ),
              )
            else ...[
              // ── KONDISI KANDANG ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle('KONDISI KANDANG'),
                  Text(
                    'ID: ${_activeDeviceId!.length > 8 ? _activeDeviceId!.substring(0, 8).toUpperCase() : _activeDeviceId}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryBlue),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildConditionCards(),
              const SizedBox(height: 20),

              // ── KONTROL KANDANG ──
              _buildSectionTitle('KONTROL KANDANG'),
              const SizedBox(height: 8),
              _buildControlItems(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF333333), letterSpacing: 0.8),
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
            icon: Icons.thermostat, label: 'SUHU', value: _isSensorLoading ? '...' : _temperature, unit: '°C',
            status: tempStatus['status'], statusColor: tempStatus['color'], iconColor: const Color(0xFFFF6B35),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ConditionCard(
            icon: Icons.opacity_rounded, label: 'KELEMBAPAN', value: _isSensorLoading ? '...' : _humidity, unit: '%',
            status: 'Normal', statusColor: AppColors.statusNormal, iconColor: const Color(0xFF2196F3),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ConditionCard(
            icon: Icons.air_rounded, label: 'AMONIA', value: _isSensorLoading ? '...' : _ammonia, unit: 'PPM',
            status: ammoniaStatus['status'], statusColor: ammoniaStatus['color'], iconColor: const Color(0xFF4CAF50),
          ),
        ),
      ],
    );
  }

  Widget _buildControlItems() {
    return Column(
      children: List.generate(controlItems.length, (index) {
        final item = controlItems[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ControlItem(
            icon: item['icon'] as IconData,
            title: item['title'] as String,
            subtitle: item['subtitle'] as String,
            isEnabled: item['isEnabled'] as bool,
            color: item['color'] as Color,
            onToggle: (value) => _toggleControl(index, value),
          ),
        );
      }),
    );
  }
}

// ════════════════════════════════════════════
// CONDITION CARD UI
// ════════════════════════════════════════════
class _ConditionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final String status;
  final Color statusColor;
  final Color iconColor;

  const _ConditionCard({
    required this.icon, required this.label, required this.value, required this.unit,
    required this.status, required this.statusColor, required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary, letterSpacing: 0.2), textAlign: TextAlign.center),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(width: 2),
                Text(unit, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
// CONTROL ITEM UI
// ════════════════════════════════════════════
class _ControlItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isEnabled;
  final Color color;
  final Function(bool) onToggle;

  const _ControlItem({
    required this.icon, required this.title, required this.subtitle,
    required this.isEnabled, required this.color, required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: Color(0xFF888888))),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: isEnabled,
              onChanged: onToggle,
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF4E342E),
              inactiveThumbColor: const Color(0xFFBBBBBB),
              inactiveTrackColor: const Color(0xFFDDDDDD),
            ),
          ),
        ],
      ),
    );
  }
}