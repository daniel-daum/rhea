#!/usr/bin/env bash
# Load the bulk-extracted baseline dataset into Postgres.
# Usage:  ./load_baseline.sh "postgres://user:pass@host:5432/dbname"
# Expects db/baseline/{products.csv,receipts.csv,line_items.csv} (produced by the
# bulk extraction) and applies schema.sql first. Idempotent: re-running upserts.
set -euo pipefail

DB_URL="${1:?usage: ./load_baseline.sh <postgres-connection-url>}"
DIR="$(cd "$(dirname "$0")" && pwd)"

psql "$DB_URL" -v ON_ERROR_STOP=1 -f "$DIR/schema.sql"

psql "$DB_URL" -v ON_ERROR_STOP=1 <<SQL
BEGIN;

-- ---------- staging ----------
CREATE TEMP TABLE stg_products (LIKE products INCLUDING DEFAULTS EXCLUDING IDENTITY EXCLUDING CONSTRAINTS);
ALTER TABLE stg_products DROP COLUMN id;
\copy stg_products (common_name, category, is_organic, default_unit, notes, created_at) FROM '$DIR/baseline/products.csv' WITH (FORMAT csv, HEADER true)

CREATE TEMP TABLE stg_receipts (LIKE receipts INCLUDING DEFAULTS EXCLUDING CONSTRAINTS);
\copy stg_receipts (id, receipt_key, merchant, chain, store_number, store_address, purchase_date, purchased_at, receipt_number, total, tax, payment_method, confirmed, source, source_file, overall_confidence) FROM '$DIR/baseline/receipts.csv' WITH (FORMAT csv, HEADER true)

CREATE TEMP TABLE stg_line_items (
    receipt_key     TEXT,
    line_no         INT,
    item_code       TEXT,
    raw_name        TEXT,
    ai_common_name  TEXT,
    common_name     TEXT,
    category        TEXT,
    line_type       TEXT,
    quantity        NUMERIC,
    unit_price      NUMERIC,
    weight_lbs      NUMERIC,
    price_per_lb    NUMERIC,
    list_price      NUMERIC,
    price_paid      NUMERIC,
    item_confidence NUMERIC
);
\copy stg_line_items FROM '$DIR/baseline/line_items.csv' WITH (FORMAT csv, HEADER true)

-- ---------- upsert products ----------
INSERT INTO products (common_name, category, is_organic, default_unit, notes)
SELECT common_name, category, COALESCE(is_organic, FALSE), default_unit, notes
FROM stg_products
ON CONFLICT (common_name) DO UPDATE SET
    category = EXCLUDED.category,
    is_organic = EXCLUDED.is_organic,
    default_unit = EXCLUDED.default_unit;

-- ---------- upsert receipts (natural key wins) ----------
INSERT INTO receipts (id, receipt_key, merchant, chain, store_number, store_address,
                      purchase_date, purchased_at, receipt_number, total, tax,
                      payment_method, confirmed, source, source_file, overall_confidence)
SELECT id, receipt_key, merchant, chain, store_number, store_address,
       purchase_date, purchased_at, receipt_number, total, tax,
       payment_method, confirmed, source, source_file, overall_confidence
FROM stg_receipts
ON CONFLICT (receipt_key) DO UPDATE SET
    merchant = EXCLUDED.merchant, chain = EXCLUDED.chain,
    store_number = EXCLUDED.store_number, store_address = EXCLUDED.store_address,
    purchase_date = EXCLUDED.purchase_date, purchased_at = EXCLUDED.purchased_at,
    receipt_number = EXCLUDED.receipt_number, total = EXCLUDED.total,
    tax = EXCLUDED.tax, payment_method = EXCLUDED.payment_method,
    confirmed = EXCLUDED.confirmed, source = EXCLUDED.source,
    source_file = EXCLUDED.source_file,
    overall_confidence = EXCLUDED.overall_confidence,
    updated_at = now();

-- ---------- replace line items per receipt ----------
DELETE FROM receipt_line_items
WHERE receipt_id IN (SELECT r.id FROM receipts r JOIN stg_line_items s ON s.receipt_key = r.receipt_key);

INSERT INTO receipt_line_items (receipt_id, line_no, item_code, raw_name, ai_common_name,
                                common_name, product_id, category, line_type, quantity,
                                unit_price, weight_lbs, price_per_lb, list_price,
                                price_paid, item_confidence)
SELECT r.id, s.line_no, s.item_code, s.raw_name, s.ai_common_name,
       s.common_name, p.id, s.category, COALESCE(s.line_type, 'item'), s.quantity,
       s.unit_price, s.weight_lbs, s.price_per_lb, s.list_price,
       s.price_paid, s.item_confidence
FROM stg_line_items s
JOIN receipts r ON r.receipt_key = s.receipt_key
LEFT JOIN products p ON p.common_name = s.common_name;

COMMIT;

-- ---------- QC report ----------
SELECT COUNT(*) AS receipts FROM receipts;
SELECT COUNT(*) AS line_items FROM receipt_line_items;
SELECT * FROM v_receipt_qc WHERE ABS(COALESCE(unexplained_diff,0)) > 0.02 LIMIT 20;
SQL

echo "Done."
