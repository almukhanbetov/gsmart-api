package main

import (
	"context"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
)

// sessionTTL — срок жизни сессии с момента последнего запроса (скользящий).
const sessionTTL = 90 * 24 * time.Hour

const authUserKey = "authUser"

var errNoSession = errors.New("сессия не найдена или истекла")

func hashToken(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}

// createSession выдаёт новый токен пользователю. В БД пишется только хеш.
func createSession(ctx context.Context, userID int) (string, error) {
	raw := make([]byte, 32)
	if _, err := rand.Read(raw); err != nil {
		return "", err
	}
	token := base64.RawURLEncoding.EncodeToString(raw)

	// заодно убираем просроченные сессии, чтобы таблица не росла
	if _, err := db.Exec(ctx, `DELETE FROM api_sessions WHERE expires_at < now()`); err != nil {
		return "", err
	}

	_, err := db.Exec(
		ctx,
		`INSERT INTO api_sessions (token_hash, user_id, expires_at) VALUES ($1, $2, $3)`,
		hashToken(token),
		userID,
		time.Now().Add(sessionTTL),
	)
	if err != nil {
		return "", err
	}

	return token, nil
}

// findSessionUser возвращает владельца действующей сессии и продлевает её.
// Данные пользователя (в том числе user_code) берутся из users, а не из запроса.
func findSessionUser(ctx context.Context, token string) (User, error) {
	var user User

	err := db.QueryRow(
		ctx,
		`
		UPDATE api_sessions s
		SET last_used_at = now(), expires_at = $2
		FROM users u
		WHERE s.token_hash = $1
			AND s.expires_at > now()
			AND u.id = s.user_id
		RETURNING
			u.id,
			u.phone,
			COALESCE(u.fullname, ''),
			u.user_code,
			COALESCE(u.bin, '')
		`,
		hashToken(token),
		time.Now().Add(sessionTTL),
	).Scan(
		&user.ID,
		&user.Phone,
		&user.Fullname,
		&user.UserCode,
		&user.Bin,
	)

	if errors.Is(err, pgx.ErrNoRows) {
		return User{}, errNoSession
	}

	return user, err
}

func deleteSession(ctx context.Context, token string) error {
	_, err := db.Exec(ctx, `DELETE FROM api_sessions WHERE token_hash = $1`, hashToken(token))
	return err
}

// bearerToken достаёт токен из заголовка "Authorization: Bearer <token>".
func bearerToken(c *gin.Context) string {
	header := c.GetHeader("Authorization")
	scheme, token, found := strings.Cut(header, " ")
	if !found || !strings.EqualFold(scheme, "Bearer") {
		return ""
	}
	return strings.TrimSpace(token)
}

// authenticate проверяет токен и кладёт пользователя в контекст.
// Возвращает false, если ответ уже отправлен.
func authenticate(c *gin.Context, token string) bool {
	user, err := findSessionUser(c.Request.Context(), token)

	if errors.Is(err, errNoSession) {
		c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
			"error": "Сессия истекла. Войдите снова",
		})
		return false
	}

	if err != nil {
		log.Println("Ошибка проверки сессии:", err)

		c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{
			"error": "Ошибка сервера",
		})
		return false
	}

	c.Set(authUserKey, user)
	return true
}

// requireAuth пропускает только запросы с действующей сессией.
func requireAuth() gin.HandlerFunc {
	return func(c *gin.Context) {
		token := bearerToken(c)
		if token == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{
				"error": "Требуется авторизация",
			})
			return
		}

		if authenticate(c, token) {
			c.Next()
		}
	}
}

// requireDeviceOwner пропускает запрос к :account, только если автомат
// привязан к владельцу сессии. Ставится после requireAuth.
func requireDeviceOwner() gin.HandlerFunc {
	return func(c *gin.Context) {
		user := c.MustGet(authUserKey).(User)

		owned, err := deviceBelongsToUser(
			c.Request.Context(),
			c.Param("account"),
			user.UserCode,
		)
		if err != nil {
			log.Println("Ошибка проверки устройства:", err)

			c.AbortWithStatusJSON(http.StatusInternalServerError, gin.H{
				"error": "Ошибка сервера",
			})
			return
		}

		if !owned {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{
				"error": "Нет доступа к этому устройству",
			})
			return
		}

		c.Next()
	}
}
