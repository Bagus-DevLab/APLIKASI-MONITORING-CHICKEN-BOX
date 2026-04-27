import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:developer' as developer;
import '../services/device_service.dart';
import '../core/network/token_manager.dart';
import '../models/device/device.dart';
import '../models/device/device_component.dart';
import '../core/network/api_exception.dart';
import '../providers/device_provider.dart';
import '../constants/app_colors.dart';
import 'device_assignment_page.dart';

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
  int? _lightLevel;  // 0 = gelap, 1 = terang, null = no data
  bool _isSensorLoading = true;

  // Current user ID for ownership check (controls "Kelola Akses" visibility)
  String? _currentUserId;

  @override
  void initState() {
    super.initState();

    // Defer API calls and Provider access to the next frame so that
    // TokenManager has finished initializing after navigation completes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _initializeDashboard();
      _loadCurrentUserId();

      // Sync toggle states with the global DeviceProvider.
      // This ensures the Provider has an entry for this device so
      // Consumer<DeviceProvider> can read/write component states.
      final provider = Provider.of<DeviceProvider>(context, listen: false);
      provider.refreshDeviceStates(widget.device.id);
    });
  }

  /// Load current user's UUID from TokenManager for ownership comparison
  Future<void> _loadCurrentUserId() async {
    final userId = await TokenManager().getUserId();
    if (mounted) {
      setState(() => _currentUserId = userId);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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
          _lightLevel = latestLog.lightLevel;
          _isSensorLoading = false;
        });

        developer.log(
          '✓ Sensor data updated: T=${_temperature}°C, H=${_humidity}%, A=${_ammonia}ppm, L=${latestLog.lightLevelDisplay}',
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
        actions: [
          // Only show "Kelola Akses" if the current user is the device owner.
          // Operators/viewers should not see this button — the backend also
          // enforces this with a 403, but hiding the button prevents confusion.
          if (_currentUserId != null &&
              _currentUserId == widget.device.userId)
            IconButton(
              icon: const Icon(Icons.people_outline, color: Colors.white),
              tooltip: 'Kelola Akses',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DeviceAssignmentPage(
                      device: widget.device,
                    ),
                  ),
                );
              },
            ),
        ],
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
            const SizedBox(height: 10),
            _buildLightLevelIndicator(),
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

  /// Build a subtle chip/badge showing the current light level.
  ///
  /// Displays "Terang" (bright, sunny icon) or "Gelap" (dark, moon icon).
  /// Shows a loading placeholder while sensor data is being fetched.
  Widget _buildLightLevelIndicator() {
    final bool isBright = _lightLevel == 1;
    final String label = _isSensorLoading
        ? 'Memuat...'
        : (_lightLevel != null ? (isBright ? 'Terang' : 'Gelap') : 'N/A');
    final IconData icon = _isSensorLoading
        ? Icons.hourglass_empty
        : (isBright ? Icons.wb_sunny_rounded : Icons.nightlight_round);
    final Color color = _isSensorLoading
        ? AppColors.textSecondary
        : (isBright ? const Color(0xFFFFA000) : const Color(0xFF5C6BC0));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            'Kondisi Cahaya:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Build control items using Consumer<DeviceProvider> for global state.
  ///
  /// Each component reads its ON/OFF and loading state from the Provider,
  /// ensuring state persists across navigation (the root cause fix).
  Widget _buildControlItems() {
    // Static list of components to render.
    // Currently only Lampu and Pompa are wired on the "Lite" hardware.
    // Uncomment the others when the full relay board is deployed.
    const components = [
      // DeviceComponent.kipas,
      DeviceComponent.lampu,
      DeviceComponent.pompa,
      // DeviceComponent.pakanOtomatis,
      // DeviceComponent.exhaustFan,
    ];

    return Consumer<DeviceProvider>(
      builder: (context, provider, child) {
        return Column(
          children: components.map((component) {
            final isEnabled = provider.getComponentState(
              widget.device.id,
              component,
            );
            final isLoading = provider.isComponentLoading(
              widget.device.id,
              component,
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ControlItem(
                icon: _getComponentIcon(component),
                title: component.displayName,
                subtitle: component.englishName,
                isEnabled: isEnabled,
                isLoading: isLoading,
                color: _getComponentColor(component),
                onToggle: (value) {
                  provider.toggleComponent(
                    context,
                    widget.device.id,
                    component,
                    value,
                  );
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  /// Map DeviceComponent to its Material icon.
  IconData _getComponentIcon(DeviceComponent component) {
    switch (component) {
      case DeviceComponent.kipas:
        return Icons.air_rounded;
      case DeviceComponent.lampu:
        return Icons.lightbulb_rounded;
      case DeviceComponent.pompa:
        return Icons.water_drop_rounded;
      case DeviceComponent.pakanOtomatis:
        return Icons.restaurant_rounded;
      case DeviceComponent.exhaustFan:
        return Icons.wind_power;
    }
  }

  /// Map DeviceComponent to its brand color.
  Color _getComponentColor(DeviceComponent component) {
    switch (component) {
      case DeviceComponent.kipas:
        return const Color(0xFF2196F3);
      case DeviceComponent.lampu:
        return const Color(0xFFFFC107);
      case DeviceComponent.pompa:
        return const Color(0xFF2196F3);
      case DeviceComponent.pakanOtomatis:
        return const Color(0xFF4CAF50);
      case DeviceComponent.exhaustFan:
        return const Color(0xFF00BCD4);
    }
  }
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
