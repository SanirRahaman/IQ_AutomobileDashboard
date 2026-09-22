import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ink = Color(0xFF182230);
  static const muted = Color(0xFF667085);
  static const border = Color(0xFFE4E7EC);
  static const canvas = Color(0xFFF7F8FA);
  static const surface = Colors.white;
  static const brand = Color(0xFFB42318);
  static const brandSoft = Color(0xFFFFE9E7);
  static const positive = Color(0xFF067647);
  static const positiveSoft = Color(0xFFECFDF3);
  static const warning = Color(0xFFB54708);
  static const warningSoft = Color(0xFFFFFAEB);
  static const info = Color(0xFF175CD3);
  static const infoSoft = Color(0xFFEFF8FF);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.brand,
    brightness: Brightness.light,
    surface: AppColors.surface,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.canvas,
    fontFamily: 'Arial',
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        color: AppColors.ink,
        fontSize: 32,
        height: 1.15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      headlineSmall: TextStyle(
        color: AppColors.ink,
        fontSize: 22,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
      ),
      titleLarge: TextStyle(
        color: AppColors.ink,
        fontSize: 18,
        height: 1.3,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: AppColors.ink,
        fontSize: 15,
        height: 1.35,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(
        color: AppColors.ink,
        fontSize: 15,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        color: AppColors.muted,
        fontSize: 13,
        height: 1.45,
      ),
      labelLarge: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
    dividerColor: AppColors.border,
    cardTheme: const CardTheme(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        side: BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: AppColors.border),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 42),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.border),
        minimumSize: const Size(0, 42),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    tooltipTheme: const TooltipThemeData(
      waitDuration: Duration(milliseconds: 350),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      textStyle: TextStyle(color: Colors.white, fontSize: 12),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
  );
}
