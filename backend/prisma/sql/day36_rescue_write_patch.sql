-- Day 36: shared mutation safety for Rescue write/media/comment/status APIs.
-- Additive, transactional, and safe to re-run after a successful first apply.
-- No seed data is created by this patch.
BEGIN;

ALTER TABLE public.media_assets
  ADD COLUMN IF NOT EXISTS verification_version INTEGER NOT NULL DEFAULT 0;

ALTER TABLE public.media_assets
  DROP CONSTRAINT IF EXISTS media_assets_verification_version_check;
ALTER TABLE public.media_assets
  ADD CONSTRAINT media_assets_verification_version_check
  CHECK (verification_version >= 0);

-- Day 36 cloud storage verification confirmed the Supabase Free ceiling is
-- 50 MB. Reassert the same limit at persistence even when Day 34 was applied
-- from an earlier 100 MB contract revision.
ALTER TABLE public.media_assets
  DROP CONSTRAINT IF EXISTS media_assets_size_check;
ALTER TABLE public.media_assets
  ADD CONSTRAINT media_assets_size_check CHECK (
    size_bytes > 0
    AND (
      (mime_type = 'video/mp4' AND size_bytes <= 52428800)
      OR (mime_type <> 'video/mp4' AND size_bytes <= 10485760)
    )
  );

CREATE TABLE IF NOT EXISTS public.idempotency_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL,
  method VARCHAR(8) NOT NULL,
  normalized_path VARCHAR(255) NOT NULL,
  key_hash CHAR(64) NOT NULL,
  request_hash CHAR(64) NOT NULL,
  response_status SMALLINT NOT NULL,
  response_body JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL,
  CONSTRAINT idempotency_records_user_fkey
    FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE,
  CONSTRAINT idempotency_records_scope_key
    UNIQUE (user_id, method, normalized_path, key_hash),
  CONSTRAINT idempotency_records_method_check CHECK (
    method = upper(method)
    AND method IN ('POST', 'PATCH', 'PUT', 'DELETE')
  ),
  CONSTRAINT idempotency_records_normalized_path_check CHECK (
    normalized_path = btrim(normalized_path)
    AND normalized_path LIKE '/%'
    AND char_length(normalized_path) BETWEEN 1 AND 255
  ),
  CONSTRAINT idempotency_records_key_hash_check CHECK (
    key_hash = lower(key_hash)
    AND key_hash ~ '^[0-9a-f]{64}$'
  ),
  CONSTRAINT idempotency_records_request_hash_check CHECK (
    request_hash = lower(request_hash)
    AND request_hash ~ '^[0-9a-f]{64}$'
  ),
  CONSTRAINT idempotency_records_response_status_check CHECK (
    response_status BETWEEN 100 AND 599
  ),
  CONSTRAINT idempotency_records_response_body_check CHECK (
    jsonb_typeof(response_body) = 'object'
  ),
  CONSTRAINT idempotency_records_retention_check CHECK (
    expires_at >= created_at + INTERVAL '24 hours'
  )
);

CREATE TABLE IF NOT EXISTS public.outbox_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  topic VARCHAR(100) NOT NULL,
  event_type VARCHAR(120) NOT NULL,
  aggregate_type VARCHAR(100) NOT NULL,
  aggregate_id UUID NOT NULL,
  actor_user_id UUID,
  payload JSONB NOT NULL,
  schema_version SMALLINT NOT NULL DEFAULT 1,
  dedupe_key VARCHAR(255) NOT NULL,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  available_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  locked_at TIMESTAMPTZ,
  lock_expires_at TIMESTAMPTZ,
  locked_by VARCHAR(128),
  attempts INTEGER NOT NULL DEFAULT 0,
  processed_at TIMESTAMPTZ,
  last_error TEXT,
  CONSTRAINT outbox_events_actor_fkey
    FOREIGN KEY (actor_user_id) REFERENCES public.users(id) ON DELETE SET NULL,
  CONSTRAINT outbox_events_dedupe_key_key UNIQUE (dedupe_key),
  CONSTRAINT outbox_events_names_check CHECK (
    char_length(btrim(topic)) BETWEEN 1 AND 100
    AND char_length(btrim(event_type)) BETWEEN 1 AND 120
    AND char_length(btrim(aggregate_type)) BETWEEN 1 AND 100
    AND char_length(btrim(dedupe_key)) BETWEEN 1 AND 255
  ),
  CONSTRAINT outbox_events_payload_check CHECK (
    jsonb_typeof(payload) = 'object'
  ),
  CONSTRAINT outbox_events_schema_version_check CHECK (schema_version >= 1),
  CONSTRAINT outbox_events_attempts_check CHECK (attempts >= 0),
  CONSTRAINT outbox_events_timeline_check CHECK (
    available_at >= occurred_at
    AND (processed_at IS NULL OR processed_at >= occurred_at)
  ),
  CONSTRAINT outbox_events_lock_state_check CHECK (
    num_nonnulls(locked_at, lock_expires_at, locked_by) = 0
    OR (
      num_nonnulls(locked_at, lock_expires_at, locked_by) = 3
      AND lock_expires_at > locked_at
    )
  )
);

