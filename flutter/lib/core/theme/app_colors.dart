import 'package:flutter/material.dart';

/// Семантические цветовые токены поверх ColorScheme.
/// Доступ: `context.colors`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brightness,
    required this.pageBackground,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceMuted,
    required this.border,
    required this.borderStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentSoft,
    required this.accentAlt,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.online,
    required this.offline,
    required this.heroGradient,
    required this.shadow,
  });

  final Brightness brightness;
  final Color pageBackground;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceMuted;
  final Color border;
  final Color borderStrong;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentSoft;
  final Color accentAlt;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color online;
  final Color offline;
  final List<Color> heroGradient;
  final Color shadow;

  bool get isDark => brightness == Brightness.dark;

  // --- палитры ---------------------------------------------------------

  static const _indigo = Color(0xFF5B5BF0);
  static const _violet = Color(0xFF7C5CFF);
  static const _cyan = Color(0xFF3DC8E8);
  static const _emerald = Color(0xFF12B981);
  static const _amber = Color(0xFFF5A524);
  static const _rose = Color(0xFFF04E6E);

  static const AppColors light = AppColors(
    brightness: Brightness.light,
    pageBackground: Color(0xFFF4F5F8),
    surface: Colors.white,
    surfaceElevated: Colors.white,
    surfaceMuted: Color(0xFFEEF0F5),
    border: Color(0xFFE6E8EF),
    borderStrong: Color(0xFFD7DAE4),
    textPrimary: Color(0xFF15171C),
    textSecondary: Color(0xFF5A606E),
    textMuted: Color(0xFF9098A5),
    accent: _indigo,
    accentSoft: Color(0xFFEBEBFE),
    accentAlt: _violet,
    success: Color(0xFF0E9E6E),
    successSoft: Color(0xFFDDF3EB),
    warning: Color(0xFFB9791A),
    warningSoft: Color(0xFFFBEFDA),
    danger: Color(0xFFD83A5B),
    dangerSoft: Color(0xFFFCE4E9),
    online: _emerald,
    offline: Color(0xFFAAB1BE),
    heroGradient: [Color(0xFF4B4BE6), Color(0xFF7A5CFF), Color(0xFF4CC5E8)],
    shadow: Color(0x14101828),
  );

  static const AppColors dark = AppColors(
    brightness: Brightness.dark,
    pageBackground: Color(0xFF0C0D12),
    surface: Color(0xFF16181F),
    surfaceElevated: Color(0xFF1D2029),
    surfaceMuted: Color(0xFF20232D),
    border: Color(0xFF262A34),
    borderStrong: Color(0xFF333846),
    textPrimary: Color(0xFFEDEEF2),
    textSecondary: Color(0xFFA7ADBB),
    textMuted: Color(0xFF6C7382),
    accent: Color(0xFF8A8AFF),
    accentSoft: Color(0xFF23233A),
    accentAlt: Color(0xFF9D86FF),
    success: Color(0xFF34D399),
    successSoft: Color(0xFF12352C),
    warning: _amber,
    warningSoft: Color(0xFF3A2E17),
    danger: Color(0xFFFB7185),
    dangerSoft: Color(0xFF3B1F27),
    online: _emerald,
    offline: Color(0xFF565D6B),
    heroGradient: [Color(0xFF3B3BC7), Color(0xFF6D4FE0), Color(0xFF2E9FBF)],
    shadow: Color(0x33000000),
  );

  static const Color cyan = _cyan;
  static const Color rose = _rose;

  @override
  AppColors copyWith({Brightness? brightness}) => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return t < 0.5 ? this : other;
  }
}

extension AppColorsX on BuildContext {
  AppColors get colors =>
      Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
