# Развёртывание gsmart API с HTTPS

## Что известно о VPS (проверено снаружи)

| Порт | Кто отвечает | Что там |
|---|---|---|
| 80 | Apache 2.4.58 | на голый IP отдаёт листинг каталога «Index of /» |
| 443 | nginx 1.24.0 | Let's Encrypt для `smart24.kz`, `pay.smart24.kz` |
| 8081 | gsmart API (Gin) | открыт наружу, HTTP |

Своего домена у API нет. Что нужно уточнить или сделать:

1. **Домен для API**: поддомен с A-записью на `37.140.243.167`.
2. **Способ выпуска сертификатов.** Порт 80 занят Apache, поэтому сначала
   посмотреть, как выпущены существующие:
   `sudo certbot certificates` и `sudo cat /etc/letsencrypt/renewal/smart24.kz.conf`
   (строки `authenticator` и `webroot_path`).
3. **Фактический `docker-compose.yml`** в `/home/aset/gsmart-api`: там образ
   `almuko/gsmart-api` и `PORT=8081` (в репозитории другой compose для сборки).

## Порядок

1. Создать DNS-запись `API_DOMAIN → 37.140.243.167` и дождаться её применения.
2. Выпустить сертификат тем же способом, что и для `smart24.kz`, например:
   `sudo certbot certonly --webroot -w <webroot_path из renewal-конфига> -d API_DOMAIN`.
3. Установить конфиг nginx из `deploy/nginx/gsmart-api.conf.template`
   (подставить домен), затем `sudo nginx -t && sudo systemctl reload nginx`.
4. Проверить `curl https://API_DOMAIN/api/health` → `{"db":true}`.
5. Собрать и выпустить приложение с `--dart-define=API_URL=https://API_DOMAIN`.
6. Закрыть прямой доступ к API: в compose на сервере добавить
   `BIND_HOST: "127.0.0.1"`, затем `docker compose up -d`.
   До этого старые сборки, которые ходят на `http://37.140.243.167:8081`, продолжают
   работать (кроме истории, для неё теперь нужен токен).
