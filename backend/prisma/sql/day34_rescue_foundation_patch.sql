-- Day 34: real PostgreSQL/Supabase persistence foundation for Rescue.
-- Additive, transactional, and safe to re-run after a successful first apply.
BEGIN;

DO $$
BEGIN
  CREATE TYPE "RescueCaseStatus" AS ENUM ('missing', 'found');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE "RescueContactPreference" AS ENUM ('in_app', 'phone_with_consent');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE "RescueCommentModerationState" AS ENUM ('visible', 'pending', 'hidden');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE "MediaPurpose" AS ENUM (
    'pet_profile',
    'rescue_case',
    'rescue_comment',
    'adoption_listing',
    'adoption_chat'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE "MediaLifecycleStatus" AS ENUM (
    'requested',
    'uploaded',
    'verified',
    'attached',
    'rejected',
    'deleted'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.rescue_case_drafts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id UUID NOT NULL,
  source VARCHAR(32),
  pet_name VARCHAR(50),
  species "PetSpecies",
  breed_or_color VARCHAR(100),
  lost_at TIMESTAMPTZ,
  exact_latitude NUMERIC(9, 6),
  exact_longitude NUMERIC(9, 6),
  formatted_address TEXT,
  area_label VARCHAR(160),
  privacy_radius_meters INTEGER NOT NULL DEFAULT 500,
  identifying_features VARCHAR(500),
  behavior_hint VARCHAR(500),
  contact_preference "RescueContactPreference" NOT NULL DEFAULT 'in_app',
  version INTEGER NOT NULL DEFAULT 1,
  published_at TIMESTAMPTZ,
  discarded_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT rescue_case_drafts_owner_fkey
    FOREIGN KEY (owner_user_id) REFERENCES public.users(id) ON DELETE CASCADE,
  CONSTRAINT rescue_case_drafts_id_owner_key UNIQUE (id, owner_user_id),
  CONSTRAINT rescue_case_drafts_version_check CHECK (version >= 1),
  CONSTRAINT rescue_case_drafts_source_check CHECK (
    source IS NULL OR source IN ('rescue_home', 'deep_link')
  ),
  CONSTRAINT rescue_case_drafts_pet_name_check CHECK (
    pet_name IS NULL OR char_length(btrim(pet_name)) BETWEEN 1 AND 50
  ),
  CONSTRAINT rescue_case_drafts_breed_or_color_check CHECK (
    breed_or_color IS NULL OR char_length(btrim(breed_or_color)) BETWEEN 1 AND 100
  ),
  CONSTRAINT rescue_case_drafts_identifying_features_check CHECK (
    identifying_features IS NULL
    OR char_length(btrim(identifying_features)) BETWEEN 1 AND 500
  ),
  CONSTRAINT rescue_case_drafts_behavior_hint_check CHECK (
    behavior_hint IS NULL OR char_length(behavior_hint) <= 500
  ),
  CONSTRAINT rescue_case_drafts_location_pair_check CHECK (
    (exact_latitude IS NULL AND exact_longitude IS NULL)
    OR (exact_latitude IS NOT NULL AND exact_longitude IS NOT NULL)
  ),
  CONSTRAINT rescue_case_drafts_latitude_check CHECK (
    exact_latitude IS NULL OR exact_latitude BETWEEN -90 AND 90
  ),
  CONSTRAINT rescue_case_drafts_longitude_check CHECK (
    exact_longitude IS NULL OR exact_longitude BETWEEN -180 AND 180
  ),
  CONSTRAINT rescue_case_drafts_privacy_radius_check CHECK (
    privacy_radius_meters >= 100
  ),
  CONSTRAINT rescue_case_drafts_terminal_state_check CHECK (
    published_at IS NULL OR discarded_at IS NULL
  )
);

CREATE TABLE IF NOT EXISTS public.rescue_cases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source_draft_id UUID NOT NULL,
  owner_user_id UUID NOT NULL,
  pet_name VARCHAR(50) NOT NULL,
  species "PetSpecies" NOT NULL,
  breed_or_color VARCHAR(100) NOT NULL,
  age_label VARCHAR(80),
  lost_at TIMESTAMPTZ NOT NULL,
  area_label VARCHAR(160) NOT NULL,
  approximate_latitude NUMERIC(9, 6) NOT NULL,
  approximate_longitude NUMERIC(9, 6) NOT NULL,
  privacy_radius_meters INTEGER NOT NULL DEFAULT 500,
  public_location geography(Point, 4326) GENERATED ALWAYS AS (
    ST_SetSRID(
      ST_MakePoint(
        approximate_longitude::double precision,
        approximate_latitude::double precision
      ),
      4326
    )::geography
  ) STORED,
  identifying_features VARCHAR(500) NOT NULL,
  behavior_hint VARCHAR(500),
  contact_preference "RescueContactPreference" NOT NULL DEFAULT 'in_app',
  status "RescueCaseStatus" NOT NULL DEFAULT 'missing',
  version INTEGER NOT NULL DEFAULT 1,
  comment_count INTEGER NOT NULL DEFAULT 0,
  found_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT rescue_cases_source_draft_key UNIQUE (source_draft_id),
  CONSTRAINT rescue_cases_id_owner_key UNIQUE (id, owner_user_id),
  CONSTRAINT rescue_cases_source_draft_fkey
    FOREIGN KEY (source_draft_id) REFERENCES public.rescue_case_drafts(id) ON DELETE RESTRICT,
  CONSTRAINT rescue_cases_owner_fkey
    FOREIGN KEY (owner_user_id) REFERENCES public.users(id) ON DELETE RESTRICT,
  CONSTRAINT rescue_cases_version_check CHECK (version >= 1),
  CONSTRAINT rescue_cases_comment_count_check CHECK (comment_count >= 0),
  CONSTRAINT rescue_cases_pet_name_check CHECK (
    char_length(btrim(pet_name)) BETWEEN 1 AND 50
  ),
  CONSTRAINT rescue_cases_breed_or_color_check CHECK (
    char_length(btrim(breed_or_color)) BETWEEN 1 AND 100
  ),
  CONSTRAINT rescue_cases_identifying_features_check CHECK (
    char_length(btrim(identifying_features)) BETWEEN 1 AND 500
  ),
  CONSTRAINT rescue_cases_behavior_hint_check CHECK (
    behavior_hint IS NULL OR char_length(behavior_hint) <= 500
  ),
  CONSTRAINT rescue_cases_area_label_check CHECK (
    char_length(btrim(area_label)) BETWEEN 1 AND 160
  ),
  CONSTRAINT rescue_cases_latitude_check CHECK (
    approximate_latitude BETWEEN -90 AND 90
  ),
  CONSTRAINT rescue_cases_longitude_check CHECK (
    approximate_longitude BETWEEN -180 AND 180
  ),
  CONSTRAINT rescue_cases_privacy_radius_check CHECK (
    privacy_radius_meters >= 100
  ),
  CONSTRAINT rescue_cases_found_state_check CHECK (
    (status = 'missing' AND found_at IS NULL)
    OR (status = 'found' AND found_at IS NOT NULL)
  )
);

