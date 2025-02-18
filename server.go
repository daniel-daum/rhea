package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/joho/godotenv"
)

type Settings struct {
	env  string
	port string
}

type responseWriter struct {
	http.ResponseWriter
	status int
}

func SetSettings() *Settings {
	slog.Info("Reading environment variables")

	if os.Getenv("SLIDING_FISHSTICK_ENV") != "PRODUCTION" {
		err := godotenv.Load()
		if err != nil {
			slog.Error("Error loading .env file", slog.Any("error", err))
		}
	}
	env := os.Getenv("SLIDING_FISHSTICK_ENV")
	port := os.Getenv("SLIDING_FISHSTICK_PORT")

	if env == "" {
		env = "DEVELOPMENT"
		slog.Warn("SLIDING_FISHSTICK_ENV env var is empty, using default", slog.String("env", env))
	}

	if port == "" {
		port = "8000"
		slog.Warn("SLIDING_FISHSTICK_PORT env var is empty, using default", slog.String("port", port))
	}

	settings := Settings{
		env:  env,
		port: port,
	}

	return &settings
}

func wrapResponseWriter(w http.ResponseWriter) *responseWriter {
	return &responseWriter{ResponseWriter: w}
}

func (rw *responseWriter) Status() int {
	return rw.status
}

// LoggingMiddleware logs the incoming HTTP request & its duration.
func LoggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {

		start := time.Now()
		wrapped := wrapResponseWriter(w)

		next.ServeHTTP(wrapped, r)

		slog.Info("Request",
			"method", r.Method,
			"path", r.URL.EscapedPath(),
			"status", wrapped.status,
			"duration", time.Since(start))

	})
}

func SlidingFishStick(settings *Settings) *http.Server {

	router := http.NewServeMux()

	// Add routes here
	router.HandleFunc("GET /api/health", HealthCheck)
	router.HandleFunc("GET /api/docs", Reference)

	// Middleware
	finalRouter := LoggingMiddleware(router)

	server := &http.Server{
		Addr:    ":" + settings.port,
		Handler: finalRouter,
	}

	return server
}

func StartServer(settings Settings) error {

	// When this context is canceled, we will gracefully stop the server.
	ctx, cancel := signal.NotifyContext(context.Background(), syscall.SIGHUP, syscall.SIGINT, syscall.SIGTERM, syscall.SIGQUIT)
	defer cancel()

	// When the server is stopped *not by that context*, but by any other problems, it will return its error via this.
	serr := make(chan error, 1)

	// Start the server and collect its error return.

	slog.Info("Starting Sliding Fishstick server", "port", settings.port, "env", settings.env)
	server := SlidingFishStick(&settings)

	go func() { serr <- server.ListenAndServe() }()

	// Wait for either the server to fail, or the context to end.
	var err error
	select {
	case err = <-serr:
	case <-ctx.Done():
	}

	// Make a best effort to shut down the server cleanly. We don’t
	// need to collect the server’s error if we didn’t already;
	// Shutdown will let us know (unless something worse happens, in
	// which case it will tell us that).
	sdctx, sdcancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer sdcancel()
	// Cleanup start:
	slog.Info("Stopping Sliding Fishstick server")

	// cleanup end:
	return errors.Join(err, server.Shutdown(sdctx))
}
