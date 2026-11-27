\set ON_ERROR_STOP on

BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '60s';

CREATE TABLE public.notification_preferences (
  user_id uuid PRIMARY KEY
    REFERENCES public.users(id) ON DELETE CASCADE,
  version integer NOT NULL DEFAULT 1,
  nearby_lost_cases boolean NOT NULL DEFAULT true,
  chat_messages boolean NOT NULL DEFAULT true,
  adoption_updates boolean NOT NULL DEFAULT true,
  quiet_hours_enabled boolean NOT NULL DEFAULT false,
  quiet_hours_start varchar(5),
  quiet_hours_end varchar(5),
  created_at timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT notification_preferences_version_check
    CHECK (version >= 1),
  CONSTRAINT notification_preferences_quiet_hours_check
    CHECK (
      (
        NOT quiet_hours_enabled
        AND quiet_hours_start IS NULL
        AND quiet_hours_end IS NULL
      )
      OR (
        quiet_hours_enabled
        AND quiet_hours_start ~ '^(?:[01][0-9]|2[0-3]):[0-5][0-9]$'
        AND quiet_hours_end ~ '^(?:[01][0-9]|2[0-3]):[0-5][0-9]$'
        AND quiet_hours_start <> quiet_hours_end
      )
    )
);

CREATE TABLE public.privacy_defaults (
  user_id uuid PRIMARY KEY
    REFERENCES public.users(id) ON DELETE CASCADE,
  version integer NOT NULL DEFAULT 1,
  hide_house_number boolean NOT NULL DEFAULT true,
  hide_phone_by_default boolean NOT NULL DEFAULT true,
  review_media_before_publish boolean NOT NULL DEFAULT true,
  created_at timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at timestamptz(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT privacy_defaults_version_check
    CHECK (version >= 1)
);

CREATE FUNCTION public.day59_touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  NEW.updated_at := CURRENT_TIMESTAMP;
  RETURN NEW;
END
$$;

REVOKE ALL ON FUNCTION public.day59_touch_updated_at() FROM PUBLIC;

CREATE TRIGGER notification_preferences_touch_updated_at
BEFORE UPDATE ON public.notification_preferences
FOR EACH ROW
EXECUTE FUNCTION public.day59_touch_updated_at();

CREATE TRIGGER privacy_defaults_touch_updated_at
BEFORE UPDATE ON public.privacy_defaults
FOR EACH ROW
EXECUTE FUNCTION public.day59_touch_updated_at();

ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.privacy_defaults ENABLE ROW LEVEL SECURITY;

COMMIT;

SELECT 'DAY59_PREFERENCES_PATCH_PASS' AS status;
