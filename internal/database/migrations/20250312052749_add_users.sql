-- Create "users" table
CREATE TABLE "users" ("id" uuid NOT NULL, "first_name" text NOT NULL, "last_name" text NOT NULL, "username" text NOT NULL, "email" text NOT NULL, "password" text NOT NULL, "verified" boolean NOT NULL, "created_at" timestamp NOT NULL, "updated_at" timestamp NOT NULL, "deleted_at" timestamp NULL, PRIMARY KEY ("id"), CONSTRAINT "users_email_key" UNIQUE ("email"));
