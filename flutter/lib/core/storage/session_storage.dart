import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/models/login_response.dart';
import '../api/api_exception.dart';

/// Хранилище сессии поверх shared_preferences (аналог mobile/src/lib/session.ts,
/// там — AsyncStorage, ключ "session") и обновление данных через GET /api/me.
///
/// Правила:
///  * пароль не хранится (его и нет в ответе login), хранится только токен
///    серверной сессии;
///  * телефон/пароль/токен/полный JSON сессии не логируются;
///  * при ошибке обновления остаётся последняя успешная копия данных.
class SessionStore extends ChangeNotifier {
  SessionStore._();
  static final SessionStore instance = SessionStore._();

  static const String _key = 'session';
  static const String _tokenKey = 'session_token';
  static const String _updatedAtKey = 'session_updated_at';

  /// Автоматическое обновление (открытие экрана, возврат из фона) пропускается,
  /// если данные моложе этого интервала. Ручное — выполняется всегда.
  @visibleForTesting
  static Duration autoRefreshMinAge = const Duration(seconds: 15);

  static const String _noTokenMessage =
      'Чтобы обновлять данные, выйдите и войдите снова.';
  static const String _expiredMessage = 'Сессия истекла. Войдите снова.';

  @visibleForTesting
  AuthRepository repository = AuthRepository();

  LoginResponse? _session;
  String? _token;
  DateTime? _updatedAt;
  bool _loaded = false;
  bool _refreshing = false;
  String? _refreshError;
  String? _signedOutReason;

  /// Меняется при каждом входе/выходе. Ответ, пришедший для старого значения,
  /// отбрасывается — данные прошлой сессии не попадут в новую.
  int _generation = 0;
  Future<void>? _inFlight;

  LoginResponse? get session => _session;
  String? get token => _token;
  bool get isLoggedIn => _session != null;
  bool get isLoaded => _loaded;

  /// Время последнего успешного получения данных (login или /api/me).
  DateTime? get updatedAt => _updatedAt;

  /// Идёт запрос /api/me.
  bool get isRefreshing => _refreshing;

  /// Текст последней ошибки обновления; null — ошибки нет.
  String? get refreshError => _refreshError;

  /// Почему сессия была завершена принудительно (для экрана входа).
  String? get signedOutReason => _signedOutReason;

  /// Загрузка при старте приложения (main()).
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        _session = LoginResponse.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
        _token = prefs.getString(_tokenKey);
        _updatedAt = DateTime.tryParse(prefs.getString(_updatedAtKey) ?? '');
      }
    } catch (_) {
      _session = null;
      _token = null;
      _updatedAt = null;
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> save(LoginResponse response, {String? token}) async {
    _generation++;
    _inFlight = null;
    _refreshing = false;
    _refreshError = null;
    _signedOutReason = null;
    _session = response;
    _token = token;
    _updatedAt = DateTime.now();
    _loaded = true;
    notifyListeners();
    await _persist();
  }

  /// Обновляет данные с сервера. Параллельные вызовы получают один и тот же
  /// запрос. С [force] = false запрос пропускается, если данные свежие.
  Future<void> refresh({bool force = true}) {
    final pending = _inFlight;
    if (pending != null) return pending;
    if (_session == null) return Future.value();

    final token = _token;
    if (token == null || token.isEmpty) {
      // сессия сохранена старой версией приложения — токена нет
      if (_refreshError != _noTokenMessage) {
        _refreshError = _noTokenMessage;
        notifyListeners();
      }
      return Future.value();
    }

    final updatedAt = _updatedAt;
    if (!force &&
        _refreshError == null &&
        updatedAt != null &&
        DateTime.now().difference(updatedAt) < autoRefreshMinAge) {
      return Future.value();
    }

    _refreshing = true;
    notifyListeners();

    final request = _refresh(token, _generation);
    _inFlight = request;
    return request;
  }

  Future<void> _refresh(String token, int generation) async {
    try {
      final fresh = await repository.me(token);
      if (generation != _generation) return;

      _session = fresh;
      _updatedAt = DateTime.now();
      _refreshError = null;
      await _persist();
    } on ApiException catch (e) {
      if (generation != _generation) return;

      if (e.statusCode == 401) {
        await clear(reason: _expiredMessage);
        return;
      }
      _refreshError = e.message;
    } catch (_) {
      if (generation != _generation) return;
      _refreshError = 'Не удалось обновить данные. Попробуйте ещё раз.';
    } finally {
      if (generation == _generation) {
        _refreshing = false;
        _inFlight = null;
        notifyListeners();
      }
    }
  }

  /// Сервер ответил 401 на запрос, сделанный с [token]: сессия недействительна.
  /// Если с тех пор пользователь уже вышел или вошёл заново, ничего не делаем.
  Future<void> expire(String? token) async {
    if (_session == null || _token != token) return;
    await clear(reason: _expiredMessage);
  }

  /// Выход по кнопке: локальные данные удаляются сразу, сессия на сервере
  /// отзывается в фоне (ошибка сети выходу не мешает).
  Future<void> signOut() async {
    final token = _token;
    await clear();
    if (token != null && token.isNotEmpty) {
      unawaited(repository.logout(token).catchError((Object _) {}));
    }
  }

  Future<void> clear({String? reason}) async {
    _generation++;
    _inFlight = null;
    _refreshing = false;
    _refreshError = null;
    _signedOutReason = reason;
    _session = null;
    _token = null;
    _updatedAt = null;
    _loaded = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      await prefs.remove(_tokenKey);
      await prefs.remove(_updatedAtKey);
    } catch (_) {
      // игнорируем
    }
  }

  Future<void> _persist() async {
    final session = _session;
    if (session == null) return;
    final generation = _generation;
    try {
      final prefs = await SharedPreferences.getInstance();
      // за время ожидания пользователь мог выйти — старую копию не пишем
      if (generation != _generation) return;
      await prefs.setString(_key, jsonEncode(session.toJson()));
      final token = _token;
      if (token == null) {
        await prefs.remove(_tokenKey);
      } else {
        await prefs.setString(_tokenKey, token);
      }
      final updatedAt = _updatedAt;
      if (updatedAt != null) {
        await prefs.setString(_updatedAtKey, updatedAt.toIso8601String());
      }
    } catch (_) {
      // не критично: сессия останется в памяти на время запуска
    }
  }
}
