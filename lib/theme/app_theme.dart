import 'package:flutter/material.dart';

import 'package:sensorflow_accelerometer/models/sensor_axis.dart';

abstract final class AppColors {
  static const background = Color(0xFF0A0D12);
  static const surface = Color(0xFF12161D);
  static const surfaceRaised = Color(0xFF171C24);
  static const outline = Color(0xFF242B36);
  static const grid = Color(0xFF1F2530);
  static const textPrimary = Color(0xFFE8ECF2);
  static const textSecondary = Color(0xFF8A93A3);
  static const textMuted = Color(0xFF586173);
  static const accent = Color(0xFF7CB7FF);
  static const record = Color(0xFFFF3B4E);
  static const success = Color(0xFF34D399);
  static const warning = Color(0xFFFBBF24);

  static const axisX = Color(0xFFFF6B6B);
  static const axisY = Color(0xFF4ADE80);
  static const axisZ = Color(0xFF60A5FA);

  static Color forAxis(SensorAxis axis) => switch (axis) {
    SensorAxis.x => axisX,
    SensorAxis.y => axisY,
    SensorAxis.z => axisZ,
  };
}

abstract final class AppText {
  static const tabular = [FontFeature.tabularFigures()];

  static const label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.1,
    color: AppColors.textSecondary,
  );

  static const value = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    fontFeatures: tabular,
    height: 1.1,
  );

  static const caption = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );
}

abstract final class AppTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
    ).copyWith(
      primary: AppColors.accent,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.record,
      outline: AppColors.outline,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: ThemeData.dark().textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceRaised,
        elevation: 0,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.outline),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        showDragHandle: true,
        dragHandleColor: AppColors.outline,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.outline),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.accent.withValues(alpha: 0.16)
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? AppColors.accent
                : AppColors.textSecondary,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.background,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.outline),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
