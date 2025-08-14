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
	rhea := Rhea(settings)

	// Start server
	if err := StartServer(rhea); err != nil {
		slog.Error("Server failed", "error", err)
		os.Exit(1)
	}
}
