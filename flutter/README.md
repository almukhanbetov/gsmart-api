# gsmart Flutter

Отдельное Flutter-приложение личного кабинета Smart24. Функционально повторяет
`../mobile/` (React Native / Expo) и работает с текущим production API **без
изменения backend**.

## Запуск

```bash
flutter pub get
flutter run                       # использует production API по умолчанию
# или указать свой backend:
flutter run --dart-define=API_URL=http://10.0.2.2:8080
```

`API_URL` по умолчанию — `http://37.140.243.167:8081` (тот же адрес, что в
`../mobile/.env`). Задаётся в одном месте: `lib/core/api/api_config.dart`.

## Проверки

```bash
flutter analyze
flutter test
```

## Структура

```
lib/
├── main.dart
├── core/
│   ├── api/        api_client.dart · api_config.dart · api_exception.dart
│   ├── storage/    session_storage.dart      (shared_preferences)
│   ├── theme/      app_theme.dart            (Material 3)
│   ├── router/     app_router.dart           (go_router)
│   ├── format.dart                           (перенос mobile/src/lib/format.ts)
│   └── utils/json.dart
├── features/
│   ├── auth/        models/(user,login_response) · data/auth_repository · presentation/login_screen
│   ├── dashboard/   models/device_totals · presentation/dashboard_screen
│   ├── devices/     models/device · presentation/device_detail_screen
│   └── transactions/
│       ├── data/transactions_repository.dart
│       ├── money/    models/money_entry · money_screen
│       ├── coin/     models/coin_entry · coin_screen
│       └── payments/ models/payment_entry · payments_screen
└── shared/widgets/  signal_bars · status_views · date_range_bar · transaction_history_screen
```

## API

| Метод | Endpoint | Экран |
|---|---|---|
| POST | `/api/login` | LoginScreen (в ответе — данные и `token` сессии) |
| GET | `/api/me` | обновление главной и экрана автомата |
| POST | `/api/logout` | выход (отзыв сессии) |
| GET | `/api/money/:account` | MoneyScreen |
| GET | `/api/coin/:account` | CoinScreen |
| GET | `/api/payments/:account` | PaymentsScreen |

Все запросы, кроме login, идут с `Authorization: Bearer <token>`. История
отдаётся только по автоматам владельца сессии. Пароль на устройстве не
хранится, токен и последняя копия данных — в `shared_preferences`.
Ответ 401 завершает сессию и возвращает на экран входа.

Данные обновляются при открытии главной и экрана автомата, при возврате
приложения из фона и жестом «потянуть вниз». «Сегодня» считается по
Asia/Almaty (см. `projectUtcOffset` в `lib/core/format.dart`).
