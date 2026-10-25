import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dinieco/core/theme/dinieco_theme.dart';
import 'package:dinieco/models/ble_models.dart';
import 'package:dinieco/models/models.dart';
import 'package:dinieco/providers/ble_provider.dart';
import 'package:dinieco/providers/dinieco_provider.dart';
import 'package:dinieco/screens/post_meal_summary_screen.dart';
import 'mock_api_service.dart';
import 'mock_ble_service.dart';

/// Spy implementation of [MockApiService] that captures arguments passed to [recordMealSession]
class SpyApiService extends MockApiService {
  Map<String, dynamic>? lastRecordedMealArgs;
  int recordMealCalls = 0;
  int uploadImageCalls = 0;

  @override
  Future<Map<String, dynamic>> uploadMealImage(XFile imageFile) async {
    uploadImageCalls++;
    return {
      'image_id': 'uploaded-img-999',
      'filename': imageFile.name,
      'image_url': '/uploads/${imageFile.name}',
      'format': 'JPEG',
      'width': 1024,
      'height': 768,
      'file_size_bytes': 2048,
      'content_type': 'image/jpeg',
    };
  }

  @override
  Future<MealRecord?> recordMealSession({
    required String mealName,
    required double initialWeightG,
    required double remainingWeightG,
    required List<FoodComponentItem> components,
    String weightSource = 'device',
    double tareWeightG = 0.0,
    String? imageUrl,
    double? startGrossWeightG,
    double? endGrossWeightG,
    double? plateWeightG,
    String plateWeightMode = 'none',
    double? startFoodWeightG,
    double? endFoodWeightG,
    double? weightReductionG,
    String? startImageUrl,
    String? endImageUrl,
    String startImageSource = 'app_camera',
    String endImageSource = 'app_camera',
    String? deviceId,
    bool isCalibrated = true,
    bool isFlaggedIncrease = false,
    String? readingsHistory,
  }) async {
    recordMealCalls++;
    lastRecordedMealArgs = {
      'mealName': mealName,
      'initialWeightG': initialWeightG,
      'remainingWeightG': remainingWeightG,
      'components': components,
      'weightSource': weightSource,
      'tareWeightG': tareWeightG,
      'imageUrl': imageUrl,
      'startGrossWeightG': startGrossWeightG,
      'endGrossWeightG': endGrossWeightG,
      'plateWeightG': plateWeightG,
      'plateWeightMode': plateWeightMode,
      'startFoodWeightG': startFoodWeightG,
      'endFoodWeightG': endFoodWeightG,
      'weightReductionG': weightReductionG,
      'startImageUrl': startImageUrl,
      'endImageUrl': endImageUrl,
      'startImageSource': startImageSource,
      'endImageSource': endImageSource,
      'deviceId': deviceId,
      'isCalibrated': isCalibrated,
      'isFlaggedIncrease': isFlaggedIncrease,
      'readingsHistory': readingsHistory,
    };

    return super.recordMealSession(
      mealName: mealName,
      initialWeightG: initialWeightG,
      remainingWeightG: remainingWeightG,
      components: components,
      weightSource: weightSource,
      tareWeightG: tareWeightG,
      imageUrl: imageUrl,
      startGrossWeightG: startGrossWeightG,
      endGrossWeightG: endGrossWeightG,
      plateWeightG: plateWeightG,
      plateWeightMode: plateWeightMode,
      startFoodWeightG: startFoodWeightG,
      endFoodWeightG: endFoodWeightG,
      weightReductionG: weightReductionG,
      startImageUrl: startImageUrl,
      endImageUrl: endImageUrl,
      startImageSource: startImageSource,
      endImageSource: endImageSource,
      deviceId: deviceId,
      isCalibrated: isCalibrated,
      isFlaggedIncrease: isFlaggedIncrease,
      readingsHistory: readingsHistory,
    );
  }
}

