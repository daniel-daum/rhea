CREATE TABLE chain (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    name TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT (now ()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT (now ()),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE store (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    chain_id BIGINT NOT NULL REFERENCES chain (id),
    store_number INTEGER UNIQUE NOT NULL,
    street_address TEXT UNIQUE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT (now ()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT (now ()),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE receipt (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    store_id BIGINT NOT NULL REFERENCES store (id),
    receipt_number BIGINT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT (now ()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT (now ()),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE item (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    chain_id BIGINT NOT NULL REFERENCES chain (id),
    store_id BIGINT NOT NULL REFERENCES store (id),
    category TEXT NOT NULL,
    code INTEGER,
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT (now ()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT (now ()),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE purchases (
    day DATE NOT NULL,
    chain_id BIGINT NOT NULL REFERENCES chain (id),
    store_id BIGINT NOT NULL REFERENCES store (id),
    receipt_id BIGINT NOT NULL REFERENCES receipt (id),
    item_id BIGINT NOT NULL REFERENCES item (id),
    quantity_units INTEGER,
    price_per_unit NUMERIC(18, 7),
    weight_pounds NUMERIC(18, 7),
    price_per_lb NUMERIC(18, 7),
    price NUMERIC(18, 7) NOT NULL,
    sale NUMERIC(18, 7) NOT NULL,
    paid NUMERIC(18, 7) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT (now ()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT (now ()),
    deleted_at TIMESTAMPTZ
);
