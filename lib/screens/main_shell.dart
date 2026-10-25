import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';
import 'home_dashboard_screen.dart';
import 'active_session_screen.dart';
import 'post_meal_summary_screen.dart';
import 'diagnostics_calibration_screen.dart';
import 'tablet_analytics_screen.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;
  bool _showingPostMealSummary = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
      _showingPostMealSummary = false;
    });
  }

  void _onStartMeal() {
    setState(() {
      _currentIndex = 2; // Active Session tab
      _showingPostMealSummary = false;
    });
  }

  void _onFinishMeal() {
    setState(() {
      _showingPostMealSummary = true;
    });
  }

  void _onReturnHome() {
    setState(() {
      _currentIndex = 0; // Home tab
      _showingPostMealSummary = false;
    });
  }

  void _onViewAnalytics() {
    setState(() {
      _currentIndex = 3; // Analytics tab
      _showingPostMealSummary = false;
    });
  }

  void _onViewDiagnostics() {
    setState(() {
      _currentIndex = 4; // Diagnostics tab
      _showingPostMealSummary = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget currentScreen;

    if (_showingPostMealSummary) {
      currentScreen = PostMealSummaryScreen(
        onReturnHome: _onReturnHome,
        onViewAnalytics: _onViewAnalytics,
      );
    } else {
      switch (_currentIndex) {
        case 0:
          currentScreen = HomeDashboardScreen(
            onStartMeal: _onStartMeal,
            onViewAnalytics: _onViewAnalytics,
            onViewDiagnostics: _onViewDiagnostics,
          );
          break;
        case 1:
          currentScreen = HomeDashboardScreen(
            onStartMeal: _onStartMeal,
            onViewAnalytics: _onViewAnalytics,
            onViewDiagnostics: _onViewDiagnostics,
          );
          break;
        case 2:
          currentScreen = ActiveSessionScreen(
            onFinishMeal: _onFinishMeal,
            onCancel: _onReturnHome,
          );
          break;
        case 3:
          currentScreen = TabletAnalyticsScreen(
            onBack: _onReturnHome,
          );
          break;
        case 4:
          currentScreen = DiagnosticsCalibrationScreen(
            onBack: _onReturnHome,
          );
          break;
        default:
          currentScreen = HomeDashboardScreen(
            onStartMeal: _onStartMeal,
            onViewAnalytics: _onViewAnalytics,
            onViewDiagnostics: _onViewDiagnostics,
          );
      }
    }

    return Scaffold(
      body: currentScreen,
      bottomNavigationBar: _showingPostMealSummary
          ? null
          : DiniecoBottomNavBar(
              currentIndex: _currentIndex,
              onTap: _navigateToTab,
            ),
    );
  }
}
