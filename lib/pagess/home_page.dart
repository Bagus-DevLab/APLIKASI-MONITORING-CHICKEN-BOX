import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../routes/app_routes.dart';
import '../constants/floating_navbar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  int _historyTabIndex = 0;
  bool _bluetoothEnabled = false;
  final TextEditingController _namaCandangController = TextEditingController();
  final TextEditingController _idPerangkatController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _currentIndex == 0
          ? KandangAppBar(
              userName: 'Hai, Dafri',
              userRole: 'Salamat Pagi',
              userImageUrl: 'assets/images/profil.jpg',
              isOnline: true,
              onNotificationTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notification tapped!')),
                );
              },
              notificationCount: 1,
            )
          : null,
      body: Column(
        children: [
          // Main Content - Scrollable
          Expanded(
            child: _buildPageContent(),
          ),

          // Fixed Floating NavBar
          Container(
            margin: const EdgeInsets.only(
              bottom: 20,
              left: 20,
              right: 20,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowColorDark,
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NavItem(
                    icon: Icons.home_rounded,
                    label: 'Home',
                    isSelected: _currentIndex == 0,
                    onTap: () => setState(() => _currentIndex = 0),
                  ),
                  _NavItem(
                    icon: Icons.dashboard_customize_rounded,
                    label: 'Perangkat',
                    isSelected: _currentIndex == 1,
                    onTap: () => setState(() => _currentIndex = 1),
                  ),
                  _NavItem(
                    icon: Icons.history_rounded,
                    label: 'Riwayat',
                    isSelected: _currentIndex == 2,
                    onTap: () => setState(() => _currentIndex = 2),
                  ),
                  _NavItem(
                    icon: Icons.person_rounded,
                    label: 'Profil',
                    isSelected: _currentIndex == 3,
                    onTap: () => setState(() => _currentIndex = 3),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the appropriate page content based on current index
  Widget _buildPageContent() {
    switch (_currentIndex) {
      case 0:
        return _buildHomePage();
      case 1:
        return _buildDevicesPage();
      case 2:
        return _buildHistoryContent();
      case 3:
        return _buildProfilePage();
      default:
        return _buildHomePage();
    }
  }

  // ============ PROFILE PAGE ============
  Widget _buildProfilePage() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Profile Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 28,
            ),
            decoration: BoxDecoration(
              color: AppColors.darkBackground,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Profile Image
                Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    color: AppColors.accentOrange,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/profil.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.person,
                          size: 60,
                          color: Colors.white,
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // User Name
                const Text(
                  'Defri',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 24),

                // "Profil" Title
                const Text(
                  'Profil',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),

          // Content Area
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Informasi Akun Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'INFORMASI AKUN',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Email Field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'EMAIL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.shadowColor,
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Text(
                            'defriamaliya231@gmail.com',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Kandang Saya Section
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'KANDANG SAYA',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Kandang List
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadowColor,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Daftar Kandang',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadowColor,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Kandang Ayam Petelur - 1000 Ekor',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _showLogoutConfirmation,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                        color: AppColors.statusAlert,
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'Keluar dari akun',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.statusAlert,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi Logout'),
          content: const Text('Apakah Anda yakin ingin keluar?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.login,
                  (route) => false,
                );
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  /// History Page Content
  Widget _buildHistoryContent() {
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
        'iconColor': AppColors.statusWarning,
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
        'iconColor': AppColors.accentOrange,
        'title': 'Lampu Penghangat Aktif',
        'description':
            'Lampu penghangat dinyalakan untuk menjaga suhu kandang.',
        'time': '08:30 - Hari ini',
      },
      {
        'icon': Icons.pets_rounded,
        'iconColor': AppColors.primaryGreen,
        'title': 'Pakan Otomatis Berjalan',
        'description': 'Sistem pakan otomatis berjalan sesuai jadwal pagi.',
        'time': '07:00 - Hari ini',
      },
      {
        'icon': Icons.opacity_rounded,
        'iconColor': AppColors.primaryBlue,
        'title': 'Pompa Dimatikan',
        'description': 'Pompa penyiram dimatikan oleh pengguna.',
        'time': '08:15 - Hari ini',
      },
      {
        'icon': Icons.thermostat_rounded,
        'iconColor': AppColors.statusWarning,
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

  /// Home Page Content
  Widget _buildHomePage() {
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

  /// Devices/Perangkat Page Content
  Widget _buildDevicesPage() {
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
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: const Text(
              'Tambah Perangkat',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // BLUETOOTH Section
                const Text(
                  'BLUETOOTH',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                _buildBluetoothCard(),
                const SizedBox(height: 32),

                // Input Manual Divider
                const Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: AppColors.borderLight,
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'Input Manual',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: AppColors.borderLight,
                        thickness: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Manual Input Card
                _buildManualInputCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build Bluetooth Card
  Widget _buildBluetoothCard() {
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
      child: Row(
        children: [
          // Bluetooth Icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.bluetooth_rounded,
              color: AppColors.primaryBlue,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),

          // Content
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Bluetooth',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Aktifkan untuk mencari perangkat terdekat dan Pastikan alat sudah di colok kelistrik.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Toggle
          Switch(
            value: _bluetoothEnabled,
            onChanged: (value) {
              setState(() => _bluetoothEnabled = value);
            },
            activeThumbColor: AppColors.primaryGreen,
            activeTrackColor: AppColors.primaryGreen.withValues(alpha: 0.4),
            inactiveTrackColor: AppColors.textTertiary.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  /// Build Manual Input Card
  Widget _buildManualInputCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Input ID Kandang Manual',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Masukkan ID perangkat secara manual jika tidak ditemukan lewat Bluetooth.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Nama Kandang Input
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Nama Kandang',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _namaCandangController,
                decoration: InputDecoration(
                  hintText: 'Contoh: Kandang A',
                  hintStyle: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: AppColors.lightBackground,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.borderLight,
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.borderLight,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primaryGreen,
                      width: 2,
                    ),
                  ),
                ),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ID Perangkat Input
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ID Perangkat',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _idPerangkatController,
                decoration: InputDecoration(
                  hintText: 'Contoh: ESP32-AIB2C3',
                  hintStyle: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: AppColors.lightBackground,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.borderLight,
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.borderLight,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primaryGreen,
                      width: 2,
                    ),
                  ),
                ),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Simpan Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Handle save action
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Perangkat disimpan ke server!'),
                    backgroundColor: Colors.green,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Simpan Ke Server',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============ HELPER WIDGETS ============

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

// ============ NAVBAR ITEM WIDGET ============

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.primaryGreen.withValues(alpha: 0.1),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? AppColors.primaryGreen
                      : AppColors.textTertiary,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? AppColors.primaryGreen
                        : AppColors.textTertiary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}