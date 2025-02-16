package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func assertStatus(t testing.TB, got, want int){
    t.Helper()
    if got != want {
        t.Errorf("did not get correct status, got %d, want %d", got, want)
    }
}
func TestHealthCheck(t *testing.T) {

	t.Run("/health -> returns 200", func(t *testing.T) {

		request, _ := http.NewRequest(http.MethodGet, "/health", nil)
		response := httptest.NewRecorder()

		HealthCheck(response, request)

        assertStatus(t, response.Code, http.StatusOK)
	})

	t.Run("/health -> returns healthy in a json body", func(t *testing.T) {

		request, _ := http.NewRequest(http.MethodGet, "/health", nil)
		response := httptest.NewRecorder()

		HealthCheck(response, request)

        var got HealthResponse
        
        err := json.NewDecoder(response.Body).Decode(&got)
		want := HealthResponse{Status: "healthy"}

        if err != nil {
			t.Fatalf("Unable to parse response from server %q into healthresponse type, '%v'", response.Body, err)
		}

		if got != want {
			t.Errorf("got %q want %q", got, want)
		}

	})
}
