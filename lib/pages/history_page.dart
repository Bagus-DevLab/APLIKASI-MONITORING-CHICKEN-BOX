import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import '../core/network/dio_client.dart';
import '../constants/app_colors.dart';
import '../constants/api_config.dart';


class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  int _historyTabIndex = 0;

  final Dio _dio = DioClient().dio;

  bool _isLoading = true;
  String? _activeDeviceId;
  List<dynamic> _sensorLogs = [];
  List<dynamic> _alertsLog = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchHistoryData();
    });
  }

  // --- FUNGSI AMBIL DATA DARI API (via DioClient) ---
  Future<void> _fetchHistoryData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // 1. Dapatkan Device ID dulu
      // AuthInterceptor handles the token automatically.
      // Non-2xx responses throw DioException (handled by interceptor).
      final devResponse = await _dio.get(ApiConfig.devicesUrl);

      final devData = devResponse.data;
      // Backend returns paginated response: { data: [...], total, page, ... }
      final List devices = devData is Map
          ? (devData['data'] as List? ?? [])
          : (devData is List ? devData : []);

      if (devices.isNotEmpty) {
        _activeDeviceId = devices[0]['id'].toString();

        // 2. Fetch Logs (Suhu, Kelembapan, Amonia) — 50 data terakhir
        final logsResponse = await _dio.get(
          ApiConfig.deviceLogsHistoryUrl(_activeDeviceId!),
        );

        // 3. Fetch Alerts (tab Aktivitas)
        final alertsResponse = await _dio.get(
          ApiConfig.deviceAlertsUrl(_activeDeviceId!),
        );

        if (!mounted) return;
        setState(() {
          // Paginated: extract the 'data' array
          final logsData = logsResponse.data;
          _sensorLogs = logsData is Map
              ? (logsData['data'] as List? ?? [])
              : (logsData is List ? logsData : []);

          final alertsData = alertsResponse.data;
          _alertsLog = alertsData is Map
              ? (alertsData['data'] as List? ?? [])
              : (alertsData is List ? alertsData : []);

          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } on DioException catch (e) {
      // Typed ApiException from interceptor (401 triggers global logout)
      developer.log('✗ API error fetching history: ${e.error}', name: 'HistoryPage');
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      developer.log('✗ Error fetching history: $e', name: 'HistoryPage');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- HELPER FORMAT WAKTU ---
  String _formatTime(String isoTime) {
    try {
      final date = DateTime.parse(isoTime).toLocal();
      return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return "--:--";
    }
  }

  String _formatDate(String isoTime) {
    try {
      final date = DateTime.parse(isoTime).toLocal();
      return "${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return "--:--";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: const BoxDecoration(
            color: AppColors.darkBackground,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Riwayat',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                  ),
                  // Tombol Refresh Manual
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                    onPressed: _fetchHistoryData,
                  )
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Data Monitoring Kandang Terakhir',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.accentOrange),
              ),
            ],
          ),
        ),

        // Tabs
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildHistoryTab('Suhu', 0, Icons.thermostat_rounded),
                const SizedBox(width: 12),
                _buildHistoryTab('Kelembapan', 1, Icons.opacity_rounded),
                const SizedBox(width: 12),
                _buildHistoryTab('Amonia', 2, Icons.air_rounded),
                const SizedBox(width: 12),
                _buildHistoryTab('Aktivitas', 3, Icons.trending_up_rounded),
              ],
            ),
          ),
        ),

        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryGreen))
              : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildHistoryTabContent(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab(String label, int index, IconData icon) {
    final isSelected = _historyTabIndex == index;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _historyTabIndex = index),
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? AppColors.primaryGreen : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? AppColors.primaryGreen : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isSelected)
              Container(
                height: 3,
                width: 60,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTabContent() {
    if (_sensorLogs.isEmpty && _historyTabIndex != 3) {
      return const Center(child: Text("Belum ada data masuk."));
    }

    switch (_historyTabIndex) {
      case 0: return _buildSuhuTable();
      case 1: return _buildKelembapanTable();
      case 2: return _buildAmoniaTable();
      case 3: return _buildAktivitasList();
      default: return _buildSuhuTable();
    }
  }

  Widget _buildSuhuTable() {
    List<Map<String, String>> data = _sensorLogs.map((log) {
      double val = log['temperature'] != null ? (log['temperature'] as num).toDouble() : 0.0;
      bool isWarning = val > 30.0 || val < 25.0; // Anggap >30 atau <25 itu warning
      return {
        'waktu': _formatTime(log['timestamp']),
        'nilai': '${val.toStringAsFixed(1)}°C',
        'status': isWarning ? 'warning' : 'normal',
      };
    }).toList();
    return _buildDataTable('Data Suhu (50 Terakhir)', data);
  }

  Widget _buildKelembapanTable() {
    List<Map<String, String>> data = _sensorLogs.map((log) {
      double val = log['humidity'] != null ? (log['humidity'] as num).toDouble() : 0.0;
      bool isWarning = val > 80.0 || val < 50.0; // Sesuai standar kelembapan
      return {
        'waktu': _formatTime(log['timestamp']),
        'nilai': '${val.toStringAsFixed(1)}%',
        'status': isWarning ? 'warning' : 'normal',
      };
    }).toList();
    return _buildDataTable('Data Kelembapan (50 Terakhir)', data);
  }

  Widget _buildAmoniaTable() {
    List<Map<String, String>> data = _sensorLogs.map((log) {
      double val = log['ammonia'] != null ? (log['ammonia'] as num).toDouble() : 0.0;
      bool isWarning = val > 15.0; // Amonia > 15 ppm bahaya
      return {
        'waktu': _formatTime(log['timestamp']),
        'nilai': '${val.toStringAsFixed(1)} ppm',
        'status': isWarning ? 'warning' : 'normal',
      };
    }).toList();
    return _buildDataTable('Data Amonia (50 Terakhir)', data);
  }

  Widget _buildDataTable(String title, List<Map<String, String>> data) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const Row(
                  children: [
                    Expanded(flex: 1, child: Text('WAKTU', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                    Expanded(flex: 1, child: Text('NILAI', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                    Expanded(flex: 1, child: Text('STATUS', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: AppColors.borderLight),
                const SizedBox(height: 8),
                ...data.map((item) {
                  final isWarning = item['status'] == 'warning';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(flex: 1, child: Text(item['waktu']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary))),
                        Expanded(
                            flex: 1,
                            child: Text(
                              item['nilai']!,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isWarning ? AppColors.accentOrange : AppColors.primaryGreen),
                            )
                        ),
                        Expanded(
                            flex: 1,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Icon(
                                  isWarning ? Icons.warning_rounded : Icons.check_circle_rounded,
                                  size: 20,
                                  color: isWarning ? AppColors.statusWarning : AppColors.statusNormal
                              ),
                            )
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildAktivitasList() {
    if (_alertsLog.isEmpty) {
      return const Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Text("Kandang aman, belum ada catatan bahaya.", style: TextStyle(color: AppColors.textSecondary)),
          )
      );
    }

    return Column(
      children: _alertsLog.map((alert) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.secondaryLight,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: AppColors.shadowColor, blurRadius: 4, offset: const Offset(0, 2))],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: const Color(0xFFE74C3C).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.warning_rounded, color: Color(0xFFE74C3C), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Peringatan Sensor', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      const SizedBox(height: 4),
                      Text(
                        alert['alert_message'] ?? 'Ada kondisi tidak normal',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: AppColors.textSecondary, height: 1.4),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatDate(alert['timestamp']),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: AppColors.textTertiary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}