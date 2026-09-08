/// Единственное место, где задаётся адрес backend.
///
/// По умолчанию — тот же production API, что использует `mobile/`
/// (mobile/.env → EXPO_PUBLIC_API_URL=http://37.140.243.167:8081).
///
/// Переопределяется без правки кода:
///   flutter run --dart-define=API_URL=http://10.0.2.2:8080
class ApiConfig {
  const ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://37.140.243.167:8081',
  );

  /// Таймаут на любой HTTP-запрос.
  static const Duration timeout = Duration(seconds: 15);
}
