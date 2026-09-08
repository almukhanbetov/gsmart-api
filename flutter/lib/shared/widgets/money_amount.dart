import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme/app_spacing.dart';

/// Денежная сумма с анимацией изменения значения (count-up).
class MoneyAmount extends StatelessWidget {
  const MoneyAmount({
    super.key,
    required this.value,
    this.style,
    this.color,
    this.animate = true,
  });

  final num value;
  final TextStyle? style;
  final Color? color;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final baseStyle = (style ?? Theme.of(context).textTheme.headlineMedium)
        ?.copyWith(color: color, fontFeatures: const [FontFeature.tabularFigures()]);

    if (!animate) {
      return Text(formatTenge(value), style: baseStyle);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: AppDuration.counter,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(formatTenge(v.round()), style: baseStyle),
    );
  }
}
