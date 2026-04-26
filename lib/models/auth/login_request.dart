/// Login request model for POST /api/auth/firebase/login
/// 
/// Based on API_CONTRACT.md Section 3.1: Authentication
/// 
/// Constraints:
/// - id_token: Required, max 4096 chars
class LoginRequest {
  final String idToken;

  LoginRequest({required this.idToken});

  /// Validate id_token length (max 4096 chars as per contract)
  bool isValid() {
    return idToken.isNotEmpty && idToken.length <= 4096;
  }

  Map<String, dynamic> toJson() {
    return {
      'id_token': idToken,
    };
  }

  @override
  String toString() => 'LoginRequest(idToken: ${idToken.substring(0, 20)}...)';
}
