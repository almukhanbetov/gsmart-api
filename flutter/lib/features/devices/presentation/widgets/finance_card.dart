import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/format.dart';
import '../../../../core/storage/session_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../dashboard/models/device_totals.dart';
import '../../../transactions/coin/models/coin_entry.dart';
import '../../../transactions/data/transactions_repository.dart';
import '../../../transactions/money/models/money_entry.dart';
import '../../../transactions/payments/models/payment_entry.dart';
import '../../models/finance_period.dart';

/// Карточка «Финансы»: крупный итог за выбранный период, выбор периода,
/// диапазон дат и разбивка «Купюры / Монеты / Безналичные» за тот же период.
///
/// Данные — история автомата (GET /api/money|coin|payments/:account).
/// Итог и разбивка считаются по одним и тем же операциям и границам дат
/// (дни по Asia/Almaty, будущие операции не учитываются); итог = сумма строк.
/// Если хотя бы один запрос не удался, ни итог, ни строки не показываются —
/// только «Повторить».
class FinanceCard extends StatefulWidget {
  const FinanceCard({super.key, required this.account});

  final String account;

  @override
  State<FinanceCard> createState() => _FinanceCardState();
}

class _History {
  const _History(this.money, this.coin, this.payments);
  final List<MoneyEntry> money;
  final List<CoinEntry> coin;
  final List<PaymentEntry> payments;
}

class _FinanceCardState extends State<FinanceCard> {
  final _repo = TransactionsRepository();

  /// Пункт, а не даты: границы пересчитываются при каждой отрисовке
  /// (новый день, обновление данных). Даты фиксированы только у «Период…».
  FinancePeriod _period = FinancePeriod.today;
  FinanceRange? _custom;

  _History? _history;
  String? _error;
  bool _loading = false;
  bool _initialized = false;
  Future<void>? _inFlight;

  DateTime? _sessionUpdatedAt;
  Timer? _midnight;

  FinanceRange get _range => FinanceRange.of(_period, custom: _custom);

  @override
  void initState() {
    super.initState();
    _sessionUpdatedAt = SessionStore.instance.updatedAt;
    SessionStore.instance.addListener(_onSessionChanged);
    _scheduleMidnight();
    _load();
    _initialized = true;
  }

