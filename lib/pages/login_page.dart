import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert'; // Wajib buat jsonEncode & jsonDecode
import 'package:http/http.dart' as http; // Wajib buat nembak API
import '../routes/app_routes.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Gunakan instance GoogleSignIn tanpa parameter dulu untuk mencoba default config dari json
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Logout dulu untuk memastikan prompt akun muncul bersih
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // Kalau user batalin login (tutup popup Google)
      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 1. Ambil token otentikasi dari Google
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 2. Buat kredensial khusus buat Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 3. LOGIN KE FIREBASE
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // 4. Ambil Token Firebase (Ini KTP sementaranya)
        final String? firebaseToken = await user.getIdToken();

        if (firebaseToken != null) {

          // ---> PROSES TUKAR TAMBAH TOKEN KE BACKEND VPS <---
          final response = await http.post(
            Uri.parse('https://api.pcb.my.id/auth/firebase/login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'id_token': firebaseToken, // Kirim KTP Firebase
            }),
          );

          // 5. Cek jawaban dari FastAPI lu
          if (response.statusCode == 200) {
            final responseData = jsonDecode(response.body);

            // Ambil JWT Lokal buatan FastAPI
            final String backendToken = responseData['access_token'];

            // Simpan JWT Lokal ke memori HP
            await _secureStorage.write(key: 'jwt_token', value: backendToken);

            // 6. Login Sukses 100%, Pindah ke halaman Home
            if (mounted) {
              Navigator.of(context).pushReplacementNamed(AppRoutes.home);
            }
          } else {
            // Kalau FastAPI nolak tokennya
            throw Exception('Backend menolak login: ${response.statusCode} - ${response.body}');
          }

        }
      } else {
        throw Exception('Gagal mendapatkan user dari Firebase.');
      }

    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Firebase Error: ${e.message}'),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan: $error'),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ... (KODINGAN UI KE BAWAH TETAP SAMA PERSIS, TIDAK ADA YANG DIUBAH) ...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  color: const Color(0xFF5C4033),
                  width: double.infinity,
                  padding: const EdgeInsets.only(
                    top: 40,
                    bottom: 0,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.08),
                      Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.home,
                                            size: 70,
                                            color: Color(0xFFFF8C00),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              Positioned(
                                top: -10,
                                right: -10,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1976D2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.wifi,
                                    size: 24,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          const Text(
                            'KANDANG PINTAR',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Monitoring Ternak Lebih Efisien',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFFC0C0C0),
                              letterSpacing: 0.3,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: MediaQuery.of(context).size.height * 0.08),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  height: 80,
                  child: CustomPaint(
                    painter: WavyDividerPainter(),
                  ),
                ),
                Container(
                  color: const Color(0xFFEBEBEB),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 40,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selamat Datang',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF1A1A1A),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Masuk dengan akun Google kamu untuk mulai monitoring kandang ayam.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF666666),
                          height: 1.6,
                          letterSpacing: 0.2,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleGoogleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            elevation: 3,
                            shadowColor: Colors.black.withValues(alpha: 0.15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5C4033)),
                            ),
                          )
                              : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/google_logo.png',
                                width: 24,
                                height: 24,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.account_circle,
                                    size: 24,
                                    color: Color(0xFF1F2937),
                                  );
                                },
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Masuk dengan Google',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1F2937),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF888888),
                            letterSpacing: 0.1,
                            height: 1.5,
                          ),
                          children: [
                            TextSpan(
                              text: 'Dengan masuk, kamu menyetujui ',
                            ),
                            TextSpan(
                              text: 'Syarat & Ketentuan',
                              style: TextStyle(
                                color: Color(0xFFC62828),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(
                              text: ' serta Kebijakan Privasi Smart Kandang.',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 25,
            left: -25,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 3,
                ),
              ),
            ),
          ),
          Positioned(
            top: 80,
            right: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 3,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 180,
            left: -35,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WavyDividerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final brownPaint = Paint()
      ..color = const Color(0xFF5C4033)
      ..style = PaintingStyle.fill;

    final grayPaint = Paint()
      ..color = const Color(0xFFEBEBEB)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      grayPaint,
    );

    final path = Path();
    path.moveTo(0, size.height * 0.4);

    double waveWidth = 80;
    double waveHeight = 40;

    for (double x = 0; x <= size.width; x += waveWidth) {
      path.quadraticBezierTo(
        x + waveWidth / 2,
        size.height * 0.4 - waveHeight,
        x + waveWidth,
        size.height * 0.4,
      );
    }

    path.lineTo(size.width, 0);
    path.lineTo(0, 0);
    path.close();

    canvas.drawPath(path, brownPaint);
  }

  @override
  bool shouldRepaint(WavyDividerPainter oldDelegate) => false;
}