import 'package:flutter/material.dart';
import 'dinieco_colors.dart';

class DiniecoTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: DiniecoColors.primary,
        onPrimary: DiniecoColors.onPrimary,
        primaryContainer: DiniecoColors.primaryContainer,
        onPrimaryContainer: DiniecoColors.secondaryContainer,
        secondary: DiniecoColors.secondary,
        onSecondary: Colors.white,
        secondaryContainer: DiniecoColors.secondaryContainer,
        onSecondaryContainer: DiniecoColors.onSecondaryContainer,
        error: DiniecoColors.error,
        onError: Colors.white,
        errorContainer: DiniecoColors.errorContainer,
        onErrorContainer: DiniecoColors.error,
        surface: DiniecoColors.surface,
        onSurface: DiniecoColors.onSurface,
        onSurfaceVariant: DiniecoColors.onSurfaceVariant,
        outline: DiniecoColors.onSurfaceMuted,
        outlineVariant: DiniecoColors.borderSubtle,
      ),
      scaffoldBackgroundColor: DiniecoColors.background,
      cardTheme: CardThemeData(
        color: DiniecoColors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: DiniecoColors.borderSubtle, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: DiniecoColors.limeAccent,
          foregroundColor: DiniecoColors.primary,
          elevation: 0,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: DiniecoColors.primary,
          side: const BorderSide(color: DiniecoColors.borderSubtle, width: 1.5),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: DiniecoColors.onSurface),
        titleTextStyle: TextStyle(
          color: DiniecoColors.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
