-- Receipt 0BADF00D-CAFE-4000-9000-0000000000A2
INSERT INTO receipts (id, receipt_key, merchant, chain, store_number, store_address,
                      purchase_date, purchased_at, receipt_number, total, tax,
                      payment_method, confirmed, source, source_file, overall_confidence)
VALUES ('0BADF00D-CAFE-4000-9000-0000000000A2', 'testmart_4021_2026-03-14_tm-889201', 'TESTMART #4021', 'TESTMART', '4021', '123 Fixture Ave, Sampleton CA',
        '2026-03-14', '2026-03-14T17:41:00Z', 'TM-889201', 11.65, 0.86,
        'Mastercard ****9021', TRUE, 'rhea', 'testmart_multibuy.pdf', 0.97)
ON CONFLICT (receipt_key) DO UPDATE SET
    merchant = EXCLUDED.merchant, chain = EXCLUDED.chain,
    store_number = EXCLUDED.store_number, store_address = EXCLUDED.store_address,
    purchase_date = EXCLUDED.purchase_date, purchased_at = EXCLUDED.purchased_at,
    receipt_number = EXCLUDED.receipt_number, total = EXCLUDED.total, tax = EXCLUDED.tax,
    payment_method = EXCLUDED.payment_method, confirmed = EXCLUDED.confirmed,
    source_file = EXCLUDED.source_file, overall_confidence = EXCLUDED.overall_confidence,
    updated_at = now();
DELETE FROM receipt_line_items WHERE receipt_id = (SELECT id FROM receipts WHERE receipt_key = 'testmart_4021_2026-03-14_tm-889201');
INSERT INTO receipt_line_items (receipt_id, line_no, item_code, raw_name, ai_common_name, common_name, category, line_type, quantity, unit_price, weight_lbs, price_per_lb, list_price, price_paid, item_confidence)
VALUES
    ((SELECT id FROM receipts WHERE receipt_key = 'testmart_4021_2026-03-14_tm-889201'), 1, NULL, 'TM COLA 2L', 'cola', 'user reviewed name', 'GROCERY', 'item', 3.000, 1.5000, NULL, NULL, 4.50, 4.50, 0.97),
    ((SELECT id FROM receipts WHERE receipt_key = 'testmart_4021_2026-03-14_tm-889201'), 2, NULL, 'TM CHIPS PARTY SIZE', 'chips', NULL, 'GROCERY', 'item', 2.000, 2.5000, NULL, NULL, 5.00, 5.00, 0.97),
    ((SELECT id FROM receipts WHERE receipt_key = 'testmart_4021_2026-03-14_tm-889201'), 3, NULL, 'TM SPARKLING WATER', 'sparkling water', NULL, 'GROCERY', 'item', 1.000, 1.2900, NULL, NULL, 1.29, 1.29, 0.97);