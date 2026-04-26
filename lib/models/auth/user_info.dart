/// User information model
/// 
/// Based on API_CONTRACT.md Section 3.1: Authentication
/// Returned as part of LoginResponse and GET /api/users/me
/// 
/// Note: The `id` field is nullable because the login response's
/// nested `user_info` object does not include it, while
/// `GET /api/users/me` and `GET /api/admin/users` do.
class UserInfo {
  /// User UUID — present in /users/me and /admin/users responses,
  /// absent in the login response's nested user_info object.
  final String? id;

  final String email;
  final String fullName;
  final String? picture;
  final String role;

  UserInfo({
    this.id,
    required this.email,
    required this.fullName,
    this.picture,
    required this.role,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id'] as String?,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      picture: json['picture'] as String?,
      role: json['role'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
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
