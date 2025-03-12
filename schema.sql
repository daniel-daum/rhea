CREATE TABLE users (
    id uuid UNIQUE NOT NULL PRIMARY KEY,
    first_name text NOT NULL,
    last_name text NOT NULL,
    username text NOT NULL,
    email text UNIQUE NOT NULL,
    password text NOT NULL,
    verified boolean NOT NULL,
    created_at timestamp NOT NULL,
    updated_at timestamp NOT NULL,
    deleted_at timestamp
);
