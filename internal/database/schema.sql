CREATE TABLE users (
    user_id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    username TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT (now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT (now()),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE chains (
    chain_id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    name TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT (now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT (now()),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE stores (
    store_id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    chain_id BIGINT NOT NULL REFERENCES chains(chain_id),
    store_number INTEGER NOT NULL,
    street_address TEXT NOT NULL,
    description TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT (now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT (now()),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE items (
    item_id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    chain_id BIGINT NOT NULL REFERENCES chains(chain_id),
    item_number INTEGER NOT NULL,
    item_name TEXT NOT NULL,
    item_category TEXT,
    item_description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT (now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT (now()),
    deleted_at TIMESTAMPTZ 
);

CREATE TABLE reciepts (
    reciept_id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    store_id BIGINT NOT NULL REFERENCES stores(store_id),
    reciept_number BIGINT NOT NULL,
    transaction_date TIMESTAMPTZ NOT NULL,
    final_total NUMERIC(18,7) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT (now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT (now()),
    deleted_at TIMESTAMPTZ  
);

CREATE TABLE groceries (
    grocery_id uuid UNIQUE NOT NULL PRIMARY KEY,
    reciept_id BIGINT NOT NULL REFERENCES reciepts(reciept_id),
    item_id BIGINT NOT NULL REFERENCES items(item_id),
    quantity INTEGER,
    price_per_quantity NUMERIC(18,7),
    weight NUMERIC(18,7),
    price_per_lb NUMERIC(18,7),
    total_price NUMERIC(18,7) NOT NULL,
    discount_amount NUMERIC(18,7) NOT NULL,
    total_paid NUMERIC(18,7) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT (now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT (now()),
    deleted_at TIMESTAMPTZ  
);