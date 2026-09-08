import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/models/login_response.dart';

/// Хранилище сессии поверх shared_preferences (аналог mobile/src/lib/session.ts,
/// там — AsyncStorage, ключ "session").
///
/// Правила:
///  * пароль не хранится (его и нет в ответе login);
///  * телефон/пароль/полный JSON сессии не логируются.
class SessionStore extends ChangeNotifier {
  SessionStore._();
  static final SessionStore instance = SessionStore._();

  static const String _key = 'session';

  LoginResponse? _session;
  bool _loaded = false;

  LoginResponse? get session => _session;
  bool get isLoggedIn => _session != null;
  bool get isLoaded => _loaded;

  /// Загрузка при старте приложения (main()).
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null && raw.isNotEmpty) {
        _session = LoginResponse.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      _session = null;
    } finally {
      _loaded = true;
      notifyListeners();
    }
  }

  Future<void> save(LoginResponse response) async {
    _session = response;
    _loaded = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(response.toJson()));
    } catch (_) {
      // не критично: сессия останется в памяти на время запуска
    }
  }

  Future<void> clear() async {
    _session = null;
    _loaded = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {
      // игнорируем
    }
  }
}