CREATE TABLE IF NOT EXISTS public.media_upload_sessions (
  media_id UUID PRIMARY KEY,
  staging_storage_key TEXT NOT NULL,
  upload_expires_at TIMESTAMPTZ NOT NULL,
  detected_mime_type VARCHAR(32),
  detected_size_bytes BIGINT,
  sanitized_storage_key TEXT,
  sanitized_sha256 CHAR(64),
  storage_etag TEXT,
  verification_started_at TIMESTAMPTZ,
  lease_until TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  rejected_at TIMESTAMPTZ,
  rejection_code VARCHAR(32),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT media_upload_sessions_media_fkey
    FOREIGN KEY (media_id) REFERENCES public.media_assets(id) ON DELETE CASCADE,
  CONSTRAINT media_upload_sessions_staging_storage_key_key
    UNIQUE (staging_storage_key),
  CONSTRAINT media_upload_sessions_sanitized_storage_key_key
    UNIQUE (sanitized_storage_key),
  CONSTRAINT media_upload_sessions_storage_key_check CHECK (
    staging_storage_key = btrim(staging_storage_key)
    AND char_length(staging_storage_key) > 0
    AND (
      sanitized_storage_key IS NULL
      OR (
        sanitized_storage_key = btrim(sanitized_storage_key)
        AND char_length(sanitized_storage_key) > 0
      )
    )
  ),
  CONSTRAINT media_upload_sessions_expiry_check CHECK (
    upload_expires_at > created_at
  ),
  CONSTRAINT media_upload_sessions_detected_pair_check CHECK (
    num_nonnulls(detected_mime_type, detected_size_bytes) IN (0, 2)
  ),
  CONSTRAINT media_upload_sessions_detected_mime_check CHECK (
    detected_mime_type IS NULL
    OR detected_mime_type IN (
      'image/jpeg', 'image/png', 'image/webp', 'video/mp4'
    )
  ),
  CONSTRAINT media_upload_sessions_detected_size_check CHECK (
    detected_size_bytes IS NULL
    OR (
      detected_size_bytes > 0
      AND (
        (detected_mime_type = 'video/mp4' AND detected_size_bytes <= 52428800)
        OR (
          detected_mime_type <> 'video/mp4'
          AND detected_size_bytes <= 10485760
        )
      )
    )
  ),
  CONSTRAINT media_upload_sessions_sanitized_pair_check CHECK (
    num_nonnulls(sanitized_storage_key, sanitized_sha256) IN (0, 2)
  ),
  CONSTRAINT media_upload_sessions_sanitized_sha256_check CHECK (
    sanitized_sha256 IS NULL
    OR (
      sanitized_sha256 = lower(sanitized_sha256)
      AND sanitized_sha256 ~ '^[0-9a-f]{64}$'
    )
  ),
  CONSTRAINT media_upload_sessions_lease_check CHECK (
    (verification_started_at IS NOT NULL OR lease_until IS NULL)
    AND (lease_until IS NULL OR lease_until > verification_started_at)
  ),
  CONSTRAINT media_upload_sessions_terminal_state_check CHECK (
    num_nonnulls(completed_at, rejected_at) <= 1
  ),
  CONSTRAINT media_upload_sessions_rejection_check CHECK (
    (rejected_at IS NULL AND rejection_code IS NULL)
    OR (rejected_at IS NOT NULL AND rejection_code IS NOT NULL)
  ),
  CONSTRAINT media_upload_sessions_completion_check CHECK (
    completed_at IS NULL
    OR (
      detected_mime_type IS NOT NULL
      AND detected_size_bytes IS NOT NULL
      AND sanitized_storage_key IS NOT NULL
      AND sanitized_sha256 IS NOT NULL
      AND verification_started_at IS NOT NULL
      AND completed_at >= verification_started_at
    )
  ),
  CONSTRAINT media_upload_sessions_terminal_timeline_check CHECK (
    (rejected_at IS NULL OR rejected_at >= created_at)
    AND (completed_at IS NULL OR completed_at >= created_at)
  )
);

