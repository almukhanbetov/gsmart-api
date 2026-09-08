import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Мягкая круглая кнопка-иконка (back, actions, theme toggle).
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.filled = true,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: filled ? c.surface : Colors.transparent,
      shape: CircleBorder(
        side: filled ? BorderSide(color: c.border) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 20, color: c.textPrimary),
        ),
      ),
    );
  }
}

/// Кастомная back-кнопка для вложенных экранов.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppIconButton(
      icon: Icons.arrow_back_rounded,
      tooltip: 'Назад',
      onPressed: () => Navigator.of(context).maybePop(),
    );
  }
}
