package main

// Интеграционные тесты сессий и доступа к устройствам.
//
// Нужна отдельная пустая БД — тест создаёт в ней таблицы и тестовые данные:
//
//	docker run -d --rm --name gsmart-test-db -e POSTGRES_PASSWORD=test -p 55432:5432 postgres:17-alpine
//	TEST_DATABASE_URL=postgres://postgres:test@localhost:55432/postgres?sslmode=disable go test ./...
//
// Без TEST_DATABASE_URL тесты пропускаются.

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
)

const testFixtureSQL = `
	DROP TABLE IF EXISTS users, devices, money, coin, payments, api_sessions;

	CREATE TABLE users (
		id SERIAL PRIMARY KEY, phone VARCHAR, fullname VARCHAR,
		password_hash VARCHAR, created_at TIMESTAMP DEFAULT now(),
		user_code INTEGER, bin VARCHAR
	);
	CREATE TABLE devices (
		id SERIAL PRIMARY KEY, account VARCHAR, user_code INTEGER,
		device_name VARCHAR, type INTEGER, bin VARCHAR, gruppa VARCHAR,
		"DeviceStatus" BOOLEAN, "ServerStatus" BOOLEAN, abon_time DATE,
		summa NUMERIC, signal_wifi VARCHAR, status BOOLEAN,
		data_status TIMESTAMP, data_inkas TIMESTAMP
	);
	CREATE TABLE money (id SERIAL PRIMARY KEY, account INTEGER, pay_money INTEGER, created_at TIMESTAMP);
	CREATE TABLE coin (id SERIAL PRIMARY KEY, account INTEGER, pay_coin INTEGER, created_at TIMESTAMP);
	CREATE TABLE payments (
		id BIGSERIAL PRIMARY KEY, txn_id VARCHAR, account VARCHAR, sum NUMERIC,
		result INTEGER, comment TEXT, created TIMESTAMP
	);
`

// setupTestDB поднимает схему и двух пользователей: A (user_code 100, автомат
// 1001) и B (user_code 200, автомат 2002). Пароль у обоих — "secret".
func setupTestDB(t *testing.T) {
	t.Helper()

	url := os.Getenv("TEST_DATABASE_URL")
	if url == "" {
		t.Skip("TEST_DATABASE_URL не задан")
	}

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, url)
	if err != nil {
		t.Fatal(err)
	}
	db = pool
	t.Cleanup(pool.Close)

	schemaMu.Lock()
	schemaReady = false
	schemaMu.Unlock()

	if _, err := db.Exec(ctx, testFixtureSQL); err != nil {
		t.Fatal(err)
	}
	if err := ensureSchema(ctx); err != nil {
		t.Fatal(err)
	}

	hash, err := bcrypt.GenerateFromPassword([]byte("secret"), bcrypt.MinCost)
	if err != nil {
		t.Fatal(err)
	}

	_, err = db.Exec(ctx, `
		INSERT INTO users (phone, fullname, password_hash, user_code, bin) VALUES
			('7001', 'User A', $1, 100, 'BIN-A'),
			('7002', 'User B', $1, 200, 'BIN-B')
	`, string(hash))
	if err != nil {
		t.Fatal(err)
	}

	_, err = db.Exec(ctx, `
		INSERT INTO devices (account, user_code, device_name, type, "DeviceStatus", "ServerStatus", summa, status) VALUES
			('1001', 100, 'Мойка A', 1, false, true, 3000, true),
			('2002', 200, 'Мойка B', 1, true, true, 5000, true);
		INSERT INTO money (account, pay_money, created_at) VALUES (1001, 500, now()), (2002, 900, now());
		INSERT INTO coin (account, pay_coin, created_at) VALUES (1001, 20, now()), (2002, 40, now());
		INSERT INTO payments (txn_id, account, sum, result, comment, created) VALUES
			('t1', '1001', 30, 1, '', now()), ('t2', '2002', 70, 1, '', now());
	`)
	if err != nil {
		t.Fatal(err)
	}
}

type testResponse struct {
	status int
	body   map[string]any
}

func doRequest(t *testing.T, router http.Handler, method, path, token, body string) testResponse {
	t.Helper()

	req := httptest.NewRequest(method, path, strings.NewReader(body))
	if body != "" {
		req.Header.Set("Content-Type", "application/json")
	}
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}

	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	res := testResponse{status: rec.Code}
	if rec.Body.Len() > 0 {
		if err := json.Unmarshal(rec.Body.Bytes(), &res.body); err != nil {
			t.Fatalf("%s %s: не JSON: %s", method, path, rec.Body.String())
		}
	}
	return res
}

