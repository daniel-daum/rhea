-- Modify "users" table
ALTER TABLE "users" ALTER COLUMN "verified" SET DEFAULT false, ALTER COLUMN "created_at" TYPE timestamptz, ALTER COLUMN "created_at" SET DEFAULT now(), ALTER COLUMN "updated_at" TYPE timestamptz, ALTER COLUMN "updated_at" SET DEFAULT now(), ALTER COLUMN "deleted_at" TYPE timestamptz, ADD CONSTRAINT "users_username_key" UNIQUE ("username");
