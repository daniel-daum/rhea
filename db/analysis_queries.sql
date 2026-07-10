-- ============================================================
-- Rhea analytical queries
-- Each query stands alone — paste into Metabase (native question)
-- or Jupyter. All build on v_prices / base tables; line_type
-- filtering is already handled by the views.
-- ============================================================

-- ------------------------------------------------------------
-- 1. TOTAL SPEND
-- ------------------------------------------------------------

-- 1a. All-time grocery spend
SELECT SUM(total) AS total_spend, COUNT(*) AS n_receipts
FROM receipts;

-- 1b. Spend per month (Metabase line chart)
SELECT date_trunc('month', purchase_date)::date AS month,
       SUM(total) AS spend,
       COUNT(*)   AS trips
FROM receipts
GROUP BY 1 ORDER BY 1;

-- 1c. Spend by month AND chain (stacked bar)
SELECT date_trunc('month', purchase_date)::date AS month,
       chain,
       SUM(total) AS spend
FROM receipts
GROUP BY 1, 2 ORDER BY 1, 2;

-- 1d. Spend by category (uses normalized product category)
SELECT COALESCE(product_category, 'unmapped') AS category,
       SUM(price_paid) AS spend,
       COUNT(*)        AS n_purchases
FROM v_prices
GROUP BY 1 ORDER BY spend DESC;

-- ------------------------------------------------------------
-- 2. RETAILER BREAKDOWN
-- ------------------------------------------------------------

-- 2a. Which retailer gets our money
SELECT chain,
       SUM(total)                   AS spend,
       COUNT(*)                     AS trips,
       ROUND(AVG(total), 2)         AS avg_basket,
       MIN(purchase_date)           AS first_trip,
       MAX(purchase_date)           AS last_trip
FROM receipts
GROUP BY chain ORDER BY spend DESC;

-- 2b. Share of wallet over time (100% stacked area in Metabase)
SELECT date_trunc('month', purchase_date)::date AS month,
       chain,
       SUM(total) AS spend
FROM receipts
GROUP BY 1, 2 ORDER BY 1;

-- ------------------------------------------------------------
-- 3. WHAT WE BUY MOST
-- ------------------------------------------------------------

-- 3a. Most frequently purchased products
SELECT product,
       COUNT(*)                    AS times_bought,
       SUM(price_paid)             AS total_spent,
       COUNT(DISTINCT chain)       AS chains_bought_at
FROM v_prices
GROUP BY product
ORDER BY times_bought DESC
LIMIT 30;

-- 3b. Where the money actually goes (by product)
SELECT product,
       SUM(price_paid) AS total_spent,
       COUNT(*)        AS times_bought
FROM v_prices
GROUP BY product
ORDER BY total_spent DESC
LIMIT 30;

-- 3c. Pounds purchased of by-weight staples
SELECT product,
       ROUND(SUM(weight_lbs), 1)          AS total_lbs,
       ROUND(SUM(price_paid), 2)          AS total_spent,
       ROUND(SUM(price_paid) / NULLIF(SUM(weight_lbs), 0), 2) AS blended_price_per_lb
FROM v_prices
WHERE effective_unit = 'lb'
GROUP BY product
ORDER BY total_lbs DESC
LIMIT 20;

-- ------------------------------------------------------------
-- 4. CROSS-RETAILER PRICE COMPARISON (the point of all this)
-- ------------------------------------------------------------

-- 4a. Head-to-head: products bought at 2+ chains, cheapest vs priciest chain
WITH per_chain AS (
    SELECT product, effective_unit, chain,
           AVG(effective_unit_price) AS avg_price,
           COUNT(*)                  AS n
    FROM v_prices
    WHERE effective_unit_price IS NOT NULL
    GROUP BY 1, 2, 3
),
spread AS (
    SELECT product, effective_unit,
           COUNT(*)                                        AS n_chains,
           MIN(avg_price)                                  AS cheapest,
           MAX(avg_price)                                  AS priciest
    FROM per_chain
    GROUP BY 1, 2
    HAVING COUNT(*) >= 2
)
SELECT s.product,
       s.effective_unit,
       cheap.chain                                          AS cheapest_at,
       ROUND(s.cheapest, 2)                                 AS cheapest_price,
       exp.chain                                            AS priciest_at,
       ROUND(s.priciest, 2)                                 AS priciest_price,
       ROUND(100.0 * (s.priciest - s.cheapest) / s.cheapest, 0) AS pct_premium
FROM spread s
JOIN per_chain cheap ON cheap.product = s.product AND cheap.effective_unit = s.effective_unit
                    AND cheap.avg_price = s.cheapest
JOIN per_chain exp   ON exp.product = s.product   AND exp.effective_unit = s.effective_unit
                    AND exp.avg_price = s.priciest
