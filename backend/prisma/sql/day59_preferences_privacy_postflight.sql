\set ON_ERROR_STOP on

DO $$
DECLARE
  rls_count integer;
BEGIN
  IF to_regclass('public.notification_preferences') IS NULL
    OR to_regclass('public.privacy_defaults') IS NULL THEN
    RAISE EXCEPTION 'Day 59 postflight failed; preference tables are missing';
  END IF;

  IF (
    SELECT count(*)
    FROM pg_constraint
    WHERE conname IN (
      'notification_preferences_version_check',
      'notification_preferences_quiet_hours_check',
      'privacy_defaults_version_check'
    )
  ) <> 3 THEN
    RAISE EXCEPTION 'Day 59 postflight failed; integrity constraints are missing';
  END IF;

  IF (
    SELECT count(*)
    FROM pg_trigger
    WHERE tgname IN (
      'notification_preferences_touch_updated_at',
      'privacy_defaults_touch_updated_at'
    )
      AND NOT tgisinternal
  ) <> 2 THEN
    RAISE EXCEPTION 'Day 59 postflight failed; update triggers are missing';
  END IF;

  SELECT count(*)
  INTO rls_count
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN ('notification_preferences', 'privacy_defaults')
    AND c.relrowsecurity;

  IF rls_count <> 2 THEN
    RAISE EXCEPTION 'Day 59 postflight failed; deny-by-default RLS is not enabled';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.notification_preferences
    WHERE version < 1
      OR (
        quiet_hours_enabled
        AND (
          quiet_hours_start IS NULL
          OR quiet_hours_end IS NULL
          OR quiet_hours_start = quiet_hours_end
        )
      )
      OR (
        NOT quiet_hours_enabled
        AND (quiet_hours_start IS NOT NULL OR quiet_hours_end IS NOT NULL)
      )
  ) THEN
    RAISE EXCEPTION 'Day 59 postflight failed; invalid notification preference rows exist';
  END IF;
END
$$;

SELECT
  'DAY59_PREFERENCES_POSTFLIGHT_PASS' AS status,
  (SELECT count(*) FROM public.notification_preferences) AS notification_count,
  (SELECT count(*) FROM public.privacy_defaults) AS privacy_count;
