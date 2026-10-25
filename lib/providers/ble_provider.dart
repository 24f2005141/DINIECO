import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ble_models.dart';
import '../services/ble_service.dart';

class BleProvider extends ChangeNotifier {
  final BleService bleService;

  BleConnectionStatus _status = BleConnectionStatus.readyToScan;
  BleConnectionStatus get status => _status;

  List<BleDeviceItem> _discoveredDevices = [];
  List<BleDeviceItem> get discoveredDevices => _discoveredDevices;

  BleDeviceItem? _connectedDevice;
  BleDeviceItem? get connectedDevice => _connectedDevice;

  BleConfigProfile _currentProfile = BleConfigProfile.esp32Test();
  BleConfigProfile get currentProfile => _currentProfile;

  BleTelemetryPacket? _latestPacket;
  BleTelemetryPacket? get latestPacket => _latestPacket;

  final List<BleTelemetryPacket> _telemetryLog = [];
  List<BleTelemetryPacket> get telemetryLog => List.unmodifiable(_telemetryLog);

  bool _showAllDevices = false;
  bool get showAllDevices => _showAllDevices;

  String? _savedDeviceId;
  String? get savedDeviceId => _savedDeviceId;

  String? _savedDeviceName;
  String? get savedDeviceName => _savedDeviceName;

  DateTime? _lastConnectedTime;
  DateTime? get lastConnectedTime => _lastConnectedTime;

  String? _lastError;
  String? get lastError => _lastError;

  StreamSubscription<BleConnectionStatus>? _statusSub;
  StreamSubscription<List<BleDeviceItem>>? _scanSub;
  StreamSubscription<BleTelemetryPacket>? _telemetrySub;

  static const int _maxLogSize = 30;
  static const String _prefSavedDeviceId = 'dinieco_ble_saved_device_id';
  static const String _prefSavedDeviceName = 'dinieco_ble_saved_device_name';
  static const String _prefSavedProfile = 'dinieco_ble_saved_profile';

  BleProvider({BleService? service}) : bleService = service ?? FlutterBlueBleService() {
    _init();
  }

  void _init() {
    _statusSub = bleService.statusStream.listen((status) {
      _status = status;
      if (status == BleConnectionStatus.connected) {
        _lastConnectedTime = DateTime.now();
        _lastError = null;
      } else if (status == BleConnectionStatus.connectionFailed) {
        _lastError = 'Connection failed or service/characteristic not found';
      }
      notifyListeners();
    });

    _scanSub = bleService.scanResultsStream.listen((devices) {
      _discoveredDevices = devices;
      notifyListeners();
    });

    _telemetrySub = bleService.telemetryStream.listen((packet) {
      _latestPacket = packet;
      _telemetryLog.insert(0, packet);
      if (_telemetryLog.length > _maxLogSize) {
        _telemetryLog.removeLast();
      }
      notifyListeners();
    });

    loadSavedPreferences();
  }

  Future<void> loadSavedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _savedDeviceId = prefs.getString(_prefSavedDeviceId);
      _savedDeviceName = prefs.getString(_prefSavedDeviceName);

      final profileJsonStr = prefs.getString(_prefSavedProfile);
      if (profileJsonStr != null) {
        try {
          final map = jsonDecode(profileJsonStr) as Map<String, dynamic>;
          _currentProfile = BleConfigProfile.fromJson(map);
          bleService.setProfile(_currentProfile);
        } catch (_) {}
      }

      notifyListeners();

      // If a device was previously saved and auto-reconnect is on, attempt connection
      if (_savedDeviceId != null && _currentProfile.autoReconnect) {
        final enabled = await bleService.isBluetoothEnabled();
        if (enabled) {
          final target = BleDeviceItem(
            id: _savedDeviceId!,
            name: _savedDeviceName ?? 'Saved Pad',
            rssi: -60,
          );
          connectDevice(target);
        }
      }
    } catch (_) {}
  }

  Future<void> savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_connectedDevice != null) {
        await prefs.setString(_prefSavedDeviceId, _connectedDevice!.id);
        await prefs.setString(_prefSavedDeviceName, _connectedDevice!.name);
        _savedDeviceId = _connectedDevice!.id;
        _savedDeviceName = _connectedDevice!.name;
      }
      await prefs.setString(_prefSavedProfile, jsonEncode(_currentProfile.toJson()));
    } catch (_) {}
  }

  Future<void> startScan() async {
    _lastError = null;
    await bleService.startScan(showAllDevices: _showAllDevices);
    notifyListeners();
  }

  Future<void> stopScan() async {
    await bleService.stopScan();
    notifyListeners();
  }

  void toggleShowAllDevices() {
    _showAllDevices = !_showAllDevices;
    notifyListeners();
    if (_status == BleConnectionStatus.scanning) {
      startScan();
    }
  }

  Future<bool> connectDevice(BleDeviceItem device) async {
    _lastError = null;
    _connectedDevice = device;
    notifyListeners();

    final success = await bleService.connect(device, profile: _currentProfile);
    if (success) {
      _connectedDevice = device;
      await savePreferences();
    } else {
      _connectedDevice = null;
    }
    notifyListeners();
    return success;
  }

  Future<void> disconnectDevice() async {
    await bleService.disconnect();
    _connectedDevice = null;
    _latestPacket = null;
    notifyListeners();
  }

  Future<void> forgetDevice() async {
    await disconnectDevice();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefSavedDeviceId);
    await prefs.remove(_prefSavedDeviceName);
    _savedDeviceId = null;
    _savedDeviceName = null;
    notifyListeners();
  }

  void selectPreset(String presetId) {
    if (presetId == 'esp32_test') {
      _currentProfile = BleConfigProfile.esp32Test();
    } else if (presetId == 'dinieco_prod') {
      _currentProfile = BleConfigProfile.diniecoProduction();
    }
    bleService.setProfile(_currentProfile);
    savePreferences();
    notifyListeners();
  }

  void updateCustomProfile(BleConfigProfile profile) {
    _currentProfile = profile;
    bleService.setProfile(_currentProfile);
    savePreferences();
    notifyListeners();
  }

  void clearLog() {
    _telemetryLog.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _statusSub?.cancel();
    _scanSub?.cancel();
    _telemetrySub?.cancel();
    bleService.dispose();
    super.dispose();
  }
}
