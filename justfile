test:
	@go test .

run:
	@dotenvx run -- go run .

build:
	@go build .

migrate-up name:
    dotenvx run -- atlas migrate diff {{name}} --env local

migrate-down:
    dotenvx run -- atlas migrate down --env local

migrate-deploy:
    dotenvx run -- atlas migrate apply --env local
