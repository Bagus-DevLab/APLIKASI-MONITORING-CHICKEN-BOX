import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Map<String, dynamic>> controlItems = [
    {
      'icon': Icons.water_drop_rounded,
      'title': 'Automation Pump',
      'subtitle': 'Pompa Penyiraman Otomatis',
      'isEnabled': false,
      'color': const Color(0xFF2196F3),
    },
    {
      'icon': Icons.lightbulb_rounded,
      'title': 'Lampu Penghangat',
      'subtitle': 'Pemanas Kandang Ayam',
      'isEnabled': true,
      'color': const Color(0xFFFFC107),
    },
    {
      'icon': Icons.grain_rounded,
      'title': 'Pakan',
      'subtitle': 'Sistem Pemberian pakan',
      'isEnabled': true,
      'color': const Color(0xFFFF9800),
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFEBEBEB),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('KONDISI KANDANG'),
            const SizedBox(height: 10),
            _buildConditionCards(),
            const SizedBox(height: 24),
            _buildSectionTitle('KONTROL KANDANG'),
            const SizedBox(height: 10),
            _buildControlItems(),
          ],
        ),
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
    return Row(
      children: const [
        Expanded(
          child: _ConditionCard(
            icon: Icons.thermostat,
            label: 'SUHU',
            value: '28.5',
            unit: '°C',
            status: 'Naik',
            statusColor: Color(0xFFE64A19),
            iconColor: Color(0xFFFF6B35),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _ConditionCard(
            icon: Icons.opacity_rounded,
            label: 'KELEMBAPAN',
            value: '65',
            unit: '%',
            status: 'Normal',
            statusColor: Color(0xFF43A047),
            iconColor: Color(0xFF2196F3),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _ConditionCard(
            icon: Icons.air_rounded,
            label: 'AMONIA',
            value: '12.4',
            unit: 'PPM',
            status: 'Normal',
            statusColor: Color(0xFF43A047),
            iconColor: Color(0xFF4CAF50),
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
            onToggle: (value) {
              setState(() {
                controlItems[index]['isEnabled'] = value;
              });
            },
          ),
        );
      }),
    );
  }
}

// ════════════════════════════════════════════
// CONDITION CARD
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
    final bool isNaik = status == 'Naik';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: Color(0xFF888888),
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
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1A1A1A),
                  height: 1,
                ),
              ),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF888888),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isNaik
                      ? Icons.arrow_upward_rounded
                      : Icons.check_rounded,
                  size: 10,
                  color: statusColor,
                ),
                const SizedBox(width: 3),
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
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════
// CONTROL ITEM
// ════════════════════════════════════════════

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
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),

          // Text
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

          // Toggle — aktif: coklat gelap, nonaktif: abu
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