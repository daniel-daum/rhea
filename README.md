# Sliding Fishstick
Sliding Fishstick is a project aimed at building a traditional REST API using the Go programming language. This project is designed for practice and learning purposes, and it incorporates various tools and libraries to facilitate development, database management, and environment configuration.

# Architecture
I use net/http for route handling. Atlas for migrations, sqlc for queries, and postgres as my database. No real architecture patterns other than that.

# Running - Natively
To run the Sliding Fishstick application, follow these steps:

1. **Clone the repository:**
    ```sh
    git clone https://github.com/daniel-daum/sliding-fish-stick.git
    cd sliding-fish-stick
    ```

2. **Set up environment variables:**
    Create a `.env` file in the root directory of the project and add the necessary environment variables. You can use the `.env.example` file as a reference.

3. **Install dependencies:**
    Ensure you have all the required tools installed (see the "Required Tools" section below). Then, install Go dependencies:
    ```sh
    go mod tidy
    ```    
    
4. **Run the application:**
    ```sh
    go run main.go
    ```
  
# Running - Docker
To run via docker 

1. **Clone the repository:**
    ```sh
    git clone https://github.com/daniel-daum/sliding-fish-stick.git
    cd sliding-fish-stick
    ```

2. **Run docker compose**
    ```sh
    docker compose up
    ```
    
# Running - Justfile Commands
The project includes a `justfile` to manage tasks and workflows. If you have just installed, here are the available commands and how to use them:

1. **Run Tests:**
    ```sh
    just test
    ```

2. **Run the Application:**
    ```sh
    just run
    ```

3. **Build the Application:**
    ```sh
    just build
    ```

4. **Migrate Database Up:**
    ```sh
    just migrate-up name=<migration_name>
    ```

5. **Migrate Database Down:**
    ```sh
    just migrate-down
    ```

6. **Deploy Migrations:**
    ```sh
    just migrate-deploy
    ```

7. **Clean Database Schema:**
    ```sh
    just migrate-clean
    ```

# Development
There are several tools used in this project:

- **Go**: The primary programming language used for building the API. [golang homepage](https://go.dev)
- **Justfile**: A tool for managing tasks and workflows. [the justfile GitHub page](https://github.com/casey/just)
- **Dotenvx**: A library for managing environment variables. [dotenvx homepage](https://dotenvx.com)
- **Sqlc**: A tool for generating SQL queries from Go code. [the Sqlc Github page](https://github.com/kyleconroy/sqlc)
- **Atlas**: A tool for managing database migrations. [the Atlas GitHub page](https://github.com/ariga/atlas)
- **Scalar**: An API reference generator/alternative to Swagger. [the Scalar GitHub page](https://github.com/scalar/scalar)

