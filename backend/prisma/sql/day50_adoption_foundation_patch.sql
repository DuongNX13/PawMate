-- Day 50: Adoption listing/request persistence and minimal request chat thread.
-- Additive, transactional, and safe to re-run after a successful first apply.
BEGIN;

DO $$
BEGIN
  CREATE TYPE "AdoptionListingStatus" AS ENUM (
    'available',
    'pending',
    'adopted',
    'closed'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE "AdoptionDecision" AS ENUM ('skip', 'like');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

DO $$
BEGIN
  CREATE TYPE "AdoptionRequestStatus" AS ENUM (
    'submitted',
    'reviewing',
    'approved',
    'rejected',
    'cancelled'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.adoption_listings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  shelter_id UUID NOT NULL,
  hero_media_id UUID NOT NULL,
  pet_name VARCHAR(50) NOT NULL,
  species "PetSpecies" NOT NULL,
  breed VARCHAR(100),
  age_label VARCHAR(80) NOT NULL,
  description VARCHAR(2000),
  traits TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  health_badges TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  verification_badges TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  latitude NUMERIC(9, 6),
  longitude NUMERIC(9, 6),
  status "AdoptionListingStatus" NOT NULL DEFAULT 'available',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ,
  CONSTRAINT adoption_listings_shelter_fkey
    FOREIGN KEY (shelter_id) REFERENCES public.users(id) ON DELETE RESTRICT,
  CONSTRAINT adoption_listings_hero_media_fkey
    FOREIGN KEY (hero_media_id) REFERENCES public.media_assets(id) ON DELETE RESTRICT,
  CONSTRAINT adoption_listings_id_shelter_key UNIQUE (id, shelter_id),
  CONSTRAINT adoption_listings_pet_name_check
    CHECK (char_length(btrim(pet_name)) BETWEEN 1 AND 50),
  CONSTRAINT adoption_listings_age_label_check
    CHECK (char_length(btrim(age_label)) BETWEEN 1 AND 80),
  CONSTRAINT adoption_listings_breed_check
    CHECK (breed IS NULL OR char_length(btrim(breed)) BETWEEN 1 AND 100),
  CONSTRAINT adoption_listings_description_check
    CHECK (description IS NULL OR char_length(btrim(description)) BETWEEN 1 AND 2000),
  CONSTRAINT adoption_listings_location_pair_check
    CHECK (
      (latitude IS NULL AND longitude IS NULL)
      OR (latitude IS NOT NULL AND longitude IS NOT NULL)
    ),
  CONSTRAINT adoption_listings_latitude_check
    CHECK (latitude IS NULL OR latitude BETWEEN -90 AND 90),
  CONSTRAINT adoption_listings_longitude_check
    CHECK (longitude IS NULL OR longitude BETWEEN -180 AND 180)
);

CREATE TABLE IF NOT EXISTS public.adoption_decisions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id UUID NOT NULL,
  adopter_user_id UUID NOT NULL,
  decision "AdoptionDecision" NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT adoption_decisions_listing_fkey
    FOREIGN KEY (listing_id) REFERENCES public.adoption_listings(id) ON DELETE CASCADE,
  CONSTRAINT adoption_decisions_adopter_fkey
    FOREIGN KEY (adopter_user_id) REFERENCES public.users(id) ON DELETE CASCADE,
  CONSTRAINT adoption_decisions_listing_adopter_key
    UNIQUE (listing_id, adopter_user_id)
);