ORDER BY pct_premium DESC;

-- 4b. Single product deep-dive (swap the product name; Metabase: make it a filter variable)
SELECT chain, purchase_date, raw_name,
       effective_unit, effective_unit_price,
       weight_lbs, quantity, price_paid, on_sale
FROM v_prices
WHERE product = 'bananas'   -- or: product LIKE '%yogurt%'
ORDER BY purchase_date;

-- 4c. Which chain "wins" the most products (is cheapest most often)
WITH per_chain AS (
    SELECT product, chain, AVG(effective_unit_price) AS avg_price
    FROM v_prices
    WHERE effective_unit_price IS NOT NULL
    GROUP BY 1, 2
),
ranked AS (
    SELECT product, chain,
           RANK() OVER (PARTITION BY product ORDER BY avg_price) AS rnk,
           COUNT(*) OVER (PARTITION BY product) AS n_chains
    FROM per_chain
)
SELECT chain,
       COUNT(*) AS products_cheapest_at
FROM ranked
WHERE rnk = 1 AND n_chains >= 2
GROUP BY chain
ORDER BY products_cheapest_at DESC;

-- 4d. The organic premium: same product organic vs not, per lb
WITH base AS (
    SELECT REPLACE(product, 'organic ', '') AS base_product,
           is_organic,
           AVG(effective_unit_price)        AS avg_price
    FROM v_prices
    WHERE effective_unit = 'lb' AND effective_unit_price IS NOT NULL
    GROUP BY 1, 2
)
SELECT o.base_product,
       ROUND(c.avg_price, 2)  AS conventional_per_lb,
       ROUND(o.avg_price, 2)  AS organic_per_lb,
       ROUND(100.0 * (o.avg_price - c.avg_price) / c.avg_price, 0) AS organic_premium_pct
FROM base o
JOIN base c ON c.base_product = o.base_product
           AND o.is_organic IS TRUE AND c.is_organic IS FALSE
ORDER BY organic_premium_pct DESC;

-- ------------------------------------------------------------
-- 5. SHOPPING FREQUENCY & HABITS
-- ------------------------------------------------------------

-- 5a. How often we shop (trips per week, overall and by chain)
SELECT chain,
       COUNT(*)                                            AS trips,
       ROUND(COUNT(*)::numeric /
             NULLIF((MAX(purchase_date) - MIN(purchase_date)) / 7.0, 0), 2) AS trips_per_week
FROM receipts
GROUP BY chain ORDER BY trips DESC;

-- 5b. Days between trips (overall cadence)
WITH gaps AS (
    SELECT purchase_date - LAG(purchase_date) OVER (ORDER BY purchase_date) AS gap
    FROM receipts
)
SELECT ROUND(AVG(gap), 1)                 AS avg_days_between_trips,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY gap) AS median_gap,
       MAX(gap)                           AS longest_gap
FROM gaps WHERE gap IS NOT NULL;

-- 5c. Day-of-week habits
SELECT to_char(purchase_date, 'Dy') AS dow,
       COUNT(*)                     AS trips,
       ROUND(AVG(total), 2)         AS avg_basket
FROM receipts
GROUP BY 1, EXTRACT(dow FROM purchase_date)
ORDER BY EXTRACT(dow FROM purchase_date);

-- 5d. Repurchase cadence per product (how often do we rebuy bananas?)
WITH gaps AS (
    SELECT product,
           purchase_date - LAG(purchase_date) OVER (PARTITION BY product ORDER BY purchase_date) AS gap
    FROM v_prices
)
SELECT product,
       COUNT(*) + 1                    AS times_bought,
       ROUND(AVG(gap), 1)              AS avg_days_between
FROM gaps
WHERE gap IS NOT NULL
GROUP BY product
HAVING COUNT(*) >= 4
ORDER BY times_bought DESC
LIMIT 25;

-- ------------------------------------------------------------
-- 6. SALES & DISCOUNTS
-- ------------------------------------------------------------

