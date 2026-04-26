import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../models/device/device.dart';
import '../models/device/device_assignment.dart';
import '../services/device_service.dart';
import '../core/network/api_exception.dart';
import '../utils/error_handler.dart';
import '../constants/app_colors.dart';

/// Device Assignment Page — Manage user access for a specific device
///
/// Allows an Admin (device owner) to:
/// - View all currently assigned users (operators & viewers)
/// - Assign a new user by email with a selected role
/// - Remove an existing assignment
///
/// Flow for adding a user:
/// 1. Admin enters email → selects role (Operator/Viewer)
/// 2. `findUserByEmail()` resolves email → UUID via GET /api/admin/users
/// 3. `assignUserToDevice()` sends POST with { user_id, role }
/// 4. On success: refresh list, clear input, show SnackBar
class DeviceAssignmentPage extends StatefulWidget {
  final Device device;

  const DeviceAssignmentPage({
    super.key,
    required this.device,
  });

  @override
  State<DeviceAssignmentPage> createState() => _DeviceAssignmentPageState();
}

class _DeviceAssignmentPageState extends State<DeviceAssignmentPage> {
  final DeviceService _deviceService = DeviceService();
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();

  // State
  List<DeviceAssignment> _assignments = [];
  bool _isLoading = true;
  bool _isAdding = false;
  String _selectedRole = 'operator';
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAssignments();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // DATA LOADING
  // ═══════════════════════════════════════════════════════════════

  Future<void> _loadAssignments() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final assignments = await _deviceService.getDeviceAssignments(
        deviceId: widget.device.id,
      );

