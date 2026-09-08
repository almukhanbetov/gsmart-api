import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Лёгкий shimmer без внешних зависимостей: бегущий блик по маске.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});
  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final dx = bounds.width * (_c.value * 2 - 1);
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                c.surfaceMuted,
                c.border,
                c.surfaceMuted,
              ],
              stops: const [0.35, 0.5, 0.65],
              transform: _SlideGradient(dx / bounds.width),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.ratio);
  final double ratio;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * ratio, 0, 0);
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.colors.surfaceMuted,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: AppRadius.rLg,
        border: Border.all(color: c.border),
      ),
      padding: AppSpacing.card,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 120, height: 12),
          SizedBox(height: 14),
          SkeletonBox(width: 180, height: 26),
          Spacer(),
          Row(
            children: [
              Expanded(child: SkeletonBox(height: 12)),
              SizedBox(width: 12),
              Expanded(child: SkeletonBox(height: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Скелет дашборда: hero + 4 метрики + 3 карточки автоматов.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        padding: AppSpacing.page,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          const _SkeletonCard(height: 168),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: const [
              Expanded(child: _SkeletonCard(height: 96)),
              SizedBox(width: AppSpacing.md),
              Expanded(child: _SkeletonCard(height: 96)),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          for (var i = 0; i < 3; i++) ...[
            const _SkeletonCard(height: 132),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

/// Скелет списка истории операций.
class HistorySkeleton extends StatelessWidget {
  const HistorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        padding: AppSpacing.page,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          const _SkeletonCard(height: 128),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < 6; i++) ...[
            Row(
              children: const [
                SkeletonBox(width: 40, height: 40, radius: 12),
                SizedBox(width: 12),
                Expanded(child: SkeletonBox(height: 14)),
                SizedBox(width: 12),
                SkeletonBox(width: 70, height: 14),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ],
      ),
    );
  }
}
