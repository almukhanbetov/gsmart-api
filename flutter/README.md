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

## API (не меняется)

| Метод | Endpoint | Экран |
|---|---|---|
| POST | `/api/login` | LoginScreen |
| — | (dashboard использует данные из ответа login) | DashboardScreen |
| GET | `/api/money/:account` | MoneyScreen |
| GET | `/api/coin/:account` | CoinScreen |
| GET | `/api/payments/:account` | PaymentsScreen |

JWT и новых endpoint нет — используется текущая серверная логика.
