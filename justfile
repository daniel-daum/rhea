test:
	@go test .

run:
	@dotenvx run -- go run .

build:
	@go build .

migrate name:
    dotenvx run -- atlas migrate diff {{name}} --env local
    
apply:
    dotenvx run -- atlas migrate apply --env local