DO $$
BEGIN
  CREATE TYPE "PetHealthStatus" AS ENUM (
    'healthy',
    'monitoring',
    'chronic',
    'recovery',
    'unknown'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE "users"
  ADD COLUMN IF NOT EXISTS "google_sub" TEXT,
  ADD COLUMN IF NOT EXISTS "apple_sub" TEXT,
  ADD COLUMN IF NOT EXISTS "failed_login_attempts" INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS "locked_until" TIMESTAMP(3);

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'pets'
      AND column_name = 'health_status'
      AND udt_name = 'text'
  ) THEN
    ALTER TABLE "pets"
      ALTER COLUMN "health_status" DROP DEFAULT,
      ALTER COLUMN "health_status" TYPE "PetHealthStatus"
        USING COALESCE(NULLIF("health_status", ''), 'healthy')::"PetHealthStatus",
      ALTER COLUMN "health_status" SET DEFAULT 'healthy';
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS "users_google_sub_key"
  ON "users" ("google_sub");

CREATE UNIQUE INDEX IF NOT EXISTS "users_apple_sub_key"
  ON "users" ("apple_sub");
