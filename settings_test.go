package main

import (
	"os"
	"testing"
)

func TestGetEnvWithDefaults(t *testing.T) {
	// Test cases struct
	tests := []struct {
		name         string
		key          string
		envValue     string
		defaultValue string
		expected     string
	}{
		{
			name:         "Should return default when env is empty",
			key:          "TEST_ENV1",
			envValue:     "",
			defaultValue: "default1",
			expected:     "default1",
		},
		{
			name:         "Should return env value when set",
			key:          "TEST_ENV2",
			envValue:     "custom_value",
			defaultValue: "default2",
			expected:     "custom_value",
		},
		{
			name:         "Should return default when env is not set",
			key:          "TEST_ENV3",
			envValue:     "",
			defaultValue: "default3",
			expected:     "default3",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Clear environment variable first
			os.Unsetenv(tt.key)

			// Set environment variable if test case requires it
			if tt.envValue != "" {
				os.Setenv(tt.key, tt.envValue)
			}

			// Test the function
			result := getEnvWithDefaults(tt.key, tt.defaultValue)

			// Check result
			if result != tt.expected {
				t.Errorf("getEnvWithDefaults(%s, %s) = %s; want %s",
					tt.key, tt.defaultValue, result, tt.expected)
			}

			// Cleanup
			os.Unsetenv(tt.key)
		})
	}
}

func TestServerSettings(t *testing.T) {
	// Test with test flag true (no .env file loading)
	t.Run("Server Settings with test flag", func(t *testing.T) {
		// Clear environment variables
		os.Unsetenv("ENV")
		os.Unsetenv("PORT")

		// Get settings
		settings := ServerSettings()

		// Check default values
		if settings.Env() != defaultEnv {
			t.Errorf("Expected env to be %s, got %s", defaultEnv, settings.Env())
		}

		if settings.Port() != defaultPort {
			t.Errorf("Expected port to be %s, got %s", defaultPort, settings.Port())
		}
	})

	t.Run("Server Settings with custom env variables", func(t *testing.T) {
		// Set custom environment variables
		customEnv := "production"
		customPort := "3000"

		os.Setenv("ENV", customEnv)
		os.Setenv("PORT", customPort)

		// Get settings
		settings := ServerSettings()

		// Check custom values
		if settings.Env() != customEnv {
			t.Errorf("Expected env to be %s, got %s", customEnv, settings.Env())
		}

		if settings.Port() != customPort {
			t.Errorf("Expected port to be %s, got %s", customPort, settings.Port())
		}

		// Cleanup
		os.Unsetenv("ENV")
		os.Unsetenv("PORT")
	})
}
