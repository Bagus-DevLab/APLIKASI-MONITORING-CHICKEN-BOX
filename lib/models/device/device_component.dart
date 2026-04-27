/// Device component enum for control commands
/// 
/// Based on API_CONTRACT.md Section 3.3: Device Management
/// POST /api/devices/{device_id}/control
/// 
/// Valid component values (from contract line 765-778):
/// - kipas: Fan (Ventilation fan)
/// - lampu: Light (Coop lighting)
/// - pompa: Pump (Water pump)
/// - pakan_otomatis: Auto Feeder (Automatic feeding system)
/// - exhaust_fan: Exhaust Fan (Ammonia/heat ventilation)
/// 
/// Usage:
/// ```dart
/// await deviceService.controlDevice(
///   deviceId: device.id,
///   component: DeviceComponent.kipas,
///   state: true,
/// );
/// ```
enum DeviceComponent {
  /// Ventilation fan
  kipas,

  /// Coop lighting
  lampu,

  /// Water pump
  pompa,

  /// Automatic feeding system
  pakanOtomatis,

  /// Exhaust fan for ammonia/heat ventilation
  exhaustFan,
}

/// Extension to convert DeviceComponent enum to API string values
extension DeviceComponentExtension on DeviceComponent {
  /// Convert enum to API string value
  /// 
  /// Maps:
  /// - DeviceComponent.kipas → "kipas"
  /// - DeviceComponent.lampu → "lampu"
  /// - DeviceComponent.pompa → "pompa"
  /// - DeviceComponent.pakanOtomatis → "pakan_otomatis"
  /// - DeviceComponent.exhaustFan → "exhaust_fan"
  String toApiValue() {
    switch (this) {
      case DeviceComponent.kipas:
        return 'kipas';
      case DeviceComponent.lampu:
        return 'lampu';
      case DeviceComponent.pompa:
        return 'pompa';
      case DeviceComponent.pakanOtomatis:
        return 'pakan_otomatis';
      case DeviceComponent.exhaustFan:
        return 'exhaust_fan';
    }
  }

  /// Get display name in Indonesian
  String get displayName {
    switch (this) {
      case DeviceComponent.kipas:
        return 'Kipas';
      case DeviceComponent.lampu:
        return 'Lampu';
      case DeviceComponent.pompa:
        return 'Pompa';
      case DeviceComponent.pakanOtomatis:
        return 'Pakan Otomatis';
      case DeviceComponent.exhaustFan:
        return 'Exhaust Fan';
    }
  }

  /// Get English name
  String get englishName {
    switch (this) {
      case DeviceComponent.kipas:
        return 'Fan';
      case DeviceComponent.lampu:
        return 'Light';
      case DeviceComponent.pompa:
        return 'Pump';
      case DeviceComponent.pakanOtomatis:
        return 'Auto Feeder';
      case DeviceComponent.exhaustFan:
        return 'Exhaust Fan';
    }
  }

  /// Get icon name (for UI)
  String get iconName {
    switch (this) {
      case DeviceComponent.kipas:
        return 'fan';
      case DeviceComponent.lampu:
        return 'lightbulb';
      case DeviceComponent.pompa:
        return 'water_drop';
      case DeviceComponent.pakanOtomatis:
        return 'restaurant';
      case DeviceComponent.exhaustFan:
        return 'wind_power';
    }
  }

  /// Parse API string value to enum
  /// 
  /// Throws ArgumentError if value is invalid
  static DeviceComponent fromApiValue(String value) {
    switch (value) {
      case 'kipas':
        return DeviceComponent.kipas;
      case 'lampu':
        return DeviceComponent.lampu;
      case 'pompa':
        return DeviceComponent.pompa;
      case 'pakan_otomatis':
        return DeviceComponent.pakanOtomatis;
      case 'exhaust_fan':
        return DeviceComponent.exhaustFan;
      default:
        throw ArgumentError(
          'Invalid component value: $value. '
          'Valid values: kipas, lampu, pompa, pakan_otomatis, exhaust_fan',
        );
    }
  }

  /// Get all valid API values as a list
  static List<String> get validApiValues => [
        'kipas',
        'lampu',
        'pompa',
        'pakan_otomatis',
        'exhaust_fan',
      ];
}
