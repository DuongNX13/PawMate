-- Development/test seed only. Do not run this file against production.
\set ON_ERROR_STOP on

BEGIN;

INSERT INTO public.notification_preferences (user_id)
SELECT id FROM public.users
ON CONFLICT (user_id) DO NOTHING;

INSERT INTO public.privacy_defaults (user_id)
SELECT id FROM public.users
ON CONFLICT (user_id) DO NOTHING;

COMMIT;

SELECT 'DAY59_PREFERENCES_SEED_PASS' AS status;
