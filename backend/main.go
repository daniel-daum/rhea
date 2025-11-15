package main

import (
	"log/slog"
	"os"
)

func main() {
	// logging
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))

	// Configuration
	settings := ServerSettings()

	// Initialize database
	queries, pool, err := InitDatabase(settings)
	if err != nil {
		slog.Error("Database initialization failed", "error", err)
		os.Exit(1)
	}
	defer pool.Close()

	rhea := Rhea(settings, queries)

	// Start server
	if err := StartServer(rhea); err != nil {
		slog.Error("Server failed", "error", err)
		os.Exit(1)
	}
}
