package main

import (
	"context"
	"log/slog"
	"time"

	database "github.com/daniel-daum/rhea/database/sqlc"
	"github.com/jackc/pgx/v5/pgxpool"
)

// InitDatabase creates a new database connection pool and returns a sqlc Queries instance
func InitDatabase(settings *Settings) (*database.Queries, *pgxpool.Pool, error) {
	// Create a context with timeout for connection
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Create connection pool
	pool, err := pgxpool.New(ctx, settings.DBUrl())
	if err != nil {
		slog.Error("Failed to create database connection pool", "error", err)
		return nil, nil, err
	}

	// Test the connection with ping
	if err := pool.Ping(ctx); err != nil {
		slog.Error("Failed to ping database", "error", err)
		pool.Close()
		return nil, nil, err
	}

	// Additional validation: try to execute a simple query
	conn, err := pool.Acquire(ctx)
	if err != nil {
		slog.Error("Failed to acquire database connection", "error", err)
		pool.Close()
		return nil, nil, err
	}
	defer conn.Release()

	var result int
	err = conn.QueryRow(ctx, "SELECT 1").Scan(&result)
	if err != nil {
		slog.Error("Failed to execute test query on database", "error", err)
		pool.Close()
		return nil, nil, err
	}

	if result != 1 {
		slog.Error("Database test query returned unexpected result", "expected", 1, "got", result)
		pool.Close()
		return nil, nil, err
	}

	slog.Info("Database connection established successfully")

	// Create sqlc queries instance
	queries := database.New(pool)

	return queries, pool, nil
}
