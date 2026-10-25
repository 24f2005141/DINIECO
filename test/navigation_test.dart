import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dinieco/main.dart';
import 'package:dinieco/screens/main_shell.dart';
import 'package:dinieco/providers/dinieco_provider.dart';
import 'package:dinieco/screens/home_dashboard_screen.dart';
import 'package:dinieco/screens/active_session_screen.dart';
import 'package:dinieco/screens/post_meal_summary_screen.dart';
import 'package:dinieco/screens/diagnostics_calibration_screen.dart';
import 'package:dinieco/screens/tablet_analytics_screen.dart';
import 'mock_api_service.dart';

void main() {
  testWidgets('Test navigate to Smart Pad', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(DiniecoApp(diniecoProvider: DiniecoProvider(api: MockApiService()), home: const MainShell()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Smart Pad'));
    await tester.pumpAndSettle();
    expect(find.byType(DiagnosticsCalibrationScreen), findsOneWidget);
  });

  testWidgets('Test navigate to Analytics', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(DiniecoApp(diniecoProvider: DiniecoProvider(api: MockApiService()), home: const MainShell()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Analytics'));
    await tester.pumpAndSettle();
    expect(find.byType(TabletAnalyticsScreen), findsOneWidget);
  });

  testWidgets('Test navigate to Start Active Session', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(DiniecoApp(diniecoProvider: DiniecoProvider(api: MockApiService()), home: const MainShell()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start'));
    await tester.pumpAndSettle();
    expect(find.byType(ActiveSessionScreen), findsOneWidget);
  });

  testWidgets('Test interactive CTA transitions (Start Meal button & Post-Meal Summary)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(DiniecoApp(diniecoProvider: DiniecoProvider(api: MockApiService()), home: const MainShell()));
    await tester.pumpAndSettle();

    // Tap CTA "+ Start Meal Session" on Home Hero Card
    final startMealBtn = find.text('Start Meal Session').first;
    expect(startMealBtn, findsOneWidget);
    await tester.ensureVisible(startMealBtn);
    await tester.tap(startMealBtn);
    await tester.pumpAndSettle();

    // Should transition to ActiveSessionScreen
    expect(find.byType(ActiveSessionScreen), findsOneWidget);

    // Tap "Finish Meal & Record Waste"
    final finishBtn = find.text('Finish Meal & Record Waste');
    expect(finishBtn, findsOneWidget);
    await tester.ensureVisible(finishBtn);
    await tester.tap(finishBtn);
    await tester.pumpAndSettle();

    // Should transition to PostMealSummaryScreen
    expect(find.byType(PostMealSummaryScreen), findsOneWidget);
    expect(find.text('Post-Meal Summary'), findsOneWidget);
    expect(find.text('Food Waste Score'), findsOneWidget);

    // Tap "Save to History & Return Home"
    final returnHomeBtn = find.text('Save to History & Return Home');
    expect(returnHomeBtn, findsOneWidget);
    await tester.ensureVisible(returnHomeBtn);
    await tester.tap(returnHomeBtn);
    await tester.pumpAndSettle();

    // Should be back at HomeDashboardScreen
    expect(find.byType(HomeDashboardScreen), findsOneWidget);
  });
}
