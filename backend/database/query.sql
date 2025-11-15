-- chain
-- name: CreateChain :one
INSERT INTO chain (name) VALUES ($1) RETURNING id;

-- name: GetChain :one
SELECT * FROM chain WHERE id = $1;

-- name: DeleteChain :exec
DELETE FROM chain WHERE id = $1;

-- store
-- name: CreateStore :one
INSERT INTO store (chain_id, store_number, street_address) VALUES ($1, $2, $3) RETURNING id;

-- name: GetStore :one
SELECT * FROM store WHERE id = $1;

-- name: DeleteStore :exec
DELETE FROM store WHERE id = $1;

-- receipt
-- name: CreateReceipt :one
INSERT INTO receipt (id, receipt_number) VALUES ($1, $2) RETURNING id;

-- name: GetReceipt :one
SELECT * FROM receipt WHERE id = $1;

-- name: DeleteReceipt :exec
DELETE FROM receipt WHERE id = $1;

-- item
-- name: CreateItem :one
INSERT INTO item (chain_id, store_id, category, code, name) VALUES ($1, $2, $3, $4, $5) returning id;

-- name: GetItem :one
SELECT * FROM item WHERE id = $1;

-- name: DeleteItem :exec
DELETE FROM item WHERE id = $1;

-- purchases
-- name: CreatePurchase :one
INSERT INTO purchases 
    (day, chain_id, store_id, receipt_id, item_id, quantity_units, price_per_unit, weight_pounds, price_per_lb, price, sale, paid) 
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12) RETURNING day;


