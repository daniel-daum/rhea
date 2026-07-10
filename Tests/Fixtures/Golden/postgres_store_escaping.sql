INSERT INTO receipts (id,receipt_key,merchant,chain,store_number,store_address,purchase_date,purchased_at,receipt_number,total,tax,payment_method,confirmed,source,source_file,overall_confidence)
VALUES ('0BADF00D-CAFE-4000-8000-000000000002','o-brien-s_2026-05-01_r-weekly-9','O''''Brien''s Grocery','O''BRIEN''S',NULL,'123 Main St
Apt #4','2026-05-01',NULL,'R-"Weekly"-9',10.00,NULL,NULL,TRUE,'rhea','golden_escaping_receipt.pdf',NULL)
ON CONFLICT (receipt_key) DO UPDATE SET
  merchant=EXCLUDED.merchant,chain=EXCLUDED.chain,store_number=EXCLUDED.store_number,
  store_address=EXCLUDED.store_address,purchase_date=EXCLUDED.purchase_date,purchased_at=EXCLUDED.purchased_at,
  receipt_number=EXCLUDED.receipt_number,total=EXCLUDED.total,tax=EXCLUDED.tax,
  payment_method=EXCLUDED.payment_method,confirmed=EXCLUDED.confirmed,
  source_file=EXCLUDED.source_file,overall_confidence=EXCLUDED.overall_confidence,updated_at=now();
DELETE FROM receipt_line_items WHERE receipt_id=(SELECT id FROM receipts WHERE receipt_key='o-brien-s_2026-05-01_r-weekly-9');INSERT INTO receipt_line_items(receipt_id,line_no,item_code,raw_name,ai_common_name,common_name,category,line_type,quantity,unit_price,weight_lbs,price_per_lb,list_price,price_paid,item_confidence)
VALUES ((SELECT id FROM receipts WHERE receipt_key='o-brien-s_2026-05-01_r-weekly-9'),1,NULL,'Café specialty ☕ "Doorbuster"',NULL,NULL,NULL,'item',1.000,10.0000,NULL,NULL,10.00,10.00,NULL),
((SELECT id FROM receipts WHERE receipt_key='o-brien-s_2026-05-01_r-weekly-9'),2,'5''0\1','C:\Users\test\file.txt',NULL,NULL,NULL,'item',NULL,NULL,NULL,NULL,NULL,NULL,NULL);
