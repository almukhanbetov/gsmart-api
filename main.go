package main

import (
	"context"
	"log"
	"os"

	"github.com/joho/godotenv"
)

func main() {
	_ = godotenv.Load()

	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		log.Fatal("DATABASE_URL не указан")
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	db = connectDB(databaseURL)
	defer db.Close()

	if err := ensureSchema(context.Background()); err != nil {
		log.Println("Предупреждение: схема БД не подготовлена:", err)
	}

	// BIND_HOST=127.0.0.1 — API доступен только локально (за nginx с HTTPS).
	// Пусто — все интерфейсы, как раньше.
	addr := os.Getenv("BIND_HOST") + ":" + port

	router := setupRouter()

	log.Println("API запущен на", addr)

	if err := router.Run(addr); err != nil {
		log.Fatal("Ошибка запуска API:", err)
	}
}
