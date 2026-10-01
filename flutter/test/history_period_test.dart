import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gsmart/core/format.dart';
import 'package:gsmart/core/theme/app_theme.dart';
import 'package:gsmart/shared/widgets/date_range_bar.dart';
import 'package:gsmart/shared/widgets/transaction_history_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Дата «как из API»: время Алматы с суффиксом Z (см. projectNow).
DateTime _daysAgo(int days) =>
    projectNow().subtract(Duration(days: days));

Finder _chip(String label) => find.descendant(
    of: find.byType(DateRangeBar), matching: find.text(label));

/// Выбранный чип — белый текст на акцентном фоне.
bool _chipSelected(WidgetTester tester, String label) =>
    tester.widget<Text>(_chip(label)).style?.color == Colors.white;

String _range(DateTime from, DateTime to) =>
    '${formatDateShort(from)} — ${formatDateShort(to)}';

void main() {
  setUpAll(() => initializeDateFormatting('ru'));

  group('DateRange.forPreset — дни по Asia/Almaty', () {
    // 1 октября 20:00 UTC = 2 октября 01:00 в Алматы
    final now = DateTime.utc(2026, 10, 1, 20);

    test('«Сегодня» — уже 2 октября, хотя по UTC ещё 1-е', () {
      final r = DateRange.forPreset(DateRangePreset.today, now: now);
      expect(r.from, DateTime(2026, 10, 2));
      expect(r.to, DateTime(2026, 10, 2));
    });

    test('«Неделя» и «Месяц»', () {
      final week = DateRange.forPreset(DateRangePreset.week, now: now);
      expect(week.from, DateTime(2026, 9, 26));
      expect(week.to, DateTime(2026, 10, 2));

      final month = DateRange.forPreset(DateRangePreset.month, now: now);
      expect(month.from, DateTime(2026, 10, 1));
      expect(month.to, DateTime(2026, 10, 2));
    });

    test('операция 00:30 по Алматы попадает в «Сегодня», 23:59 вчера — нет',
        () {
      final r = DateRange.forPreset(DateRangePreset.today, now: now);
      expect(isWithinRange(DateTime.parse('2026-10-02T00:30:00Z'), r.from, r.to),
          isTrue);
      expect(isWithinRange(DateTime.parse('2026-10-01T23:59:00Z'), r.from, r.to),
          isFalse);
    });

    test('заголовки «Сегодня» / «Вчера» по Алматы', () {
      expect(formatDayGroup(DateTime(2026, 10, 2), now: now), 'Сегодня');
      expect(formatDayGroup(DateTime(2026, 10, 1), now: now), 'Вчера');
      expect(
          formatRelativeDateTime(DateTime.parse('2026-10-01T23:59:00Z'),
              now: now),
          'Вчера, 23:59');
    });
  });

  group('экран истории', () {
    late int loads;

    // сегодня 100, вчера 200, 3 дня назад 400, 40 дней назад 800
    final rows = [
      TxnRow(id: 1, date: _daysAgo(0), amount: 100),
      TxnRow(id: 2, date: _daysAgo(1), amount: 200),
      TxnRow(id: 3, date: _daysAgo(3), amount: 400),
      TxnRow(id: 4, date: _daysAgo(40), amount: 800),
    ];

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(430, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      loads = 0;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        home: TransactionHistoryScreen(
          title: 'Купюры',
          subtitle: '№ 1',
          accent: Colors.teal,
          rowIcon: Icons.receipt_long_rounded,
          loader: () async {
            loads++;
            return rows;
          },
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('при открытии выбран «Сегодня», список и итог — за сегодня',
        (tester) async {
      await open(tester);

      expect(_chipSelected(tester, 'Сегодня'), isTrue);
      expect(_chipSelected(tester, 'Месяц'), isFalse);

      final today = DateRange.forPreset(DateRangePreset.today);
      expect(find.text(_range(today.from, today.to)), findsOneWidget);

      expect(find.text('+ ${formatTenge(100)}'), findsOneWidget);
      expect(find.text('+ ${formatTenge(200)}'), findsNothing);
      expect(find.text('+ ${formatTenge(400)}'), findsNothing);
      expect(find.text(formatTenge(100)), findsOneWidget); // итог
      expect(tester.takeException(), isNull);
    });

    testWidgets('ручное переключение «Неделя» / «Месяц» / «Период» работает',
        (tester) async {
      await open(tester);

      await tester.tap(_chip('Неделя'));
      await tester.pumpAndSettle();
      expect(_chipSelected(tester, 'Неделя'), isTrue);
      expect(_chipSelected(tester, 'Сегодня'), isFalse);
      expect(find.text(formatTenge(700)), findsOneWidget); // 100+200+400
      expect(find.text('+ ${formatTenge(800)}'), findsNothing);

      await tester.tap(_chip('Месяц'));
      await tester.pumpAndSettle();
      expect(_chipSelected(tester, 'Месяц'), isTrue);
      final month = DateRange.forPreset(DateRangePreset.month);
      expect(find.text(_range(month.from, month.to)), findsOneWidget);
      final monthTotal = rows
          .where((r) => isWithinRange(r.date, month.from, month.to))
          .fold<num>(0, (s, r) => s + r.amount);
      expect(find.text(formatTenge(monthTotal)), findsOneWidget);

      // произвольный период: открыть календарь и сохранить
      // в тестовом шрифте чип за краем горизонтального ряда — прокручиваем
      await tester.ensureVisible(_chip('Период'));
      await tester.pumpAndSettle();
      await tester.tap(_chip('Период'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(_chipSelected(tester, 'Период'), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('«потянуть вниз» перезагружает данные и сохраняет период',
        (tester) async {
      await open(tester);
      expect(loads, 1);

      await tester.tap(_chip('Неделя'));
      await tester.pumpAndSettle();

      // порог RefreshIndicator — 25% высоты экрана (2400 → 600 px)
      await tester.drag(find.text('+ ${formatTenge(100)}'), const Offset(0, 900));
      await tester.pumpAndSettle();

      expect(loads, 2);
      expect(_chipSelected(tester, 'Неделя'), isTrue);
      expect(find.text(formatTenge(700)), findsOneWidget);
    });

    testWidgets('новое открытие экрана снова начинается с «Сегодня»',
        (tester) async {
      await open(tester);
      await tester.tap(_chip('Месяц'));
      await tester.pumpAndSettle();
      expect(_chipSelected(tester, 'Месяц'), isTrue);

      await tester.pumpWidget(const SizedBox()); // экран закрыт
      await open(tester);
      expect(_chipSelected(tester, 'Сегодня'), isTrue);
    });
  });
}
