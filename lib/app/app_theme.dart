import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ink = Color(0xFF182230);
  static const muted = Color(0xFF667085);
  static const border = Color(0xFFE4E7EC);
  static const canvas = Color(0xFFF7F8FA);
  static const surface = Colors.white;
  static const brand = Color(0xFFB42318);
  static const brandSoft = Color(0xFFFFE9E7);
  static const critical = Color(0xFFB42318);
  static const criticalSoft = Color(0xFFFEF3F2);
  static const positive = Color(0xFF067647);
  static const positiveSoft = Color(0xFFECFDF3);
  static const warning = Color(0xFFB54708);
  static const warningSoft = Color(0xFFFFFAEB);
  static const info = Color(0xFF175CD3);
  static const infoSoft = Color(0xFFEFF8FF);
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
}

abstract final class AppRadii {
  static const sm = 8.0;
  static const md = 10.0;
  static const lg = 14.0;
}

ThemeData _buildLightTheme() {
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
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg)),
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
    dialogTheme: const DialogTheme(
      backgroundColor: AppColors.surface,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg)),
      ),
    ),
    dataTableTheme: const DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(AppColors.canvas),
      dividerThickness: 1,
      dataTextStyle: TextStyle(color: AppColors.ink, fontSize: 13),
      headingTextStyle: TextStyle(
        color: AppColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.canvas,
      selectedColor: AppColors.infoSoft,
      side: const BorderSide(color: AppColors.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      labelStyle: const TextStyle(
        color: AppColors.ink,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.muted,
      textColor: AppColors.ink,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    ),
  );
}

/// Semantic colours shared by widgets and custom chart painters.
class AppPalette {
  const AppPalette(this.dark);
  final bool dark;
  Color get ink => dark ? const Color(0xFFE6EAF0) : AppColors.ink;
  Color get muted => dark ? const Color(0xFFA9B4C4) : AppColors.muted;
  Color get border => dark ? const Color(0xFF334155) : AppColors.border;
  Color get canvas => dark ? const Color(0xFF10161F) : AppColors.canvas;
  Color get surface => dark ? const Color(0xFF192330) : AppColors.surface;
  Color get brand => dark ? const Color(0xFFFF9B91) : AppColors.brand;
  Color get brandSoft => dark ? const Color(0xFF432A2D) : AppColors.brandSoft;
  Color get critical => dark ? const Color(0xFFFF9B91) : AppColors.critical;
  Color get criticalSoft =>
      dark ? const Color(0xFF432A2D) : AppColors.criticalSoft;
  Color get positive => dark ? const Color(0xFF75D9B0) : AppColors.positive;
  Color get positiveSoft =>
      dark ? const Color(0xFF15392E) : AppColors.positiveSoft;
  Color get warning => dark ? const Color(0xFFF4C078) : AppColors.warning;
  Color get warningSoft =>
      dark ? const Color(0xFF3E3220) : AppColors.warningSoft;
  Color get info => dark ? const Color(0xFF8DBBFF) : AppColors.info;
  Color get infoSoft => dark ? const Color(0xFF20364F) : AppColors.infoSoft;
}

extension AppPaletteContext on BuildContext {
  AppPalette get colors =>
      AppPalette(Theme.of(this).brightness == Brightness.dark);
}

ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  final base = _buildLightTheme();
  final c = AppPalette(brightness == Brightness.dark);
  final scheme = ColorScheme.fromSeed(
          seedColor: AppColors.brand,
          brightness: brightness,
          surface: c.surface)
      .copyWith(
    primary: c.brand,
    onPrimary:
        brightness == Brightness.dark ? const Color(0xFF35120F) : Colors.white,
    onSurface: c.ink,
    onSurfaceVariant: c.muted,
    outline: c.border,
    outlineVariant: c.border,
  );
  return base.copyWith(
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.canvas,
    canvasColor: c.surface,
    dividerColor: c.border,
    disabledColor: c.muted,
    textTheme: base.textTheme
        .apply(bodyColor: c.ink, displayColor: c.ink)
        .copyWith(
            bodyMedium: base.textTheme.bodyMedium?.copyWith(color: c.muted)),
    iconTheme: IconThemeData(color: c.muted),
    appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent),
    cardTheme: base.cardTheme.copyWith(
        color: c.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: c.border))),
    dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: c.surface, surfaceTintColor: Colors.transparent),
    bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        modalBackgroundColor: c.surface,
        surfaceTintColor: Colors.transparent),
    popupMenuTheme: PopupMenuThemeData(
        color: c.surface,
        textStyle: TextStyle(color: c.ink),
        surfaceTintColor: Colors.transparent),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
        fillColor: c.surface,
        labelStyle: TextStyle(color: c.muted),
        hintStyle: TextStyle(color: c.muted),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: c.border))),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            backgroundColor: c.brand,
            foregroundColor: scheme.onPrimary,
            minimumSize: const Size(0, 42))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            foregroundColor: c.ink,
            side: BorderSide(color: c.border),
            minimumSize: const Size(0, 42))),
    tooltipTheme: base.tooltipTheme.copyWith(
        decoration:
            BoxDecoration(color: c.ink, borderRadius: BorderRadius.circular(8)),
        textStyle: TextStyle(color: c.surface, fontSize: 12)),
    dataTableTheme: base.dataTableTheme.copyWith(
        headingRowColor: WidgetStatePropertyAll(c.canvas),
        dataTextStyle: TextStyle(color: c.ink, fontSize: 13),
        headingTextStyle: TextStyle(
            color: c.muted, fontSize: 12, fontWeight: FontWeight.w600)),
    chipTheme: base.chipTheme.copyWith(
        backgroundColor: c.canvas,
        selectedColor: c.brandSoft,
        side: BorderSide(color: c.border),
        checkmarkColor: c.brand,
        labelStyle:
            TextStyle(color: c.ink, fontSize: 12, fontWeight: FontWeight.w600)),
    listTileTheme:
        base.listTileTheme.copyWith(iconColor: c.muted, textColor: c.ink),
  );
}
