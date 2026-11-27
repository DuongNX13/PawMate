\set ON_ERROR_STOP on

BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '60s';

ALTER TABLE public.adoption_listings
  ADD COLUMN IF NOT EXISTS age_months smallint;

UPDATE public.adoption_listings
SET age_months = ((regexp_match(
  lower(btrim(age_label)),
  '^([0-9]+)[[:space:]]*(tháng|thang)([[:space:]]*tuổi)?$'
))[1])::smallint
WHERE age_months IS NULL
  AND lower(btrim(age_label)) ~
  '^([0-9]+)[[:space:]]*(tháng|thang)([[:space:]]*tuổi)?$';

UPDATE public.adoption_listings
SET age_months = (((regexp_match(
  lower(btrim(age_label)),
  '^([0-9]+)[[:space:]]*(tuổi|năm|nam)$'
))[1])::integer * 12)::smallint
WHERE age_months IS NULL
  AND lower(btrim(age_label)) ~
    '^([0-9]+)[[:space:]]*(tuổi|năm|nam)$';

-- Re-runnable: add the check only when an earlier run has not created it.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'adoption_listings_age_months_check'
      AND conrelid = 'public.adoption_listings'::regclass
  ) THEN
    ALTER TABLE public.adoption_listings
      ADD CONSTRAINT adoption_listings_age_months_check
      CHECK (age_months IS NULL OR age_months BETWEEN 0 AND 360) NOT VALID;
  END IF;
END
$$;

ALTER TABLE public.adoption_listings
  VALIDATE CONSTRAINT adoption_listings_age_months_check;

CREATE INDEX IF NOT EXISTS adoption_listings_age_months_status_created_idx
  ON public.adoption_listings (age_months, status, created_at DESC, id)
  WHERE deleted_at IS NULL;

COMMIT;

SELECT 'DAY108_ADOPTION_AGE_FILTER_PATCH_PASS' AS status;
