import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dinieco/main.dart';
import 'package:dinieco/screens/auth/login_screen.dart';
import 'package:dinieco/screens/auth/register_screen.dart';
import 'package:dinieco/screens/active_session_screen.dart';
import 'package:dinieco/screens/post_meal_summary_screen.dart';
import 'package:dinieco/providers/dinieco_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Test Login screen form validation', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const DiniecoApp());
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);

    // Tap Sign In with empty fields
    final signInBtn = find.widgetWithText(ElevatedButton, 'Sign In');
    expect(signInBtn, findsOneWidget);
    await tester.tap(signInBtn);
    await tester.pumpAndSettle();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);

    // Enter invalid email
    await tester.enterText(find.byType(TextFormField).at(0), 'invalidemail');
    await tester.enterText(find.byType(TextFormField).at(1), '123');
    await tester.tap(signInBtn);
    await tester.pumpAndSettle();

    expect(find.text('Enter a valid email address'), findsOneWidget);
    expect(find.text('Password must be at least 6 characters'), findsOneWidget);
  });

  testWidgets('Test Navigation from Login to Register screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const DiniecoApp());
    await tester.pumpAndSettle();

    final registerLink = find.text('Create Account');
    expect(registerLink, findsOneWidget);
    await tester.tap(registerLink);
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.text('Create Account'), findsWidgets);
    expect(find.text('Full Name'), findsOneWidget);
  });

  testWidgets('Test ActiveSessionScreen renders meal photo actions', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      DiniecoApp(
        diniecoProvider: DiniecoProvider(),
        home: ActiveSessionScreen(
          onFinishMeal: () {},
          onCancel: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify photo action buttons exist
    expect(find.text('Take Meal Photo'), findsOneWidget);
    expect(find.text('From Gallery'), findsOneWidget);
    expect(find.text('Tap to Capture or Upload Meal Photo'), findsOneWidget);
  });

  testWidgets('Test PostMealSummaryScreen renders empty state when no meal', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      DiniecoApp(
        diniecoProvider: DiniecoProvider(),
        home: PostMealSummaryScreen(
          onReturnHome: () {},
          onViewAnalytics: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No Recent Meal Session'), findsOneWidget);
    expect(find.text('Return to Dashboard'), findsOneWidget);
  });
}
