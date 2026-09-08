import 'package:flutter/material.dart';

/// Типографика приложения. Системный шрифт, аккуратно настроенные размеры и
/// насыщенности — без внешних font-пакетов.
abstract final class AppTypography {
  static TextTheme build(Color primary, Color secondary) {
    TextStyle s(
      double size,
      FontWeight weight, {
      double? height,
      double? spacing,
      Color? color,
    }) {
      return TextStyle(
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: spacing,
        color: color ?? primary,
      );
    }

    return TextTheme(
      displaySmall: s(34, FontWeight.w700, height: 1.1, spacing: -0.5),
      headlineMedium: s(26, FontWeight.w700, height: 1.15, spacing: -0.3),
      headlineSmall: s(22, FontWeight.w700, height: 1.2, spacing: -0.2),
      titleLarge: s(19, FontWeight.w600, height: 1.25),
      titleMedium: s(16, FontWeight.w600, height: 1.3),
      titleSmall: s(14, FontWeight.w600, height: 1.3),
      bodyLarge: s(15.5, FontWeight.w400, height: 1.45),
      bodyMedium: s(14, FontWeight.w400, height: 1.45, color: secondary),
      bodySmall: s(12.5, FontWeight.w400, height: 1.4, color: secondary),
      labelLarge: s(14.5, FontWeight.w600, spacing: 0.1),
      labelMedium: s(12.5, FontWeight.w600, spacing: 0.2),
      labelSmall: s(11, FontWeight.w600, spacing: 0.6, color: secondary),
    );
  }
}
