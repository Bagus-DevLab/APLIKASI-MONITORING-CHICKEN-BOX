import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  int _historyTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.darkBackground,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Riwayat',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Data Monitoring Kandang',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.accentOrange,
                ),
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
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _buildHistoryTabContent(),
            ),
          ),
        ),
      ],
    );
  }

  /// Build history tab button
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
                  color: isSelected
                      ? AppColors.primaryGreen
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.primaryGreen
                        : AppColors.textSecondary,
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

  /// Build history tab content based on selected tab
  Widget _buildHistoryTabContent() {
    switch (_historyTabIndex) {
      case 0:
        return _buildSuhuTable();
      case 1:
        return _buildKelembapanTable();
      case 2:
        return _buildAmoniaTable();
      case 3:
        return _buildAktivitasList();
      default:
        return _buildSuhuTable();
    }
  }

  /// Build Suhu Table
  Widget _buildSuhuTable() {
    final suhuData = [
      {'waktu': '15:00', 'nilai': '28.5°C', 'status': 'warning'},
      {'waktu': '14:00', 'nilai': '28.2°C', 'status': 'normal'},
      {'waktu': '13:00', 'nilai': '27.9°C', 'status': 'normal'},
      {'waktu': '12:00', 'nilai': '27.6°C', 'status': 'normal'},
      {'waktu': '11:00', 'nilai': '26.8°C', 'status': 'normal'},
      {'waktu': '10:00', 'nilai': '26.6°C', 'status': 'normal'},
      {'waktu': '09:00', 'nilai': '26.4°C', 'status': 'normal'},
      {'waktu': '08:00', 'nilai': '26.1°C', 'status': 'normal'},
      {'waktu': '07:00', 'nilai': '25.5°C', 'status': 'normal'},
      {'waktu': '06:00', 'nilai': '25.3°C', 'status': 'normal'},
      {'waktu': '05:00', 'nilai': '24.8°C', 'status': 'normal'},
      {'waktu': '04:00', 'nilai': '24.6°C', 'status': 'normal'},
      {'waktu': '03:00', 'nilai': '24.9°C', 'status': 'normal'},
      {'waktu': '02:00', 'nilai': '24.4°C', 'status': 'normal'},
      {'waktu': '01:00', 'nilai': '24.2°C', 'status': 'normal'},
    ];

    return _buildDataTable('Data Suhu Per jam', suhuData);
  }

  /// Build Kelembapan Table
  Widget _buildKelembapanTable() {
    final kelembapanData = [
      {'waktu': '15:00', 'nilai': '78%', 'status': 'warning'},
      {'waktu': '14:00', 'nilai': '76%', 'status': 'normal'},
      {'waktu': '13:00', 'nilai': '72%', 'status': 'normal'},
      {'waktu': '12:00', 'nilai': '72%', 'status': 'normal'},
      {'waktu': '11:00', 'nilai': '68%', 'status': 'normal'},
      {'waktu': '10:00', 'nilai': '68%', 'status': 'normal'},
      {'waktu': '09:00', 'nilai': '66%', 'status': 'normal'},
      {'waktu': '08:00', 'nilai': '68%', 'status': 'normal'},
      {'waktu': '07:00', 'nilai': '68%', 'status': 'normal'},
      {'waktu': '06:00', 'nilai': '68%', 'status': 'normal'},
      {'waktu': '05:00', 'nilai': '55%', 'status': 'normal'},
      {'waktu': '04:00', 'nilai': '55%', 'status': 'normal'},
      {'waktu': '03:00', 'nilai': '55%', 'status': 'normal'},
      {'waktu': '02:00', 'nilai': '55%', 'status': 'normal'},
      {'waktu': '01:00', 'nilai': '55%', 'status': 'normal'},
    ];

    return _buildDataTable('Data Kelembapan Per jam', kelembapanData);
  }

  /// Build Amonia Table
  Widget _buildAmoniaTable() {
    final amoniaData = [
      {'waktu': '15:00', 'nilai': '18.2 ppm', 'status': 'warning'},
      {'waktu': '14:00', 'nilai': '16.8 ppm', 'status': 'warning'},
      {'waktu': '13:00', 'nilai': '14.2 ppm', 'status': 'normal'},
      {'waktu': '12:00', 'nilai': '14.0 ppm', 'status': 'normal'},
      {'waktu': '11:00', 'nilai': '15.1 ppm', 'status': 'normal'},
      {'waktu': '10:00', 'nilai': '12.4 ppm', 'status': 'normal'},
      {'waktu': '09:00', 'nilai': '11.8 ppm', 'status': 'normal'},
      {'waktu': '08:00', 'nilai': '10.8 ppm', 'status': 'normal'},
      {'waktu': '07:00', 'nilai': '9.6 ppm', 'status': 'normal'},
      {'waktu': '06:00', 'nilai': '9.4 ppm', 'status': 'normal'},
      {'waktu': '05:00', 'nilai': '9.0 ppm', 'status': 'normal'},
      {'waktu': '04:00', 'nilai': '8.4 ppm', 'status': 'normal'},
      {'waktu': '03:00', 'nilai': '8.2 ppm', 'status': 'normal'},
      {'waktu': '02:00', 'nilai': '8.2 ppm', 'status': 'normal'},
      {'waktu': '01:00', 'nilai': '8.0 ppm', 'status': 'normal'},
    ];

    return _buildDataTable('Data Amonia Per jam', amoniaData);
  }

  /// Build Data Table
  Widget _buildDataTable(String title, List<Map<String, String>> data) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          // Table
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                // Column Header
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: Text(
                        'WAKTU',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'NILAI',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'STATUS',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: AppColors.borderLight),
                const SizedBox(height: 8),

                // Data rows
                ...data.map((item) {
                  final isWarning = item['status'] == 'warning';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Text(
                            item['waktu']!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Text(
                            item['nilai']!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isWarning
                                  ? AppColors.accentOrange
                                  : AppColors.primaryGreen,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Icon(
                              isWarning
                                  ? Icons.warning_rounded
                                  : Icons.check_circle_rounded,
                              size: 20,
                              color: isWarning
                                  ? AppColors.statusWarning
                                  : AppColors.statusNormal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Build Aktivitas List
  Widget _buildAktivitasList() {
    final activities = [
      {
        'icon': Icons.warning_rounded,
        'iconColor': const Color(0xFFE74C3C),
        'title': 'Amonia Melebihi Batas',
        'description':
            'Kadar amonia mencapai 18.2 ppm, melebihi batas aman 15 ppm.',
        'time': '15:00 - Hari ini',
      },
      {
        'icon': Icons.air_rounded,
        'iconColor': AppColors.primaryBlue,
        'title': 'Kipas Exhaust Dinyalakan',
        'description': 'Kipas exhaust otomatis aktif karena amonia tinggi.',
        'time': '15:02 - Hari ini',
      },
      {
        'icon': Icons.lightbulb_rounded,
        'iconColor': const Color(0xFFFFB300),
        'title': 'Lampu Penghangat Aktif',
        'description':
            'Lampu penghangat dinyalakan untuk menjaga suhu kandang.',
        'time': '08:30 - Hari ini',
      },
      {
        'icon': Icons.inventory_2_rounded,
        'iconColor': AppColors.accentOrange,
        'title': 'Pakan Otomatis Berjalan',
        'description': 'Sistem pakan otomatis berjalan sesuai jadwal pagi.',
        'time': '07:00 - Hari ini',
      },
      {
        'icon': Icons.water_drop_rounded,
        'iconColor': AppColors.primaryBlue,
        'title': 'Pompa Dimatikan',
        'description': 'Pompa penyiram dimatikan oleh pengguna.',
        'time': '08:15 - Hari ini',
      },
      {
        'icon': Icons.thermostat_rounded,
        'iconColor': const Color(0xFFE74C3C),
        'title': 'Suhu Meningkat',
        'description': 'Suhu kandang naik ke 28°C, mendekati batas atas.',
        'time': '15:00 - Hari ini',
      },
    ];

    return Column(
      children: activities
          .map(
            (activity) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: (activity['iconColor'] as Color)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        activity['icon'] as IconData,
                        color: activity['iconColor'] as Color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            activity['title'] as String,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            activity['description'] as String,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            activity['time'] as String,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}