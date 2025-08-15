# Runs the Go project in development mode
run:
	cd backend && dotenvx run -- air

# Runs the tests for the backend
test:
	cd backend && go test

# Builds the go binary for the backend
build:
	@go build -C ./backend -o ../rhea

# Generates the database migration file in the backend/database/migrations folder (supply <name>)
migrate name:
    cd backend && dotenvx run -- atlas migrate diff {{name}} --env local --dir file://database/migrations

# Applies existing migrations to the database
apply:
    cd backend && dotenvx run -- atlas migrate apply --env local --dir file://database/migrations

# Removes all applied migrations to the development database
destroy:
    cd backend && dotenvx run -- atlas schema clean --env local

# Reads the database/query.sql file and generates typesafe Go code in the database/sqlc folder
generate:
    cd backend && dotenvx run -- sqlc generate