-- 6a. Sale behavior per chain (are Safeway's sales real?)
SELECT * FROM v_chain_sale_stats ORDER BY pct_lines_on_sale DESC;

-- 6b. Shelf price vs paid price per chain — "costs more but discounts more"?
SELECT chain,
       ROUND(AVG(effective_unit_list_price), 2) AS avg_shelf_unit_price,
       ROUND(AVG(effective_unit_price), 2)      AS avg_paid_unit_price,
       ROUND(100.0 * (AVG(effective_unit_list_price) - AVG(effective_unit_price))
             / NULLIF(AVG(effective_unit_list_price), 0), 1) AS avg_realized_discount_pct
FROM v_prices
WHERE effective_unit_list_price IS NOT NULL
GROUP BY chain ORDER BY avg_shelf_unit_price DESC;

-- 6c. Our best scores (biggest single-line discounts)
SELECT purchase_date, chain, product,
       list_price, price_paid, discount_amount, discount_pct
FROM v_prices
WHERE on_sale
ORDER BY discount_amount DESC
LIMIT 25;

-- 6d. Total saved per month
SELECT date_trunc('month', purchase_date)::date AS month,
       SUM(discount_amount) AS saved,
       SUM(price_paid)      AS spent
FROM v_prices
GROUP BY 1 ORDER BY 1;

-- ------------------------------------------------------------
-- 7. PRICE TRENDS (personal inflation)
-- ------------------------------------------------------------

-- 7a. Price history for one product across chains (line chart, one line per chain)
SELECT purchase_date, chain, effective_unit_price
FROM v_prices
WHERE product = 'bananas' AND effective_unit_price IS NOT NULL
ORDER BY purchase_date;

-- 7b. Personal price index: avg unit price of repeat staples, by quarter
WITH staples AS (
    SELECT product FROM v_prices
    GROUP BY product HAVING COUNT(*) >= 6
)
SELECT date_trunc('quarter', purchase_date)::date AS quarter,
       ROUND(AVG(effective_unit_price), 2)        AS avg_staple_unit_price
FROM v_prices
WHERE product IN (SELECT product FROM staples)
  AND effective_unit_price IS NOT NULL
GROUP BY 1 ORDER BY 1;

-- 7c. Products whose price rose the most (first vs last purchase)
WITH firsts AS (
    SELECT DISTINCT ON (product) product,
           effective_unit_price AS first_price, purchase_date AS first_date
    FROM v_prices WHERE effective_unit_price IS NOT NULL
    ORDER BY product, purchase_date
),
lasts AS (
    SELECT DISTINCT ON (product) product,
           effective_unit_price AS last_price, purchase_date AS last_date
    FROM v_prices WHERE effective_unit_price IS NOT NULL
    ORDER BY product, purchase_date DESC
)
SELECT f.product, f.first_date, f.first_price, l.last_date, l.last_price,
       ROUND(100.0 * (l.last_price - f.first_price) / f.first_price, 0) AS pct_change
FROM firsts f
JOIN lasts l USING (product)
WHERE l.last_date > f.first_date + 60      -- at least ~2 months apart
  AND f.first_price > 0
ORDER BY pct_change DESC
LIMIT 25;

-- ------------------------------------------------------------
-- 8. ODDS & ENDS
-- ------------------------------------------------------------

-- 8a. Biggest single baskets
SELECT purchase_date, chain, total,
       (SELECT COUNT(*) FROM receipt_line_items li WHERE li.receipt_id = r.id) AS n_items
FROM receipts r
ORDER BY total DESC LIMIT 10;

-- 8b. Deposits & fees paid over time (CRV, bag fees)
SELECT date_trunc('month', r.purchase_date)::date AS month,
       li.line_type,
       SUM(li.price_paid) AS amount
FROM receipt_line_items li JOIN receipts r ON r.id = li.receipt_id
WHERE li.line_type IN ('deposit', 'fee')
GROUP BY 1, 2 ORDER BY 1;

-- 8c. Non-grocery spend hiding in grocery runs (Costco effect)
SELECT r.chain, li.raw_name, li.common_name, li.price_paid, r.purchase_date
FROM receipt_line_items li JOIN receipts r ON r.id = li.receipt_id
WHERE li.line_type = 'non_grocery'
ORDER BY li.price_paid DESC;

-- 8d. Products we only ever buy at one chain (loyalty / availability)
SELECT product, MAX(chain) AS only_chain,
       COUNT(*) AS times_bought, SUM(price_paid) AS spent
FROM v_prices
GROUP BY product
HAVING COUNT(DISTINCT chain) = 1 AND COUNT(*) >= 5
ORDER BY spent DESC;

-- 8e. Price volatility: staples with the widest price swings
SELECT product, effective_unit,
       COUNT(*)                             AS n,
       ROUND(MIN(effective_unit_price), 2)  AS min_price,
       ROUND(MAX(effective_unit_price), 2)  AS max_price,
       ROUND(STDDEV(effective_unit_price), 2) AS stddev
FROM v_prices
WHERE effective_unit_price IS NOT NULL
GROUP BY 1, 2
HAVING COUNT(*) >= 5
ORDER BY stddev DESC NULLS LAST
LIMIT 25;

-- 8f. Data quality: receipts whose lines don't reconcile (should be only the 3 damaged scans)
SELECT * FROM v_receipt_qc WHERE ABS(COALESCE(unexplained_diff, 0)) > 0.02;
