package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"github.com/MarceloPetrucio/go-scalar-api-reference"
	database "github.com/daniel-daum/rhea/database/sqlc"
)

type HealthResponse struct {
	Status string `json:"status" example:"healthy"`
}

func ErrorLog(err error, r *http.Request) {
	slog.Error(
		"Error marshalling json response",
		"error", err,
		"method", r.Method,
		"url", r.URL.RequestURI(),
		"agent", r.UserAgent(),
	)
}

type CreateChainRequest struct {
	Chain string `json:"chain"`
}

type CreateChainResponse struct {
	ID     int64  `json:"id"`
	Name   string `json:"name"`
	Status string `json:"status"`
}

func CreateChain(w http.ResponseWriter, r *http.Request, queries *database.Queries) {
	// Parse JSON request body
	var req CreateChainRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		slog.Error("Failed to decode JSON request", "error", err)
		http.Error(w, `{"error":"Invalid JSON"}`, http.StatusBadRequest)
		return
	}

	// Validate and sanitize input
	chainName := strings.TrimSpace(req.Chain)
	if chainName == "" {
		slog.Error("Chain name is empty after trimming")
		http.Error(w, `{"error":"Chain name is required"}`, http.StatusBadRequest)
		return
	}

	if len(chainName) > 255 {
		slog.Error("Chain name too long", "length", len(chainName))
		http.Error(w, `{"error":"Chain name too long (max 255 characters)"}`, http.StatusBadRequest)
		return
	}

	// Create database record
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	chainID, err := queries.CreateChain(ctx, chainName)
	if err != nil {
		slog.Error("Failed to create chain in database", "error", err, "chain_name", chainName)
		http.Error(w, `{"error":"Failed to create chain"}`, http.StatusInternalServerError)
		return
	}

	// Return success response
	response := CreateChainResponse{
		ID:     chainID,
		Name:   chainName,
		Status: "created",
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)

	if err := json.NewEncoder(w).Encode(response); err != nil {
		ErrorLog(err, r)
	}

	slog.Info("Chain created successfully", "id", chainID, "name", chainName)
}

func HealthCheck(w http.ResponseWriter, r *http.Request) {
	healthResponse := HealthResponse{Status: "healthy"}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)

	err := json.NewEncoder(w).Encode(healthResponse)

	if err != nil {
		ErrorLog(err, r)
	}
}

func Reference(w http.ResponseWriter, r *http.Request) {
	htmlContent, err := scalar.ApiReferenceHTML(&scalar.Options{
		SpecURL: "./api/swagger/swagger.yaml",
		CustomOptions: scalar.CustomOptions{
			PageTitle: "Rhea API",
		},
		DarkMode: true,
	})

	if err != nil {
		ErrorLog(err, r)
	}

	fmt.Fprintln(w, htmlContent)
}
