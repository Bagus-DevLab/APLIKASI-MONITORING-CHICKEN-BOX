import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:developer' as developer;
import '../services/device_service.dart';
import '../models/device/device.dart';
import '../models/device/sensor_log.dart';
import '../models/device/device_component.dart';
import '../models/common/paginated_response.dart';
import '../core/network/api_exception.dart';
import '../utils/error_handler.dart';
import '../constants/app_colors.dart';

/// Device Detail Page - Shows sensor data and control switches for a specific device
/// 
/// Accepts a Device object as an argument and displays:
/// - Real-time sensor data (temperature, humidity, ammonia)
/// - Control switches for device components (kipas, lampu, pompa, pakan_otomatis)
/// - Device online status
/// 
/// Features:
/// - Auto-refresh sensor data every 5 seconds
/// - Per-switch loading indicators
/// - Optimistic UI updates with rollback on error
/// - Backend state as single source of truth (no local cache)
class DeviceDetailPage extends StatefulWidget {
  final Device device;

  const DeviceDetailPage({
    super.key,
    required this.device,
  });

  @override
  State<DeviceDetailPage> createState() => _DeviceDetailPageState();
}

class _DeviceDetailPageState extends State<DeviceDetailPage> {
  final DeviceService _deviceService = DeviceService();
  Timer? _timer;

  // Sensor data state
  String _temperature = '--';
  String _humidity = '--';
  String _ammonia = '--';
  bool _isSensorLoading = true;

  // Control items state
  late List<_ControlItemState> _controlItems;

