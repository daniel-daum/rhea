package main

import (
	"log/slog"
	"os"
)

const env string = "SFS_ENV"
const port string = "SFS_PORT"

const defaultEnv string = "local"
const defaultPort string = "8000"

type Settings struct {
	env  string
	port string
}

func (s Settings) Env() string {
	return s.env
}

func (s Settings) Port() string {
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

func ServerSettings() *Settings {
	return &Settings{
		env:  getEnvWithDefaults(env, defaultEnv),
		port: getEnvWithDefaults(port, defaultPort),
	}

}
