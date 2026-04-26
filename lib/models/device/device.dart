/// Device model representing a chicken coop IoT device
/// 
/// Based on API_CONTRACT.md Section 3.3: Device Management
/// 
/// Device Object Fields (from contract line 558-567):
/// - id: UUID (unique device identifier)
/// - mac_address: string (hardware MAC address)
/// - name: string or null (human-readable name, null if unclaimed)
/// - user_id: UUID or null (owner's user ID, null if unclaimed)
/// - last_heartbeat: ISO 8601 or null (last MQTT message timestamp)
/// - is_online: boolean (computed field, true if heartbeat within 120 seconds)
/// 
/// Example JSON:
/// ```json
/// {
///   "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
///   "mac_address": "44:1D:64:BE:22:08",
///   "name": "Kandang Utara",
///   "user_id": "b2c3d4e5-f6a7-8901-bcde-f12345678901",
///   "last_heartbeat": "2026-04-26T10:30:00Z",
///   "is_online": true
/// }
/// ```
class Device {
  /// Unique device identifier (UUID)
  final String id;

  /// Hardware MAC address (format: XX:XX:XX:XX:XX:XX)
  final String macAddress;

  /// Human-readable name for the coop
  /// Null if device is unclaimed
  final String? name;

  /// Owner's user ID (UUID)
  /// Null if device is unclaimed
  final String? userId;

  /// Last MQTT heartbeat timestamp
  /// Null if device has never connected
  final DateTime? lastHeartbeat;

  /// Online status (computed by backend)
  /// True if last_heartbeat is within 120 seconds of now
  final bool isOnline;

  Device({
    required this.id,
    required this.macAddress,
    this.name,
    this.userId,
    this.lastHeartbeat,
    required this.isOnline,
  });

  /// Create Device from JSON
  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      macAddress: json['mac_address'] as String,
      name: json['name'] as String?,
      userId: json['user_id'] as String?,
      lastHeartbeat: json['last_heartbeat'] != null
          ? DateTime.parse(json['last_heartbeat'] as String)
          : null,
      isOnline: json['is_online'] as bool,
    );
  }

  /// Convert Device to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mac_address': macAddress,
      'name': name,
      'user_id': userId,
      'last_heartbeat': lastHeartbeat?.toIso8601String(),
      'is_online': isOnline,
    };
  }

  /// Check if device is claimed by a user
  bool get isClaimed => userId != null;

  /// Check if device is unclaimed
  bool get isUnclaimed => userId == null;

  /// Get display name for UI
  /// Falls back to shortened MAC address if name is null
  String get displayName {
    if (name != null && name!.isNotEmpty) {
      return name!;
    }
    // Show first 8 characters of MAC address as fallback
    return 'Device ${macAddress.substring(0, 8)}';
  }

  /// Get time since last heartbeat in seconds
  /// Returns null if device has never connected
  int? get secondsSinceLastSeen {
    if (lastHeartbeat == null) return null;
    return DateTime.now().difference(lastHeartbeat!).inSeconds;
  }

  /// Get human-readable time since last seen
  /// Returns "Belum pernah terhubung" if never connected
  String get timeSinceLastSeenDisplay {
    final seconds = secondsSinceLastSeen;
    if (seconds == null) return 'Belum pernah terhubung';

    if (seconds < 60) {
      return '$seconds detik yang lalu';
    } else if (seconds < 3600) {
      final minutes = seconds ~/ 60;
      return '$minutes menit yang lalu';
    } else if (seconds < 86400) {
      final hours = seconds ~/ 3600;
      return '$hours jam yang lalu';
    } else {
      final days = seconds ~/ 86400;
      return '$days hari yang lalu';
    }
  }

  /// Get online status display text
  String get onlineStatusDisplay => isOnline ? 'Online' : 'Offline';

  /// Get online status color (for UI)
  /// Returns color name as string
  String get onlineStatusColor => isOnline ? 'green' : 'red';

  /// Check if device has never connected
  bool get hasNeverConnected => lastHeartbeat == null;

  /// Get formatted MAC address (always uppercase with colons)
  String get formattedMacAddress => macAddress.toUpperCase();

  /// Copy with method for immutable updates
  Device copyWith({
    String? id,
    String? macAddress,
    String? name,
    String? userId,
    DateTime? lastHeartbeat,
    bool? isOnline,
  }) {
    return Device(
      id: id ?? this.id,
      macAddress: macAddress ?? this.macAddress,
      name: name ?? this.name,
      userId: userId ?? this.userId,
      lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  @override
  String toString() {
    return 'Device(id: $id, name: ${name ?? "unclaimed"}, macAddress: $macAddress, isOnline: $isOnline)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Device && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
