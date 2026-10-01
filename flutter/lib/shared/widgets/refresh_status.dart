import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'app_card.dart';

/// Тонкая полоска загрузки поверх экрана: данные остаются видимыми.
class RefreshProgressBar extends StatelessWidget {
  const RefreshProgressBar({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: AppDuration.fast,
        child: SizedBox(
          height: 2,
          child: visible
              ? LinearProgressIndicator(
                  minHeight: 2,
                  color: c.accent,
                  backgroundColor: Colors.transparent,
                )
              : null,
        ),
      ),
    );
  }
}

/// Плашка «не удалось обновить»: показываем последнюю успешную копию
/// и даём повторить запрос.
class RefreshErrorBanner extends StatelessWidget {
  const RefreshErrorBanner({
    super.key,
    required this.message,
    required this.updatedAt,
    required this.onRetry,
  });

  final String message;
  final DateTime? updatedAt;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final at = updatedAt;
    final reason = message.endsWith('.') ? message : '$message.';

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.sm, AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.dangerSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.cloud_off_rounded, size: 18, color: c.danger),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Не удалось обновить данные',
                    style: text.titleSmall?.copyWith(color: c.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  at == null
                      ? reason
                      : '$reason Показаны данные от ${formatDateTime(at)}.',
                  style: text.bodySmall?.copyWith(color: c.textMuted),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Повторить'),
          ),
        ],
      ),
    );
  }
}
