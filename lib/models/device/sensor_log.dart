/// Sensor log model representing a single sensor reading
/// 
/// Based on API_CONTRACT.md Section 3.3: Device Management
/// GET /api/devices/{device_id}/logs
/// 
/// Sensor Log Fields (from contract line 722-734):
/// - id: integer (auto-increment log ID)
/// - temperature: float (temperature in Celsius)
/// - humidity: float (relative humidity percentage)
/// - ammonia: float (ammonia concentration in ppm)
/// - light_level: integer or null (LDR reading: 0 = dark, 1 = bright)
/// - is_alert: boolean (whether this reading triggered an alert)
/// - alert_message: string or null (alert description, null if no alert)
/// - timestamp: ISO 8601 (when the reading was recorded)
/// 
/// Data is sorted by timestamp DESC (newest first) by backend.
/// 
/// Example JSON:
/// ```json
/// {
///   "id": 12345,
///   "temperature": 30.5,
///   "humidity": 75.0,
///   "ammonia": 12.5,
///   "light_level": 1,
///   "is_alert": false,
///   "alert_message": null,
///   "timestamp": "2026-04-26T10:30:00Z"
/// }
/// ```
class SensorLog {
  /// Auto-increment log ID
  final int id;

  /// Temperature in Celsius
  final double temperature;

  /// Relative humidity percentage (0-100)
  final double humidity;

  /// Ammonia concentration in ppm (parts per million)
  final double ammonia;

  /// LDR light level reading: 0 = dark (gelap), 1 = bright (terang)
  /// Null for legacy data that predates the LDR sensor addition.
  final int? lightLevel;

  /// Whether this reading triggered an alert
  final bool isAlert;

  /// Alert description (e.g., "Suhu terlalu tinggi: 36.5°C")
  /// Null if no alert
  final String? alertMessage;

  /// When the reading was recorded (ISO 8601)
  final DateTime timestamp;

  SensorLog({
    required this.id,
    required this.temperature,
    required this.humidity,
    required this.ammonia,
    this.lightLevel,
    required this.isAlert,
    this.alertMessage,
    required this.timestamp,
  });

  /// Create SensorLog from JSON
  factory SensorLog.fromJson(Map<String, dynamic> json) {
    return SensorLog(
      id: json['id'] as int,
      temperature: (json['temperature'] as num).toDouble(),
      humidity: (json['humidity'] as num).toDouble(),
      ammonia: (json['ammonia'] as num).toDouble(),
      lightLevel: json['light_level'] as int?,
      isAlert: json['is_alert'] as bool,
      alertMessage: json['alert_message'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  /// Convert SensorLog to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'temperature': temperature,
      'humidity': humidity,
      'ammonia': ammonia,
      'light_level': lightLevel,
      'is_alert': isAlert,
      'alert_message': alertMessage,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Check if this log has an alert
  bool get hasAlert => isAlert;

  /// Get formatted timestamp for display
  /// Format: "26 Apr 2026, 10:30"
  String get formattedTimestamp {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final day = timestamp.day;
    final month = months[timestamp.month - 1];
    final year = timestamp.year;
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$day $month $year, $hour:$minute';
  }

  /// Get short formatted timestamp for display
  /// Format: "10:30" (today) or "26 Apr" (other days)
  String get shortFormattedTimestamp {
    final now = DateTime.now();
    final isToday = timestamp.year == now.year &&
        timestamp.month == now.month &&
        timestamp.day == now.day;

    if (isToday) {
      final hour = timestamp.hour.toString().padLeft(2, '0');
      final minute = timestamp.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else {
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      final day = timestamp.day;
      final month = months[timestamp.month - 1];
      return '$day $month';
    }
  }

  /// Get temperature display with unit
  /// Format: "30.5°C"
  String get temperatureDisplay => '${temperature.toStringAsFixed(1)}°C';

  /// Get humidity display with unit
  /// Format: "75.0%"
  String get humidityDisplay => '${humidity.toStringAsFixed(1)}%';

  /// Get ammonia display with unit
  /// Format: "12.5 ppm"
  String get ammoniaDisplay => '${ammonia.toStringAsFixed(1)} ppm';

  /// Get human-readable light level display
  /// Returns "Terang" (bright), "Gelap" (dark), or "N/A" (no data)
  String get lightLevelDisplay {
    final level = lightLevel;
    if (level == null) return 'N/A';
    return level == 1 ? 'Terang' : 'Gelap';
  }

  /// Whether the coop is bright (light_level == 1)
  bool get isBright => lightLevel == 1;

  /// Get temperature status based on contract thresholds
  /// Normal: 25-30°C
  /// Waspada: 20-25°C or 30-35°C
  /// Bahaya: <20°C or >35°C
  String get temperatureStatus {
    if (temperature >= 25 && temperature <= 30) {
      return 'Normal';
    } else if ((temperature >= 20 && temperature < 25) ||
        (temperature > 30 && temperature <= 35)) {
      return 'Waspada';
    } else {
      return 'Bahaya';
    }
  }

  /// Get temperature status color for UI
  String get temperatureStatusColor {
    switch (temperatureStatus) {
      case 'Normal':
        return 'green';
      case 'Waspada':
        return 'orange';
      case 'Bahaya':
        return 'red';
      default:
        return 'gray';
    }
  }

  /// Check if temperature is in normal range (25-30°C)
  bool get isTemperatureNormal => temperature >= 25 && temperature <= 30;

  /// Check if temperature is in warning range (20-25°C or 30-35°C)
  bool get isTemperatureWarning =>
      (temperature >= 20 && temperature < 25) ||
      (temperature > 30 && temperature <= 35);

  /// Check if temperature is in danger range (<20°C or >35°C)
  bool get isTemperatureDanger => temperature < 20 || temperature > 35;

  /// Get relative time display (e.g., "5 menit yang lalu")
  String get relativeTimeDisplay {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds} detik yang lalu';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} menit yang lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam yang lalu';
    } else {
      return '${difference.inDays} hari yang lalu';
    }
  }

  /// Copy with method for immutable updates
  SensorLog copyWith({
    int? id,
    double? temperature,
    double? humidity,
    double? ammonia,
    int? lightLevel,
    bool? isAlert,
    String? alertMessage,
    DateTime? timestamp,
  }) {
    return SensorLog(
      id: id ?? this.id,
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      ammonia: ammonia ?? this.ammonia,
      lightLevel: lightLevel ?? this.lightLevel,
      isAlert: isAlert ?? this.isAlert,
      alertMessage: alertMessage ?? this.alertMessage,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  String toString() {
    return 'SensorLog(id: $id, temp: ${temperatureDisplay}, humidity: ${humidityDisplay}, ammonia: ${ammoniaDisplay}, light: $lightLevelDisplay, alert: $isAlert)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SensorLog && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
