import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'app_card.dart';
import 'app_top_bar.dart';
import 'date_range_bar.dart';
import 'empty_state.dart';
import 'error_state.dart';
import 'fade_slide_in.dart';
import 'loading_skeleton.dart';
import 'money_amount.dart';

/// Одна строка истории: дата операции + сумма.
class TxnRow {
  const TxnRow({required this.id, required this.date, required this.amount});
  final int id;
  final DateTime? date;
  final num amount;
}

/// Общий экран истории для Купюр / Монет / Безналичных.
///
/// Бизнес-логика перенесена из mobile по смыслу:
///  * полная история по account через существующий endpoint;
///  * фильтр по выбранному диапазону дат — на клиенте;
///  * итог = сумма отфильтрованных значений.
class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.rowIcon,
    required this.loader,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final IconData rowIcon;
  final Future<List<TxnRow>> Function() loader;

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  late Future<List<TxnRow>> _future;
  DateRange _range = DateRange.forPreset(DateRangePreset.month);

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  void _reload() => setState(() => _future = widget.loader());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(title: widget.title, subtitle: widget.subtitle),
      body: FutureBuilder<List<TxnRow>>(
        future: _future,
        builder: (context, snapshot) {
          final loading = snapshot.connectionState == ConnectionState.waiting;

          return AnimatedSwitcher(
            duration: AppDuration.base,
            child: loading
                ? const HistorySkeleton()
                : snapshot.hasError
                    ? ErrorState(
                        message: snapshot.error is ApiException
                            ? (snapshot.error as ApiException).message
                            : 'Проверьте соединение и попробуйте снова.',
                        onRetry: _reload,
                      )
                    : _Content(
                        all: snapshot.data ?? const [],
                        range: _range,
                        accent: widget.accent,
                        rowIcon: widget.rowIcon,
                        onRangeChanged: (r) => setState(() => _range = r),
                        onRefresh: () async => _reload(),
                      ),
          );
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.all,
    required this.range,
    required this.accent,
    required this.rowIcon,
    required this.onRangeChanged,
    required this.onRefresh,
  });

  final List<TxnRow> all;
  final DateRange range;
  final Color accent;
  final IconData rowIcon;
  final ValueChanged<DateRange> onRangeChanged;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final filtered = all
        .where((r) => isWithinRange(r.date, range.from, range.to))
        .toList()
      ..sort((a, b) =>
          (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
    final total = filtered.fold<num>(0, (s, r) => s + r.amount);

    // группировка по дням
    final groups = <DateTime, List<TxnRow>>{};
    for (final r in filtered) {
      final d = r.date;
      final key = d == null ? DateTime(0) : DateTime(d.year, d.month, d.day);
      groups.putIfAbsent(key, () => []).add(r);
    }
    final dayKeys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return RefreshIndicator(
      color: c.accent,
      onRefresh: onRefresh,
      child: ListView(
        padding: AppSpacing.page,
        children: [
          FadeSlideIn(
            child: _TotalHero(total: total, accent: accent),
          ),
          const SizedBox(height: AppSpacing.lg),
          DateRangeBar(value: range, onChanged: onRangeChanged),
          const SizedBox(height: AppSpacing.lg),
          if (all.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xxxl),
              child: EmptyState(
                icon: Icons.history_rounded,
                title: 'Операций пока нет',
                message: 'По этому автомату ещё не было поступлений',
              ),
            )
          else if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xxxl),
              child: EmptyState(
                icon: Icons.event_busy_rounded,
                title: 'Ничего не найдено',
                message: 'За выбранный период поступлений не найдено',
              ),
            )
          else
            for (final day in dayKeys) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xs, AppSpacing.md, 0, AppSpacing.sm),
                child: Text(
                  formatDayGroup(day),
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: c.textMuted),
                ),
              ),
              AppCard(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  children: [
                    for (var i = 0; i < groups[day]!.length; i++) ...[
                      if (i != 0) Divider(color: c.border, height: 1),
                      _OperationRow(
                        row: groups[day]![i],
                        accent: accent,
                        icon: rowIcon,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
        ],
      ),
    );
  }
}

class _TotalHero extends StatelessWidget {
  const _TotalHero({required this.total, required this.accent});
  final num total;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        borderRadius: AppRadius.rXl,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(accent, Colors.black, 0.05)!,
            Color.lerp(accent, context.colors.accentAlt, 0.55)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Итого за период',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          MoneyAmount(
            value: total,
            style: Theme.of(context).textTheme.headlineMedium,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _OperationRow extends StatelessWidget {
  const _OperationRow({
    required this.row,
    required this.accent,
    required this.icon,
  });

  final TxnRow row;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: c.isDark ? 0.18 : 0.12),
              borderRadius: AppRadius.rSm,
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              formatRelativeDateTime(row.date),
              style: text.bodyMedium?.copyWith(color: c.textSecondary),
            ),
          ),
          Text(
            '+ ${formatTenge(row.amount)}',
            style: text.titleSmall?.copyWith(
              color: c.textPrimary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
