import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gsmart/core/api/api_client.dart';
import 'package:gsmart/core/storage/session_storage.dart';
import 'package:gsmart/features/auth/data/auth_repository.dart';
import 'package:gsmart/features/auth/models/login_response.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> sessionJson({
  String name = 'Иван',
  int userCode = 1001,
  String account = '1001001',
  bool deviceStatus = true,
  num summa = 3000,
}) =>
    {
      'user': {
        'id': 1,
        'phone': '77000000001',
        'fullname': name,
        'user_code': userCode,
        'bin': '',
      },
      'devices': [
        {
          'id': 1,
          'account': account,
          'user_code': userCode,
          'device_name': 'Мойка',
          'type': 1,
          'bin': '',
          'gruppa': '',
          'device_status': deviceStatus,
          'server_status': true,
          'abon_time': null,
          'summa': summa,
          'signal_wifi': '-60',
          'status': true,
          'data_status': null,
          'data_inkas': null,
        }
      ],
      'money': [],
      'coin': [],
      'payments': [],
    };

LoginResponse session({bool deviceStatus = true, num summa = 3000}) =>
    LoginResponse.fromJson(
        sessionJson(deviceStatus: deviceStatus, summa: summa));

/// Подменяет HTTP у SessionStore. [handler] получает каждый запрос.
List<http.Request> useServer(
    Future<http.Response> Function(http.Request) handler) {
  final requests = <http.Request>[];
  SessionStore.instance.repository = AuthRepository(
    client: ApiClient(
      baseUrl: 'http://test',
      client: MockClient((request) {
        requests.add(request);
        return handler(request);
      }),
    ),
  );
  return requests;
}

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  final store = SessionStore.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await store.clear();
  });

  test('refresh: запрос с токеном, данные и сохранённая копия обновляются',
      () async {
    await store.save(session(deviceStatus: false, summa: 3000), token: 'tok-1');
    final before = store.updatedAt!;

    final requests = useServer(
      (_) async => jsonResponse(sessionJson(deviceStatus: true, summa: 4500)),
    );
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await store.refresh();

    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/api/me');
    expect(requests.single.headers['Authorization'], 'Bearer tok-1');

    expect(store.session!.devices.single.deviceStatus, isTrue);
    expect(store.session!.devices.single.summa, 4500);
    expect(store.refreshError, isNull);
    expect(store.isRefreshing, isFalse);
    expect(store.updatedAt!.isAfter(before), isTrue);

    // копия на диске тоже свежая, токен сохранён
    final prefs = await SharedPreferences.getInstance();
    final saved = LoginResponse.fromJson(
        jsonDecode(prefs.getString('session')!) as Map<String, dynamic>);
    expect(saved.devices.single.summa, 4500);
    expect(prefs.getString('session_token'), 'tok-1');
  });

  test('одновременные вызовы — один запрос', () async {
    await store.save(session(), token: 'tok');
    final gate = Completer<http.Response>();
    final requests = useServer((_) => gate.future);

    final a = store.refresh();
    final b = store.refresh();
    final c = store.refresh(force: false);
    expect(store.isRefreshing, isTrue);

    gate.complete(jsonResponse(sessionJson()));
    await Future.wait([a, b, c]);

    expect(requests, hasLength(1));
    expect(store.isRefreshing, isFalse);
  });

  test('force: false пропускает запрос, если данные свежие', () async {
    await store.save(session(), token: 'tok');
    final requests = useServer((_) async => jsonResponse(sessionJson()));

    await store.refresh(force: false);
    expect(requests, isEmpty);

    await store.refresh();
    expect(requests, hasLength(1));
  });

  test('сетевая ошибка: последняя копия остаётся, повтор восстанавливает',
      () async {
    await store.save(session(summa: 3000), token: 'tok');
    final savedAt = store.updatedAt;

    var online = false;
    useServer((_) async {
      if (!online) throw const SocketException('offline');
      return jsonResponse(sessionJson(summa: 7000));
    });

    await store.refresh();
    expect(store.isLoggedIn, isTrue);
    expect(store.session!.devices.single.summa, 3000);
    expect(store.refreshError, 'Нет подключения к серверу.');
    expect(store.updatedAt, savedAt);
    expect(store.isRefreshing, isFalse);

    online = true;
    await store.refresh();
    expect(store.refreshError, isNull);
    expect(store.session!.devices.single.summa, 7000);
  });

  test('ошибка сервера 500 — данные не теряются', () async {
    await store.save(session(summa: 3000), token: 'tok');
    useServer((_) async =>
        jsonResponse({'error': 'Ошибка получения устройств'}, 500));

    await store.refresh();
    expect(store.session!.devices.single.summa, 3000);
    expect(store.refreshError, 'Ошибка получения устройств');
  });

  test('401 — сессия завершается с понятной причиной', () async {
    await store.save(session(), token: 'expired');
    useServer((_) async =>
        jsonResponse({'error': 'Сессия истекла. Войдите снова'}, 401));

    await store.refresh();
    expect(store.isLoggedIn, isFalse);
    expect(store.token, isNull);
    expect(store.signedOutReason, 'Сессия истекла. Войдите снова.');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('session'), isNull);
    expect(prefs.getString('session_token'), isNull);
  });

  test('выход во время запроса — ответ старой сессии отбрасывается', () async {
    await store.save(session(), token: 'tok');
    final gate = Completer<http.Response>();
    final requests = useServer((request) {
      if (request.url.path == '/api/logout') {
        return Future.value(http.Response('', 204));
      }
      return gate.future;
    });

    final pending = store.refresh();
    await store.signOut();
    gate.complete(jsonResponse(sessionJson(summa: 9999)));
    await pending;
    await Future<void>.delayed(Duration.zero);

    expect(store.isLoggedIn, isFalse);
    expect(store.isRefreshing, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('session'), isNull);
    // сессия отозвана и на сервере
    expect(requests.where((r) => r.url.path == '/api/logout'), hasLength(1));
  });

  test('смена пользователя во время запроса — данные не смешиваются',
      () async {
    await store.save(session(), token: 'tok-a');
    final gate = Completer<http.Response>();
    useServer((_) => gate.future);

    final pending = store.refresh();

    final userB = LoginResponse.fromJson(
        sessionJson(name: 'Пётр', userCode: 2002, account: '2002002'));
    await store.save(userB, token: 'tok-b');

    gate.complete(jsonResponse(sessionJson(name: 'Иван')));
    await pending;

    expect(store.session!.user.fullname, 'Пётр');
    expect(store.session!.devices.single.account, '2002002');
    expect(store.token, 'tok-b');
    expect(store.isRefreshing, isFalse);
  });

  test('сессия без токена (старая версия) — подсказка, запроса нет', () async {
    await store.save(session());
    final requests = useServer((_) async => jsonResponse(sessionJson()));

    await store.refresh();
    expect(requests, isEmpty);
    expect(store.isLoggedIn, isTrue);
    expect(store.refreshError, contains('войдите снова'));
  });

  test('load восстанавливает токен и время обновления', () async {
    await store.save(session(), token: 'tok');
    final updatedAt = store.updatedAt;

    final prefs = await SharedPreferences.getInstance();
    SharedPreferences.setMockInitialValues({
      'session': prefs.getString('session')!,
      'session_token': prefs.getString('session_token')!,
      'session_updated_at': prefs.getString('session_updated_at')!,
    });
    await store.load();

    expect(store.token, 'tok');
    expect(store.updatedAt, updatedAt);
  });
}