CREATE TABLE IF NOT EXISTS public.rescue_case_private_locations (
  case_id UUID PRIMARY KEY,
  owner_user_id UUID NOT NULL,
  latitude NUMERIC(9, 6) NOT NULL,
  longitude NUMERIC(9, 6) NOT NULL,
  formatted_address TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT rescue_case_private_locations_case_owner_key UNIQUE (case_id, owner_user_id),
  CONSTRAINT rescue_case_private_locations_case_owner_fkey
    FOREIGN KEY (case_id, owner_user_id)
    REFERENCES public.rescue_cases(id, owner_user_id)
    ON DELETE CASCADE,
  CONSTRAINT rescue_case_private_locations_owner_fkey
    FOREIGN KEY (owner_user_id) REFERENCES public.users(id) ON DELETE RESTRICT,
  CONSTRAINT rescue_case_private_locations_latitude_check CHECK (
    latitude BETWEEN -90 AND 90
  ),
  CONSTRAINT rescue_case_private_locations_longitude_check CHECK (
    longitude BETWEEN -180 AND 180
  )
);

CREATE TABLE IF NOT EXISTS public.rescue_comments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL,
  author_user_id UUID NOT NULL,
  body VARCHAR(500) NOT NULL,
  reply_to_comment_id UUID,
  moderation_state "RescueCommentModerationState" NOT NULL DEFAULT 'visible',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT rescue_comments_id_case_key UNIQUE (id, case_id),
  CONSTRAINT rescue_comments_case_fkey
    FOREIGN KEY (case_id) REFERENCES public.rescue_cases(id) ON DELETE CASCADE,
  CONSTRAINT rescue_comments_author_fkey
    FOREIGN KEY (author_user_id) REFERENCES public.users(id) ON DELETE RESTRICT,
  CONSTRAINT rescue_comments_reply_case_fkey
    FOREIGN KEY (reply_to_comment_id, case_id)
    REFERENCES public.rescue_comments(id, case_id)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT rescue_comments_body_check CHECK (
    char_length(btrim(body)) BETWEEN 1 AND 500
  )
);