  @override
  void initState() {
    super.initState();
    _initializeControlItems();
    _initializeDashboard();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Initialize control items with DeviceComponent enum
  void _initializeControlItems() {
    _controlItems = [
      _ControlItemState(
        component: DeviceComponent.kipas,
        icon: Icons.air_rounded,
        color: const Color(0xFF2196F3),
      ),
      _ControlItemState(
        component: DeviceComponent.lampu,
        icon: Icons.lightbulb_rounded,
        color: const Color(0xFFFFC107),
      ),
      _ControlItemState(
        component: DeviceComponent.pompa,
        icon: Icons.water_drop_rounded,
        color: const Color(0xFF2196F3),
      ),
      _ControlItemState(
        component: DeviceComponent.pakanOtomatis,
        icon: Icons.restaurant_rounded,
        color: const Color(0xFF4CAF50),
      ),
    ];
  }

  /// Initialize dashboard - load sensor data and start auto-refresh
  Future<void> _initializeDashboard() async {
    developer.log(
      '→ Initializing dashboard for device: ${widget.device.displayName}',
      name: 'DeviceDetailPage',
    );

    await _fetchSensorData();

    // Auto-refresh every 5 seconds
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _fetchSensorData();
    });
  }

  /// Fetch latest sensor data from API
  Future<void> _fetchSensorData() async {
    try {
      final logsResponse = await _deviceService.getDeviceLogs(
        deviceId: widget.device.id,
        page: 1,
        limit: 1,
      );

      if (logsResponse.isNotEmpty && mounted) {
        final latestLog = logsResponse.data.first;
        setState(() {
          _temperature = latestLog.temperature.toStringAsFixed(1);
          _humidity = latestLog.humidity.toStringAsFixed(1);
          _ammonia = latestLog.ammonia.toStringAsFixed(1);
          _isSensorLoading = false;
        });

        developer.log(
          '✓ Sensor data updated: T=${_temperature}°C, H=${_humidity}%, A=${_ammonia}ppm',
          name: 'DeviceDetailPage',
        );
      }
    } on NotFoundException catch (e) {
      developer.log(
        '✗ Device not found or no logs: ${e.message}',
        name: 'DeviceDetailPage',
      );
      if (mounted) {
        setState(() => _isSensorLoading = false);
      }
    } catch (e) {
      developer.log(
        '✗ Error fetching sensor data: $e',
        name: 'DeviceDetailPage',
        error: e,
      );
      // Don't show error for background refresh failures
    }
  }

  /// Toggle device component (with per-switch loading state)
  Future<void> _toggleControl(int index, bool newValue) async {
    final item = _controlItems[index];
    final originalValue = item.isEnabled;

    developer.log(
      '→ Toggling ${item.component.displayName} to ${newValue ? "ON" : "OFF"}',
      name: 'DeviceDetailPage',
    );

    // Show loading state on THIS switch only
    setState(() {
      item.isLoading = true;
      item.isEnabled = newValue; // Optimistic update
    });

    try {
      await _deviceService.controlDevice(
        deviceId: widget.device.id,
        component: item.component,
        state: newValue,
      );

      // Success - keep the new state
      if (mounted) {
        setState(() => item.isLoading = false);

        ErrorHandler.showSuccessSnackbar(
          context,
          '${item.component.displayName} berhasil ${newValue ? "dinyalakan" : "dimatikan"}',
        );
      }

      developer.log(
        '✓ ${item.component.displayName} toggled successfully',
        name: 'DeviceDetailPage',
      );
    } on ForbiddenException catch (e) {
      // Viewer role cannot control
      developer.log(
        '✗ Control forbidden: ${e.message}',
        name: 'DeviceDetailPage',
      );

      if (mounted) {
        setState(() {
          item.isEnabled = originalValue; // Revert
          item.isLoading = false;
        });
        ErrorHandler.showErrorDialog(context, 'Akses Ditolak', e.message);
      }
    } on ServerException catch (e) {
      // MQTT broker unreachable
      developer.log(
        '✗ Server error: ${e.message}',
        name: 'DeviceDetailPage',
      );

      if (mounted) {
        setState(() {
          item.isEnabled = originalValue; // Revert
          item.isLoading = false;
        });
        ErrorHandler.showErrorDialog(
          context,
          'Gagal Mengirim Perintah',
          e.message,
        );
      }
    } on RateLimitException catch (e) {
      // Rate limit exceeded
      developer.log(
        '✗ Rate limit exceeded: ${e.message}',
        name: 'DeviceDetailPage',
      );

      if (mounted) {
        setState(() {
          item.isEnabled = originalValue; // Revert
          item.isLoading = false;
        });
        ErrorHandler.showRateLimitSnackbar(context, e.message);
      }
    } on NetworkException catch (e) {
      // Network error
      developer.log(
        '✗ Network error: ${e.message}',
        name: 'DeviceDetailPage',
      );

      if (mounted) {
        setState(() {
          item.isEnabled = originalValue; // Revert
          item.isLoading = false;
        });
        ErrorHandler.showNetworkErrorSnackbar(
          context,
          e.message,
          () => _toggleControl(index, newValue),
        );
      }
    } catch (e) {
      developer.log(
        '✗ Unexpected error: $e',
        name: 'DeviceDetailPage',
        error: e,
      );

      if (mounted) {
        setState(() {
          item.isEnabled = originalValue; // Revert
          item.isLoading = false;
        });
        ErrorHandler.showErrorSnackbar(context, 'Terjadi kesalahan: $e');
      }
    }
  }

  /// Get temperature status based on contract thresholds
  Map<String, dynamic> _getTemperatureStatus(double value) {
    if (value >= 25 && value <= 30) {
      return {'status': 'Normal', 'color': AppColors.statusNormal};
    } else if ((value >= 20 && value < 25) || (value > 30 && value <= 35)) {
      return {'status': 'Waspada', 'color': AppColors.statusWarning};
    } else {
      return {'status': 'Bahaya', 'color': AppColors.statusAlert};
    }
  }

  /// Get ammonia status
  Map<String, dynamic> _getAmmoniaStatus(double value) {
    if (value <= 10) {
      return {'status': 'Normal', 'color': AppColors.statusNormal};
    } else if (value <= 20) {
      return {'status': 'Waspada', 'color': AppColors.statusWarning};
    } else {
      return {'status': 'Bahaya', 'color': AppColors.statusAlert};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBEBEB),
      appBar: AppBar(
        backgroundColor: AppColors.darkBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.device.displayName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.device.isOnline ? Colors.green : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.device.onlineStatusDisplay,
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.device.isOnline
                        ? Colors.greenAccent
                        : Colors.redAccent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Device info card
            _buildDeviceInfoCard(),
            const SizedBox(height: 20),

            // Sensor data section
            _buildSectionTitle('KONDISI KANDANG'),
            const SizedBox(height: 8),
            _buildConditionCards(),
            const SizedBox(height: 20),

            // Control section
            _buildSectionTitle('KONTROL KANDANG'),
            const SizedBox(height: 8),
            _buildControlItems(),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 20, color: AppColors.primaryBlue),
              const SizedBox(width: 8),
              const Text(
                'Informasi Device',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow('MAC Address', widget.device.macAddress),
          _buildInfoRow('Device ID', widget.device.id.substring(0, 8).toUpperCase()),
          if (!widget.device.hasNeverConnected)
            _buildInfoRow('Terakhir Terlihat', widget.device.timeSinceLastSeenDisplay),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Color(0xFF333333),
        letterSpacing: 0.8,
      ),
    );
  }

  Widget _buildConditionCards() {
    double tempVal = double.tryParse(_temperature) ?? 0;
    double ammoniaVal = double.tryParse(_ammonia) ?? 0;

    final tempStatus = _getTemperatureStatus(tempVal);
    final ammoniaStatus = _getAmmoniaStatus(ammoniaVal);

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
      children: List.generate(_controlItems.length, (index) {
        final item = _controlItems[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ControlItem(
            icon: item.icon,
            title: item.component.displayName,
            subtitle: item.component.englishName,
            isEnabled: item.isEnabled,
            isLoading: item.isLoading,
            color: item.color,
            onToggle: (value) => _toggleControl(index, value),
          ),
        );
      }),
    );
  }
}

/// Control item state class
class _ControlItemState {
  final DeviceComponent component;
  final IconData icon;
  final Color color;
  bool isEnabled;
  bool isLoading;

  _ControlItemState({
    required this.component,
    required this.icon,
    required this.color,
    this.isEnabled = false,
    this.isLoading = false,
  });
}

/// Condition card widget
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 6),
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
                    fontSize: 22,
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
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
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

/// Control item widget with loading state
class _ControlItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isEnabled;
  final bool isLoading;
  final Color color;
  final Function(bool) onToggle;

  const _ControlItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isEnabled,
    required this.isLoading,
    required this.color,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF888888),
                  ),
                ),
              ],
            ),
          ),
          // Show loading indicator or switch
          if (isLoading)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryGreen,
              ),
            )
          else
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
