-- Day 27: preserve the optional HH:mm value collected by P1-13.
BEGIN;

ALTER TABLE public.health_records
  ADD COLUMN IF NOT EXISTS event_time VARCHAR(5);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'health_records_event_time_format_check'
      AND conrelid = 'public.health_records'::regclass
  ) THEN
    ALTER TABLE public.health_records
      ADD CONSTRAINT health_records_event_time_format_check
      CHECK (
        event_time IS NULL
        OR event_time ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
      ) NOT VALID;
  END IF;
END $$;

-- VALIDATE uses a lighter lock than adding and validating the check in one step.
ALTER TABLE public.health_records
  VALIDATE CONSTRAINT health_records_event_time_format_check;

COMMIT;

-- Repair/rollback if deployment must be reversed:
-- ALTER TABLE public.health_records DROP CONSTRAINT IF EXISTS health_records_event_time_format_check;
-- ALTER TABLE public.health_records DROP COLUMN IF EXISTS event_time;
