import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/ble_models.dart';

/// Abstract BLE Service interface allowing clean mocking in automated tests
abstract class BleService {
  Stream<BleConnectionStatus> get statusStream;
  BleConnectionStatus get currentStatus;

  Stream<List<BleDeviceItem>> get scanResultsStream;
  List<BleDeviceItem> get currentDiscoveredDevices;

  Stream<BleTelemetryPacket> get telemetryStream;
  BleTelemetryPacket? get latestTelemetry;

  BleDeviceItem? get connectedDevice;
  BleConfigProfile get activeProfile;

  Future<bool> checkAndRequestPermissions();
  Future<bool> isBluetoothEnabled();
  Future<void> startScan({bool showAllDevices = false});
  Future<void> stopScan();
  Future<bool> connect(BleDeviceItem device, {BleConfigProfile? profile});
  Future<void> disconnect();
  void setProfile(BleConfigProfile profile);
  void dispose();
}

/// Concrete implementation of [BleService] using [FlutterBluePlus] and [PermissionHandler]
class FlutterBlueBleService implements BleService {
  BleConfigProfile _activeProfile;
  BleConnectionStatus _currentStatus = BleConnectionStatus.readyToScan;
  BleDeviceItem? _connectedDevice;
  BluetoothDevice? _activePeripheral;
  StreamSubscription<List<int>>? _characteristicSub;
  StreamSubscription<BluetoothConnectionState>? _deviceStateSub;
  StreamSubscription<List<ScanResult>>? _scanSub;
  StreamSubscription<BluetoothAdapterState>? _adapterSub;

  final Map<String, BleDeviceItem> _discoveredDevicesMap = {};
  BleTelemetryPacket? _latestTelemetry;
  int? _lastSequence;
  DateTime? _lastPacketTime;
  Timer? _freshnessWatchdog;
  bool _showAllDevices = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;

  final _statusController = StreamController<BleConnectionStatus>.broadcast();
  final _scanResultsController = StreamController<List<BleDeviceItem>>.broadcast();
  final _telemetryController = StreamController<BleTelemetryPacket>.broadcast();

  FlutterBlueBleService({BleConfigProfile? initialProfile})
      : _activeProfile = initialProfile ?? BleConfigProfile.esp32Test() {
    _initAdapterMonitoring();
    _startFreshnessWatchdog();
  }

  @override
  Stream<BleConnectionStatus> get statusStream => _statusController.stream;

  @override
  BleConnectionStatus get currentStatus => _currentStatus;

  @override
  Stream<List<BleDeviceItem>> get scanResultsStream => _scanResultsController.stream;

  @override
  List<BleDeviceItem> get currentDiscoveredDevices => _discoveredDevicesMap.values.toList();

  @override
  Stream<BleTelemetryPacket> get telemetryStream => _telemetryController.stream;

  @override
  BleTelemetryPacket? get latestTelemetry => _latestTelemetry;

  @override
  BleDeviceItem? get connectedDevice => _connectedDevice;

  @override
  BleConfigProfile get activeProfile => _activeProfile;

  void _updateStatus(BleConnectionStatus newStatus) {
    if (_currentStatus != newStatus) {
      _currentStatus = newStatus;
      _statusController.add(_currentStatus);
    }
  }

  void _initAdapterMonitoring() {
    if (!Platform.isAndroid && !Platform.isIOS) {
      _updateStatus(BleConnectionStatus.readyToScan);
      return;
    }
    try {
      _adapterSub = FlutterBluePlus.adapterState.listen((state) {
        if (state != BluetoothAdapterState.on) {
          _updateStatus(BleConnectionStatus.bluetoothDisabled);
        } else if (_currentStatus == BleConnectionStatus.bluetoothDisabled) {
          _updateStatus(BleConnectionStatus.readyToScan);
        }
      });
    } catch (_) {
      _updateStatus(BleConnectionStatus.readyToScan);
    }
  }

