import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dinieco/main.dart';
import 'package:dinieco/screens/main_shell.dart';
import 'package:dinieco/screens/active_session_screen.dart';
import 'package:dinieco/screens/diagnostics_calibration_screen.dart';
import 'package:dinieco/widgets/circular_weight_gauge.dart';
import 'package:dinieco/providers/dinieco_provider.dart';
import 'package:dinieco/models/models.dart';
import 'mock_api_service.dart';

void main() {
  testWidgets('Test Active Session weight gauge and component rendering', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final provider = DiniecoProvider(api: MockApiService());
    await tester.pumpWidget(DiniecoApp(diniecoProvider: provider, home: const MainShell()));
    await tester.pumpAndSettle();

    // Navigate to Active Session
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(find.byType(ActiveSessionScreen), findsOneWidget);
    expect(find.byType(CircularWeightGauge), findsOneWidget);
    expect(find.text('Total Weight'), findsOneWidget);
    expect(find.text('Stabilized'), findsOneWidget);

    // Verify Tare button exists
    final tareBtn = find.text('Zero / Tare Smart Pad');
    expect(tareBtn, findsOneWidget);
    await tester.ensureVisible(tareBtn);
    await tester.tap(tareBtn);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('Test Hardware Diagnostics & Calibration wizard step execution', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final provider = DiniecoProvider(api: MockApiService());
    provider.setPadStatus(PadStatus(
      deviceId: 'DINIECO-PAD-001',
      batteryPercent: 92,
      loadSensorStatus: 'Active (HX711 24-bit)',
      cameraStatus: 'Connected (OV2640)',
      isConnected: true,
      baselineTareG: 0.0,
    ));

    await tester.pumpWidget(DiniecoApp(diniecoProvider: provider, home: const MainShell()));
    await tester.pumpAndSettle();

    // Navigate to Smart Pad Diagnostics
    await tester.tap(find.text('Smart Pad'));
    await tester.pumpAndSettle();

    expect(find.byType(DiagnosticsCalibrationScreen), findsOneWidget);
    expect(find.text('Active (HX711 24-bit)'), findsOneWidget);
    expect(find.text('Connected (OV2640)'), findsOneWidget);

    // Trigger calibration button
    final calibBtn = find.text('START HARDWARE CALIBRATION');
    expect(calibBtn, findsOneWidget);
    await tester.ensureVisible(calibBtn);
    await tester.tap(calibBtn);
    await tester.pump();

    // Advance through the timer delays
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpAndSettle();

    expect(find.text('Step 4 of 4'), findsOneWidget);
  });
}
