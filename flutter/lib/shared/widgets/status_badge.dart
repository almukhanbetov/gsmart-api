import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

enum BadgeTone { online, offline, neutral, warning }

/// Компактный статус-бейдж с точкой.
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.neutral,
    this.dense = false,
  });

  final String label;
  final BadgeTone tone;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color dot, Color fg, Color bg) = switch (tone) {
      BadgeTone.online => (c.online, c.success, c.successSoft),
      BadgeTone.offline => (c.offline, c.textSecondary, c.surfaceMuted),
      BadgeTone.warning => (c.warning, c.warning, c.warningSoft),
      BadgeTone.neutral => (c.textMuted, c.textSecondary, c.surfaceMuted),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.sm : AppSpacing.md,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.rPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: fg,
                  letterSpacing: 0.2,
                  fontSize: dense ? 10.5 : 11.5,
                ),
          ),
        ],
      ),
    );
  }
}
