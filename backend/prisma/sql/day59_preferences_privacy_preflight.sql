\set ON_ERROR_STOP on

DO $$
DECLARE
  partial_objects integer;
BEGIN
  IF to_regclass('public.users') IS NULL THEN
    RAISE EXCEPTION 'Day 59 preflight failed; public.users is missing';
  END IF;

  SELECT
    (CASE WHEN to_regclass('public.notification_preferences') IS NOT NULL THEN 1 ELSE 0 END)
    + (CASE WHEN to_regclass('public.privacy_defaults') IS NOT NULL THEN 1 ELSE 0 END)
    + (CASE WHEN to_regprocedure('public.day59_touch_updated_at()') IS NOT NULL THEN 1 ELSE 0 END)
  INTO partial_objects;

  IF partial_objects <> 0 THEN
    RAISE EXCEPTION
      'Day 59 preflight failed; partial or previously applied preference schema detected (% objects)',
      partial_objects;
  END IF;
END
$$;

SELECT 'DAY59_PREFERENCES_PREFLIGHT_PASS' AS status;
