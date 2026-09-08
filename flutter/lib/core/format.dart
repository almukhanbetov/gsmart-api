import 'package:intl/intl.dart';

/// Форматирование и клиентские расчёты — перенос mobile/src/lib/format.ts.
/// Расчётная логика (signalQuality / isToday / isWithinRange) не меняется.

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
String formatRelativeDateTime(DateTime? value) {
  if (value == null) return '—';
  final now = DateTime.now();
  final d = DateTime(value.year, value.month, value.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(d).inDays;

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
String formatDayGroup(DateTime day) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Сегодня';
  if (diff == 1) return 'Вчера';
  return _dayMonthYear.format(day);
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

/// true, если дата — сегодня (mobile: isToday()).
bool isToday(DateTime? value) {
  if (value == null) return false;
  final now = DateTime.now();
  return value.year == now.year &&
      value.month == now.month &&
      value.day == now.day;
}

/// Диапазон дат включительно по календарным дням (mobile: isWithinRange).
bool isWithinRange(DateTime? value, DateTime from, DateTime to) {
  if (value == null) return false;
  final day = DateTime(value.year, value.month, value.day);
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day);
  return !day.isBefore(start) && !day.isAfter(end);
}
