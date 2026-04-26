/// Device assignment model representing a user assigned to a device
///
/// Based on API_CONTRACT.md Section 3.3: Device Management
/// Endpoints: POST /api/devices/{device_id}/assign
///            GET  /api/devices/{device_id}/assignments
///
/// Response structure:
/// ```json
/// {
///   "id": "c3d4e5f6-a7b8-9012-cdef-123456789012",
///   "device_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
///   "user_id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",
///   "user_email": "operator@example.com",
///   "user_name": "Operator One",
///   "role": "operator",
///   "assigned_by": "d4e5f6a7-b8c9-0123-def0-1234567890ab",
///   "created_at": "2026-04-26T10:30:00Z"
/// }
/// ```
class DeviceAssignment {
  /// Unique assignment record ID (UUID)
  final String id;

  /// Target device ID (UUID)
  final String deviceId;

  /// Assigned user's ID (UUID)
  final String userId;

  /// Assigned user's email address
  final String userEmail;

  /// Assigned user's display name
  final String userName;

  /// Access level granted: "operator" or "viewer"
  final String role;

  /// UUID of the admin who created this assignment
  final String assignedBy;

  /// Timestamp when the assignment was created
  final DateTime createdAt;

  DeviceAssignment({
    required this.id,
    required this.deviceId,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.role,
    required this.assignedBy,
    required this.createdAt,
  });

  /// Create DeviceAssignment from JSON
  factory DeviceAssignment.fromJson(Map<String, dynamic> json) {
    return DeviceAssignment(
      id: json['id'] as String,
      deviceId: json['device_id'] as String,
      userId: json['user_id'] as String,
      userEmail: json['user_email'] as String,
      userName: json['user_name'] as String,
      role: json['role'] as String,
      assignedBy: json['assigned_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert DeviceAssignment to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'user_id': userId,
      'user_email': userEmail,
      'user_name': userName,
      'role': role,
      'assigned_by': assignedBy,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // ═══════════════════════════════════════════════════════════════
  // UTILITY GETTERS
  // ═══════════════════════════════════════════════════════════════

  /// Human-readable role display in Indonesian
  String get roleDisplay {
    switch (role) {
      case 'operator':
        return 'Operator';
      case 'viewer':
        return 'Viewer';
      default:
        return role;
    }
  }

  /// Whether this assignment grants control access
  bool get canControl => role == 'operator';

  /// Whether this assignment is view-only
  bool get isViewOnly => role == 'viewer';

  /// User's initial letter for avatar display
  String get userInitial {
    if (userName.isNotEmpty) return userName[0].toUpperCase();
    if (userEmail.isNotEmpty) return userEmail[0].toUpperCase();
    return '?';
  }

  /// Formatted creation date: "26 Apr 2026, 10:30"
  String get formattedCreatedAt {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    final local = createdAt.toLocal();
    final month = months[local.month - 1];
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} $month ${local.year}, $hour:$minute';
  }

  @override
  String toString() =>
      'DeviceAssignment(id: $id, user: $userEmail, role: $role)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeviceAssignment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
