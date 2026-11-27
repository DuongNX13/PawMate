-- Day 36 rollback for a failed initial write/media rollout.
-- DESTRUCTIVE for Day 36 control-plane data: replay records, pending outbox
-- events, and media upload audit sessions are removed. Core Rescue entities
-- and media assets remain intact. Back up and obtain release approval first.
BEGIN;

DROP TABLE IF EXISTS public.media_upload_sessions;
DROP TABLE IF EXISTS public.outbox_events;
DROP TABLE IF EXISTS public.idempotency_records;

ALTER TABLE public.media_assets
  DROP CONSTRAINT IF EXISTS media_assets_verification_version_check;
ALTER TABLE public.media_assets
  DROP COLUMN IF EXISTS verification_version;

-- The three media position indexes belong to the Day 34 foundation and are
-- intentionally preserved.

COMMIT;
