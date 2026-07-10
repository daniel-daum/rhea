-- ============================================================
-- Rhea grocery-receipt analysis schema (v2)
-- Target: self-hosted Postgres. Idempotent: safe to re-run.
-- Run:  psql -d <your_database> -f schema.sql
-- ============================================================

-- ------------------------------------------------------------
-- products: canonical product dimension for cross-store analysis.
-- common_name is the controlled vocabulary you filter on
-- (lowercase, plural where natural: 'bananas', 'yellow onions').
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS products (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    common_name  TEXT NOT NULL UNIQUE,
    category     TEXT,                                   -- normalized: produce, dairy, meat, seafood, bakery, pantry, frozen, beverage, alcohol, snacks, household, other
    is_organic   BOOLEAN NOT NULL DEFAULT FALSE,
    default_unit TEXT CHECK (default_unit IN ('lb','each')),
    notes        TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------
-- receipts: one row per receipt.
-- receipt_key is the natural key (chain_store_date_receiptnumber)
-- and is UNIQUE so baseline + Rhea exports can't double-insert.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS receipts (
    id             UUID PRIMARY KEY,
    receipt_key    TEXT NOT NULL UNIQUE,
    merchant       TEXT NOT NULL,
    chain          TEXT,
    store_number   TEXT,
    store_address  TEXT,
    purchase_date  DATE NOT NULL,
    purchased_at   TIMESTAMPTZ,                          -- full timestamp when the receipt shows a time
    receipt_number TEXT,
    total          NUMERIC(10,2) NOT NULL,
    tax            NUMERIC(10,2),
    payment_method TEXT,
    confirmed      BOOLEAN NOT NULL DEFAULT FALSE,
    source         TEXT NOT NULL DEFAULT 'rhea'
                   CHECK (source IN ('baseline','rhea','manual')),
    source_file    TEXT,
    overall_confidence NUMERIC(3,2),
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_receipts_chain_date ON receipts (chain, purchase_date);

-- ------------------------------------------------------------
-- receipt_line_items: one row per printed line.
-- raw_name      = exactly as printed (never edited)
-- ai_common_name= model suggestion
-- common_name   = canonical name (what you query on); should match products.common_name
-- line_type     = keeps deposits/fees/refunds/non-grocery out of price stats
-- effective_*   = generated columns that normalize per-lb vs per-each pricing
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS receipt_line_items (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    receipt_id     UUID NOT NULL REFERENCES receipts(id) ON DELETE CASCADE,
    line_no        INT  NOT NULL,
    item_code      TEXT,                                 -- UPC / PLU / SKU as printed
    raw_name       TEXT NOT NULL,
    ai_common_name TEXT,
    common_name    TEXT,
    product_id     BIGINT REFERENCES products(id),
    category       TEXT,                                 -- department as printed (PRODUCE, GROCERY, ...)
    line_type      TEXT NOT NULL DEFAULT 'item'
                   CHECK (line_type IN ('item','deposit','fee','refund','discount','non_grocery')),
    quantity       NUMERIC(10,3),                        -- by-unit items
    unit_price     NUMERIC(10,4),
    weight_lbs     NUMERIC(10,4),                        -- by-weight items
    price_per_lb   NUMERIC(10,4),
    list_price     NUMERIC(10,2),                        -- regular shelf price
    price_paid     NUMERIC(10,2),                        -- actual charged after discounts
    item_confidence NUMERIC(3,2),

    -- Normalized comparison columns (the point of this schema):
    effective_unit TEXT GENERATED ALWAYS AS (
        CASE WHEN weight_lbs IS NOT NULL AND weight_lbs > 0 THEN 'lb' ELSE 'each' END
    ) STORED,
    effective_unit_price NUMERIC(12,4) GENERATED ALWAYS AS (
        CASE
            WHEN weight_lbs IS NOT NULL AND weight_lbs > 0 THEN price_paid / weight_lbs
            WHEN quantity   IS NOT NULL AND quantity   > 0 THEN price_paid / quantity
            ELSE price_paid
        END
    ) STORED,
    discount_amount NUMERIC(10,2) GENERATED ALWAYS AS (
        CASE WHEN list_price IS NOT NULL AND price_paid IS NOT NULL
              AND list_price > price_paid
             THEN list_price - price_paid END
    ) STORED,

    UNIQUE (receipt_id, line_no)
);

CREATE INDEX IF NOT EXISTS idx_li_common_name ON receipt_line_items (common_name);
CREATE INDEX IF NOT EXISTS idx_li_product     ON receipt_line_items (product_id);
CREATE INDEX IF NOT EXISTS idx_li_receipt     ON receipt_line_items (receipt_id);

-- ------------------------------------------------------------
-- Analysis views
-- ------------------------------------------------------------

-- Every real grocery purchase, price-normalized. Primary Metabase/Jupyter source.
CREATE OR REPLACE VIEW v_prices AS
SELECT
    r.chain,
    r.store_number,
    r.store_address,
    r.purchase_date,
    COALESCE(li.common_name, li.ai_common_name, li.raw_name) AS product,
    p.is_organic,
    p.category                        AS product_category,
    li.common_name,
    li.raw_name,
    li.category,
    li.item_code,
    li.effective_unit,
    li.effective_unit_price,          -- $/lb or $/each, based on price actually paid
    CASE                              -- same normalization, at regular shelf price
        WHEN li.weight_lbs IS NOT NULL AND li.weight_lbs > 0 THEN li.list_price / li.weight_lbs
        WHEN li.quantity   IS NOT NULL AND li.quantity   > 0 THEN li.list_price / li.quantity
        ELSE li.list_price
    END                               AS effective_unit_list_price,
    li.quantity,
    li.weight_lbs,
    li.list_price,
    li.price_paid,
    (li.discount_amount IS NOT NULL)  AS on_sale,
    li.discount_amount,
    CASE WHEN li.discount_amount IS NOT NULL AND li.list_price > 0
         THEN ROUND(100.0 * li.discount_amount / li.list_price, 1)
    END                               AS discount_pct,
    r.receipt_key,
    li.line_no
FROM receipt_line_items li
JOIN receipts r ON r.id = li.receipt_id
LEFT JOIN products p ON p.id = li.product_id
WHERE li.line_type = 'item';

-- "Are bananas cheaper at Whole Foods or Safeway?"
-- SELECT * FROM v_price_comparison WHERE product LIKE '%banana%';
CREATE OR REPLACE VIEW v_price_comparison AS
SELECT
    product,
    effective_unit,
    chain,
    COUNT(*)                              AS n_purchases,
    ROUND(MIN(effective_unit_price), 2)   AS min_price,
    ROUND(AVG(effective_unit_price), 2)   AS avg_price,
    ROUND(MAX(effective_unit_price), 2)   AS max_price,
    MAX(purchase_date)                    AS last_purchased
FROM v_prices
GROUP BY product, effective_unit, chain;

-- Price history of a product over time, per chain (Metabase line chart).
CREATE OR REPLACE VIEW v_price_history AS
SELECT
    purchase_date,
    chain,
    product,
    effective_unit,
    effective_unit_price,
    on_sale
FROM v_prices
ORDER BY product, purchase_date;

-- "Does Safeway cost more but run more sales?" — sale behavior per chain.
CREATE OR REPLACE VIEW v_chain_sale_stats AS
SELECT
    chain,
    COUNT(*)                                          AS n_lines,
    COUNT(*) FILTER (WHERE on_sale)                   AS n_on_sale,
    ROUND(100.0 * COUNT(*) FILTER (WHERE on_sale) / COUNT(*), 1) AS pct_lines_on_sale,
    ROUND(AVG(discount_pct) FILTER (WHERE on_sale), 1)           AS avg_discount_pct,
    ROUND(SUM(discount_amount), 2)                    AS total_saved,
    ROUND(SUM(price_paid), 2)                         AS total_spent
FROM v_prices
GROUP BY chain;

-- Monthly spend by chain and category (Metabase dashboard).
CREATE OR REPLACE VIEW v_monthly_spend AS
SELECT
    date_trunc('month', r.purchase_date)::date AS month,
    r.chain,
    COALESCE(li.category, 'UNKNOWN')           AS category,
    SUM(li.price_paid)                         AS spend,
    COUNT(DISTINCT r.id)                       AS n_receipts
FROM receipt_line_items li
JOIN receipts r ON r.id = li.receipt_id
WHERE li.line_type IN ('item','non_grocery')
GROUP BY 1, 2, 3;

-- QC: does the sum of line items match the printed receipt total?
CREATE OR REPLACE VIEW v_receipt_qc AS
SELECT
    r.receipt_key,
    r.chain,
    r.purchase_date,
    r.total                             AS printed_total,
    SUM(li.price_paid)                  AS line_item_sum,
    r.total - COALESCE(SUM(li.price_paid), 0) - COALESCE(r.tax, 0) AS unexplained_diff,
    r.source,
    r.source_file
FROM receipts r
LEFT JOIN receipt_line_items li ON li.receipt_id = r.id
GROUP BY r.id
ORDER BY ABS(r.total - COALESCE(SUM(li.price_paid), 0) - COALESCE(r.tax, 0)) DESC;