CREATE TABLE IF NOT EXISTS public.media_assets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_user_id UUID NOT NULL,
  purpose "MediaPurpose" NOT NULL,
  mime_type VARCHAR(32) NOT NULL,
  size_bytes BIGINT NOT NULL,
  sha256 VARCHAR(64) NOT NULL,
  status "MediaLifecycleStatus" NOT NULL DEFAULT 'requested',
  storage_key TEXT NOT NULL,
  public_url TEXT,
  width INTEGER,
  height INTEGER,
  duration_seconds NUMERIC(10, 3),
  draft_id UUID,
  case_id UUID,
  comment_id UUID,
  position SMALLINT,
  verified_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT media_assets_storage_key_key UNIQUE (storage_key),
  CONSTRAINT media_assets_owner_fkey
    FOREIGN KEY (owner_user_id) REFERENCES public.users(id) ON DELETE CASCADE,
  CONSTRAINT media_assets_draft_fkey
    FOREIGN KEY (draft_id) REFERENCES public.rescue_case_drafts(id) ON DELETE CASCADE,
  CONSTRAINT media_assets_case_fkey
    FOREIGN KEY (case_id) REFERENCES public.rescue_cases(id) ON DELETE CASCADE,
  CONSTRAINT media_assets_comment_fkey
    FOREIGN KEY (comment_id) REFERENCES public.rescue_comments(id) ON DELETE CASCADE,
  CONSTRAINT media_assets_mime_type_check CHECK (
    mime_type IN ('image/jpeg', 'image/png', 'image/webp', 'video/mp4')
  ),
  CONSTRAINT media_assets_size_check CHECK (
    size_bytes > 0
    AND (
      (mime_type = 'video/mp4' AND size_bytes <= 52428800)
      OR (mime_type <> 'video/mp4' AND size_bytes <= 10485760)
    )
  ),
  CONSTRAINT media_assets_sha256_check CHECK (
    sha256 ~ '^[0-9a-fA-F]{64}$'
  ),
  CONSTRAINT media_assets_dimensions_check CHECK (
    (width IS NULL OR width > 0)
    AND (height IS NULL OR height > 0)
    AND (duration_seconds IS NULL OR duration_seconds >= 0)
  ),
  CONSTRAINT media_assets_entity_count_check CHECK (
    num_nonnulls(draft_id, case_id, comment_id) <= 1
    AND (status <> 'attached' OR num_nonnulls(draft_id, case_id, comment_id) = 1)
  ),
  CONSTRAINT media_assets_position_check CHECK (
    position IS NULL OR position BETWEEN 0 AND 4
  ),
  CONSTRAINT media_assets_attached_position_check CHECK (
    status <> 'attached' OR position IS NOT NULL
  ),
  CONSTRAINT media_assets_purpose_entity_check CHECK (
    (draft_id IS NULL AND case_id IS NULL AND comment_id IS NULL)
    OR (comment_id IS NOT NULL AND purpose = 'rescue_comment')
    OR ((draft_id IS NOT NULL OR case_id IS NOT NULL) AND purpose = 'rescue_case')
  )
);

-- Reassert the cloud-compatible media ceiling for databases where this table
-- already existed before the Day 36 storage proof was run.
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

CREATE TABLE IF NOT EXISTS public.rescue_status_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  case_id UUID NOT NULL,
  changed_by_user_id UUID NOT NULL,
  from_status "RescueCaseStatus",
  to_status "RescueCaseStatus" NOT NULL,
  expected_version INTEGER NOT NULL,
  new_version INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT rescue_status_events_case_version_key UNIQUE (case_id, new_version),
  CONSTRAINT rescue_status_events_case_fkey
    FOREIGN KEY (case_id) REFERENCES public.rescue_cases(id) ON DELETE CASCADE,
  CONSTRAINT rescue_status_events_actor_fkey
    FOREIGN KEY (changed_by_user_id) REFERENCES public.users(id) ON DELETE RESTRICT,
  CONSTRAINT rescue_status_events_version_check CHECK (
    expected_version >= 0 AND new_version = expected_version + 1
  ),
  CONSTRAINT rescue_status_events_transition_check CHECK (
    (from_status IS NULL AND to_status = 'missing')
    OR (from_status = 'missing' AND to_status = 'found')
  )
);

CREATE INDEX IF NOT EXISTS rescue_case_drafts_owner_state_updated_idx
  ON public.rescue_case_drafts (owner_user_id, published_at, discarded_at, updated_at DESC);
CREATE INDEX IF NOT EXISTS rescue_cases_status_lost_at_idx
  ON public.rescue_cases (status, lost_at DESC, id);
CREATE INDEX IF NOT EXISTS rescue_cases_species_status_lost_at_idx
  ON public.rescue_cases (species, status, lost_at DESC);
