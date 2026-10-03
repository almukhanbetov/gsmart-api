import 'package:intl/intl.dart';

import '../../../core/format.dart';

/// Периоды общего итога в секции «Финансы» экрана автомата.
/// Отдельно от пресетов истории (`DateRangePreset`): там «Неделя» и «Месяц»
/// означают другое и не меняются.
enum FinancePeriod {
  today('Сегодня'),
  currentWeek('Текущая неделя'),
  currentMonth('Текущий месяц'),
  last30Days('Последние 30 дней'),
  last7Days('Последние 7 дней'),
  custom('Период…');

  const FinancePeriod(this.label);

  final String label;
}

/// Календарные дни [from]..[to] включительно (время 00:00, компоненты —
/// дата по Алматы).
class FinanceRange {
  const FinanceRange(this.from, this.to);

  final DateTime from;
  final DateTime to;

  static final _date = DateFormat('dd.MM.yyyy');

  /// «02.10.2026» или «28.09.2026 – 02.10.2026».
  String get label {
    final a = _date.format(from);
    final b = _date.format(to);
    return a == b ? a : '$a – $b';
  }

  /// Границы периода на «сейчас» по Алматы ([now] — момент времени; по
  /// умолчанию текущий). Для [FinancePeriod.custom] нужен [custom].
  static FinanceRange of(
    FinancePeriod period, {
    DateTime? now,
    FinanceRange? custom,
  }) {
    final t = projectNow(now);
    // DateTime(y, m, d - n) — без Duration: летнее время телефона не
    // сдвигает календарный день
    DateTime day(int minusDays) => DateTime(t.year, t.month, t.day - minusDays);
    final today = day(0);
    switch (period) {
      case FinancePeriod.today:
        return FinanceRange(today, today);
      case FinancePeriod.currentWeek:
        // понедельник: weekday 1..7
        return FinanceRange(day(t.weekday - 1), today);
      case FinancePeriod.currentMonth:
        return FinanceRange(DateTime(t.year, t.month, 1), today);
      case FinancePeriod.last30Days:
        return FinanceRange(day(29), today);
      case FinancePeriod.last7Days:
        return FinanceRange(day(6), today);
      case FinancePeriod.custom:
        return custom ?? FinanceRange(today, today);
    }
  }
}
