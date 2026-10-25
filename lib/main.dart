import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/dinieco_colors.dart';
import 'core/theme/dinieco_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/dinieco_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/active_session_screen.dart';
import 'screens/post_meal_summary_screen.dart';
import 'screens/diagnostics_calibration_screen.dart';
import 'screens/tablet_analytics_screen.dart';
import 'screens/hardware_connectivity_screen.dart';
import 'providers/ble_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DiniecoApp());
}

class DiniecoApp extends StatelessWidget {
  final AuthProvider? authProvider;
  final DiniecoProvider? diniecoProvider;
  final BleProvider? bleProvider;
  final Widget? home;

  const DiniecoApp({
    super.key,
    this.authProvider,
    this.diniecoProvider,
    this.bleProvider,
    this.home,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => authProvider ?? (AuthProvider()..init()),
        ),
        ChangeNotifierProvider<DiniecoProvider>(
          create: (_) => diniecoProvider ?? (DiniecoProvider()..init()),
        ),
        ChangeNotifierProvider<BleProvider>(
          create: (_) => bleProvider ?? BleProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'DINIECO',
        theme: DiniecoTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: home ?? const AuthGate(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const MainShell(initialIndex: 0),
          '/active': (context) => ActiveSessionScreen(
                onFinishMeal: () => Navigator.pushReplacementNamed(context, '/summary'),
                onCancel: () => Navigator.pop(context),
              ),
          '/summary': (context) => PostMealSummaryScreen(
                onReturnHome: () => Navigator.pushReplacementNamed(context, '/home'),
                onViewAnalytics: () => Navigator.pushReplacementNamed(context, '/analytics'),
              ),
          '/diagnostics': (context) => DiagnosticsCalibrationScreen(
                onBack: () => Navigator.pop(context),
              ),
          '/analytics': (context) => TabletAnalyticsScreen(
                onBack: () => Navigator.pop(context),
              ),
          '/connectivity': (context) => const HardwareConnectivityScreen(),
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    switch (auth.status) {
      case AuthStatus.initializing:
        return Scaffold(
          backgroundColor: DiniecoColors.background,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'DINIECO',
                  style: TextStyle(
                    fontFamily: 'Space Grotesk',
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                    color: DiniecoColors.primary,
                  ),
                ),
              ],
            ),
          ),
        );
      case AuthStatus.authenticated:
        return const MainShell();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}
