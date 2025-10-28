# Rhea
Rhea is a web application consisting of a TypeScript React frontend and a Go REST API backend. This project is just for fun and learning purposes.

# Prerequisites

## Docker Setup (Recommended)
- [Docker](https://www.docker.com/get-started) and Docker Compose

## Native/Local Development Setup
- [Go 1.23+](https://golang.org/dl/)
- [Node.js 18+](https://nodejs.org/) and npm
- [PostgreSQL](https://www.postgresql.org/download/)
- [dotenvx](https://dotenvx.com/docs/install) - Environment variable management
- [Air](https://github.com/air-verse/air) - Go live reload: `go install github.com/air-verse/air@latest`
- [Atlas](https://atlasgo.io/getting-started#installation) - Database migrations
- [sqlc](https://sqlc.dev/) - SQL code generation: `go install github.com/sqlc-dev/sqlc/cmd/sqlc@latest`
- [Just](https://github.com/casey/just) - Command runner (optional, for using justfile)

# Running via Docker

1. **Clone the repository:**
    ```sh
    git clone https://github.com/daniel-daum/rhea.git
    cd rhea
    ```

2. **Run docker compose**
    ```sh
    docker compose up
    ```

# Usage

After running `docker compose up`, the application will be available at:
- **Frontend**: http://localhost:3000 - React web interface for grocery pricing analysis
- **Backend API**: http://localhost:8000 - Go REST API with endpoints at `/api`. For example: `/api/health` and `/api/docs`
    