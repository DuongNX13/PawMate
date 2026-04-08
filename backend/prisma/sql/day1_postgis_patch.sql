-- Day 1 follow-up patch for local PostGIS verification.
-- Prisma can materialize the geography column through db push, but the
-- spatial GIST index on vets.location still needs raw SQL.

CREATE EXTENSION IF NOT EXISTS postgis;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_class
    WHERE relname = 'vets'
      AND relkind = 'r'
      AND relnamespace = 'public'::regnamespace
  ) AND NOT EXISTS (
    SELECT 1
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname = 'vets_location_gist_idx'
  ) THEN
    EXECUTE 'CREATE INDEX vets_location_gist_idx ON public.vets USING GIST (location)';
  END IF;
END $$;

