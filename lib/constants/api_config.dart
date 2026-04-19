import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  // Fungsi inisialisasi .env
  static Future<void> initialize() async {
    await dotenv.load(fileName: ".env");
  }

  // Ambil Base URL
  static String get baseUrl => dotenv.env['BASE_URL'] ?? 'https://api.pcb.my.id';

  // ─── DAFTAR ENDPOINT API ───
  
  // Authentication
  static String get authFirebaseLoginUrl => '$baseUrl/auth/firebase/login';

  // Users
  static String get usersUrl => '$baseUrl/users/me';
  // (Method GET untuk baca, PATCH untuk update, DELETE untuk hapus akun bisa pakai URL yang sama ini)

  // Devices (Kandang)
  static String get devicesUrl => '$baseUrl/devices/';
  static String get claimDeviceUrl => '$baseUrl/devices/claim';
  static String get registerDeviceUrl => '$baseUrl/devices/register';     // BARU
  static String get unclaimedDevicesUrl => '$baseUrl/devices/unclaimed';  // BARU
  
  // Devices Dinamis (Butuh Device ID)
  static String deviceStatusUrl(String deviceId) => '$baseUrl/devices/$deviceId/status';
  static String deviceLogsUrl(String deviceId) => '$baseUrl/devices/$deviceId/logs';
  static String deviceLogsHistoryUrl(String deviceId) => '$baseUrl/devices/$deviceId/logs?limit=50';
  static String deviceAlertsUrl(String deviceId) => '$baseUrl/devices/$deviceId/alerts';
  static String deviceControlUrl(String deviceId) => '$baseUrl/devices/$deviceId/control';
  static String deviceUnclaimUrl(String deviceId) => '$baseUrl/devices/$deviceId/unclaim';
}