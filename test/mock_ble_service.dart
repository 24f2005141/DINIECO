import 'dart:async';
import 'package:dinieco/models/ble_models.dart';
import 'package:dinieco/services/ble_service.dart';

/// Test mock implementation of [BleService] allowing complete control over
/// BLE adapter states, discovery, GATT connections, and incoming telemetry packets.
class MockBleService implements BleService {
  BleConnectionStatus _currentStatus = BleConnectionStatus.readyToScan;
  final List<BleDeviceItem> _discoveredDevices = [];
  BleTelemetryPacket? _latestTelemetry;
  BleDeviceItem? _connectedDevice;
  BleConfigProfile _activeProfile = BleConfigProfile.esp32Test();

  final _statusController = StreamController<BleConnectionStatus>.broadcast();
  final _scanResultsController = StreamController<List<BleDeviceItem>>.broadcast();
  final _telemetryController = StreamController<BleTelemetryPacket>.broadcast();

  bool isScanning = false;
  bool mockPermissionsGranted = true;
  bool mockBluetoothEnabled = true;

  // Spies / Call records
  int startScanCalls = 0;
  int stopScanCalls = 0;
  int connectCalls = 0;
  int disconnectCalls = 0;
  BleDeviceItem? lastConnectedDevice;

  @override
  Stream<BleConnectionStatus> get statusStream => _statusController.stream;

  @override
  BleConnectionStatus get currentStatus => _currentStatus;

  @override
  Stream<List<BleDeviceItem>> get scanResultsStream => _scanResultsController.stream;

  @override
  List<BleDeviceItem> get currentDiscoveredDevices => List.unmodifiable(_discoveredDevices);

  @override
  Stream<BleTelemetryPacket> get telemetryStream => _telemetryController.stream;

  @override
  BleTelemetryPacket? get latestTelemetry => _latestTelemetry;

  @override
  BleDeviceItem? get connectedDevice => _connectedDevice;

  @override
  BleConfigProfile get activeProfile => _activeProfile;

  @override
  Future<bool> checkAndRequestPermissions() async {
    return mockPermissionsGranted;
  }

  @override
  Future<bool> isBluetoothEnabled() async {
    return mockBluetoothEnabled;
  }

  @override
  Future<void> startScan({bool showAllDevices = false}) async {
    startScanCalls++;
    isScanning = true;
    _updateStatus(BleConnectionStatus.scanning);
  }

  @override
  Future<void> stopScan() async {
    stopScanCalls++;
    isScanning = false;
    if (_currentStatus == BleConnectionStatus.scanning) {
      _updateStatus(BleConnectionStatus.readyToScan);
    }
  }

  @override
  Future<bool> connect(BleDeviceItem device, {BleConfigProfile? profile}) async {
    connectCalls++;
    lastConnectedDevice = device;
    _connectedDevice = device;
    if (profile != null) {
      _activeProfile = profile;
    }

    _updateStatus(BleConnectionStatus.connecting);
    await Future.delayed(const Duration(milliseconds: 10));
    _updateStatus(BleConnectionStatus.discoveringServices);
    await Future.delayed(const Duration(milliseconds: 10));
    _updateStatus(BleConnectionStatus.connected);
    return true;
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    _connectedDevice = null;
    _updateStatus(BleConnectionStatus.disconnected);
  }

  @override
  void setProfile(BleConfigProfile profile) {
    _activeProfile = profile;
  }

  @override
  void dispose() {
    _statusController.close();
    _scanResultsController.close();
    _telemetryController.close();
  }

  // Helper methods to simulate hardware events in tests
  void emitStatus(BleConnectionStatus status) {
    _updateStatus(status);
  }

  void emitDiscoveredDevices(List<BleDeviceItem> devices) {
    _discoveredDevices
      ..clear()
      ..addAll(devices);
    _scanResultsController.add(List.unmodifiable(_discoveredDevices));
  }

  void emitTelemetry(BleTelemetryPacket packet) {
    _latestTelemetry = packet;
    _telemetryController.add(packet);
  }

  void emitRawJson(String jsonString) {
    final packet = BleTelemetryPacket.parseJson(jsonString);
    if (packet != null) {
      emitTelemetry(packet);
    }
  }

  void _updateStatus(BleConnectionStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }
}