CREATE INDEX IF NOT EXISTS rescue_cases_owner_created_idx
  ON public.rescue_cases (owner_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS rescue_cases_public_location_gist_idx
  ON public.rescue_cases USING GIST (public_location);
CREATE INDEX IF NOT EXISTS rescue_case_private_locations_owner_idx
  ON public.rescue_case_private_locations (owner_user_id);
CREATE INDEX IF NOT EXISTS rescue_comments_case_created_idx
  ON public.rescue_comments (case_id, created_at, id);
CREATE INDEX IF NOT EXISTS rescue_comments_author_created_idx
  ON public.rescue_comments (author_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS media_assets_owner_status_created_idx
  ON public.media_assets (owner_user_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS media_assets_draft_position_idx
  ON public.media_assets (draft_id, position);
CREATE INDEX IF NOT EXISTS media_assets_case_position_idx
  ON public.media_assets (case_id, position);
CREATE INDEX IF NOT EXISTS media_assets_comment_position_idx
  ON public.media_assets (comment_id, position);
CREATE UNIQUE INDEX IF NOT EXISTS media_assets_draft_position_key
  ON public.media_assets (draft_id, position) WHERE draft_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS media_assets_case_position_key
  ON public.media_assets (case_id, position) WHERE case_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS media_assets_comment_position_key
  ON public.media_assets (comment_id, position) WHERE comment_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS rescue_status_events_case_created_idx
  ON public.rescue_status_events (case_id, created_at);
CREATE INDEX IF NOT EXISTS rescue_status_events_actor_created_idx
  ON public.rescue_status_events (changed_by_user_id, created_at DESC);

-- Portable request-user helper for Supabase/PostgREST RLS and local verification.
CREATE OR REPLACE FUNCTION public.pawmate_request_user_id()
RETURNS UUID
LANGUAGE plpgsql
STABLE
SET search_path = pg_catalog, public
AS $$
DECLARE
  raw_claims TEXT;
  raw_user_id TEXT;
BEGIN
  raw_user_id := NULLIF(current_setting('request.jwt.claim.sub', true), '');
  IF raw_user_id IS NULL THEN
    raw_claims := NULLIF(current_setting('request.jwt.claims', true), '');
    IF raw_claims IS NOT NULL THEN
      raw_user_id := raw_claims::jsonb ->> 'sub';
    END IF;
  END IF;

  IF raw_user_id IS NULL THEN
    RETURN NULL;
  END IF;

  BEGIN
    RETURN raw_user_id::UUID;
  EXCEPTION
    WHEN invalid_text_representation THEN RETURN NULL;
  END;
END;
$$;

ALTER TABLE public.rescue_case_drafts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rescue_cases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rescue_case_private_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rescue_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.media_assets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rescue_status_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rescue_case_drafts_owner_read ON public.rescue_case_drafts;
CREATE POLICY rescue_case_drafts_owner_read
  ON public.rescue_case_drafts
  FOR SELECT
  USING (owner_user_id = public.pawmate_request_user_id());

DROP POLICY IF EXISTS rescue_cases_owner_read ON public.rescue_cases;
CREATE POLICY rescue_cases_owner_read
  ON public.rescue_cases
  FOR SELECT
  USING (owner_user_id = public.pawmate_request_user_id() AND deleted_at IS NULL);

DROP POLICY IF EXISTS rescue_case_private_locations_owner_read
  ON public.rescue_case_private_locations;
CREATE POLICY rescue_case_private_locations_owner_read
  ON public.rescue_case_private_locations
  FOR SELECT
  USING (owner_user_id = public.pawmate_request_user_id());

DROP POLICY IF EXISTS media_assets_owner_read ON public.media_assets;
CREATE POLICY media_assets_owner_read
  ON public.media_assets
  FOR SELECT
  USING (owner_user_id = public.pawmate_request_user_id() AND deleted_at IS NULL);

DROP POLICY IF EXISTS rescue_comments_authenticated_read ON public.rescue_comments;
CREATE POLICY rescue_comments_authenticated_read
  ON public.rescue_comments
  FOR SELECT
  USING (public.pawmate_request_user_id() IS NOT NULL AND deleted_at IS NULL);

DROP POLICY IF EXISTS rescue_status_events_authenticated_read
  ON public.rescue_status_events;
CREATE POLICY rescue_status_events_authenticated_read
  ON public.rescue_status_events
  FOR SELECT
  USING (public.pawmate_request_user_id() IS NOT NULL);

-- The app contract exposes sanitized DTOs through the backend, not direct base tables.
-- Remove Supabase PostgREST table privileges when those roles exist so owner IDs,
-- exact locations, storage keys and moderation fields cannot bypass the API mapper.
DO $$
DECLARE
  role_name TEXT;
BEGIN
  FOREACH role_name IN ARRAY ARRAY['anon', 'authenticated']
  LOOP
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = role_name) THEN
      EXECUTE format(
        'REVOKE ALL PRIVILEGES ON TABLE %s FROM %I',
        'public.rescue_case_drafts, public.rescue_cases, public.rescue_case_private_locations, public.rescue_comments, public.media_assets, public.rescue_status_events',
        role_name
      );
    END IF;
  END LOOP;
END $$;

COMMIT;
