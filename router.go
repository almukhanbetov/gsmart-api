package main

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

func setupRouter() *gin.Engine {
	router := gin.Default()

	router.GET("/", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"service": "gsmart API",
			"status":  "working",
		})
	})

	router.GET("/api/health", healthHandler)

	api := router.Group("/api", requireDB())

	api.POST("/login", loginHandler)

	api.GET("/money/:account", getMoneyHandler)
	api.GET("/coin/:account", getCoinHandler)
	api.GET("/payments/:account", getPaymentsHandler)

	return router
}

// requireDB останавливает запрос с понятной ошибкой, если БД недоступна,
// вместо того чтобы каждый обработчик падал со своим текстом.
func requireDB() gin.HandlerFunc {
	return func(c *gin.Context) {
		if err := db.Ping(c.Request.Context()); err != nil {
			c.AbortWithStatusJSON(http.StatusServiceUnavailable, gin.H{
				"error": "Нет подключения к базе данных",
			})
			return
		}

		c.Next()
	}
}

func healthHandler(c *gin.Context) {
	if err := db.Ping(c.Request.Context()); err != nil {
		c.JSON(http.StatusServiceUnavailable, gin.H{"db": false})
		return
	}

	c.JSON(http.StatusOK, gin.H{"db": true})
}
