package main

import (
	"context"
	"sync"
)

// schemaSQL создаёт таблицы, которых нет в исходной БД. Запросы идемпотентны:
// повторный запуск ничего не меняет.
//
// api_sessions — серверные сессии мобильного приложения. Хранится только
// SHA-256 от токена, сам токен знает лишь клиент.
const schemaSQL = `
	CREATE TABLE IF NOT EXISTS api_sessions (
		id           BIGSERIAL   PRIMARY KEY,
		token_hash   TEXT        NOT NULL UNIQUE,
		user_id      INTEGER     NOT NULL,
		created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
		last_used_at TIMESTAMPTZ NOT NULL DEFAULT now(),
		expires_at   TIMESTAMPTZ NOT NULL
	);
	CREATE INDEX IF NOT EXISTS api_sessions_user_id_idx ON api_sessions (user_id);
	CREATE INDEX IF NOT EXISTS api_sessions_expires_at_idx ON api_sessions (expires_at);
`

var (
	schemaMu    sync.Mutex
	schemaReady bool
)

// ensureSchema применяет schemaSQL один раз за время работы процесса.
// Если БД была недоступна при старте, повторяется при следующем запросе.
func ensureSchema(ctx context.Context) error {
	schemaMu.Lock()
	defer schemaMu.Unlock()

	if schemaReady {
		return nil
	}

	if _, err := db.Exec(ctx, schemaSQL); err != nil {
		return err
	}

	schemaReady = true
	return nil
}
