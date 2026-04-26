import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../services/device_service.dart';
import '../models/common/paginated_response.dart';
import '../models/device/device.dart';
import '../core/network/api_exception.dart';
import '../utils/error_handler.dart';
import '../constants/app_colors.dart';
import 'device_detail_page.dart';

/// Device List Page - Main dashboard after login
/// 
/// Displays a paginated list of claimed devices with role-based filtering.
/// Users can navigate to device detail pages by tapping on a device card.
/// 
/// Features:
/// - Paginated device list with Next/Previous buttons
/// - Pull-to-refresh
/// - Empty state with "Scan QR Code" button
/// - Loading states
/// - Error handling with retry
class DeviceListPage extends StatefulWidget {
  const DeviceListPage({super.key});

  @override
  State<DeviceListPage> createState() => _DeviceListPageState();
}

class _DeviceListPageState extends State<DeviceListPage> {
  final DeviceService _deviceService = DeviceService();

  // Pagination state
  PaginatedResponse<Device>? _devicesResponse;
  int _currentPage = 1;
  final int _itemsPerPage = 20;

  // Loading states
  bool _isLoading = false;
  bool _isLoadingMore = false;

  // Error state
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  /// Load devices from API
  Future<void> _loadDevices({bool isRefresh = false}) async {
    developer.log(
      '→ Loading devices (page: $_currentPage, refresh: $isRefresh)',
      name: 'DeviceListPage',
    );

    if (isRefresh) {
      setState(() {
        _currentPage = 1;
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final response = await _deviceService.getDevices(
        page: _currentPage,
        limit: _itemsPerPage,
      );

      if (mounted) {
        setState(() {
          _devicesResponse = response;
          _isLoading = false;
          _isLoadingMore = false;
          _errorMessage = null;
        });
      }

      developer.log(
        '✓ Loaded ${response.itemCount} devices (page ${response.page}/${response.totalPages})',
        name: 'DeviceListPage',
      );
    } on ApiException catch (e) {
      developer.log(
        '✗ Failed to load devices: ${e.message}',
        name: 'DeviceListPage',
        error: e,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _errorMessage = e.message;
        });

        // Show error feedback
        ErrorHandler.handleApiException(
          context,
          e,
          onRetry: () => _loadDevices(isRefresh: true),
        );
      }
    } catch (e) {
      developer.log(
        '✗ Unexpected error loading devices: $e',
        name: 'DeviceListPage',
        error: e,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _errorMessage = 'Terjadi kesalahan yang tidak diketahui';
        });

        ErrorHandler.showErrorSnackbar(
          context,
          'Terjadi kesalahan: $e',
        );
      }
    }
  }

  /// Navigate to previous page
  void _goToPreviousPage() {
    if (_devicesResponse?.hasPreviousPage == true && !_isLoadingMore) {
      setState(() => _currentPage--);
      _loadDevices();
    }
  }

  /// Navigate to next page
  void _goToNextPage() {
    if (_devicesResponse?.hasNextPage == true && !_isLoadingMore) {
      setState(() => _currentPage++);
      _loadDevices();
    }
  }

  /// Navigate to device detail page
  void _navigateToDeviceDetail(Device device) {
    developer.log(
      '→ Navigating to device detail: ${device.displayName}',
      name: 'DeviceListPage',
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DeviceDetailPage(device: device),
      ),
    ).then((_) {
      // Refresh device list when returning from detail page
      _loadDevices(isRefresh: true);
    });
  }

  /// Navigate to scan page
  void _navigateToScanPage() {
    Navigator.pushNamed(context, '/scan').then((_) {
      // Refresh device list after scanning
      _loadDevices(isRefresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToScanPage,
        backgroundColor: AppColors.primaryGreen,
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: const Text(
          'Scan QR Code',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        color: AppColors.darkBackground,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daftar Kandang',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          if (_devicesResponse != null)
            Text(
              'Total: ${_devicesResponse!.total} kandang',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_errorMessage != null && _devicesResponse == null) {
      return _buildErrorState();
    }

    if (_devicesResponse == null || _devicesResponse!.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () => _loadDevices(isRefresh: true),
      color: AppColors.primaryGreen,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _devicesResponse!.itemCount,
              itemBuilder: (context, index) {
                final device = _devicesResponse!.data[index];
                return _buildDeviceCard(device);
              },
            ),
          ),
          if (_devicesResponse!.totalPages > 1) _buildPaginationControls(),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primaryGreen),
          const SizedBox(height: 16),
          const Text(
            'Memuat daftar kandang...',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Gagal Memuat Data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Terjadi kesalahan',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _loadDevices(isRefresh: true),
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.devices_other,
                size: 64,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Belum Ada Kandang',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Scan QR code pada perangkat ESP32\nuntuk menambahkan kandang pertama Anda',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _navigateToScanPage,
              icon: const Icon(Icons.qr_code_scanner, size: 24),
              label: const Text(
                'Scan QR Code',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(Device device) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.borderLight,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _navigateToDeviceDetail(device),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Device icon with online status
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: device.isOnline
                      ? AppColors.primaryGreen.withOpacity(0.1)
                      : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.home_work_rounded,
                  size: 28,
                  color: device.isOnline
                      ? AppColors.primaryGreen
                      : Colors.grey,
                ),
              ),
              const SizedBox(width: 16),

              // Device info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'MAC: ${device.macAddress}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: device.isOnline
                                ? AppColors.statusNormal
                                : AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          device.onlineStatusDisplay,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: device.isOnline
                                ? AppColors.statusNormal
                                : AppColors.error,
                          ),
                        ),
                        if (!device.isOnline && !device.hasNeverConnected) ...[
                          const SizedBox(width: 8),
                          Text(
                            '• ${device.timeSinceLastSeenDisplay}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow icon
              const Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaginationControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _devicesResponse!.hasPreviousPage && !_isLoadingMore
                  ? _goToPreviousPage
                  : null,
              icon: const Icon(Icons.chevron_left, size: 20),
              label: const Text(
                'Sebelumnya',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                disabledForegroundColor: Colors.grey[600],
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),

          // Page indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                Text(
                  'Halaman ${_devicesResponse!.page}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  'dari ${_devicesResponse!.totalPages}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Next button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _devicesResponse!.hasNextPage && !_isLoadingMore
                  ? _goToNextPage
                  : null,
              icon: const Icon(Icons.chevron_right, size: 20),
              label: const Text(
                'Selanjutnya',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                disabledForegroundColor: Colors.grey[600],
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
