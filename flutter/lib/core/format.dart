import 'package:intl/intl.dart';

/// Форматирование и клиентские расчёты — перенос mobile/src/lib/format.ts.
/// Расчётная логика (signalQuality / isWithinRange) не меняется; isToday
/// считает «сегодня» по часовому поясу проекта (см. [projectUtcOffset]).

final NumberFormat _money = NumberFormat.decimalPattern('ru');
final DateFormat _time = DateFormat('HH:mm');
final DateFormat _dayMonth = DateFormat('d MMM', 'ru');
final DateFormat _dayMonthYear = DateFormat('d MMMM y', 'ru');
final DateFormat _dateShort = DateFormat('dd.MM.yy');

/// "12 345 ₸".
String formatTenge(num value) => '${_money.format(value)} ₸';

/// Только число, без символа валюты.
String formatMoney(num value) => _money.format(value);

/// "Сегодня, 14:32" / "Вчера, 14:32" / "8 сен, 14:32".
String formatRelativeDateTime(DateTime? value, {DateTime? now}) {
  if (value == null) return '—';
  final diff = _daysAgo(value, now);

  final String day;
  if (diff == 0) {
    day = 'Сегодня';
  } else if (diff == 1) {
    day = 'Вчера';
  } else {
    day = _dayMonth.format(value);
  }
  return '$day, ${_time.format(value)}';
}

/// Заголовок группы истории по дню.
String formatDayGroup(DateTime day, {DateTime? now}) {
  final diff = _daysAgo(day, now);
  if (diff == 0) return 'Сегодня';
  if (diff == 1) return 'Вчера';
  return _dayMonthYear.format(day);
}

/// Сколько календарных дней назад была дата из API относительно «сегодня»
/// по Алматы. Считается в UTC, чтобы летнее время телефона не влияло.
int _daysAgo(DateTime value, DateTime? now) {
  final today = projectNow(now);
  return DateTime.utc(today.year, today.month, today.day)
      .difference(DateTime.utc(value.year, value.month, value.day))
      .inDays;
}

String formatTime(DateTime? value) => value == null ? '—' : _time.format(value);

String formatDateShort(DateTime value) => _dateShort.format(value);

String formatDateTime(DateTime? value) =>
    value == null ? '—' : DateFormat('dd.MM.yyyy, HH:mm').format(value);

/// Приветствие по времени суток.
String greeting([DateTime? now]) {
  final h = (now ?? DateTime.now()).hour;
  if (h < 5) return 'Доброй ночи';
  if (h < 12) return 'Доброе утро';
  if (h < 18) return 'Добрый день';
  return 'Добрый вечер';
}

/// Инициалы для аватара.
String initialsOf(String name, String fallback) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) {
    return fallback.isNotEmpty ? fallback.substring(0, 1).toUpperCase() : '?';
  }
  return parts.take(2).map((p) => p.substring(0, 1).toUpperCase()).join();
}

// --- расчётная логика (не менять) -------------------------------------

/// Качество Wi-Fi из dBm-строки signal_wifi. Формула из mobile:
///   `<= -100` → 0, `>= -50` → 100, между — линейно `2*(dbm+100)`.
int? signalQuality(String raw) {
  final dbm = double.tryParse(raw.trim());
  if (dbm == null) return null;
  if (dbm <= -100) return 0;
  if (dbm >= -50) return 100;
  return (2 * (dbm + 100)).round();
}

/// Часовой пояс проекта — Asia/Almaty (UTC+5, без перехода на летнее время).
///
/// В БД время хранится как `timestamp without time zone` по Алматы, а API
/// отдаёт его с суффиксом `Z`. Поэтому компоненты дат из API — это уже время
/// Алматы, и сравнивать их нужно с «сейчас» в Алматы, а не в поясе телефона.
const Duration projectUtcOffset = Duration(hours: 5);

/// Текущие дата и время в часовом поясе проекта (компоненты — по Алматы).
DateTime projectNow([DateTime? now]) =>
    (now ?? DateTime.now()).toUtc().add(projectUtcOffset);

/// true, если дата из API — сегодня по времени Алматы (mobile: isToday()).
bool isToday(DateTime? value, {DateTime? now}) {
  if (value == null) return false;
  final today = projectNow(now);
  return value.year == today.year &&
      value.month == today.month &&
      value.day == today.day;
}

/// Диапазон дат включительно по календарным дням (mobile: isWithinRange).
bool isWithinRange(DateTime? value, DateTime from, DateTime to) {
  if (value == null) return false;
  final day = DateTime(value.year, value.month, value.day);
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day);
  return !day.isBefore(start) && !day.isAfter(end);
}
