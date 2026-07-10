-- Receipt 0BADF00D-CAFE-4000-9000-0000000000A3
INSERT INTO receipts (id, receipt_key, merchant, chain, store_number, store_address,
                      purchase_date, purchased_at, receipt_number, total, tax,
                      payment_method, confirmed, source, source_file, overall_confidence)
VALUES ('0BADF00D-CAFE-4000-9000-0000000000A3', 'testmart_4021_2026-03-16_tm-889305', 'TESTMART #4021', 'TESTMART', '4021', '123 Fixture Ave, Sampleton CA',
        '2026-03-16', '2026-03-16T09:12:00Z', 'TM-889305', 14.27, 0.00,
        'Debit ****1188', TRUE, 'rhea', 'testmart_discounts.pdf', 0.96)
ON CONFLICT (receipt_key) DO UPDATE SET
    merchant = EXCLUDED.merchant, chain = EXCLUDED.chain,
    store_number = EXCLUDED.store_number, store_address = EXCLUDED.store_address,
    purchase_date = EXCLUDED.purchase_date, purchased_at = EXCLUDED.purchased_at,
    receipt_number = EXCLUDED.receipt_number, total = EXCLUDED.total, tax = EXCLUDED.tax,
    payment_method = EXCLUDED.payment_method, confirmed = EXCLUDED.confirmed,
    source_file = EXCLUDED.source_file, overall_confidence = EXCLUDED.overall_confidence,
    updated_at = now();
DELETE FROM receipt_line_items WHERE receipt_id = (SELECT id FROM receipts WHERE receipt_key = 'testmart_4021_2026-03-16_tm-889305');
INSERT INTO receipt_line_items (receipt_id, line_no, item_code, raw_name, ai_common_name, common_name, category, line_type, quantity, unit_price, weight_lbs, price_per_lb, list_price, price_paid, item_confidence)
VALUES
    ((SELECT id FROM receipts WHERE receipt_key = 'testmart_4021_2026-03-16_tm-889305'), 1, '41000000123', 'TM ROASTED COFFEE 12OZ', 'roasted coffee', 'user reviewed name', 'GROCERY', 'item', 1.000, 6.9900, NULL, NULL, 8.99, 6.99, 0.96),
    ((SELECT id FROM receipts WHERE receipt_key = 'testmart_4021_2026-03-16_tm-889305'), 2, NULL, 'TM PEANUT BUTTER', 'peanut butter', NULL, 'GROCERY', 'item', 1.000, 3.9900, NULL, NULL, 4.49, 3.99, 0.96),
    ((SELECT id FROM receipts WHERE receipt_key = 'testmart_4021_2026-03-16_tm-889305'), 3, NULL, 'TM PASTA SAUCE', 'pasta sauce', NULL, 'GROCERY', 'item', 1.000, 3.2900, NULL, NULL, 3.29, 3.29, 0.97);