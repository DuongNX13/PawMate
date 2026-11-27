\set ON_ERROR_STOP on

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'adoption_listings'
      AND column_name = 'age_months'
      AND data_type = 'smallint'
      AND is_nullable = 'YES'
  ) THEN
    RAISE EXCEPTION 'Day 108 postflight failed; nullable smallint age_months is missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'adoption_listings_age_months_check'
      AND convalidated
  ) THEN
    RAISE EXCEPTION 'Day 108 postflight failed; age constraint is missing or unvalidated';
  END IF;

  IF to_regclass('public.adoption_listings_age_months_status_created_idx') IS NULL THEN
    RAISE EXCEPTION 'Day 108 postflight failed; age filter index is missing';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.adoption_listings
    WHERE age_months IS NOT NULL AND age_months NOT BETWEEN 0 AND 360
  ) THEN
    RAISE EXCEPTION 'Day 108 postflight failed; invalid age_months value exists';
  END IF;
END
$$;

SELECT
  'DAY108_ADOPTION_AGE_FILTER_POSTFLIGHT_PASS' AS status,
  count(*) FILTER (WHERE age_months IS NOT NULL) AS normalized_listing_count,
  count(*) FILTER (WHERE age_months IS NULL) AS unresolved_listing_count
FROM public.adoption_listings;
