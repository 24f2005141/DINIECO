import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dinieco/main.dart';
import 'package:dinieco/screens/main_shell.dart';
import 'package:dinieco/screens/active_session_screen.dart';
import 'package:dinieco/providers/dinieco_provider.dart';
import 'package:dinieco/models/models.dart';
import 'mock_api_service.dart';

void main() {
  testWidgets('Test Dual Weight Mode Toggle and Manual Weight Input', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(DiniecoApp(diniecoProvider: DiniecoProvider(api: MockApiService()), home: const MainShell()));
    await tester.pumpAndSettle();

    // Navigate to Active Session
    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();

    expect(find.byType(ActiveSessionScreen), findsOneWidget);

    // Initial state is Mode A: Smart Pad BLE
    expect(find.text('Mode A: Smart Pad BLE'), findsOneWidget);
    expect(find.text('Mode B: Manual Weight'), findsOneWidget);

    // Switch to Mode B: Manual Weight
    await tester.tap(find.text('Mode B: Manual Weight'));
    await tester.pumpAndSettle();

    // Verify Manual Weight card is now rendered
    expect(find.text('Manual Net Food Weight'), findsOneWidget);
    expect(find.text('No Tare Deducted'), findsOneWidget);
    expect(find.text('Apply'), findsOneWidget);

    // Tap quick increment chip +50g
    final plus50Chip = find.text('+50g');
    expect(plus50Chip, findsOneWidget);
    await tester.tap(plus50Chip);
    await tester.pumpAndSettle();

    // Tap Apply
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
  });

  test('Test DiniecoProvider portion reconciliation & macro scaling', () {
    final provider = DiniecoProvider();
    
    // Set initial components
    provider.setManualWeight(500.0);
    expect(provider.currentWeightG, 500.0);
    expect(provider.weightSource, 'device');

    provider.setWeightSource('manual');
    expect(provider.weightSource, 'manual');

    // Test component editing
    final comp = FoodComponentItem(
      name: 'Steamed Rice',
      weightG: 250.0,
      confidence: 0.95,
      caloriesKcal: 325,
      proteinG: 6.8,
      carbsG: 70.5,
      fatG: 0.8,
    );
    provider.detectedComponents.add(comp);

    provider.updateComponentWeight(0, 300.0);
    expect(provider.detectedComponents[0].weightG, 300.0);
    // 300g rice = 300 * 1.3 = 390 kcal
    expect(provider.detectedComponents[0].caloriesKcal, 390);
    expect(provider.detectedComponents[0].proteinG, 8.1);
  });
}
