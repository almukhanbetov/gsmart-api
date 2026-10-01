package main

import (
	"errors"
	"log"
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"golang.org/x/crypto/bcrypt"
)

func loginHandler(c *gin.Context) {
	var request LoginRequest

	if err := c.ShouldBindJSON(&request); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Укажите phone и password",
		})
		return
	}

	request.Phone = strings.TrimSpace(request.Phone)

	user, passwordHash, err := findUserByPhone(
		c.Request.Context(),
		request.Phone,
	)

	if errors.Is(err, pgx.ErrNoRows) {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "Неверный телефон или пароль",
		})
		return
	}

	if err != nil {
		log.Println("Ошибка получения пользователя:", err)

		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Ошибка сервера",
		})
		return
	}

	err = bcrypt.CompareHashAndPassword(
		[]byte(passwordHash),
		[]byte(request.Password),
	)

	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{
			"error": "Неверный телефон или пароль",
		})
		return
	}

	data, ok := loadUserData(c, user)
	if !ok {
		return
	}

	data["message"] = "Авторизация успешна"

	// Токен нужен для обновления данных без повторного входа (GET /api/me).
	// Если сессию создать не удалось, вход всё равно работает как раньше.
	token, err := createSession(c.Request.Context(), user.ID)
	if err != nil {
		log.Println("Ошибка создания сессии:", err)
	} else {
		data["token"] = token
	}

	c.JSON(http.StatusOK, data)
}

// meHandler — актуальные данные владельца сессии в том же формате, что login.
func meHandler(c *gin.Context) {
	user := c.MustGet(authUserKey).(User)

	data, ok := loadUserData(c, user)
	if !ok {
		return
	}

	c.JSON(http.StatusOK, data)
}

// logoutHandler отзывает текущую сессию. Неизвестный токен — тоже успех.
func logoutHandler(c *gin.Context) {
	if token := bearerToken(c); token != "" {
		if err := deleteSession(c.Request.Context(), token); err != nil {
			log.Println("Ошибка удаления сессии:", err)

			c.JSON(http.StatusInternalServerError, gin.H{
				"error": "Ошибка сервера",
			})
			return
		}
	}

	c.Status(http.StatusNoContent)
}

// loadUserData собирает user + devices/money/coin/payments по user_code.
// При ошибке сам отправляет ответ и возвращает ok = false.
func loadUserData(c *gin.Context, user User) (gin.H, bool) {
	devices, err := getDevices(
		c.Request.Context(),
		user.UserCode,
	)
	if err != nil {
		log.Println("Ошибка получения devices:", err)

		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Ошибка получения устройств",
		})
		return nil, false
	}

	money, err := getMoney(
		c.Request.Context(),
		user.UserCode,
	)
	if err != nil {
		log.Println("Ошибка получения money:", err)

		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Ошибка получения money",
		})
		return nil, false
	}

	coins, err := getCoins(
		c.Request.Context(),
		user.UserCode,
	)
	if err != nil {
		log.Println("Ошибка получения coin:", err)

		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Ошибка получения coin",
		})
		return nil, false
	}

	payments, err := getPayments(
		c.Request.Context(),
		user.UserCode,
	)
	if err != nil {
		log.Println("Ошибка получения payments:", err)

		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Ошибка получения payments",
		})
		return nil, false
	}

	return gin.H{
		"user":     user,
		"devices":  devices,
		"money":    money,
		"coin":     coins,
		"payments": payments,
	}, true
}

func getMoneyHandler(c *gin.Context) {
	account, err := strconv.Atoi(c.Param("account"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "account должен быть числом",
		})
		return
	}

	money, err := getMoneyByAccount(c.Request.Context(), account)
	if err != nil {
		log.Println("Ошибка получения money:", err)

		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Ошибка получения money",
		})
		return
	}

	total := 0
	for _, item := range money {
		total += item.PayMoney
	}

	c.JSON(http.StatusOK, gin.H{
		"money":           money,
		"pay_money_total": total,
	})
}

func getCoinHandler(c *gin.Context) {
	account, err := strconv.Atoi(c.Param("account"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "account должен быть числом",
		})
		return
	}

	coins, err := getCoinsByAccount(c.Request.Context(), account)
	if err != nil {
		log.Println("Ошибка получения coin:", err)

		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Ошибка получения coin",
		})
		return
	}

	total := 0
	for _, item := range coins {
		total += item.PayCoin
	}

	c.JSON(http.StatusOK, gin.H{
		"coin":           coins,
		"pay_coin_total": total,
	})
}

func getPaymentsHandler(c *gin.Context) {
	account := c.Param("account")

	payments, err := getPaymentsByAccount(c.Request.Context(), account)
	if err != nil {
		log.Println("Ошибка получения payments:", err)

		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Ошибка получения payments",
		})
		return
	}

	var total float64
	for _, item := range payments {
		total += item.Sum
	}

	c.JSON(http.StatusOK, gin.H{
		"payments":  payments,
		"sum_total": total,
	})
}
