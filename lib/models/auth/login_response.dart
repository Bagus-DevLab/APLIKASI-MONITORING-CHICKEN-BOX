import 'user_info.dart';

/// Login response model for POST /api/auth/firebase/login
/// 
/// Based on API_CONTRACT.md Section 3.1: Authentication
/// 
/// Response structure:
/// ```json
/// {
///   "access_token": "eyJhbGciOiJIUzI1NiIs...",
///   "token_type": "bearer",
///   "user_info": {
///     "email": "user@example.com",
///     "full_name": "John Doe",
///     "picture": "https://lh3.googleusercontent.com/...",
///     "role": "user"
///   }
/// }
/// ```
class LoginResponse {
  final String accessToken;
  final String tokenType;
  final UserInfo userInfo;

  LoginResponse({
    required this.accessToken,
    required this.tokenType,
    required this.userInfo,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String,
      userInfo: UserInfo.fromJson(json['user_info'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'token_type': tokenType,
      'user_info': userInfo.toJson(),
    };
  }

  /// Get the full Authorization header value
  String get authorizationHeader => '$tokenType $accessToken';

  @override
  String toString() => 
      'LoginResponse(tokenType: $tokenType, user: ${userInfo.email})';
}