      if (!mounted) return;
      setState(() {
        _assignments = assignments;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      developer.log('✗ Failed to load assignments: $e', name: 'AssignmentPage');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.message;
      });
    } catch (e) {
      developer.log('✗ Unexpected error: $e', name: 'AssignmentPage');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Terjadi kesalahan yang tidak diketahui.';
      });
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // ASSIGN USER FLOW
  // ═══════════════════════════════════════════════════════════════

  Future<void> _handleAssignUser() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ErrorHandler.showErrorSnackbar(context, 'Masukkan email terlebih dahulu.');
      return;
    }

    // Basic email format check
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      ErrorHandler.showErrorSnackbar(context, 'Format email tidak valid.');
      return;
    }

    setState(() => _isAdding = true);
    _emailFocusNode.unfocus();

    try {
      // Step 1: Resolve email → user UUID
      final user = await _deviceService.findUserByEmail(email);

      if (user.id == null) {
        throw NotFoundException('User ID tidak ditemukan untuk email "$email".');
      }

      // Step 2: Assign user to device
      await _deviceService.assignUserToDevice(
        deviceId: widget.device.id,
        userId: user.id!,
        role: _selectedRole,
      );

      // Step 3: Success — clear input and refresh
      if (!mounted) return;
      _emailController.clear();
      ErrorHandler.showSuccessSnackbar(
        context,
        '${user.fullName} berhasil ditambahkan sebagai ${_selectedRole == 'operator' ? 'Operator' : 'Viewer'}.',
      );
      await _loadAssignments();
    } on ApiException catch (e) {
      if (!mounted) return;
      ErrorHandler.handleApiException(context, e);
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.showErrorSnackbar(
        context,
        'Terjadi kesalahan: ${e.toString()}',
      );
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // UNASSIGN USER FLOW
  // ═══════════════════════════════════════════════════════════════

  Future<void> _handleUnassignUser(DeviceAssignment assignment) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.person_remove, color: AppColors.error, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Hapus Akses',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Hapus akses ${assignment.roleDisplay} untuk ${assignment.userName} (${assignment.userEmail})?',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text(
              'Hapus',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    ErrorHandler.showLoadingDialog(context, message: 'Menghapus akses...');

    try {
      await _deviceService.unassignUserFromDevice(
        deviceId: widget.device.id,
        userId: assignment.userId,
      );

      if (!mounted) return;
      ErrorHandler.hideLoadingDialog(context);
      ErrorHandler.showSuccessSnackbar(
        context,
        '${assignment.userName} berhasil dihapus.',
      );
      await _loadAssignments();
    } on ApiException catch (e) {
      if (!mounted) return;
      ErrorHandler.hideLoadingDialog(context);
      ErrorHandler.handleApiException(context, e);
    } catch (e) {
      if (!mounted) return;
      ErrorHandler.hideLoadingDialog(context);
      ErrorHandler.showErrorSnackbar(
        context,
        'Gagal menghapus: ${e.toString()}',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════

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
            const Text(
              'Kelola Akses',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              widget.device.displayName,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Add user form (always visible at top)
          _buildAddUserForm(),

          // Divider
          const Divider(height: 1, color: AppColors.borderLight),

          // Assignment list
          Expanded(child: _buildAssignmentList()),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ADD USER FORM
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAddUserForm() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TAMBAH PEKERJA',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),

          // Email input
          TextField(
            controller: _emailController,
            focusNode: _emailFocusNode,
            enabled: !_isAdding,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _handleAssignUser(),
            decoration: InputDecoration(
              hintText: 'Email pekerja...',
              hintStyle: const TextStyle(color: AppColors.textTertiary),
              prefixIcon: const Icon(
                Icons.email_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primaryGreen,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Role selector + Add button row
          Row(
            children: [
              // Role dropdown
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedRole,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: AppColors.textSecondary,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'operator',
                          child: Row(
                            children: [
                              Icon(Icons.build_outlined,
                                  size: 18, color: Color(0xFF1976D2)),
                              SizedBox(width: 8),
                              Text('Operator'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'viewer',
                          child: Row(
                            children: [
                              Icon(Icons.visibility_outlined,
                                  size: 18, color: Color(0xFF757575)),
                              SizedBox(width: 8),
                              Text('Viewer'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: _isAdding
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _selectedRole = value);
                              }
                            },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Add button
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isAdding ? null : _handleAssignUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.primaryGreen.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                  icon: _isAdding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.person_add, size: 20),
                  label: Text(_isAdding ? 'Menambah...' : 'Tambah'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ASSIGNMENT LIST
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAssignmentList() {
    // Loading state
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(color: AppColors.primaryGreen),
        ),
      );
    }

    // Error state
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _loadAssignments,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Coba Lagi'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  side: const BorderSide(color: AppColors.primaryGreen),
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

    // Empty state
    if (_assignments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: AppColors.textTertiary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'Belum Ada Pekerja',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tambahkan operator atau viewer\nmenggunakan email mereka di atas.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // List of assignments
    return RefreshIndicator(
      onRefresh: _loadAssignments,
      color: AppColors.primaryGreen,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _assignments.length + 1, // +1 for header
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'DAFTAR PEKERJA (${_assignments.length})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                  letterSpacing: 1.0,
                ),
              ),
            );
          }

          final assignment = _assignments[index - 1];
          return _buildAssignmentTile(assignment);
        },
      ),
    );
  }

  Widget _buildAssignmentTile(DeviceAssignment assignment) {
    final isOperator = assignment.role == 'operator';
    final roleColor = isOperator
        ? const Color(0xFF1976D2)
        : const Color(0xFF757575);
    final roleBgColor = isOperator
        ? const Color(0xFFE3F2FD)
        : const Color(0xFFF5F5F5);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: roleColor.withValues(alpha: 0.15),
          child: Text(
            assignment.userInitial,
            style: TextStyle(
              color: roleColor,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
        ),
        title: Text(
          assignment.userName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              assignment.userEmail,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                // Role badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: roleBgColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOperator
                            ? Icons.build_outlined
                            : Icons.visibility_outlined,
                        size: 12,
                        color: roleColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        assignment.roleDisplay,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: roleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Date
                Text(
                  assignment.formattedCreatedAt,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(
            Icons.person_remove_outlined,
            color: AppColors.error,
            size: 22,
          ),
          tooltip: 'Hapus akses',
          onPressed: () => _handleUnassignUser(assignment),
        ),
      ),
    );
  }
}
