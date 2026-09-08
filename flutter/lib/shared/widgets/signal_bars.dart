import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum SignalLevel { offline, weak, medium, good, excellent }

SignalLevel signalLevelFor(int? quality) {
  if (quality == null || quality <= 0) return SignalLevel.offline;
  if (quality < 30) return SignalLevel.weak;
  if (quality < 55) return SignalLevel.medium;
  if (quality < 80) return SignalLevel.good;
  return SignalLevel.excellent;
}

/// Индикатор сигнала: 4 столбика + опциональный процент.
/// Формула качества не меняется (core/format.dart signalQuality).
class SignalBars extends StatelessWidget {
  const SignalBars({
    super.key,
    required this.quality,
    this.showLabel = false,
    this.size = 16,
  });

  final int? quality;
  final bool showLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final level = signalLevelFor(quality);
    final active = switch (level) {
      SignalLevel.offline => 0,
      SignalLevel.weak => 1,
      SignalLevel.medium => 2,
      SignalLevel.good => 3,
      SignalLevel.excellent => 4,
    };
    final color = switch (level) {
      SignalLevel.offline => c.offline,
      SignalLevel.weak => c.danger,
      SignalLevel.medium => c.warning,
      SignalLevel.good => c.success,
      SignalLevel.excellent => c.success,
    };

    final bars = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < 4; i++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            width: size * 0.22,
            height: size * (0.4 + i * 0.2),
            decoration: BoxDecoration(
              color: i < active ? color : c.border,
              borderRadius: BorderRadius.circular(size * 0.08),
            ),
          ),
          if (i != 3) SizedBox(width: size * 0.12),
        ],
      ],
    );

    if (!showLabel) return bars;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        bars,
        const SizedBox(width: 8),
        Text(
          quality == null ? '—' : '$quality%',
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}
