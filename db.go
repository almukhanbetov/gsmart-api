package main

import (
	"context"
	"log"

	"github.com/jackc/pgx/v5/pgxpool"
)

var db *pgxpool.Pool

func connectDB(databaseURL string) *pgxpool.Pool {
	pool, err := pgxpool.New(context.Background(), databaseURL)
	if err != nil {
		log.Fatal("Ошибка создания подключения:", err)
	}

	if err := pool.Ping(context.Background()); err != nil {
		log.Println("Предупреждение: нет подключения к PostgreSQL:", err)
	}

	return pool
}
