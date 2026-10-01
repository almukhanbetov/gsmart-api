import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gsmart/core/api/api_client.dart';
import 'package:gsmart/core/api/api_exception.dart';
import 'package:gsmart/core/storage/session_storage.dart';
import 'package:gsmart/features/auth/models/login_response.dart';
import 'package:gsmart/features/transactions/data/transactions_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'session_refresh_test.dart' show jsonResponse, sessionJson;

/// Совместимость истории (money/coin/payments) с защищёнными endpoint:
/// токен в заголовке, 401 → выход, 403 → сообщение без выхода.
void main() {
  final store = SessionStore.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.clear();
  });

  TransactionsRepository repo(
    List<http.Request> requests,
    Future<http.Response> Function(http.Request) handler,
  ) =>
      TransactionsRepository(
        client: ApiClient(
          baseUrl: 'http://test',
          client: MockClient((r) {
            requests.add(r);
            return handler(r);
          }),
        ),
      );

  test('все три запроса истории идут с токеном сессии', () async {
    await store.save(LoginResponse.fromJson(sessionJson()), token: 'tok');
    final requests = <http.Request>[];
    final r = repo(requests, (req) async {
      final kind = req.url.pathSegments[1];
      return jsonResponse({
        kind: [],
        if (kind == 'money') 'pay_money_total': 0,
        if (kind == 'coin') 'pay_coin_total': 0,
        if (kind == 'payments') 'sum_total': 0,
      });
    });

    await r.money('1001001');
    await r.coin('1001001');
    await r.payments('1001001');

    expect(requests.map((q) => q.url.path),
        ['/api/money/1001001', '/api/coin/1001001', '/api/payments/1001001']);
    for (final q in requests) {
      expect(q.headers['Authorization'], 'Bearer tok');
    }
  });

  test('401 — сессия завершается, экран входа с причиной', () async {
    await store.save(LoginResponse.fromJson(sessionJson()), token: 'expired');
    final r = repo([], (_) async =>
        jsonResponse({'error': 'Сессия истекла. Войдите снова'}, 401));

    await expectLater(r.money('1001001'), throwsA(isA<ApiException>()));
    expect(store.isLoggedIn, isFalse);
    expect(store.signedOutReason, 'Сессия истекла. Войдите снова.');
  });

  test('сессия старой версии без токена → 401 → вход заново', () async {
    await store.save(LoginResponse.fromJson(sessionJson()));
    final requests = <http.Request>[];
    final r = repo(requests,
        (_) async => jsonResponse({'error': 'Требуется авторизация'}, 401));

    await expectLater(r.coin('1001001'), throwsA(isA<ApiException>()));
    expect(requests.single.headers.containsKey('Authorization'), isFalse);
    expect(store.isLoggedIn, isFalse);
  });

  test('403 на чужой автомат — сообщение, сессия остаётся', () async {
    await store.save(LoginResponse.fromJson(sessionJson()), token: 'tok');
    final r = repo([], (_) async =>
        jsonResponse({'error': 'Нет доступа к этому устройству'}, 403));

    await expectLater(
      r.payments('2002002'),
      throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', 'Нет доступа к этому устройству')
          .having((e) => e.statusCode, 'statusCode', 403)),
    );
    expect(store.isLoggedIn, isTrue);
  });

  test('401 по старому токену после повторного входа не выкидывает',
      () async {
    await store.save(LoginResponse.fromJson(sessionJson()), token: 'old');
    final gate = Completer<http.Response>();
    final r = repo([], (_) => gate.future);

    final pending = r.money('1001001');
    await store.save(LoginResponse.fromJson(sessionJson(name: 'Пётр')),
        token: 'new');
    gate.complete(jsonResponse({'error': 'Сессия истекла'}, 401));

    await expectLater(pending, throwsA(isA<ApiException>()));
    expect(store.isLoggedIn, isTrue);
    expect(store.token, 'new');
  });
}
