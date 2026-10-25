import 'dart:convert';

/// High-level BLE Connection Status for hardware UI and telemetry states.
enum BleConnectionStatus {
  bluetoothDisabled,
  permissionRequired,
  readyToScan,
  scanning,
  devicesFound,
  noDevicesFound,
  connecting,
  discoveringServices,
  connected,
  connectedNoData,
  disconnected,
  connectionFailed,
  reconnecting;

  String get displayName {
    switch (this) {
      case BleConnectionStatus.bluetoothDisabled:
        return 'Bluetooth Disabled';
      case BleConnectionStatus.permissionRequired:
        return 'Permission Required';
      case BleConnectionStatus.readyToScan:
        return 'Ready to Scan';
      case BleConnectionStatus.scanning:
        return 'Scanning for Devices...';
      case BleConnectionStatus.devicesFound:
        return 'Devices Discovered';
      case BleConnectionStatus.noDevicesFound:
        return 'No Devices Found';
      case BleConnectionStatus.connecting:
        return 'Connecting to Pad...';
      case BleConnectionStatus.discoveringServices:
        return 'Discovering Services...';
      case BleConnectionStatus.connected:
        return 'Connected & Receiving Data';
      case BleConnectionStatus.connectedNoData:
        return 'Connected — No Data Arriving';
      case BleConnectionStatus.disconnected:
        return 'Disconnected';
      case BleConnectionStatus.connectionFailed:
        return 'Connection Failed';
      case BleConnectionStatus.reconnecting:
        return 'Reconnecting...';
    }
  }

  bool get isConnected => this == BleConnectionStatus.connected || this == BleConnectionStatus.connectedNoData;
}

/// Represents a discovered BLE peripheral
class BleDeviceItem {
  final String id;
  final String name;
  final int rssi;
  final bool isConnectable;
  final DateTime lastSeen;

