import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dinieco/core/theme/dinieco_theme.dart';
import 'package:dinieco/models/ble_models.dart';
import 'package:dinieco/providers/ble_provider.dart';
import 'package:dinieco/providers/dinieco_provider.dart';
import 'package:dinieco/screens/hardware_connectivity_screen.dart';
import 'mock_api_service.dart';
import 'mock_ble_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget createTestWidget({
    required MockBleService mockBle,
    required BleProvider bleProvider,
    DiniecoProvider? diniecoProvider,
  }) {
    final dp = diniecoProvider ?? DiniecoProvider(api: MockApiService());

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<BleProvider>.value(value: bleProvider),
        ChangeNotifierProvider<DiniecoProvider>.value(value: dp),
      ],
      child: MaterialApp(
        theme: DiniecoTheme.lightTheme,
        home: const HardwareConnectivityScreen(),
      ),
    );
  }

  testWidgets('Renders Hardware Connectivity screen sections correctly', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockBle = MockBleService();
    final bleProvider = BleProvider(service: mockBle);
    await tester.pumpWidget(createTestWidget(mockBle: mockBle, bleProvider: bleProvider));
    await tester.pumpAndSettle();

    // Verify Title and AppBar
    expect(find.text('Hardware & Connectivity'), findsOneWidget);

    // Section A: Connection Status Card
    expect(find.text('Ready to Scan'), findsOneWidget);
    expect(find.text('No Data Arriving'), findsOneWidget);

    // Section B: Discovered Devices Header
    expect(find.text('Nearby BLE Devices'), findsOneWidget);
    expect(find.text('SCAN FOR DEVICES'), findsOneWidget);
    expect(find.text('No devices found in range. Ensure your ESP32-C3 is advertising.'), findsOneWidget);

    // Section D: Configuration Presets
    expect(find.text('Hardware Configuration'), findsOneWidget);
    expect(find.text('ESP32-C3 — BLE Test (JSON Stream)'), findsOneWidget);

    // Section E: Live Telemetry
    expect(find.text('Live Telemetry Dashboard'), findsOneWidget);
    expect(find.text('No BLE notifications captured yet.\nConnect to ESP32-C3 to observe live JSON stream.'), findsOneWidget);
  });

  testWidgets('Scanning updates UI and displays discovered ESP32 test device', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockBle = MockBleService();
    final bleProvider = BleProvider(service: mockBle);
    await tester.pumpWidget(createTestWidget(mockBle: mockBle, bleProvider: bleProvider));
    await tester.pumpAndSettle();

    // Tap Scan button (triggers animated CircularProgressIndicator)
    await tester.tap(find.text('SCAN FOR DEVICES'));
    await tester.pump();

    expect(mockBle.startScanCalls, 1);

    // Emit discovered ESP32 device
    mockBle.emitDiscoveredDevices([
      BleDeviceItem(
        id: '24:DC:C3:99:AA:01',
        name: 'DINIECO_PAD_TEST',
        rssi: -58,
      ),
    ]);
    await tester.pump(const Duration(milliseconds: 100));

    // Verify discovered device rendered in list
    expect(find.text('DINIECO_PAD_TEST'), findsOneWidget);
    expect(find.text('CONNECT'), findsOneWidget);
    expect(find.text('MAC: 24:DC:C3:99:AA:01 • Signal: -58 dBm'), findsOneWidget);
  });

  testWidgets('Connecting to device updates status card and displays connection controls', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockBle = MockBleService();
    final bleProvider = BleProvider(service: mockBle);
    await tester.pumpWidget(createTestWidget(mockBle: mockBle, bleProvider: bleProvider));
    await tester.pumpAndSettle();

    // Emit discovered device
    final testDev = BleDeviceItem(
      id: '24:DC:C3:99:AA:01',
      name: 'DINIECO_PAD_TEST',
      rssi: -58,
    );
    mockBle.emitDiscoveredDevices([testDev]);
    await tester.pump(const Duration(milliseconds: 50));

    // Tap Connect
    await tester.tap(find.text('CONNECT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(mockBle.connectCalls, 1);
    expect(find.text('Connected & Receiving Data'), findsOneWidget);

    // Verify Section C: Connection controls appear
    expect(find.text('Disconnect'), findsOneWidget);
    expect(find.text('Forget Device'), findsOneWidget);
  });

  testWidgets('Streaming telemetry displays live weight, amber test warning, and packet log', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockBle = MockBleService();
    final bleProvider = BleProvider(service: mockBle);
    final diniecoProvider = DiniecoProvider(api: MockApiService());

    await tester.pumpWidget(createTestWidget(
      mockBle: mockBle,
      bleProvider: bleProvider,
      diniecoProvider: diniecoProvider,
    ));
    await tester.pumpAndSettle();

    // Connect device
    final testDevice = BleDeviceItem(
      id: '24:DC:C3:99:AA:01',
      name: 'DINIECO_PAD_TEST',
      rssi: -58,
    );
    mockBle.emitDiscoveredDevices([testDevice]);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('CONNECT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 100));

    // Emit live test telemetry packet matching ESP32-C3 specifications
    mockBle.emitRawJson('{"status": "ok", "source": "test", "weight_g": 102.5, "sequence": 1}');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Live Weight display
    expect(find.text('102.5 g'), findsOneWidget);
    expect(find.text('Seq #1'), findsOneWidget);

    // Verify ESP32 Test Amber badge
    expect(find.text('TEST PROFILE — SIMULATED'), findsOneWidget);

    // Emit second packet with updated weight
    mockBle.emitRawJson('{"status": "ok", "source": "test", "weight_g": 105.8, "sequence": 2}');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('105.8 g'), findsOneWidget);
    expect(find.text('Seq #2'), findsOneWidget);

    // Verify DiniecoProvider received the live weight and test profile flag
    expect(diniecoProvider.currentWeightG, 105.8);
    expect(diniecoProvider.isBleTestProfile, isTrue);
  });

  testWidgets('Disconnecting clears connected device and updates UI', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockBle = MockBleService();
    final bleProvider = BleProvider(service: mockBle);
    await tester.pumpWidget(createTestWidget(mockBle: mockBle, bleProvider: bleProvider));
    await tester.pumpAndSettle();

    final testDevice = BleDeviceItem(
      id: '24:DC:C3:99:AA:01',
      name: 'DINIECO_PAD_TEST',
      rssi: -58,
    );
    mockBle.emitDiscoveredDevices([testDevice]);
    await tester.pump(const Duration(milliseconds: 50));

    // Connect
    await tester.tap(find.text('CONNECT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Disconnect'), findsOneWidget);

    // Tap Disconnect
    await tester.tap(find.text('Disconnect'));
    await tester.pumpAndSettle();

    expect(mockBle.disconnectCalls, 1);
  });
}
