-- Receipt 0BADF00D-CAFE-4000-9000-0000000000A1
INSERT INTO receipts (id, receipt_key, merchant, chain, store_number, store_address,
                      purchase_date, purchased_at, receipt_number, total, tax,
                      payment_method, confirmed, source, source_file, overall_confidence)
VALUES ('0BADF00D-CAFE-4000-9000-0000000000A1', 'testmart_4021_2026-03-12_tm-889012', 'TESTMART #4021', 'TESTMART', '4021', '123 Fixture Ave, Sampleton CA',
        '2026-03-12', '2026-03-12T12:04:00Z', 'TM-889012', 9.76, 0.00,
        'Visa ****4477', TRUE, 'rhea', 'testmart_by_weight.pdf', 0.98)
ON CONFLICT (receipt_key) DO UPDATE SET
    merchant = EXCLUDED.merchant, chain = EXCLUDED.chain,
    store_number = EXCLUDED.store_number, store_address = EXCLUDED.store_address,
    purchase_date = EXCLUDED.purchase_date, purchased_at = EXCLUDED.purchased_at,
    receipt_number = EXCLUDED.receipt_number, total = EXCLUDED.total, tax = EXCLUDED.tax,
    payment_method = EXCLUDED.payment_method, confirmed = EXCLUDED.confirmed,
    source_file = EXCLUDED.source_file, overall_confidence = EXCLUDED.overall_confidence,
    updated_at = now();
DELETE FROM receipt_line_items WHERE receipt_id = (SELECT id FROM receipts WHERE receipt_key = 'testmart_4021_2026-03-12_tm-889012');
INSERT INTO receipt_line_items (receipt_id, line_no, item_code, raw_name, ai_common_name, common_name, category, line_type, quantity, unit_price, weight_lbs, price_per_lb, list_price, price_paid, item_confidence)
VALUES
    ((SELECT id FROM receipts WHERE receipt_key = 'testmart_4021_2026-03-12_tm-889012'), 1, NULL, 'ORGANIC BANANAS', 'organic bananas', 'user reviewed name', 'PRODUCE', 'item', NULL, NULL, 2.4400, 0.7900, 1.93, 1.93, 0.98),
    ((SELECT id FROM receipts WHERE receipt_key = 'testmart_4021_2026-03-12_tm-889012'), 2, NULL, 'ROMA TOMATOES', 'roma tomatoes', NULL, 'PRODUCE', 'item', NULL, NULL, 0.8300, 1.9900, 1.65, 1.65, 0.97),
    ((SELECT id FROM receipts WHERE receipt_key = 'testmart_4021_2026-03-12_tm-889012'), 3, NULL, 'BONELESS CHKN BRST', 'boneless chicken breast', NULL, 'MEAT', 'item', NULL, NULL, 1.5500, 3.9900, 6.18, 6.18, 0.96);