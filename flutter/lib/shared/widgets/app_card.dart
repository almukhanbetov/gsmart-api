import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'fade_slide_in.dart';

/// Базовая поверхность-карточка: мягкая тень, тонкий бордер, скругление 20.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.card,
    this.onTap,
    this.borderRadius = AppRadius.rLg,
    this.elevated = false,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;
  final bool elevated;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final card = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? (elevated ? c.surfaceElevated : c.surface),
        borderRadius: borderRadius,
        border: Border.all(color: c.border),
        boxShadow: [
          BoxShadow(
            color: c.shadow,
            blurRadius: elevated ? 28 : 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap == null) return card;
    return Pressable(
      onTap: onTap!,
      child: card,
    );
  }
}
