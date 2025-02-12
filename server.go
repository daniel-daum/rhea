package main

import (
	"log/slog"
	"net/http"
)

func slidingFishstick() {
	router := http.NewServeMux()

	router.HandleFunc("GET /health", HealthCheck)

	server := &http.Server{
		Addr:    ":8000",
		Handler: router,
	}

	slog.Info("starting server")
	
	err := server.ListenAndServe()

	if err != nil {
		slog.Error("Error starting server")
	}
}
