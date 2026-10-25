import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dinieco/main.dart';
import 'package:dinieco/screens/auth/login_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('DiniecoApp smoke test - unauthenticated opens LoginScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const DiniecoApp());
    await tester.pumpAndSettle();

    expect(find.text('DINIECO'), findsWidgets);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Enter your credentials to access your smart dining pad data.'), findsOneWidget);
  });
}
