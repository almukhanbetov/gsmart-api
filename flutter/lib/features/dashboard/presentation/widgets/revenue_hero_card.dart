import 'package:flutter/material.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/money_amount.dart';
import '../../models/dashboard_summary.dart';

/// Hero-блок дашборда: бренд «Автомойка G_smart.kz» + выручка за сегодня и её
/// разбивка + переход к списку автоматов. Градиент — единый фирменный
/// indigo/violet (тот же, что на экране входа: [AppColors.heroGradient]),
/// плюс тематические мотивы (силуэт мойки, «пена», волна).
class RevenueHeroCard extends StatelessWidget {
  const RevenueHeroCard({
    super.key,
    required this.summary,
    required this.onBrowseDevices,
  });

  final DashboardSummary summary;
  final VoidCallback onBrowseDevices;

  static const List<({double top, double right, double size, double alpha})>
      _bubbles = [
    (top: 10, right: 66, size: 10, alpha: 0.20),
    (top: 34, right: 26, size: 16, alpha: 0.14),
    (top: 66, right: 92, size: 7, alpha: 0.26),
    (top: 96, right: 44, size: 11, alpha: 0.16),
    (top: 120, right: 116, size: 6, alpha: 0.22),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;

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
      child: ClipRRect(
        borderRadius: AppRadius.rXl,
        child: Stack(
          children: [
            // силуэт мойки — водяной знак в правом нижнем углу
            const Positioned(
              right: -16,
              bottom: -18,
              child: Icon(
                Icons.local_car_wash_rounded,
                size: 150,
                color: Color(0x1EFFFFFF),
              ),
            ),
            // «пена» — пузырьки разного размера в верхней правой части
            for (final b in _bubbles)
              Positioned(
                top: b.top,
                right: b.right,
                child: Container(
                  width: b.size,
                  height: b.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: b.alpha),
                  ),
                ),
              ),
            // волна у нижнего края — водный мотив
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 28,
              child: CustomPaint(
                size: const Size(double.infinity, 28),
                painter: _WavePainter(Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Eyebrow(),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Ваша сеть автомоек',
                    style: text.headlineSmall?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      const Icon(Icons.trending_up_rounded,
                          color: Colors.white70, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Выручка сегодня',
                        style: text.labelMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  MoneyAmount(
                    value: summary.revenueToday,
                    style: text.displaySmall,
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
                  const SizedBox(height: AppSpacing.xl),
                  _BrowseButton(
                    count: summary.deviceCount,
                    onTap: onBrowseDevices,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 34,
        color: Colors.white.withValues(alpha: 0.18),
        margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      );
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: AppRadius.rPill,
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.water_drop_rounded, size: 13, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'АВТОМОЙКА G_SMART.KZ',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrowseButton extends StatelessWidget {
  const _BrowseButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  // Фиксированный тёмный indigo/violet — читается на белой плашке в обеих темах.
  static const _ink = Color(0xFF3B2E86);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: AppRadius.rPill,
      child: InkWell(
        borderRadius: AppRadius.rPill,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_car_wash_rounded, size: 18, color: _ink),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  count > 0 ? 'Мои автомойки · $count' : 'Мои автомойки',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .labelLarge
                      ?.copyWith(color: _ink),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_rounded, size: 16, color: _ink),
            ],
          ),
        ),
      ),
    );
  }
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

/// Статичная волна вдоль нижнего края hero-карточки — водный мотив.
/// Без анимации: постоянно двигающихся элементов быть не должно.
class _WavePainter extends CustomPainter {
  const _WavePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * 0.55)
      ..quadraticBezierTo(
          size.width * 0.25, size.height * 1.15, size.width * 0.5, size.height * 0.5)
      ..quadraticBezierTo(
          size.width * 0.75, size.height * -0.1, size.width, size.height * 0.45)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.color != color;
}
