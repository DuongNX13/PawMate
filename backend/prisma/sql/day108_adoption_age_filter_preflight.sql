\set ON_ERROR_STOP on

DO $$
BEGIN
  IF to_regclass('public.adoption_listings') IS NULL THEN
    RAISE EXCEPTION 'Day 108 preflight failed; public.adoption_listings is missing';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'adoption_listings'
      AND column_name = 'age_months'
  ) THEN
    RAISE EXCEPTION 'Day 108 preflight failed; age_months already exists';
  END IF;
END
$$;

SELECT 'DAY108_ADOPTION_AGE_FILTER_PREFLIGHT_PASS' AS status;
