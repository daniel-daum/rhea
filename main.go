package main

import (
	"log/slog"
	"os"
)

func main() {

	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	settings := ServerSettings(false)
	server := SlidingFishStick(settings)

	StartServer(server)
}
