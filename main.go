package main

import (
	"log/slog"
	"os"
)

func main() {
	// logging
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))

	// Configuration
	settings := ServerSettings(false)
	server := SlidingFishStick(settings)

	// Start server
	if err := StartServer(server); err != nil {
		slog.Error("Server failed", "error", err)
		os.Exit(1)
	}
}
