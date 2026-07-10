-- Receipt 0BADF00D-CAFE-4000-8000-000000000001
INSERT INTO receipts (id, receipt_key, merchant, chain, store_number, store_address,
                      purchase_date, purchased_at, receipt_number, total, tax,
                      payment_method, confirmed, source, source_file, overall_confidence)
VALUES ('0BADF00D-CAFE-4000-8000-000000000001', 'trader-joe-s_042_2026-03-14_r-1001', 'Trader Joe''s #42', 'TRADER JOE''S', '042', '123 Main St, Springfield',
        '2026-03-14', '2026-03-14T08:30:00Z', 'R-1001', 42.37, 3.12,
        'VISA •••• 4242', TRUE, 'rhea', 'golden_full_receipt.pdf', 0.87)
ON CONFLICT (receipt_key) DO UPDATE SET
    merchant = EXCLUDED.merchant, chain = EXCLUDED.chain,
    store_number = EXCLUDED.store_number, store_address = EXCLUDED.store_address,
    purchase_date = EXCLUDED.purchase_date, purchased_at = EXCLUDED.purchased_at,
    receipt_number = EXCLUDED.receipt_number, total = EXCLUDED.total, tax = EXCLUDED.tax,
    payment_method = EXCLUDED.payment_method, confirmed = EXCLUDED.confirmed,
    source_file = EXCLUDED.source_file, overall_confidence = EXCLUDED.overall_confidence,
    updated_at = now();
DELETE FROM receipt_line_items WHERE receipt_id = (SELECT id FROM receipts WHERE receipt_key = 'trader-joe-s_042_2026-03-14_r-1001');
INSERT INTO receipt_line_items (receipt_id, line_no, item_code, raw_name, ai_common_name, common_name, category, line_type, quantity, unit_price, weight_lbs, price_per_lb, list_price, price_paid, item_confidence)
VALUES
    ((SELECT id FROM receipts WHERE receipt_key = 'trader-joe-s_042_2026-03-14_r-1001'), 1, '012345678905', 'O''Brien''s Chips', 'potato chips', NULL, 'GROCERY', 'item', 2.000, 3.5000, NULL, NULL, 7.00, 7.00, 0.95),
    ((SELECT id FROM receipts WHERE receipt_key = 'trader-joe-s_042_2026-03-14_r-1001'), 2, NULL, 'Bananas', NULL, 'bananas', NULL, 'item', NULL, NULL, 1.2500, 2.0000, NULL, 2.50, NULL),
    ((SELECT id FROM receipts WHERE receipt_key = 'trader-joe-s_042_2026-03-14_r-1001'), 3, NULL, 'Plain Item', NULL, NULL, NULL, 'item', NULL, NULL, NULL, NULL, NULL, NULL, NULL),
    ((SELECT id FROM receipts WHERE receipt_key = 'trader-joe-s_042_2026-03-14_r-1001'), 4, NULL, 'CRV Deposit', NULL, NULL, NULL, 'deposit', NULL, NULL, NULL, NULL, NULL, 0.05, NULL);
