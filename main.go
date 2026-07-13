package main

import (
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

	router := setupRouter()

	log.Println("API запущен на порту", port)

	if err := router.Run(":" + port); err != nil {
		log.Fatal("Ошибка запуска API:", err)
	}
}
