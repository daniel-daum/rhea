-- Receipt 0BADF00D-CAFE-4000-8000-000000000003
INSERT INTO receipts (id, receipt_key, merchant, chain, store_number, store_address,
                      purchase_date, purchased_at, receipt_number, total, tax,
                      payment_method, confirmed, source, source_file, overall_confidence)
VALUES ('0BADF00D-CAFE-4000-8000-000000000003', 'minimal-mart_2026-01-02_r-1', 'Minimal Mart', 'MINIMAL MART', NULL, NULL,
        '2026-01-02', NULL, 'R-1', 5.00, NULL,
        NULL, TRUE, 'rhea', 'golden_minimal_receipt.pdf', NULL)
ON CONFLICT (receipt_key) DO UPDATE SET
    merchant = EXCLUDED.merchant, chain = EXCLUDED.chain,
    store_number = EXCLUDED.store_number, store_address = EXCLUDED.store_address,
    purchase_date = EXCLUDED.purchase_date, purchased_at = EXCLUDED.purchased_at,
    receipt_number = EXCLUDED.receipt_number, total = EXCLUDED.total, tax = EXCLUDED.tax,
    payment_method = EXCLUDED.payment_method, confirmed = EXCLUDED.confirmed,
    source_file = EXCLUDED.source_file, overall_confidence = EXCLUDED.overall_confidence,
    updated_at = now();
DELETE FROM receipt_line_items WHERE receipt_id = (SELECT id FROM receipts WHERE receipt_key = 'minimal-mart_2026-01-02_r-1');
INSERT INTO receipt_line_items (receipt_id, line_no, item_code, raw_name, ai_common_name, common_name, category, line_type, quantity, unit_price, weight_lbs, price_per_lb, list_price, price_paid, item_confidence)
VALUES
    ((SELECT id FROM receipts WHERE receipt_key = 'minimal-mart_2026-01-02_r-1'), 1, NULL, 'Plain Item', NULL, NULL, NULL, 'item', NULL, NULL, NULL, NULL, NULL, NULL, NULL);
