-- Create "chain" table
CREATE TABLE "chain" (
  "id" bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
  "name" text NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  "deleted_at" timestamptz NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "chain_name_key" UNIQUE ("name")
);
-- Create "store" table
CREATE TABLE "store" (
  "id" bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
  "chain_id" bigint NOT NULL,
  "store_number" integer NOT NULL,
  "street_address" text NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  "deleted_at" timestamptz NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "store_store_number_key" UNIQUE ("store_number"),
  CONSTRAINT "store_street_address_key" UNIQUE ("street_address"),
  CONSTRAINT "store_chain_id_fkey" FOREIGN KEY ("chain_id") REFERENCES "chain" ("id") ON UPDATE NO ACTION ON DELETE NO ACTION
);
-- Create "item" table
CREATE TABLE "item" (
  "id" bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
  "chain_id" bigint NOT NULL,
  "store_id" bigint NOT NULL,
  "category" text NOT NULL,
  "code" integer NULL,
  "name" text NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  "deleted_at" timestamptz NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "item_chain_id_fkey" FOREIGN KEY ("chain_id") REFERENCES "chain" ("id") ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT "item_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "store" ("id") ON UPDATE NO ACTION ON DELETE NO ACTION
);
-- Create "receipt" table
CREATE TABLE "receipt" (
  "id" bigint NOT NULL GENERATED ALWAYS AS IDENTITY,
  "store_id" bigint NOT NULL,
  "receipt_number" bigint NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  "deleted_at" timestamptz NULL,
  PRIMARY KEY ("id"),
  CONSTRAINT "receipt_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "store" ("id") ON UPDATE NO ACTION ON DELETE NO ACTION
);
-- Create "purchases" table
CREATE TABLE "purchases" (
  "day" date NOT NULL,
  "chain_id" bigint NOT NULL,
  "store_id" bigint NOT NULL,
  "receipt_id" bigint NOT NULL,
  "item_id" bigint NOT NULL,
  "quantity_units" integer NULL,
  "price_per_unit" numeric(18,7) NULL,
  "weight_pounds" numeric(18,7) NULL,
  "price_per_lb" numeric(18,7) NULL,
  "price" numeric(18,7) NOT NULL,
  "sale" numeric(18,7) NOT NULL,
  "paid" numeric(18,7) NOT NULL,
  "created_at" timestamptz NOT NULL DEFAULT now(),
  "updated_at" timestamptz NOT NULL DEFAULT now(),
  "deleted_at" timestamptz NULL,
  CONSTRAINT "purchases_chain_id_fkey" FOREIGN KEY ("chain_id") REFERENCES "chain" ("id") ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT "purchases_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "item" ("id") ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT "purchases_receipt_id_fkey" FOREIGN KEY ("receipt_id") REFERENCES "receipt" ("id") ON UPDATE NO ACTION ON DELETE NO ACTION,
  CONSTRAINT "purchases_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "store" ("id") ON UPDATE NO ACTION ON DELETE NO ACTION
);
-- Drop "groceries" table
DROP TABLE "groceries";
-- Drop "users" table
DROP TABLE "users";
-- Drop "items" table
DROP TABLE "items";
-- Drop "receipts" table
DROP TABLE "receipts";
-- Drop "stores" table
DROP TABLE "stores";
-- Drop "chains" table
DROP TABLE "chains";
