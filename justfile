test:
	@go test ./internal

run:
	cd internal && dotenvx run -- air

build:
	@go build -C ./internal -o ../rhea

migrate-up name:
    dotenvx run -- atlas migrate diff {{name}} --env local --dir file://internal/database/migrations

migrate-down:
    dotenvx run -- atlas migrate down --env local --dir file://internal/database/migrations

migrate-deploy:
    dotenvx run -- atlas migrate apply --env local --dir file://internal/database/migrations

migrate-clean:
    dotenvx run -- atlas schema clean --env local

generate-sqlc:
    dotenvx run -- sqlc generate