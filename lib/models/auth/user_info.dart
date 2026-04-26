/// User information model
/// 
/// Based on API_CONTRACT.md Section 3.1: Authentication
/// Returned as part of LoginResponse and GET /api/users/me
class UserInfo {
  final String email;
  final String fullName;
  final String? picture;
  final String role;

  UserInfo({
    required this.email,
    required this.fullName,
    this.picture,
    required this.role,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      picture: json['picture'] as String?,
      role: json['role'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'full_name': fullName,
      'picture': picture,
      'role': role,
    };
  }

  /// Check if user has admin privileges (admin or super_admin)
  bool get isAdmin => role == 'admin' || role == 'super_admin';

  /// Check if user is super admin
  bool get isSuperAdmin => role == 'super_admin';

  /// Check if user can control devices (operator, admin, or super_admin)
  bool get canControlDevices => 
      role == 'operator' || role == 'admin' || role == 'super_admin';

  /// Check if user is viewer only (read-only access)
  bool get isViewer => role == 'viewer';

  /// Check if user is basic user (no device access)
  bool get isBasicUser => role == 'user';

  @override
  String toString() => 'UserInfo(email: $email, role: $role)';
}
