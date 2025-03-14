-- name: CreateUser :one
INSERT INTO users 
    (id, first_name, last_name, username, email, password)
VALUES 
    ($1, $2, $3, $4, $5, $6) 
RETURNING *;

-- name: GetUser :one
SELECT * FROM users WHERE id = $1 LIMIT 1;

-- name: DeleteUser :exec
DELETE FROM users WHERE id = $1;

