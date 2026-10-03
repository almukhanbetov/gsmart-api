import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../core/format.dart';
import '../../core/storage/session_storage.dart';
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
import 'refresh_status.dart';

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
  /// Последний успешно загруженный список; null — ещё ни разу не загрузили.
  List<TxnRow>? _rows;
  DateTime? _loadedAt;
  String? _error;
  bool _loading = false;
  bool _pulling = false;
  Future<void>? _inFlight;
  bool _initialized = false;

  /// Пресет храним отдельно от дат: «Сегодня» / «Неделя» / «Месяц»
  /// пересчитываются при каждой отрисовке, поэтому после полуночи обновление
  /// показывает новый день. Даты фиксируются только у произвольного периода.
  /// При каждом открытии экрана — «Сегодня».
  DateRangePreset _preset = DateRangePreset.today;
  DateRange? _custom;

  DateRange get _range =>
      _preset == DateRangePreset.custom && _custom != null
          ? _custom!
          : DateRange.forPreset(_preset);

  @override
  void initState() {
    super.initState();
    _load();
    _initialized = true;
  }

  /// Загрузка истории. Повторный вызов во время запроса не создаёт второй
  /// запрос. Ошибка не стирает последние успешные данные.
  Future<void> _load() {
    final pending = _inFlight;
    if (pending != null) return pending;

    // ответ для другой сессии (выход / смена пользователя) не применяем
    final token = SessionStore.instance.token;
    final request = _fetch(token);
    _inFlight = request;
    return request;
  }

  Future<void> _fetch(String? token) async {
    _loading = true;
    _error = null;
    // из initState setState вызывать нельзя — первая отрисовка и так впереди
    if (_initialized) setState(() {});

    List<TxnRow>? rows;
    String? error;
    try {
      rows = await widget.loader();
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Проверьте соединение и попробуйте снова.';
    }

    if (!mounted) return;
    _inFlight = null;
    if (SessionStore.instance.token != token) {
      setState(() => _loading = false);
      return;
    }

    setState(() {
      _loading = false;
      if (rows != null) {
        _rows = rows;
        _loadedAt = DateTime.now();
      } else {
        _error = error;
      }
    });
  }

  Future<void> _pullToRefresh() async {
    setState(() => _pulling = true);
    try {
      // сессия — источник плиток «· сегодня» на экране автомата: обновляем
      // и её, чтобы после возврата плитки совпадали с историей
      await Future.wait([_load(), SessionStore.instance.refresh()]);
    } finally {
      if (mounted) setState(() => _pulling = false);
    }
  }

  void _onRangeChanged(DateRange range) {
    setState(() {
      _preset = range.preset;
      _custom = range.preset == DateRangePreset.custom ? range : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final error = _error;

    final Widget body;
    if (rows == null) {
      // ещё нет ни одной успешной загрузки
      body = error != null && !_loading
          ? ErrorState(message: error, onRetry: _load)
          : const HistorySkeleton();
    } else {
      body = Stack(
        children: [
          _Content(
            all: rows,
            range: _range,
            accent: widget.accent,
            rowIcon: widget.rowIcon,
            onRangeChanged: _onRangeChanged,
            onRefresh: _pullToRefresh,
            banner: error == null
                ? null
                : RefreshErrorBanner(
                    message: error,
                    updatedAt: _loadedAt,
                    onRetry: _load,
                  ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: RefreshProgressBar(visible: _loading && !_pulling),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppTopBar(title: widget.title, subtitle: widget.subtitle),
      body: AnimatedSwitcher(duration: AppDuration.base, child: body),
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
    this.banner,
  });

  final List<TxnRow> all;
  final DateRange range;
  final Color accent;
  final IconData rowIcon;
  final ValueChanged<DateRange> onRangeChanged;
  final Future<void> Function() onRefresh;

  /// Плашка «не удалось обновить» над данными.
  final Widget? banner;

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
        physics: const AlwaysScrollableScrollPhysics(),
        padding: AppSpacing.page,
        children: [
          if (banner != null) ...[
            banner!,
            const SizedBox(height: AppSpacing.lg),
          ],
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
                title: 'За выбранный период операций нет',
                message: 'Выберите другой период',
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
