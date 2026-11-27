-- Day 108 rollback is destructive and intentionally fail-closed.
-- Export age_months first, then explicitly enable the rollback setting.
\set ON_ERROR_STOP on

BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '60s';

DO $$
BEGIN
  IF coalesce(
    current_setting('pawmate.allow_destructive_rollback', true),
    'off'
  ) <> 'on' THEN
    RAISE EXCEPTION
      'Day 108 rollback refused; set pawmate.allow_destructive_rollback=on after backup';
  END IF;
END
$$;

DROP INDEX IF EXISTS public.adoption_listings_age_months_status_created_idx;
ALTER TABLE public.adoption_listings
  DROP CONSTRAINT IF EXISTS adoption_listings_age_months_check,
  DROP COLUMN IF EXISTS age_months;

COMMIT;

SELECT 'DAY108_ADOPTION_AGE_FILTER_ROLLBACK_PASS' AS status;