-- Reassert the Supabase Free-compatible ceiling for databases where the
-- upload-session table was created by an earlier Day 36 patch.
ALTER TABLE public.media_upload_sessions
  DROP CONSTRAINT IF EXISTS media_upload_sessions_detected_size_check;
ALTER TABLE public.media_upload_sessions
  ADD CONSTRAINT media_upload_sessions_detected_size_check CHECK (
    detected_size_bytes IS NULL
    OR (
      detected_size_bytes > 0
      AND (
        (detected_mime_type = 'video/mp4' AND detected_size_bytes <= 52428800)
        OR (
          detected_mime_type <> 'video/mp4'
          AND detected_size_bytes <= 10485760
        )
      )
    )
  );

-- Recreate the constraint for databases where the table already exists. A
-- completed or rejected verification keeps its start timestamp for audit while
-- releasing the active lease, so verification_started_at may be non-null when
-- lease_until is null.
ALTER TABLE public.media_upload_sessions
  DROP CONSTRAINT IF EXISTS media_upload_sessions_lease_check;
ALTER TABLE public.media_upload_sessions
  ADD CONSTRAINT media_upload_sessions_lease_check CHECK (
    (verification_started_at IS NOT NULL OR lease_until IS NULL)
    AND (lease_until IS NULL OR lease_until > verification_started_at)
  );

CREATE INDEX IF NOT EXISTS idempotency_records_expires_idx
  ON public.idempotency_records (expires_at);
CREATE INDEX IF NOT EXISTS idempotency_records_user_created_idx
  ON public.idempotency_records (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS outbox_events_aggregate_created_idx
  ON public.outbox_events (aggregate_type, aggregate_id, occurred_at);
CREATE INDEX IF NOT EXISTS outbox_events_claim_idx
  ON public.outbox_events (available_at, occurred_at, id)
  WHERE processed_at IS NULL;

CREATE INDEX IF NOT EXISTS media_upload_sessions_expiry_idx
  ON public.media_upload_sessions (upload_expires_at)
  WHERE completed_at IS NULL AND rejected_at IS NULL;

-- Day 34 already creates these indexes. Reassert them so a Day 36-only apply
-- cannot weaken attachment ordering or allow duplicate positions.
CREATE UNIQUE INDEX IF NOT EXISTS media_assets_draft_position_key
  ON public.media_assets (draft_id, position)
  WHERE draft_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS media_assets_case_position_key
  ON public.media_assets (case_id, position)
  WHERE case_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS media_assets_comment_position_key
  ON public.media_assets (comment_id, position)
  WHERE comment_id IS NOT NULL;

ALTER TABLE public.idempotency_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.outbox_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.media_upload_sessions ENABLE ROW LEVEL SECURITY;

-- These tables contain request hashes, replay bodies, delivery internals, and
-- storage audit keys. They are backend-only and must never be exposed through
-- Supabase PostgREST. No client RLS policies are intentionally created.
DO $$
DECLARE
  role_name TEXT;
BEGIN
  FOREACH role_name IN ARRAY ARRAY['anon', 'authenticated']
  LOOP
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = role_name) THEN
      EXECUTE format(
        'REVOKE ALL PRIVILEGES ON TABLE %s FROM %I',
        'public.idempotency_records, public.outbox_events, public.media_upload_sessions',
        role_name
      );
    END IF;
  END LOOP;
END $$;

COMMIT;
