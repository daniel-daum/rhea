-- Receipt 0BADF00D-CAFE-4000-9000-0000000000A4
INSERT INTO receipts (id, receipt_key, merchant, chain, store_number, store_address,
                      purchase_date, purchased_at, receipt_number, total, tax,
                      payment_method, confirmed, source, source_file, overall_confidence)
VALUES ('0BADF00D-CAFE-4000-9000-0000000000A4', 'testmart_4021_2026-03-18_tm-889417', 'TESTMART #4021', 'TESTMART', '4021', '123 Fixture Ave, Sampleton CA',
        '2026-03-18', '2026-03-18T14:37:00Z', 'TM-889417', 9.79, 0.00,
        'Cash', TRUE, 'rhea', 'testmart_deposits_refund.pdf', 0.95)
ON CONFLICT (receipt_key) DO UPDATE SET
    merchant = EXCLUDED.merchant, chain = EXCLUDED.chain,
    store_number = EXCLUDED.store_number, store_address = EXCLUDED.store_address,
    purchase_date = EXCLUDED.purchase_date, purchased_at = EXCLUDED.purchased_at,
    receipt_number = EXCLUDED.receipt_number, total = EXCLUDED.total, tax = EXCLUDED.tax,
    payment_method = EXCLUDED.payment_method, confirmed = EXCLUDED.confirmed,
    source_file = EXCLUDED.source_file, overall_confidence = EXCLUDED.overall_confidence,
    updated_at = now();
DELETE FROM receipt_line_items WHERE receipt_id = (SELECT id FROM receipts WHERE receipt_key = 'testmart_4021_2026-03-18_tm-889417');
INSERT INTO receipt_line_items (receipt_id, line_no, item_code, raw_name, ai_common_name, common_name, category, line_type, quantity, unit_price, weight_lbs, price_per_lb, list_price, price_paid, item_confidence)
VALUES
    ((SELECT id FROM receipts WHERE receipt_key = 'testmart_4021_2026-03-18_tm-889417'), 1, NULL, 'TM SPARKLING CIDER 6PK', 'sparkling cider', 'user reviewed name', 'GROCERY', 'item', 1.000, 6.9900, NULL, NULL, 6.99, 6.99, 0.96),
    ((SELECT id FROM receipts WHERE receipt_key = 'testmart_4021_2026-03-18_tm-889417'), 2, NULL, 'CRV DEPOSIT', 'crv deposit', NULL, 'GROCERY', 'deposit', 1.000, 0.3000, NULL, NULL, 0.30, 0.30, 0.95),
    ((SELECT id FROM receipts WHERE receipt_key = 'testmart_4021_2026-03-18_tm-889417'), 3, NULL, 'TM ROOT BEER 6PK', 'root beer', NULL, 'GROCERY', 'item', 1.000, 5.4900, NULL, NULL, 5.49, 5.49, 0.96),
    ((SELECT id FROM receipts WHERE receipt_key = 'testmart_4021_2026-03-18_tm-889417'), 4, NULL, 'CRV DEPOSIT', 'crv deposit', NULL, 'GROCERY', 'deposit', 1.000, 0.3000, NULL, NULL, 0.30, 0.30, 0.95),
    ((SELECT id FROM receipts WHERE receipt_key = 'testmart_4021_2026-03-18_tm-889417'), 5, NULL, 'VOID - TM BAGGED ICE', 'bagged ice', NULL, 'GROCERY', 'refund', 1.000, -2.9900, NULL, NULL, -2.99, -2.99, 0.90),
    ((SELECT id FROM receipts WHERE receipt_key = 'testmart_4021_2026-03-18_tm-889417'), 6, NULL, 'BAG FEE', 'bag fee', NULL, 'GROCERY', 'fee', 2.000, 0.1000, NULL, NULL, 0.20, 0.20, 0.95);