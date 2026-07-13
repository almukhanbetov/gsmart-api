Smart24 UI — Next.js фронтенд для API из `../` (gogintest).

## Что реализовано

- `/` — страница входа (phone + password), запрос на `POST /api/login`.
- `/dashboard` — выбор устройства (account) и три карточки:
  - Пополнения деньгами: список `pay_money` + `pay_money_total`.
  - Пополнения монетами: список `pay_coin` + `pay_coin_total`.
  - Платежи: список `sum` + `sum_total`.

Запросы к `/api/*` проксируются Next.js (см. `next.config.ts`) на бэкенд, чтобы избежать проблем с CORS.

## Запуск

Бэкенд должен быть поднят (см. `../docker-compose.yml`, порт 8080 по умолчанию).

```bash
npm install
npm run dev
```

Если API работает не на `http://localhost:8080`, задайте переменную окружения перед запуском:

```bash
API_URL=http://localhost:8081 npm run dev
```

Открыть [http://localhost:3000](http://localhost:3000).
