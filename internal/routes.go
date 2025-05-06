package main

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"

	"github.com/MarceloPetrucio/go-scalar-api-reference"
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
		SpecURL: "../docs/swagger.yaml",
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