  @override
  Future<bool> isBluetoothEnabled() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }
    try {
      final state = await FlutterBluePlus.adapterState.first;
      return state == BluetoothAdapterState.on;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<bool> checkAndRequestPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }

    if (Platform.isAndroid) {
      // Android 12+ (API 31+) uses BLUETOOTH_SCAN and BLUETOOTH_CONNECT
      final scanStatus = await Permission.bluetoothScan.request();
      final connectStatus = await Permission.bluetoothConnect.request();

      // Android 11 and lower requires location for BLE scanning
      final locationStatus = await Permission.locationWhenInUse.request();

      final isScanGranted = scanStatus.isGranted || scanStatus.isLimited;
      final isConnectGranted = connectStatus.isGranted || connectStatus.isLimited;
      final isLocationGranted = locationStatus.isGranted || locationStatus.isLimited;

      // If either scan/connect or location is granted, proceed
      if (isScanGranted && isConnectGranted) {
        return true;
      }
      if (isLocationGranted && (scanStatus.isPermanentlyDenied || connectStatus.isPermanentlyDenied)) {
        // Older Android where modern permissions don't apply
        return true;
      }

      _updateStatus(BleConnectionStatus.permissionRequired);
      return false;
    }

    // iOS handles BLE permissions automatically via Info.plist
    return true;
  }

  @override
  Future<void> startScan({bool showAllDevices = false}) async {
    _showAllDevices = showAllDevices;

    // 1. Check permissions
    final hasPerms = await checkAndRequestPermissions();
    if (!hasPerms) {
      _updateStatus(BleConnectionStatus.permissionRequired);
      return;
    }

    // 2. Check adapter
    final enabled = await isBluetoothEnabled();
    if (!enabled) {
      _updateStatus(BleConnectionStatus.bluetoothDisabled);
      return;
    }

    // 3. Clear previous scan items and start
    _discoveredDevicesMap.clear();
    _scanResultsController.add([]);
    _updateStatus(BleConnectionStatus.scanning);

    try {
      await FlutterBluePlus.stopScan();
      _scanSub?.cancel();

      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (var r in results) {
          final devName = r.advertisementData.advName.isNotEmpty
              ? r.advertisementData.advName
              : r.device.platformName;

          final id = r.device.remoteId.str;
          final filter = _activeProfile.deviceNameFilter.trim().toLowerCase();

          // Apply name filter unless diagnostic mode is enabled
          final matchesFilter = _showAllDevices ||
              filter.isEmpty ||
              devName.toLowerCase().contains(filter) ||
              r.advertisementData.serviceUuids.any((u) => u.str.toLowerCase() == _activeProfile.serviceUuid.toLowerCase());

          if (matchesFilter) {
            final item = BleDeviceItem(
              id: id,
              name: devName,
              rssi: r.rssi,
              isConnectable: r.advertisementData.connectable,
              lastSeen: DateTime.now(),
            );
            _discoveredDevicesMap[id] = item;
          }
        }

        final list = _discoveredDevicesMap.values.toList();
        _scanResultsController.add(list);
        if (list.isNotEmpty && _currentStatus == BleConnectionStatus.scanning) {
          _updateStatus(BleConnectionStatus.devicesFound);
        }
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 12),
        androidUsesFineLocation: true,
      );

      // Once scan finishes naturally
      if (_currentStatus == BleConnectionStatus.scanning) {
        if (_discoveredDevicesMap.isEmpty) {
          _updateStatus(BleConnectionStatus.noDevicesFound);
        } else {
          _updateStatus(BleConnectionStatus.devicesFound);
        }
      }
    } catch (e) {
      debugPrint('[BleService] Scan error: $e');
      _updateStatus(BleConnectionStatus.connectionFailed);
    }
  }

  @override
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      _scanSub?.cancel();
      if (_currentStatus == BleConnectionStatus.scanning) {
        _updateStatus(_discoveredDevicesMap.isEmpty
            ? BleConnectionStatus.noDevicesFound
            : BleConnectionStatus.devicesFound);
      }
    } catch (_) {}
  }

  @override
  Future<bool> connect(BleDeviceItem device, {BleConfigProfile? profile}) async {
    if (profile != null) {
      _activeProfile = profile;
    }

    // Stop active scanning before connecting
    await stopScan();

    // Disconnect previously connected device
    if (_activePeripheral != null) {
      await disconnect();
    }

    _connectedDevice = device;
    _updateStatus(BleConnectionStatus.connecting);

    try {
      final peripheral = BluetoothDevice.fromId(device.id);
      _activePeripheral = peripheral;

      // Monitor connection state
      _deviceStateSub = peripheral.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnection();
        }
      });

      // Connect with timeout
      await peripheral.connect(
        timeout: Duration(seconds: _activeProfile.timeoutSeconds),
        autoConnect: false,
      );

      _updateStatus(BleConnectionStatus.discoveringServices);

      // Discover GATT services
      final services = await peripheral.discoverServices();
      BluetoothCharacteristic? targetChar;

      final targetServiceUuid = _activeProfile.serviceUuid.toLowerCase().replaceAll('-', '');
      final targetCharUuid = _activeProfile.characteristicUuid.toLowerCase().replaceAll('-', '');

      for (var s in services) {
        final sUuid = s.uuid.str.toLowerCase().replaceAll('-', '');
        if (sUuid == targetServiceUuid || sUuid.contains(targetServiceUuid)) {
          for (var c in s.characteristics) {
            final cUuid = c.uuid.str.toLowerCase().replaceAll('-', '');
            if (cUuid == targetCharUuid || cUuid.contains(targetCharUuid)) {
              targetChar = c;
              break;
            }
          }
        }
      }

      if (targetChar == null) {
        debugPrint('[BleService] Target characteristic $targetCharUuid not found on peripheral!');
        _updateStatus(BleConnectionStatus.connectionFailed);
        await peripheral.disconnect();
        return false;
      }

      // Configure notifications
      if (_activeProfile.isNotification) {
        await targetChar.setNotifyValue(true);
        _characteristicSub = targetChar.onValueReceived.listen((bytes) {
          _handleIncomingBytes(bytes);
        });
      } else {
        // Read mode
        final initialBytes = await targetChar.read();
        _handleIncomingBytes(initialBytes);
      }

      _reconnectAttempts = 0;
      _updateStatus(BleConnectionStatus.connectedNoData);
      return true;
    } catch (e) {
      debugPrint('[BleService] Connection error: $e');
      _updateStatus(BleConnectionStatus.connectionFailed);
      _connectedDevice = null;
      _activePeripheral = null;
      return false;
    }
  }

  void _handleIncomingBytes(List<int> bytes) {
    if (bytes.isEmpty) return;
    try {
      final raw = utf8.decode(bytes);
      final packet = BleTelemetryPacket.parseJson(
        raw,
        previousSequence: _lastSequence,
      );

      if (packet != null) {
        _lastSequence = packet.sequence;
        _lastPacketTime = DateTime.now();
        _latestTelemetry = packet;
        _telemetryController.add(packet);

        if (_currentStatus != BleConnectionStatus.connected) {
          _updateStatus(BleConnectionStatus.connected);
        }
      }
    } catch (e) {
      debugPrint('[BleService] Failed to parse payload: $e');
    }
  }

  void _handleDisconnection() {
    _characteristicSub?.cancel();
    _characteristicSub = null;

    if (_activeProfile.autoReconnect && _reconnectAttempts < _maxReconnectAttempts && _connectedDevice != null) {
      _reconnectAttempts++;
      _updateStatus(BleConnectionStatus.reconnecting);
      Future.delayed(Duration(seconds: _reconnectAttempts * 2), () {
        if (_connectedDevice != null && _currentStatus == BleConnectionStatus.reconnecting) {
          connect(_connectedDevice!);
        }
      });
    } else {
      _updateStatus(BleConnectionStatus.disconnected);
      _connectedDevice = null;
      _activePeripheral = null;
    }
  }

  @override
  Future<void> disconnect() async {
    _deviceStateSub?.cancel();
    _deviceStateSub = null;
    _characteristicSub?.cancel();
    _characteristicSub = null;

    if (_activePeripheral != null) {
      try {
        await _activePeripheral!.disconnect();
      } catch (_) {}
      _activePeripheral = null;
    }

    _connectedDevice = null;
    _reconnectAttempts = 0;
    _updateStatus(BleConnectionStatus.disconnected);
  }

  @override
  void setProfile(BleConfigProfile profile) {
    _activeProfile = profile;
  }

  void _startFreshnessWatchdog() {
    _freshnessWatchdog = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_currentStatus == BleConnectionStatus.connected && _lastPacketTime != null) {
        final age = DateTime.now().difference(_lastPacketTime!);
        if (age > const Duration(seconds: 3)) {
          // Data is stale
          if (_latestTelemetry != null && !_latestTelemetry!.isStale) {
            _latestTelemetry = _latestTelemetry!.markStale();
            _telemetryController.add(_latestTelemetry!);
          }
          _updateStatus(BleConnectionStatus.connectedNoData);
        }
      }
    });
  }

  @override
  void dispose() {
    _freshnessWatchdog?.cancel();
    _adapterSub?.cancel();
    _scanSub?.cancel();
    _deviceStateSub?.cancel();
    _characteristicSub?.cancel();
    _activePeripheral?.disconnect();
    _statusController.close();
    _scanResultsController.close();
    _telemetryController.close();
  }
}