CREATE TABLE IF NOT EXISTS public.adoption_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id UUID NOT NULL,
  adopter_user_id UUID NOT NULL,
  shelter_id UUID NOT NULL,
  living_condition VARCHAR(500) NOT NULL,
  pet_experience VARCHAR(500) NOT NULL,
  care_plan VARCHAR(500) NOT NULL,
  commitment_accepted BOOLEAN NOT NULL,
  note VARCHAR(1000),
  status "AdoptionRequestStatus" NOT NULL DEFAULT 'submitted',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT adoption_requests_listing_shelter_fkey
    FOREIGN KEY (listing_id, shelter_id)
    REFERENCES public.adoption_listings(id, shelter_id) ON DELETE RESTRICT,
  CONSTRAINT adoption_requests_adopter_fkey
    FOREIGN KEY (adopter_user_id) REFERENCES public.users(id) ON DELETE RESTRICT,
  CONSTRAINT adoption_requests_shelter_fkey
    FOREIGN KEY (shelter_id) REFERENCES public.users(id) ON DELETE RESTRICT,
  CONSTRAINT adoption_requests_id_participants_key
    UNIQUE (id, adopter_user_id, shelter_id),
  CONSTRAINT adoption_requests_not_self_check
    CHECK (adopter_user_id <> shelter_id),
  CONSTRAINT adoption_requests_commitment_check
    CHECK (commitment_accepted IS TRUE),
  CONSTRAINT adoption_requests_living_condition_check
    CHECK (char_length(btrim(living_condition)) BETWEEN 1 AND 500),
  CONSTRAINT adoption_requests_pet_experience_check
    CHECK (char_length(btrim(pet_experience)) BETWEEN 1 AND 500),
  CONSTRAINT adoption_requests_care_plan_check
    CHECK (char_length(btrim(care_plan)) BETWEEN 1 AND 500),
  CONSTRAINT adoption_requests_note_check
    CHECK (note IS NULL OR char_length(note) <= 1000)
);

CREATE TABLE IF NOT EXISTS public.adoption_chat_threads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id UUID NOT NULL,
  adopter_user_id UUID NOT NULL,
  shelter_id UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  closed_at TIMESTAMPTZ,
  CONSTRAINT adoption_chat_threads_request_key UNIQUE (request_id),
  CONSTRAINT adoption_chat_threads_request_participants_fkey
    FOREIGN KEY (request_id, adopter_user_id, shelter_id)
    REFERENCES public.adoption_requests(id, adopter_user_id, shelter_id)
    ON DELETE CASCADE,
  CONSTRAINT adoption_chat_threads_adopter_fkey
    FOREIGN KEY (adopter_user_id) REFERENCES public.users(id) ON DELETE RESTRICT,
  CONSTRAINT adoption_chat_threads_shelter_fkey
    FOREIGN KEY (shelter_id) REFERENCES public.users(id) ON DELETE RESTRICT,
  CONSTRAINT adoption_chat_threads_not_self_check
    CHECK (adopter_user_id <> shelter_id)
);

-- Prisma/Fastify uses the trusted database role. Direct anon/authenticated
-- access through Supabase Data API is denied because no permissive policy is
-- created for these participant-sensitive tables.
ALTER TABLE public.adoption_listings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.adoption_decisions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.adoption_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.adoption_chat_threads ENABLE ROW LEVEL SECURITY;

CREATE UNIQUE INDEX IF NOT EXISTS adoption_requests_active_adopter_listing_key
  ON public.adoption_requests (listing_id, adopter_user_id)
  WHERE status IN ('submitted', 'reviewing', 'approved');

CREATE INDEX IF NOT EXISTS adoption_listings_status_created_idx
  ON public.adoption_listings (status, created_at DESC, id);
CREATE INDEX IF NOT EXISTS adoption_listings_species_status_created_idx
  ON public.adoption_listings (species, status, created_at DESC);
CREATE INDEX IF NOT EXISTS adoption_listings_shelter_status_created_idx
  ON public.adoption_listings (shelter_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS adoption_listings_location_idx
  ON public.adoption_listings (latitude, longitude)
  WHERE deleted_at IS NULL AND status = 'available';
CREATE INDEX IF NOT EXISTS adoption_decisions_adopter_updated_idx
  ON public.adoption_decisions (adopter_user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS adoption_requests_listing_status_created_idx
  ON public.adoption_requests (listing_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS adoption_requests_adopter_status_created_idx
  ON public.adoption_requests (adopter_user_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS adoption_requests_shelter_status_created_idx
  ON public.adoption_requests (shelter_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS adoption_chat_threads_adopter_updated_idx
  ON public.adoption_chat_threads (adopter_user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS adoption_chat_threads_shelter_updated_idx
  ON public.adoption_chat_threads (shelter_id, updated_at DESC);

NOTIFY pgrst, 'reload schema';

COMMIT;
