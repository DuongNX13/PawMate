-- Day 59 rollback. Destructive and intentionally fail-closed.
-- Set `SET pawmate.allow_destructive_rollback = 'on';` only after exporting
-- the preference tables and confirming rollback ownership.
\set ON_ERROR_STOP on

BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '60s';

DO $$
DECLARE
  allow_destructive boolean :=
    coalesce(current_setting('pawmate.allow_destructive_rollback', true), 'off')
      = 'on';
BEGIN
  IF NOT allow_destructive THEN
    RAISE EXCEPTION
      'Day 59 rollback refused; explicitly enable pawmate.allow_destructive_rollback after backup';
  END IF;
END
$$;

DROP TRIGGER IF EXISTS notification_preferences_touch_updated_at
  ON public.notification_preferences;
DROP TRIGGER IF EXISTS privacy_defaults_touch_updated_at
  ON public.privacy_defaults;
DROP TABLE IF EXISTS public.notification_preferences;
DROP TABLE IF EXISTS public.privacy_defaults;
DROP FUNCTION IF EXISTS public.day59_touch_updated_at();

COMMIT;

SELECT 'DAY59_PREFERENCES_ROLLBACK_PASS' AS status;