  @override
  void didUpdateWidget(FinanceCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.account != widget.account) {
      _history = null;
      _inFlight = null;
      _load();
    }
  }

  @override
  void dispose() {
    SessionStore.instance.removeListener(_onSessionChanged);
    _midnight?.cancel();
    super.dispose();
  }

  /// Данные сессии успешно обновились — перезагружаем историю автомата.
  void _onSessionChanged() {
    final updatedAt = SessionStore.instance.updatedAt;
    if (updatedAt == null || updatedAt == _sessionUpdatedAt) return;
    _sessionUpdatedAt = updatedAt;
    _load();
  }

  /// В полночь по Алматы пересчитываем границы периода (без запросов).
  void _scheduleMidnight() {
    _midnight?.cancel();
    _midnight = Timer(untilProjectMidnight(), () {
      if (!mounted) return;
      setState(() {});
      _scheduleMidnight();
    });
  }

  /// Повторный вызов во время запроса не создаёт второй запрос.
  Future<void> _load() {
    final pending = _inFlight;
    if (pending != null) return pending;
    final request = _fetch(widget.account, SessionStore.instance.token);
    _inFlight = request;
    return request;
  }

  Future<void> _fetch(String account, String? token) async {
    _loading = true;
    _error = null;
    // из initState setState вызывать нельзя — первая отрисовка и так впереди
    if (_initialized) setState(() {});

    _History? history;
    String? error;
    try {
      final r = await Future.wait([
        _repo.money(account),
        _repo.coin(account),
        _repo.payments(account),
      ]);
      history = _History(
        (r[0] as MoneyResult).items,
        (r[1] as CoinResult).items,
        (r[2] as PaymentsResult).items,
      );
    } on ApiException catch (e) {
      error = e.message;
    } catch (_) {
      error = 'Проверьте соединение и попробуйте снова.';
    }

    if (!mounted) return;
    _inFlight = null;
    // ответ для другой сессии или другого автомата не применяем
    if (SessionStore.instance.token != token || widget.account != account) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = false;
      _history = history;
      _error = error;
    });
  }

  Future<void> _select(FinancePeriod period) async {
    if (period != FinancePeriod.custom) {
      setState(() {
        _period = period;
        _custom = null;
      });
      return;
    }
    final now = projectNow();
    final today = DateTime(now.year, now.month, now.day);
    final current = _range;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: today, // будущие дни выбрать нельзя
      initialDateRange: DateTimeRange(
        start: current.from.isAfter(today) ? today : current.from,
        end: current.to.isAfter(today) ? today : current.to,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _period = FinancePeriod.custom;
      _custom = FinanceRange(
        DateTime(picked.start.year, picked.start.month, picked.start.day),
        DateTime(picked.end.year, picked.end.month, picked.end.day),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final range = _range;
    final history = _history;
    final ready = !_loading && _error == null && history != null;
    // одни и те же операции и границы для итога и строк
    final breakdown = ready
        ? DeviceTotals.breakdownForPeriod(
            money: history.money,
            coin: history.coin,
            payments: history.payments,
            from: range.from,
            to: range.to,
            notAfter: projectNow(), // будущие операции не учитываем
          )
        : null;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: AppRadius.rLg,
        // мягкий фиолетовый: из accentSoft в цвет карточки (светлая и тёмная)
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.accentSoft, c.surface],
        ),
        border: Border.all(color: c.accent.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(color: c.shadow, blurRadius: 16, offset: const Offset(0, 8)),
        ],
      ),
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.savings_rounded, size: 18, color: c.accent),
                const SizedBox(width: AppSpacing.sm),
                Text('Финансы',
                    style: text.titleSmall?.copyWith(color: c.textPrimary)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: _total(c, text, breakdown),
            ),
            const SizedBox(height: AppSpacing.sm),
            // за какие дни посчитан итог + выбор периода; на узком экране
            // кнопка переносится под диапазон
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  Text(
                    range.label,
                    style: text.bodySmall?.copyWith(color: c.textSecondary),
                  ),
                  ConstrainedBox(
                    constraints:
                        BoxConstraints(maxWidth: constraints.maxWidth),
                    child: _periodButton(c, text),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Divider(height: 1, color: c.accent.withValues(alpha: 0.18)),
            const SizedBox(height: AppSpacing.sm),
            _BreakdownRow(label: 'Купюры', value: breakdown?.money),
            _BreakdownRow(label: 'Монеты', value: breakdown?.coin),
            _BreakdownRow(label: 'Безналичные', value: breakdown?.payments),
          ],
        ),
      ),
    );
  }

  Widget _total(AppColors c, TextTheme text, PeriodBreakdown? breakdown) {
    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
        ),
      );
    }
    if (breakdown == null) {
      return Tooltip(
        message: _error ?? 'Не удалось загрузить итог',
        child: TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Повторить'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          ),
        ),
      );
    }
    // длинная сумма уменьшается, а не выходит за край
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        formatTenge(breakdown.total),
        maxLines: 1,
        style: text.headlineSmall?.copyWith(
          color: c.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _periodButton(AppColors c, TextTheme text) {
    final label =
        _period == FinancePeriod.custom ? 'Период' : _period.label;
    return PopupMenuButton<FinancePeriod>(
      tooltip: 'Период итога',
      initialValue: _period,
      onSelected: _select,
      itemBuilder: (context) => [
        for (final p in FinancePeriod.values)
          PopupMenuItem(value: p, child: Text(p.label)),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.xs, AppSpacing.sm, AppSpacing.xs),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: AppRadius.rPill,
          border: Border.all(color: c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.labelMedium?.copyWith(color: c.textSecondary),
              ),
            ),
            Icon(Icons.arrow_drop_down_rounded,
                size: 18, color: c.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Строка разбивки: подпись слева, сумма справа; без перехода и стрелки.
/// Пока итога нет (загрузка, ошибка) — «—», а не ноль.
class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.label, required this.value});

  final String label;
  final num? value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final v = value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.bodyMedium?.copyWith(color: c.textSecondary)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              v == null ? '—' : formatTenge(v),
              textAlign: TextAlign.right,
              style: text.bodyMedium?.copyWith(
                color: c.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
