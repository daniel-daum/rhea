CREATE TABLE users (
    id uuid UNIQUE NOT NULL PRIMARY KEY,
    first_name text NOT NULL,
    last_name text NOT NULL,
    username text UNIQUE NOT NULL,
    email text UNIQUE NOT NULL,
    password text NOT NULL,
    verified boolean NOT NULL DEFAULT FALSE,
    created_at timestamptz NOT NULL DEFAULT (now()),
    updated_at timestamptz NOT NULL DEFAULT (now()),
    deleted_at timestamptz
);