  BleDeviceItem({
    required this.id,
    required this.name,
    required this.rssi,
    this.isConnectable = true,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  String get displayName => name.isNotEmpty ? name : 'Unnamed Peripheral ($id)';

  BleDeviceItem copyWith({
    String? id,
    String? name,
    int? rssi,
    bool? isConnectable,
    DateTime? lastSeen,
  }) {
    return BleDeviceItem(
      id: id ?? this.id,
      name: name ?? this.name,
      rssi: rssi ?? this.rssi,
      isConnectable: isConnectable ?? this.isConnectable,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}

/// BLE hardware profile configuration with preset and custom support
class BleConfigProfile {
  final String profileId;
  final String name;
  final String deviceNameFilter;
  final String serviceUuid;
  final String characteristicUuid;
  final String dataFormat; // 'json' or 'binary_stream'
  final bool isNotification; // true = Notify, false = Read
  final String weightUnit; // 'g', 'kg', 'oz'
  final int timeoutSeconds;
  final bool autoReconnect;

  const BleConfigProfile({
    required this.profileId,
    required this.name,
    required this.deviceNameFilter,
    required this.serviceUuid,
    required this.characteristicUuid,
    this.dataFormat = 'json',
    this.isNotification = true,
    this.weightUnit = 'g',
    this.timeoutSeconds = 10,
    this.autoReconnect = true,
  });

  /// Factory preset for ESP32-C3 Super Mini BLE test firmware
  factory BleConfigProfile.esp32Test() {
    return const BleConfigProfile(
      profileId: 'esp32_test',
      name: 'ESP32-C3 — BLE Test',
      deviceNameFilter: 'DINIECO_PAD_TEST',
      serviceUuid: '7b8a0001-4d2f-4a6b-9c1e-123456789001',
      characteristicUuid: '7b8a0002-4d2f-4a6b-9c1e-123456789001',
      dataFormat: 'json',
      isNotification: true,
      weightUnit: 'g',
      timeoutSeconds: 10,
      autoReconnect: true,
    );
  }

  /// Factory preset for DINIECO Pad production firmware
  factory BleConfigProfile.diniecoProduction() {
    return const BleConfigProfile(
      profileId: 'dinieco_prod',
      name: 'DINIECO Pad — Production',
      deviceNameFilter: 'DINIECO-PAD',
      serviceUuid: '0000ffe0-0000-1000-8000-00805f9b34fb',
      characteristicUuid: '0000ffe1-0000-1000-8000-00805f9b34fb',
      dataFormat: 'binary_stream',
      isNotification: true,
      weightUnit: 'g',
      timeoutSeconds: 15,
      autoReconnect: true,
    );
  }

  /// Custom profile constructor
  factory BleConfigProfile.custom({
    required String name,
    required String deviceNameFilter,
    required String serviceUuid,
    required String characteristicUuid,
    String dataFormat = 'json',
    bool isNotification = true,
    String weightUnit = 'g',
    int timeoutSeconds = 10,
    bool autoReconnect = true,
  }) {
    return BleConfigProfile(
      profileId: 'custom',
      name: name,
      deviceNameFilter: deviceNameFilter,
      serviceUuid: serviceUuid,
      characteristicUuid: characteristicUuid,
      dataFormat: dataFormat,
      isNotification: isNotification,
      weightUnit: weightUnit,
      timeoutSeconds: timeoutSeconds,
      autoReconnect: autoReconnect,
    );
  }

  /// Validates standard 128-bit UUID (e.g., 7b8a0001-4d2f-4a6b-9c1e-123456789001) or 16-bit shorthand
  static bool isValidUuid(String uuid) {
    var clean = uuid.trim().replaceAll('-', '').toLowerCase();
    if (clean.startsWith('0x')) {
      clean = clean.substring(2);
    }
    if (clean.length == 4) {
      return RegExp(r'^[0-9a-f]{4}$').hasMatch(clean);
    }
    if (clean.length == 32) {
      return RegExp(r'^[0-9a-f]{32}$').hasMatch(clean);
    }
    return false;
  }

  BleConfigProfile copyWith({
    String? profileId,
    String? name,
    String? deviceNameFilter,
    String? serviceUuid,
    String? characteristicUuid,
    String? dataFormat,
    bool? isNotification,
    String? weightUnit,
    int? timeoutSeconds,
    bool? autoReconnect,
  }) {
    return BleConfigProfile(
      profileId: profileId ?? this.profileId,
      name: name ?? this.name,
      deviceNameFilter: deviceNameFilter ?? this.deviceNameFilter,
      serviceUuid: serviceUuid ?? this.serviceUuid,
      characteristicUuid: characteristicUuid ?? this.characteristicUuid,
      dataFormat: dataFormat ?? this.dataFormat,
      isNotification: isNotification ?? this.isNotification,
      weightUnit: weightUnit ?? this.weightUnit,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      autoReconnect: autoReconnect ?? this.autoReconnect,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profile_id': profileId,
      'name': name,
      'device_name_filter': deviceNameFilter,
      'service_uuid': serviceUuid,
      'characteristic_uuid': characteristicUuid,
      'data_format': dataFormat,
      'is_notification': isNotification,
      'weight_unit': weightUnit,
      'timeout_seconds': timeoutSeconds,
      'auto_reconnect': autoReconnect,
    };
  }

  factory BleConfigProfile.fromJson(Map<String, dynamic> json) {
    return BleConfigProfile(
      profileId: json['profile_id'] as String? ?? 'custom',
      name: json['name'] as String? ?? 'Custom Configuration',
      deviceNameFilter: json['device_name_filter'] as String? ?? '',
      serviceUuid: json['service_uuid'] as String? ?? '',
      characteristicUuid: json['characteristic_uuid'] as String? ?? '',
      dataFormat: json['data_format'] as String? ?? 'json',
      isNotification: json['is_notification'] as bool? ?? true,
      weightUnit: json['weight_unit'] as String? ?? 'g',
      timeoutSeconds: (json['timeout_seconds'] as num?)?.toInt() ?? 10,
      autoReconnect: json['auto_reconnect'] as bool? ?? true,
    );
  }
}

/// Parsed telemetry packet from Smart Dining Pad notifications or reads
class BleTelemetryPacket {
  final DateTime timestamp;
  final int sequence;
  final double weightG;
  final String source; // 'test' (ESP32-C3) or 'device' / 'production'
  final String status;
  final String rawPayload;
  final bool isStale;
  final bool isDuplicate;
  final bool hasMissedSequence;
  final bool? isCalibrated;
  final bool? isStable;

  BleTelemetryPacket({
    required this.timestamp,
    required this.sequence,
    required this.weightG,
    required this.source,
    required this.status,
    required this.rawPayload,
    this.isStale = false,
    this.isDuplicate = false,
    this.hasMissedSequence = false,
    this.isCalibrated,
    this.isStable,
  });

  bool get isTestSource => source.toLowerCase() == 'test';

  /// Safe factory parsing ESP32-C3 JSON payloads:
  /// {"status": "ok", "source": "test", "weight_g": 102.5, "sequence": 1}
  static BleTelemetryPacket? parseJson(
    String raw, {
    int? previousSequence,
    DateTime? packetTime,
  }) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;

      final status = decoded['status']?.toString() ?? 'unknown';
      final source = decoded['source']?.toString() ?? 'unknown';

      final weightRaw = decoded['weight_g'];
      if (weightRaw == null || weightRaw is! num) return null;
      final weightG = weightRaw.toDouble();

      final seqRaw = decoded['sequence'];
      if (seqRaw == null || seqRaw is! num) return null;
      final sequence = seqRaw.toInt();

      bool? isCalibrated;
      if (decoded.containsKey('calibrated')) {
        final c = decoded['calibrated'];
        isCalibrated = c is bool ? c : (c != null ? c.toString().toLowerCase() == 'true' : null);
      } else if (decoded.containsKey('is_calibrated')) {
        final c = decoded['is_calibrated'];
        isCalibrated = c is bool ? c : (c != null ? c.toString().toLowerCase() == 'true' : null);
      }

      bool? isStable;
      if (decoded.containsKey('stable')) {
        final s = decoded['stable'];
        isStable = s is bool ? s : (s != null ? s.toString().toLowerCase() == 'true' : null);
      } else if (decoded.containsKey('is_stable')) {
        final s = decoded['is_stable'];
        isStable = s is bool ? s : (s != null ? s.toString().toLowerCase() == 'true' : null);
      }

      final now = packetTime ?? DateTime.now();

      bool isDuplicate = false;
      bool hasMissedSequence = false;
      if (previousSequence != null) {
        if (sequence == previousSequence) {
          isDuplicate = true;
        } else if (sequence > previousSequence + 1) {
          hasMissedSequence = true;
        }
      }

      return BleTelemetryPacket(
        timestamp: now,
        sequence: sequence,
        weightG: weightG,
        source: source,
        status: status,
        rawPayload: raw,
        isStale: false,
        isDuplicate: isDuplicate,
        hasMissedSequence: hasMissedSequence,
        isCalibrated: isCalibrated,
        isStable: isStable,
      );
    } catch (_) {
      return null;
    }
  }

  BleTelemetryPacket markStale() {
    return BleTelemetryPacket(
      timestamp: timestamp,
      sequence: sequence,
      weightG: weightG,
      source: source,
      status: status,
      rawPayload: rawPayload,
      isStale: true,
      isDuplicate: isDuplicate,
      hasMissedSequence: hasMissedSequence,
      isCalibrated: isCalibrated,
      isStable: isStable,
    );
  }
}
