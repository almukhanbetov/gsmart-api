import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';

/// Тонкая обёртка над `package:http`.
///
/// Единый разбор ответа и ошибок для всех запросов. Текущий backend не требует
/// авторизации — заголовок Authorization не добавляется (см. этап проекта).
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  Future<dynamic> getJson(String path) {
    return _send(() => _client.get(_uri(path)));
  }

  Future<dynamic> postJson(String path, Map<String, dynamic> body) {
    return _send(
      () => _client.post(
        _uri(path),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
    );
  }

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(ApiConfig.timeout);
    } on TimeoutException {
      throw ApiException('Превышено время ожидания. Проверьте соединение.');
    } on SocketException {
      throw ApiException('Нет подключения к серверу.');
    } on http.ClientException {
      throw ApiException('Не удалось связаться с сервером.');
    }

    final dynamic decoded = _decodeBody(response);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    // Backend отдаёт ошибки в виде {"error": "..."}
    if (decoded is Map && decoded['error'] is String) {
      throw ApiException(decoded['error'] as String,
          statusCode: response.statusCode);
    }

    if (response.statusCode >= 500) {
      throw ApiException('Ошибка сервера. Попробуйте позже.',
          statusCode: response.statusCode);
    }

    throw ApiException('Запрос не выполнен.', statusCode: response.statusCode);
  }

  dynamic _decodeBody(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      return null;
    }
  }

  void close() => _client.close();
}