/// Helper to generate telemetry packets matching BleTelemetryPacket signature
BleTelemetryPacket makePacket({
  required double weightG,
  int sequence = 1,
  bool? isCalibrated = true,
  bool? isStable = true,
  bool isStale = false,
  DateTime? timestamp,
}) {
  return BleTelemetryPacket(
    weightG: weightG,
    sequence: sequence,
    source: 'test',
    status: 'ok',
    rawPayload: '{"status":"ok","source":"test","weight_g":$weightG,"sequence":$sequence}',
    timestamp: timestamp ?? DateTime.now(),
    isCalibrated: isCalibrated,
    isStable: isStable,
    isStale: isStale,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DINIECO Meal Measurement Workflow Test Suite (14 Verification Test Cases)', () {
    // ------------------------------------------------------------------------
    // TC1: Pre-flight & device readiness verification
    // ------------------------------------------------------------------------
    test('TC1: Pre-flight & device readiness verification across all states', () async {
      final mockBle = MockBleService();
      final bleProvider = BleProvider(service: mockBle);
      final api = SpyApiService();
      final diniecoProvider = DiniecoProvider(api: api);

      // State A: Bluetooth disabled
      mockBle.mockBluetoothEnabled = false;
      var readiness = await diniecoProvider.checkDeviceReadiness(bleProvider);
      expect(readiness.isReady, isFalse);
      expect(readiness.isBluetoothEnabled, isFalse);
      expect(readiness.errorMessage, contains('Bluetooth is turned off'));

      // State B: Bluetooth enabled, but pad disconnected
      mockBle.mockBluetoothEnabled = true;
      readiness = await diniecoProvider.checkDeviceReadiness(bleProvider);
      expect(readiness.isReady, isFalse);
      expect(readiness.isConnected, isFalse);
      expect(readiness.errorMessage, contains('Smart Dining Pad is not connected'));

      // State C: Connected, but no telemetry packet received yet
      await bleProvider.connectDevice(BleDeviceItem(id: 'TEST_ID', name: 'DINIECO_PAD_TEST', rssi: -60));
      readiness = await diniecoProvider.checkDeviceReadiness(bleProvider);
      expect(readiness.isReady, isFalse);
      expect(readiness.isConnected, isTrue);
      expect(readiness.isReceivingData, isFalse);
      expect(readiness.errorMessage, contains('No live telemetry received'));

      // State D: Connected and receiving live telemetry (<3s)
      final testPacket = makePacket(weightG: 450.0, sequence: 1, isCalibrated: true, isStable: true);
      mockBle.emitTelemetry(testPacket);
      diniecoProvider.updateFromBleTelemetry(testPacket, isTestProfile: true, deviceId: 'DINIECO_PAD_TEST');

      readiness = await diniecoProvider.checkDeviceReadiness(bleProvider);
      expect(readiness.isReady, isTrue);
      expect(readiness.isConnected, isTrue);
      expect(readiness.isReceivingData, isTrue);
      expect(readiness.isDataFresh, isTrue);
      expect(readiness.isCalibrated, isTrue);
      expect(readiness.errorMessage, isNull);

      // State E: Uncalibrated warning
      final uncalibratedPacket = makePacket(weightG: 450.0, sequence: 2, isCalibrated: false, isStable: true);
      mockBle.emitTelemetry(uncalibratedPacket);
      readiness = await diniecoProvider.checkDeviceReadiness(bleProvider);
      expect(readiness.isReady, isTrue); // Can still proceed, but with warning
      expect(readiness.isCalibrated, isFalse);
      expect(readiness.warningMessage, contains('Load-cell calibration required'));
    });

    // ------------------------------------------------------------------------
    // TC2: Plate Weight Method A (automatic scale measurement with stability check)
    // ------------------------------------------------------------------------
    test('TC2: Plate Weight Method A (automatic scale measurement with stability check)', () {
      final api = SpyApiService();
      final provider = DiniecoProvider(api: api);

      // 1. When weight is fluctuating (unstable), autoCapture returns false
      provider.setSimulatedWeight(215.0);
      for (int i = 0; i < 5; i++) {
        final p = makePacket(
          weightG: 200.0 + (i * 5.0), // 200, 205, 210, 215, 220 -> variation > 1.5g
          sequence: i,
          isStable: false,
        );
        provider.updateFromBleTelemetry(p, isTestProfile: false);
      }
      expect(provider.isWeightStable, isFalse);
      final capturedUnstable = provider.autoCapturePlateWeight();
      expect(capturedUnstable, isFalse);
      expect(provider.setupPlateWeightG, isNull);

      // 2. When weight stabilizes, autoCapture succeeds
      for (int i = 0; i < 5; i++) {
        final p = makePacket(
          weightG: 212.5,
          sequence: 10 + i,
          isStable: true,
        );
        provider.updateFromBleTelemetry(p, isTestProfile: false);
      }
      expect(provider.isWeightStable, isTrue);
      final capturedStable = provider.autoCapturePlateWeight();
      expect(capturedStable, isTrue);
      expect(provider.setupPlateWeightG, equals(212.5));
      expect(provider.setupPlateWeightMode, equals('measured'));
    });

    // ------------------------------------------------------------------------
    // TC3: Plate Weight Method B (manual numeric input)
    // ------------------------------------------------------------------------
    test('TC3: Plate Weight Method B (manual numeric input) and clear', () {
      final api = SpyApiService();
      final provider = DiniecoProvider(api: api);

      provider.setSetupPlateWeight(248.5, 'manual');
      expect(provider.setupPlateWeightG, equals(248.5));
      expect(provider.setupPlateWeightMode, equals('manual'));

      provider.clearSetupPlateWeight();
      expect(provider.setupPlateWeightG, isNull);
      expect(provider.setupPlateWeightMode, equals('none'));
    });

    // ------------------------------------------------------------------------
    // TC4: Plate Weight Skip (gross mode with plate unknown)
    // ------------------------------------------------------------------------
    test('TC4: Plate Weight Skip (gross mode with plate unknown)', () async {
      final api = SpyApiService();
      final provider = DiniecoProvider(api: api);

      // Simulate placing meal on scale
      for (int i = 0; i < 5; i++) {
        provider.updateFromBleTelemetry(
          makePacket(weightG: 500.0, sequence: i, isStable: true),
          isTestProfile: false,
        );
      }

      // Explicitly skip plate setup (mode = none)
      provider.clearSetupPlateWeight();

      final session = await provider.startMealMeasurementSession(
        mealName: 'Salad Lunch',
        imageSource: 'app_camera',
      );

      expect(session.plateWeightG, isNull);
      expect(session.plateWeightMode, equals('none'));
      expect(session.startGrossWeightG, equals(500.0));
      expect(session.startFoodWeightG, isNull); // Net food weight unknown in Gross Mode
    });

    // ------------------------------------------------------------------------
    // TC5: Starting meal gross and food weight calculation
    // ------------------------------------------------------------------------
    test('TC5: Starting meal gross and food weight calculation with measured plate', () async {
      final api = SpyApiService();
      final provider = DiniecoProvider(api: api);

      // Set plate weight to 210.0g
      provider.setSetupPlateWeight(210.0, 'measured');

      // Gross reading on scale: 660.0g
      for (int i = 0; i < 5; i++) {
        provider.updateFromBleTelemetry(
          makePacket(weightG: 660.0, sequence: i, isStable: true),
          isTestProfile: false,
        );
      }

      final session = await provider.startMealMeasurementSession(
        mealName: 'Steak & Mash',
        imageSource: 'app_camera',
      );

      expect(session.startGrossWeightG, equals(660.0));
      expect(session.plateWeightG, equals(210.0));
      expect(session.plateWeightMode, equals('measured'));
      expect(session.startFoodWeightG, equals(450.0)); // 660.0 - 210.0
    });

    // ------------------------------------------------------------------------
    // TC6: Moving average smoothing filter (5-sample window eliminating jitter)
    // ------------------------------------------------------------------------
    test('TC6: Moving average smoothing filter (5-sample window eliminating jitter)', () {
      final api = SpyApiService();
      final provider = DiniecoProvider(api: api);

      // Feed 5 noisy samples centered around 500g: 498, 503, 497, 502, 500
      final samples = [498.0, 503.0, 497.0, 502.0, 500.0];
      for (int i = 0; i < samples.length; i++) {
        provider.updateFromBleTelemetry(
          makePacket(weightG: samples[i], sequence: i, isStable: true),
          isTestProfile: false,
        );
      }

      // Mean of 498, 503, 497, 502, 500 is exactly 500.0
      expect(provider.smoothedWeightG, equals(500.0));

      // Push 6th sample: 510.0. The window (size 5) should drop 498 and keep [503, 497, 502, 500, 510]
      // Mean: (503 + 497 + 502 + 500 + 510) / 5 = 2512 / 5 = 502.4
      provider.updateFromBleTelemetry(
        makePacket(weightG: 510.0, sequence: 6, isStable: true),
        isTestProfile: false,
      );

      expect((provider.smoothedWeightG * 10).round() / 10.0, equals(502.4));
    });

    // ------------------------------------------------------------------------
    // TC7: Live weight reduction calculation during ongoing meal
    // ------------------------------------------------------------------------
    test('TC7: Live weight reduction calculation during ongoing meal', () async {
      final api = SpyApiService();
      final provider = DiniecoProvider(api: api);

      provider.setSetupPlateWeight(200.0, 'measured');

      // Start gross weight: 600g (food = 400g)
      for (int i = 0; i < 5; i++) {
        provider.updateFromBleTelemetry(
          makePacket(weightG: 600.0, sequence: i, isStable: true),
          isTestProfile: false,
        );
      }

      await provider.startMealMeasurementSession(mealName: 'Dinner');

      // Now eating progress: gross weight reduces to 450.0g
      for (int i = 0; i < 5; i++) {
        provider.updateFromBleTelemetry(
          makePacket(weightG: 450.0, sequence: 10 + i, isStable: true),
          isTestProfile: false,
        );
      }

      // Remaining Food: 450 - 200 = 250.0g
      expect(provider.currentRemainingFoodWeightG, equals(250.0));
      // Food Removed / Weight Reduction: 600 - 450 = 150.0g
      expect(provider.currentWeightReductionG, equals(150.0));
    });

    // ------------------------------------------------------------------------
    // TC8: Mid-session BLE disconnect handling
    // ------------------------------------------------------------------------
    test('TC8: Mid-session BLE disconnect handling preserves session state', () async {
      final api = SpyApiService();
      final provider = DiniecoProvider(api: api);

      provider.setSetupPlateWeight(180.0, 'manual');

      for (int i = 0; i < 5; i++) {
        provider.updateFromBleTelemetry(
          makePacket(weightG: 580.0, sequence: i, isStable: true),
          isTestProfile: false,
        );
      }

      await provider.startMealMeasurementSession(mealName: 'Active Session');
      expect(provider.hasActiveSession, isTrue);

      // Hardware disconnect occurs mid-session
      provider.onBleDisconnected();

      // Session MUST NOT be wiped out!
      expect(provider.hasActiveSession, isTrue);
      expect(provider.activeSession!.mealName, equals('Active Session'));
      expect(provider.activeSession!.startGrossWeightG, equals(580.0));
      expect(provider.activeSession!.plateWeightG, equals(180.0));
      expect(provider.padStatus.isConnected, isFalse);
    });

    // ------------------------------------------------------------------------
    // TC9: App restart / lifecycle recovery of active session from SharedPreferences
    // ------------------------------------------------------------------------
    test('TC9: App restart / lifecycle recovery of active session from SharedPreferences', () async {
      final api = SpyApiService();
      final providerA = DiniecoProvider(api: api);

      providerA.setSetupPlateWeight(220.0, 'measured');

      for (int i = 0; i < 5; i++) {
        providerA.updateFromBleTelemetry(
          makePacket(weightG: 520.0, sequence: i, isStable: true),
          isTestProfile: false,
        );
      }

      await providerA.startMealMeasurementSession(
        mealName: 'Persisted Pasta',
        imageSource: 'app_camera',
      );

      // Verify that SharedPreferences contains the session
      final prefs = await SharedPreferences.getInstance();
      final storedJson = prefs.getString('dinieco_active_meal_session');
      expect(storedJson, isNotNull);
      expect(storedJson, contains('Persisted Pasta'));

      // Simulate App Restart by instantiating a fresh DiniecoProvider
      final providerB = DiniecoProvider(api: api);
      expect(providerB.hasActiveSession, isFalse);

      await providerB.restoreActiveSessionFromStorage();

      expect(providerB.hasActiveSession, isTrue);
      final restored = providerB.activeSession!;
      expect(restored.mealName, equals('Persisted Pasta'));
      expect(restored.startGrossWeightG, equals(520.0));
      expect(restored.plateWeightG, equals(220.0));
      expect(restored.plateWeightMode, equals('measured'));
      expect(restored.startFoodWeightG, equals(300.0));
    });

    // ------------------------------------------------------------------------
    // TC10: Final weight measurement & food weight reduction
    // ------------------------------------------------------------------------
    test('TC10: Final weight measurement & food weight reduction calculation', () async {
      final api = SpyApiService();
      final provider = DiniecoProvider(api: api);

      provider.setSetupPlateWeight(200.0, 'measured');

      // Start: gross 600g (food 400g)
      for (int i = 0; i < 5; i++) {
        provider.updateFromBleTelemetry(
          makePacket(weightG: 600.0, sequence: i, isStable: true),
          isTestProfile: false,
        );
      }
      await provider.startMealMeasurementSession(mealName: 'Lunch Session');

      // End: gross 280g (food 80g)
      for (int i = 0; i < 5; i++) {
        provider.updateFromBleTelemetry(
          makePacket(weightG: 280.0, sequence: 10 + i, isStable: true),
          isTestProfile: false,
        );
      }

      final finalized = await provider.finalizeMealMeasurementSession();
      expect(finalized, isNotNull);
      expect(finalized!.startGrossWeightG, equals(600.0));
      expect(finalized.endGrossWeightG, equals(280.0));
      expect(finalized.plateWeightG, equals(200.0));
      expect(finalized.startFoodWeightG, equals(400.0));
      expect(finalized.endFoodWeightG, equals(80.0));
      // Food removed: 400 - 80 = 320.0g
      expect(finalized.weightReductionG, equals(320.0));
      expect(finalized.isFlaggedIncrease, isFalse);
    });

    // ------------------------------------------------------------------------
    // TC11: Unexpected weight increase detection & flagging
    // ------------------------------------------------------------------------
    test('TC11: Unexpected weight increase detection & flagging (isFlaggedIncrease = true, reduction = 0g)', () async {
      final api = SpyApiService();
      final provider = DiniecoProvider(api: api);

      provider.setSetupPlateWeight(200.0, 'measured');

      // Start: gross 500g (food 300g)
      for (int i = 0; i < 5; i++) {
        provider.updateFromBleTelemetry(
          makePacket(weightG: 500.0, sequence: i, isStable: true),
          isTestProfile: false,
        );
      }
      await provider.startMealMeasurementSession(mealName: 'Food Added Meal');

      // More food is added onto the plate: End gross 650g (food 450g > start food 300g)
      for (int i = 0; i < 5; i++) {
        provider.updateFromBleTelemetry(
          makePacket(weightG: 650.0, sequence: 10 + i, isStable: true),
          isTestProfile: false,
        );
      }

      final finalized = await provider.finalizeMealMeasurementSession();
      expect(finalized, isNotNull);
      expect(finalized!.isFlaggedIncrease, isTrue);
      // Food weight reduction clamped to 0.0g
      expect(finalized.weightReductionG, equals(0.0));
    });

    // ------------------------------------------------------------------------
    // TC12: Ending photo capture & upload
    // ------------------------------------------------------------------------
    test('TC12: Ending photo capture & upload via ApiService', () async {
      final api = SpyApiService();
      final provider = DiniecoProvider(api: api);

      for (int i = 0; i < 5; i++) {
        provider.updateFromBleTelemetry(
          makePacket(weightG: 400.0, sequence: i, isStable: true),
          isTestProfile: false,
        );
      }
      await provider.startMealMeasurementSession(mealName: 'Photo Session');

      final endMockPhoto = XFile('test_end_photo.jpg', name: 'test_end_photo.jpg');
      final finalized = await provider.finalizeMealMeasurementSession(
        endPhoto: endMockPhoto,
        imageSource: 'app_camera',
      );

      expect(api.uploadImageCalls, equals(1));
      expect(finalized, isNotNull);
      expect(finalized!.endImageUrl, equals('/uploads/test_end_photo.jpg'));
      expect(finalized.endImageSource, equals('app_camera'));
    });

    // ------------------------------------------------------------------------
    // TC13: Backend persistence via ApiService.recordMealSession with all extended parameters
    // ------------------------------------------------------------------------
    test('TC13: Backend persistence passes all 15 extended parameters', () async {
      final api = SpyApiService();
      final provider = DiniecoProvider(api: api);

      provider.setSetupPlateWeight(195.0, 'measured');

      for (int i = 0; i < 5; i++) {
        provider.updateFromBleTelemetry(
          makePacket(weightG: 595.0, sequence: i, isStable: true),
          isTestProfile: false,
        );
      }

      await provider.startMealMeasurementSession(
        mealName: 'Full Persistence Meal',
        imageSource: 'app_camera',
        deviceId: 'ESP32_C3_DEVICE',
        isCalibrated: true,
      );

      // Decrement weight slightly
      for (int i = 0; i < 5; i++) {
        provider.updateFromBleTelemetry(
          makePacket(weightG: 295.0, sequence: 10 + i, isStable: true),
          isTestProfile: false,
        );
      }

      final endMockPhoto = XFile('end_final.jpg', name: 'end_final.jpg');
      await provider.finalizeMealMeasurementSession(
        endPhoto: endMockPhoto,
        imageSource: 'app_camera',
      );

      expect(api.recordMealCalls, equals(1));
      final args = api.lastRecordedMealArgs!;

      expect(args['mealName'], equals('Full Persistence Meal'));
      expect(args['startGrossWeightG'], equals(595.0));
      expect(args['endGrossWeightG'], equals(295.0));
      expect(args['plateWeightG'], equals(195.0));
      expect(args['plateWeightMode'], equals('measured'));
      expect(args['startFoodWeightG'], equals(400.0));
      expect(args['endFoodWeightG'], equals(100.0));
      expect(args['weightReductionG'], equals(300.0));
      expect(args['endImageUrl'], equals('/uploads/end_final.jpg'));
      expect(args['startImageSource'], equals('app_camera'));
      expect(args['endImageSource'], equals('app_camera'));
      expect(args['deviceId'], equals('ESP32_C3_DEVICE'));
      expect(args['isCalibrated'], isTrue);
      expect(args['isFlaggedIncrease'], isFalse);
      expect(args['readingsHistory'], isNotNull);

      // Verify readings history decodes as valid JSON array
      final historyList = jsonDecode(args['readingsHistory'] as String) as List;
      expect(historyList.isNotEmpty, isTrue);
    });

    // ------------------------------------------------------------------------
    // TC14: Summary screen rendering (dual photos, food removed vs waste, calibration badge)
    // ------------------------------------------------------------------------
    testWidgets('TC14: PostMealSummaryScreen renders dual photos, calibration badge, plate mode, and food removed semantics', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final api = SpyApiService();
      final provider = DiniecoProvider(api: api);

      final testMeal = MealRecord(
        id: 'test_meal_101',
        mealName: 'Quinoa Veggie Bowl',
        startTime: DateTime.now().subtract(const Duration(minutes: 20)),
        endTime: DateTime.now(),
        initialWeightG: 500.0,
        consumedWeightG: 300.0,
        remainingWeightG: 200.0,
        wasteScore: 85,
        totalCalories: 450,
        wastePercentage: 20.0,
        status: 'completed',
        startGrossWeightG: 500.0,
        endGrossWeightG: 200.0,
        plateWeightG: 150.0,
        plateWeightMode: 'measured',
        startFoodWeightG: 350.0,
        endFoodWeightG: 50.0,
        weightReductionG: 300.0,
        startImageUrl: 'https://example.com/start_photo.jpg',
        endImageUrl: 'https://example.com/end_photo.jpg',
        startImageSource: 'app_camera',
        endImageSource: 'app_camera',
        isCalibrated: true,
        isFlaggedIncrease: false,
      );

      provider.setLastSavedMeal(testMeal);

      await tester.pumpWidget(
        ChangeNotifierProvider<DiniecoProvider>.value(
          value: provider,
          child: MaterialApp(
            theme: DiniecoTheme.lightTheme,
            home: PostMealSummaryScreen(
              onReturnHome: () {},
              onViewAnalytics: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Dual photo labels
      expect(find.text('Before Meal (Start)'), findsOneWidget);
      expect(find.text('After Meal (End)'), findsOneWidget);

      // 2. Calibration status badge
      expect(find.text('Load-Cell: Calibrated'), findsOneWidget);

      // 3. Plate weight mode pill
      expect(find.text('Plate: 150.0g (measured)'), findsOneWidget);

      // 4. Food Removed metric column (distinguished from confirmed food waste)
      expect(find.text('Food Removed'), findsOneWidget);
      expect(find.text('300.0g'), findsOneWidget);

      // 5. Semantic footnote explaining food removed is not assumed waste
      expect(
        find.text('Note: Weight removed from plate is reported as food removed / weight reduction. It is not assumed to be confirmed food waste.'),
        findsOneWidget,
      );
    });

    testWidgets('TC14 (Variant): PostMealSummaryScreen renders flagged increase banner when weight increased', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final api = SpyApiService();
      final provider = DiniecoProvider(api: api);

      final flaggedMeal = MealRecord(
        id: 'test_meal_flagged',
        mealName: 'Buffet Refill',
        startTime: DateTime.now().subtract(const Duration(minutes: 15)),
        endTime: DateTime.now(),
        initialWeightG: 400.0,
        consumedWeightG: 0.0,
        remainingWeightG: 550.0,
        wasteScore: 100,
        totalCalories: 500,
        wastePercentage: 0.0,
        status: 'completed',
        startGrossWeightG: 400.0,
        endGrossWeightG: 550.0,
        startFoodWeightG: 250.0,
        endFoodWeightG: 400.0,
        weightReductionG: 0.0,
        isCalibrated: false,
        isFlaggedIncrease: true,
      );

      provider.setLastSavedMeal(flaggedMeal);

      await tester.pumpWidget(
        ChangeNotifierProvider<DiniecoProvider>.value(
          value: provider,
          child: MaterialApp(
            theme: DiniecoTheme.lightTheme,
            home: PostMealSummaryScreen(
              onReturnHome: () {},
              onViewAnalytics: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check uncalibrated badge
      expect(find.text('Load-Cell: Uncalibrated'), findsOneWidget);

      // Check unexpected increase notice banner
      expect(
        find.text('Notice: Final weight was higher than starting weight. Food addition or plate change detected during session. Food weight reduction recorded as 0.0g.'),
        findsOneWidget,
      );
    });
  });
}
