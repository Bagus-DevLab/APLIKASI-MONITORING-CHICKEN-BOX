import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final controlItems = [
    {
      'icon': Icons.water_drop_rounded,
      'title': 'Automation Pump',
      'subtitle': 'Pompa Penyiraman Otomatis',
      'isEnabled': true,
      'color': const Color(0xFF2196F3), // Blue
    },
    {
      'icon': Icons.lightbulb_rounded,
      'title': 'Lampu Penghangat',
      'subtitle': 'Pemanas Kandang Ayam',
      'isEnabled': false,
      'color': const Color(0xFFFFC107), // Yellow
    },
    {
      'icon': Icons.wind_power_rounded,
      'title': 'Kipas Exhaust',
      'subtitle': 'Ventilasi Udara Kandang',
      'isEnabled': true,
      'color': const Color(0xFF2196F3), // Blue
    },
    {
      'icon': Icons.grain_rounded,
      'title': 'Pakan',
      'subtitle': 'Sistem Pemberian pakan',
      'isEnabled': false,
      'color': const Color(0xFFFF9800), // Orange
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KONDISI KANDANG Section
            _buildSectionTitle('KONDISI KANDANG'),
            const SizedBox(height: 8),
            _buildConditionCards(),
            const SizedBox(height: 20),

            // KONTROL KANDANG Section
            _buildSectionTitle('KONTROL KANDANG'),
            const SizedBox(height: 8),
            _buildControlItems(),
          ],
        ),
      ),
    );
  }

  /// Build Section Title
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

  /// Build Condition Cards (Suhu, Kelembapan, Amonia)
  Widget _buildConditionCards() {
    return const Row(
      children: [
        Expanded(
          child: _ConditionCard(
            icon: Icons.thermostat,
            label: 'SUHU',
            value: '28.5',
            unit: '°C',
            status: 'Alert',
            statusColor: AppColors.statusWarning,
            iconColor: Color(0xFFFF6B35), // Orange/Red
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _ConditionCard(
            icon: Icons.opacity_rounded,
            label: 'KELEMBAPAN',
            value: '65',
            unit: '%',
            status: 'Normal',
            statusColor: AppColors.statusNormal,
            iconColor: Color(0xFF2196F3), // Blue
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _ConditionCard(
            icon: Icons.air_rounded,
            label: 'AMONIA',
            value: '12.4',
            unit: 'PPM',
            status: 'Normal',
            statusColor: AppColors.statusNormal,
            iconColor: Color(0xFF4CAF50), // Green
          ),
        ),
      ],
    );
  }

  /// Build Control Items (Automation Pump, Lampu, Kipas Exhaust, Pakan)
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
                setState(() {
                  controlItems[index]['isEnabled'] = value;
                });
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
      padding: const EdgeInsets.all(12),
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
            size: 26,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
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
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ],
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