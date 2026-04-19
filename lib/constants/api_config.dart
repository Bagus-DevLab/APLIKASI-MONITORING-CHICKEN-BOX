import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  // Fungsi inisialisasi .env
  static Future<void> initialize() async {
    await dotenv.load(fileName: ".env");
  }

  // Ambil Base URL
  static String get baseUrl => dotenv.env['BASE_URL'] ?? 'https://api.pcb.my.id';

  // --- DAFTAR ENDPOINT API ---
  
  // Auth
  static String get authFirebaseLoginUrl => '$baseUrl/auth/firebase/login';

  // Users
  static String get usersUrl => '$baseUrl/users/me';

  // Devices (Kandang)
  static String get devicesUrl => '$baseUrl/devices/';
  static String get claimDeviceUrl => '$baseUrl/devices/claim';
  
  // Devices Dinamis (Butuh ID)
  static String deviceStatusUrl(String deviceId) => '$baseUrl/devices/$deviceId/status';
  static String deviceLogsUrl(String deviceId) => '$baseUrl/devices/$deviceId/logs';
  static String deviceLogsHistoryUrl(String deviceId) => '$baseUrl/devices/$deviceId/logs?limit=50';
  static String deviceAlertsUrl(String deviceId) => '$baseUrl/devices/$deviceId/alerts';
  static String deviceControlUrl(String deviceId) => '$baseUrl/devices/$deviceId/control';
  static String deviceUnclaimUrl(String deviceId) => '$baseUrl/devices/$deviceId/unclaim';
}