package main

import (
	"context"
	"errors"
	"log/slog"
	"net/http"
	"os/signal"
	"syscall"
	"time"
)

type responseWriter struct {
	http.ResponseWriter
	status int
}

func wrapResponseWriter(w http.ResponseWriter) *responseWriter {
	return &responseWriter{ResponseWriter: w}
}

func (rw *responseWriter) Status() int {
	return rw.status
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.status = code
	rw.ResponseWriter.WriteHeader(code)
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

func Rhea(settings *Settings) *http.Server {

	router := http.NewServeMux()

	// Add routes here
	router.HandleFunc("POST /api/chain", CreateChain)
	// 
	router.HandleFunc("GET /api/health", HealthCheck)
	router.HandleFunc("GET /api/docs", Reference)

	// Middleware
	finalRouter := LoggingMiddleware(router)
	slog.Info("Starting Rhea listener", "port", settings.Port(), "env", settings.Env())

	server := &http.Server{
		Addr:    ":" + settings.Port(),
		Handler: finalRouter,
	}

	return server
}

func StartServer(server *http.Server) error {

	// When this context is canceled, we will gracefully stop the server.
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGHUP, syscall.SIGINT, syscall.SIGTERM, syscall.SIGQUIT)
	defer stop()

	// Channel for server errors
	serverError := make(chan error, 1)

	// Start server in goroutine
	go func() {
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			serverError <- err
		}
	}()

	// Wait for shutdown signal or server error
	var err error
	select {
	case err = <-serverError:
		slog.Error("Server error", "error", err)
	case <-ctx.Done():
		slog.Info("Shutdown signal received")
	}

	// Graceful shutdown
	shutdownCtx, cancelShutdown := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancelShutdown()

	slog.Info("Initiating graceful shutdown")

	if shutdownErr := server.Shutdown(shutdownCtx); shutdownErr != nil {
		slog.Error("Server shutdown error", "error", shutdownErr)
		return errors.Join(err, shutdownErr)
	}

	// Check if shutdown completed before timeout
	select {
	case <-shutdownCtx.Done():
		if shutdownCtx.Err() == context.DeadlineExceeded {
			slog.Error("Server shutdown timed out")
			return errors.Join(err, context.DeadlineExceeded)
		}
	default:
		slog.Info("Server shutdown completed successfully")
	}

	return err
}
