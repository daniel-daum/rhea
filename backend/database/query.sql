-- users
-- name: CreateUser :one
INSERT INTO users  (first_name, last_name, username, password) VALUES ($1, $2, $3, $4) RETURNING *;

-- name: GetUser :one
SELECT * FROM users WHERE user_id = $1 LIMIT 1;

-- name: DeleteUser :exec
DELETE FROM users WHERE user_id = $1;


-- chains
-- name: CreateChain :one
INSERT INTO chains (name, description) VALUES ($1, $2) RETURNING *;

-- name: GetChain :one
SELECT * FROM chains WHERE chain_id = $1;

-- name: DeleteChain :exec
DELETE FROM chains WHERE chain_id = $1;


-- stores
-- name: CreateStore :one
INSERT INTO stores (chain_id, store_number, street_address, description) VALUES ($1, $2, $3, $4) RETURNING *;

-- name: GetStore :one
SELECT * FROM stores WHERE store_id = $1;

-- name: DeleteStore :exec
DELETE FROM stores WHERE store_id = $1;


-- items
-- name: CreateItem :one
INSERT INTO items (chain_id, item_number, item_name, item_category, item_description) VALUES ($1, $2, $3, $4, $5) RETURNING *;

-- name: GetItem :one
SELECT * FROM items WHERE item_id = $1;

-- name: DeleteItem :exec
DELETE FROM items WHERE item_id = $1;


-- receipts
-- name: Createreceipt :one
INSERT INTO receipts (store_id, receipt_number, transaction_date, final_total) VALUES ($1, $2, $3, $4) RETURNING *;

-- name: Getreceipt :one
SELECT * FROM receipts WHERE receipt_id = $1;

-- name: Deletereceipt :exec
DELETE FROM receipts WHERE receipt_id = $1;


-- groceries
-- name: CreateGrocery :one
INSERT INTO groceries 
    (receipt_id, item_id, quantity, price_per_quantity, weight, price_per_lb, total_price, discount_amount, total_paid) 
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *;

-- name: GetGrocery :one
SELECT * FROM groceries WHERE grocery_id = $1;

-- name: DeleteGrocery :exec
DELETE FROM groceries WHERE grocery_id = $1;