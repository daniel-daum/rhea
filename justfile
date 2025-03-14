test:
	@go test ./internal

run:
	@dotenvx run -- go run ./internal

build:
	@go build -C ./internal -o ../sliding-fish-stick 

migrate-up name:
    dotenvx run -- atlas migrate diff {{name}} --env local --dir file://internal/database/migrations

migrate-down:
    dotenvx run -- atlas migrate down --env local --dir file://internal/database/migrations

migrate-deploy:
    dotenvx run -- atlas migrate apply --env local --dir file://internal/database/migrations

migrate-clean:
    dotenvx run -- atlas schema clean --env local
