
CREATE TABLE user (
    user_id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    username TEXT UNIQUE NOT NULL,
    password TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT (now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT (now()),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE chain (
    chain_id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT (now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT (now()),
    deleted_at TIMESTAMPTZ
);
-- need chain relationship
CREATE TABLE store (
    store_id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    ---chain_id: relationship to chain (CHAIN_ID)
    store_number INTEGER NOT NULL,
    street_address TEXT NOT NULL,
    description TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT (now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT (now()),
    deleted_at TIMESTAMPTZ
);

-- need chain relationship
CREATE TABLE item (
    item_id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    -- chain_id: relationship to chain (store? or chain? items are unique at the chain level -> chain)
    item_number INTEGER NOT NULL,
    item_name TEXT NOT NULL,
    item_category TEXT,
    item_description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT (now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT (now()),
    deleted_at TIMESTAMPTZ 
);

-- need store relationship
CREATE TABLE reciept (
    reciept_id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,,
    -- store_id: relationship to store
    reciept_number BIGINT NOT NULL,
    transaction_date TIMESTAMPTZ NOT NULL,
    final_total NUMERIC(18,7) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT (now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT (now()),
    deleted_at TIMESTAMPTZ  
);

-- need receipt relationship
-- need item relationship
CREATE TABLE grocery (
    id uuid UNIQUE NOT NULL PRIMARY KEY,
    --receipt_id: relationship to recipt
    --item_id: relationship to item
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