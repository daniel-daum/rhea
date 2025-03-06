package main

import (
	"log/slog"
	"os"

	"github.com/joho/godotenv"
)

const defaultEnv string = "development"
const defaultPort string = "8000"

type Settings struct {
	env  string
	port string
}

func (s Settings) GetEnv() string {
	return s.env
}

func (s Settings) GetPort() string {
	return s.port
}

func getEnvWithDefaults(key string, defaultValue string) string {
	envValue := os.Getenv(key)

	if envValue == "" {
		slog.Info("Env var with key empty or not found. Using default value", "key", key, "default", defaultValue)
		return defaultValue
	}
	return envValue
}

func ServerSettings(testFlag bool) *Settings {
	if !testFlag {
		err := godotenv.Load()

		if err != nil {
			slog.Error("Error loading .env file", "error", err)
		}
	}

	return &Settings{
		env:  getEnvWithDefaults("ENV", defaultEnv),
		port: getEnvWithDefaults("PORT", defaultPort),
	}

}
