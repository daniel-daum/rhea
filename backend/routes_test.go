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
	
	t.Run("/health -> returns correct content type header", func(t *testing.T) {
        request := httptest.NewRequest(http.MethodGet, "/health", nil)
        response := httptest.NewRecorder()

        HealthCheck(response, request)

        got := response.Header().Get("Content-Type")
        want := "application/json"
        if got != want {
            t.Errorf("got %q want %q", got, want)
        }
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

func TestReference(t *testing.T) {
    t.Run("/docs -> returns 200", func(t *testing.T) {
        request := httptest.NewRequest(http.MethodGet, "/docs", nil)
        response := httptest.NewRecorder()

        Reference(response, request)

        assertStatus(t, response.Code, http.StatusOK)
    })

    t.Run("/docs -> returns HTML content", func(t *testing.T) {
        request := httptest.NewRequest(http.MethodGet, "/docs", nil)
        response := httptest.NewRecorder()

        Reference(response, request)

        // Check if response contains expected HTML content
        // This might need to be adjusted based on what scalar.ApiReferenceHTML returns
        if len(response.Body.String()) == 0 {
            t.Error("Expected non-empty HTML response")
        }
    })
}