func login(t *testing.T, router http.Handler, phone string) string {
	t.Helper()

	res := doRequest(t, router, http.MethodPost, "/api/login", "",
		`{"phone":"`+phone+`","password":"secret"}`)
	if res.status != http.StatusOK {
		t.Fatalf("login %s: %d %v", phone, res.status, res.body)
	}

	token, _ := res.body["token"].(string)
	if token == "" {
		t.Fatal("login не вернул token")
	}
	return token
}

func deviceAccounts(body map[string]any) []string {
	var accounts []string
	devices, _ := body["devices"].([]any)
	for _, d := range devices {
		accounts = append(accounts, d.(map[string]any)["account"].(string))
	}
	return accounts
}

func TestLoginReturnsTokenAndKeepsContract(t *testing.T) {
	setupTestDB(t)
	gin.SetMode(gin.TestMode)
	router := setupRouter()

	res := doRequest(t, router, http.MethodPost, "/api/login", "", `{"phone":"7001","password":"secret"}`)
	if res.status != http.StatusOK {
		t.Fatalf("status %d", res.status)
	}
	for _, key := range []string{"message", "user", "devices", "money", "coin", "payments", "token"} {
		if _, ok := res.body[key]; !ok {
			t.Errorf("в ответе login нет %q", key)
		}
	}

	var stored string
	err := db.QueryRow(context.Background(), `SELECT token_hash FROM api_sessions`).Scan(&stored)
	if err != nil {
		t.Fatal(err)
	}
	if stored == res.body["token"] || stored != hashToken(res.body["token"].(string)) {
		t.Error("в БД должен храниться только хеш токена")
	}

	bad := doRequest(t, router, http.MethodPost, "/api/login", "", `{"phone":"7001","password":"wrong"}`)
	if bad.status != http.StatusUnauthorized || bad.body["token"] != nil {
		t.Errorf("неверный пароль: %d %v", bad.status, bad.body)
	}
}

func TestMeRequiresValidSession(t *testing.T) {
	setupTestDB(t)
	gin.SetMode(gin.TestMode)
	router := setupRouter()

	cases := map[string]string{
		"без токена":          "",
		"чужой формат":        "garbage",
		"user_code как токен": "100",
	}
	for name, token := range cases {
		res := doRequest(t, router, http.MethodGet, "/api/me", token, "")
		if res.status != http.StatusUnauthorized {
			t.Errorf("%s: ожидали 401, получили %d", name, res.status)
		}
	}

	// просроченная сессия
	token := login(t, router, "7001")
	_, err := db.Exec(context.Background(),
		`UPDATE api_sessions SET expires_at = now() - interval '1 minute' WHERE token_hash = $1`,
		hashToken(token))
	if err != nil {
		t.Fatal(err)
	}
	if res := doRequest(t, router, http.MethodGet, "/api/me", token, ""); res.status != http.StatusUnauthorized {
		t.Errorf("просроченная сессия: ожидали 401, получили %d", res.status)
	}
}

func TestMeReturnsOnlyOwnFreshData(t *testing.T) {
	setupTestDB(t)
	gin.SetMode(gin.TestMode)
	router := setupRouter()

	token := login(t, router, "7001")

	res := doRequest(t, router, http.MethodGet, "/api/me", token, "")
	if res.status != http.StatusOK {
		t.Fatalf("status %d %v", res.status, res.body)
	}
	if got := deviceAccounts(res.body); len(got) != 1 || got[0] != "1001" {
		t.Fatalf("ожидали только автомат 1001, получили %v", got)
	}
	for _, key := range []string{"money", "coin", "payments"} {
		for _, item := range res.body[key].([]any) {
			account := item.(map[string]any)["account"]
			if account != float64(1001) && account != "1001" {
				t.Errorf("%s: чужая запись %v", key, item)
			}
		}
	}

	// данные меняются в БД — /api/me отдаёт свежие без повторного входа
	_, err := db.Exec(context.Background(), `
		UPDATE devices SET "DeviceStatus" = true, summa = 4500 WHERE account = '1001';
		INSERT INTO money (account, pay_money, created_at) VALUES (1001, 1000, now());
	`)
	if err != nil {
		t.Fatal(err)
	}

	res = doRequest(t, router, http.MethodGet, "/api/me", token, "")
	device := res.body["devices"].([]any)[0].(map[string]any)
	if device["device_status"] != true || device["summa"] != float64(4500) {
		t.Errorf("устройство не обновилось: %v", device)
	}
	if n := len(res.body["money"].([]any)); n != 2 {
		t.Errorf("ожидали 2 записи money, получили %d", n)
	}
}

