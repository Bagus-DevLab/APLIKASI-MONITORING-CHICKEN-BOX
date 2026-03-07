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
    },
    {
      'icon': Icons.lightbulb_rounded,
      'title': 'Lampu Penghangat',
      'subtitle': 'Pemanas Kandang Ayam',
      'isEnabled': false,
    },
    {
      'icon': Icons.air_rounded,
      'title': 'Kipas Exhaust',
      'subtitle': 'Ventilasi Udara Kandang',
      'isEnabled': true,
    },
    {
      'icon': Icons.pets_rounded,
      'title': 'Pakan',
      'subtitle': 'Sistem Pemberian pakan',
      'isEnabled': false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KONDISI KANDANG Section
            _buildSectionTitle('KONDISI KANDANG'),
            const SizedBox(height: 12),
            _buildConditionCards(),
            const SizedBox(height: 32),

            // KONTROL KANDANG Section
            _buildSectionTitle('KONTROL KANDANG'),
            const SizedBox(height: 12),
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
            padding: const EdgeInsets.only(bottom: 12),
            child: _ControlItem(
              icon: item['icon'] as IconData,
              title: item['title'] as String,
              subtitle: item['subtitle'] as String,
              isEnabled: item['isEnabled'] as bool,
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

  const _ConditionCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.secondaryLight,
        borderRadius: BorderRadius.circular(16),
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
            color: AppColors.primaryGreen,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
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
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
  final Function(bool) onToggle;

  const _ControlItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isEnabled,
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: AppColors.primaryGreen,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          // Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
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
              activeThumbColor: AppColors.primaryGreen,
              activeTrackColor: AppColors.primaryGreen.withValues(alpha: 0.4),
              inactiveTrackColor: AppColors.textTertiary.withValues(alpha: 0.3),
              inactiveThumbColor: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}