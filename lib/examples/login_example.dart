import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../core/network/api_exception.dart';
import '../constants/api_config.dart';

/// Example implementation of login flow using the new networking infrastructure
/// 
/// This example demonstrates:
/// 1. Initializing ApiConfig on app startup
/// 2. Listening to global logout events
/// 3. Handling Firebase authentication
/// 4. Calling AuthService.login()
/// 5. Handling all possible error types
/// 
/// IMPORTANT: This is a reference implementation. Adapt it to your existing login_page.dart

class LoginPageExample extends StatefulWidget {
  const LoginPageExample({super.key});

  @override
  State<LoginPageExample> createState() => _LoginPageExampleState();
}

class _LoginPageExampleState extends State<LoginPageExample> {
  final AuthService _authService = AuthService();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    
    // Listen to global logout events (401/403 errors)
    _authService.onLogout.listen((_) {
      if (mounted) {
        // Navigate to login screen
        Navigator.of(context).pushReplacementNamed('/login');
        
        // Show logout message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesi Anda telah berakhir. Silakan login kembali.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  /// Handle Google Sign-In and backend login
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      // Step 1: Sign in with Firebase (Google)
      final GoogleAuthProvider googleProvider = GoogleAuthProvider();
      final UserCredential userCredential = 
          await _firebaseAuth.signInWithProvider(googleProvider);

      // Step 2: Get Firebase ID token
      final String? idToken = await userCredential.user?.getIdToken();
      
      if (idToken == null) {
        throw Exception('Gagal mendapatkan token Firebase');
      }

      // Step 3: Exchange Firebase token for backend JWT
      final loginResponse = await _authService.login(idToken);

      // Step 4: Navigate to home screen
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Selamat datang, ${loginResponse.userInfo.fullName}!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } on ValidationException catch (e) {
      // 422 Validation Error - Token too long or invalid format
      _showErrorDialog(
        'Validasi Gagal',
        e.allMessages,
      );
    } on UnauthorizedException catch (e) {
      // 401 Unauthorized - Invalid or expired Firebase token
      _showErrorDialog(
        'Token Tidak Valid',
        e.message,
      );
    } on ForbiddenException catch (e) {
      // 403 Forbidden - Account deactivated
      _showErrorDialog(
        'Akses Ditolak',
        e.message,
      );
    } on RateLimitException catch (e) {
      // 429 Rate Limit - Too many login attempts
      _showErrorDialog(
        'Terlalu Banyak Percobaan',
        e.message,
      );
    } on NetworkException catch (e) {
      // Network error - No internet, timeout, etc.
      _showErrorDialog(
        'Kesalahan Jaringan',
        e.message,
      );
    } on ApiException catch (e) {
      // Other API errors
      _showErrorDialog(
        'Kesalahan',
        e.message,
      );
    } catch (e) {
      // Unexpected errors
      _showErrorDialog(
        'Kesalahan Tidak Diketahui',
        'Terjadi kesalahan: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton.icon(
                onPressed: _handleGoogleSignIn,
                icon: const Icon(Icons.login),
                label: const Text('Sign in with Google'),
              ),
      ),
    );
  }
}

/// Example: Initialize ApiConfig in main.dart
/// 
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   
///   // Initialize Firebase
///   await Firebase.initializeApp();
///   
///   // Initialize ApiConfig (loads .env and configures DioClient)
///   await ApiConfig.initialize();
///   
///   runApp(const MyApp());
/// }
/// ```

/// Example: Making authenticated API calls
/// 
/// ```dart
/// import 'package:dio/dio.dart';
/// import '../core/network/dio_client.dart';
/// import '../core/network/api_exception.dart';
/// import '../constants/api_config.dart';
/// 
/// class DeviceService {
///   final Dio _dio = DioClient().dio;
///   
///   Future<List<Device>> getDevices() async {
///     try {
///       final response = await _dio.get(ApiConfig.devicesUrl);
///       
///       if (response.statusCode == 200) {
///         final data = response.data['data'] as List;
///         return data.map((json) => Device.fromJson(json)).toList();
///       }
///       
///       throw UnknownException('Unexpected status: ${response.statusCode}');
///     } on DioException catch (e) {
///       if (e.error is ApiException) {
///         throw e.error as ApiException;
///       }
///       throw NetworkException('Network error: ${e.message}');
///     }
///   }
/// }
/// ```

/// Example: Handling errors in UI
/// 
/// ```dart
/// try {
///   final devices = await deviceService.getDevices();
///   setState(() => _devices = devices);
/// } on UnauthorizedException catch (e) {
///   // User will be automatically logged out by AuthInterceptor
///   // Just show a message
///   ScaffoldMessenger.of(context).showSnackBar(
///     SnackBar(content: Text(e.message)),
///   );
/// } on ForbiddenException catch (e) {
///   // User doesn't have permission
///   showDialog(
///     context: context,
///     builder: (context) => AlertDialog(
///       title: const Text('Akses Ditolak'),
///       content: Text(e.message),
///       actions: [
///         TextButton(
///           onPressed: () => Navigator.pop(context),
///           child: const Text('OK'),
///         ),
///       ],
///     ),
///   );
/// } on RateLimitException catch (e) {
///   // Rate limit exceeded - show "please wait" message
///   ScaffoldMessenger.of(context).showSnackBar(
///     SnackBar(
///       content: Text(e.message),
///       duration: const Duration(seconds: 5),
///     ),
///   );
/// } on NetworkException catch (e) {
///   // Network error - show retry option
///   ScaffoldMessenger.of(context).showSnackBar(
///     SnackBar(
///       content: Text(e.message),
///       action: SnackBarAction(
///         label: 'Retry',
///         onPressed: () => _loadDevices(),
///       ),
///     ),
///   );
/// }
/// ```