func TestHistoryChecksDeviceOwnership(t *testing.T) {
	setupTestDB(t)
	gin.SetMode(gin.TestMode)
	router := setupRouter()

	token := login(t, router, "7001")

	for _, kind := range []string{"money", "coin", "payments"} {
		own := doRequest(t, router, http.MethodGet, "/api/"+kind+"/1001", token, "")
		if own.status != http.StatusOK {
			t.Errorf("%s своего автомата: %d", kind, own.status)
		}

		foreign := doRequest(t, router, http.MethodGet, "/api/"+kind+"/2002", token, "")
		if foreign.status != http.StatusForbidden {
			t.Errorf("%s чужого автомата: ожидали 403, получили %d", kind, foreign.status)
		}

		invalid := doRequest(t, router, http.MethodGet, "/api/"+kind+"/2002", "garbage", "")
		if invalid.status != http.StatusUnauthorized {
			t.Errorf("%s с неверным токеном: ожидали 401, получили %d", kind, invalid.status)
		}

		noToken := doRequest(t, router, http.MethodGet, "/api/"+kind+"/1001", "", "")
		if noToken.status != http.StatusUnauthorized {
			t.Errorf("%s без токена: ожидали 401, получили %d", kind, noToken.status)
		}

		// account или user_code вместо токена доступа не дают
		for _, fake := range []string{"1001", "100"} {
			res := doRequest(t, router, http.MethodGet, "/api/"+kind+"/1001", fake, "")
			if res.status != http.StatusUnauthorized {
				t.Errorf("%s с токеном %q: ожидали 401, получили %d", kind, fake, res.status)
			}
		}
	}

	// после выхода история тоже закрыта
	doRequest(t, router, http.MethodPost, "/api/logout", token, "")
	if res := doRequest(t, router, http.MethodGet, "/api/money/1001", token, ""); res.status != http.StatusUnauthorized {
		t.Errorf("после logout: ожидали 401, получили %d", res.status)
	}
}

func TestLogoutRevokesSession(t *testing.T) {
	setupTestDB(t)
	gin.SetMode(gin.TestMode)
	router := setupRouter()

	tokenA := login(t, router, "7001")
	tokenB := login(t, router, "7002")

	if res := doRequest(t, router, http.MethodPost, "/api/logout", tokenA, ""); res.status != http.StatusNoContent {
		t.Fatalf("logout: %d", res.status)
	}
	if res := doRequest(t, router, http.MethodGet, "/api/me", tokenA, ""); res.status != http.StatusUnauthorized {
		t.Errorf("после logout: ожидали 401, получили %d", res.status)
	}

	// выход A не затрагивает сессию B
	res := doRequest(t, router, http.MethodGet, "/api/me", tokenB, "")
	if res.status != http.StatusOK {
		t.Fatalf("сессия B: %d", res.status)
	}
	if got := deviceAccounts(res.body); len(got) != 1 || got[0] != "2002" {
		t.Errorf("B видит %v", got)
	}

	// повторный logout и logout без токена — не ошибка
	if res := doRequest(t, router, http.MethodPost, "/api/logout", tokenA, ""); res.status != http.StatusNoContent {
		t.Errorf("повторный logout: %d", res.status)
	}
}

func TestSessionIsExtendedOnUse(t *testing.T) {
	setupTestDB(t)
	gin.SetMode(gin.TestMode)
	router := setupRouter()

	token := login(t, router, "7001")
	ctx := context.Background()

	if _, err := db.Exec(ctx,
		`UPDATE api_sessions SET expires_at = now() + interval '1 hour' WHERE token_hash = $1`,
		hashToken(token)); err != nil {
		t.Fatal(err)
	}

	doRequest(t, router, http.MethodGet, "/api/me", token, "")

	var expires time.Time
	if err := db.QueryRow(ctx, `SELECT expires_at FROM api_sessions WHERE token_hash = $1`,
		hashToken(token)).Scan(&expires); err != nil {
		t.Fatal(err)
	}
	if time.Until(expires) < sessionTTL-time.Hour {
		t.Errorf("сессия не продлена: истекает через %v", time.Until(expires))
	}
}
