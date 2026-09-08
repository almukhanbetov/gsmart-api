import 'package:flutter/material.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/money_amount.dart';
import '../../models/dashboard_summary.dart';

/// Hero-блок дашборда: выручка за сегодня + разбивка. Единственное место
/// с умеренным градиентом.
class RevenueHeroCard extends StatelessWidget {
  const RevenueHeroCard({super.key, required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Container(
      decoration: BoxDecoration(
        borderRadius: AppRadius.rXl,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: c.heroGradient,
        ),
        boxShadow: [
          BoxShadow(
            color: c.heroGradient.first.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: _glow(90, Colors.white.withValues(alpha: 0.12)),
          ),
          Positioned(
            left: -20,
            bottom: -40,
            child: _glow(120, Colors.white.withValues(alpha: 0.08)),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.trending_up_rounded,
                        color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Выручка сегодня',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                MoneyAmount(
                  value: summary.revenueToday,
                  style: Theme.of(context).textTheme.displaySmall,
                  color: Colors.white,
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    _Breakdown(
                      icon: Icons.receipt_long_rounded,
                      label: 'Купюры',
                      value: summary.banknotesToday,
                    ),
                    _divider(),
                    _Breakdown(
                      icon: Icons.toll_rounded,
                      label: 'Монеты',
                      value: summary.coinsToday,
                    ),
                    _divider(),
                    _Breakdown(
                      icon: Icons.contactless_rounded,
                      label: 'Безнал',
                      value: summary.cashlessToday.round(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );

  Widget _divider() => Container(
        width: 1,
        height: 34,
        color: Colors.white.withValues(alpha: 0.18),
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      );
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final num value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: Colors.white.withValues(alpha: 0.75)),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 0.2,
                ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(value),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
