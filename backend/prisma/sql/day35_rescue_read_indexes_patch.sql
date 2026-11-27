BEGIN;

-- Day 35 public-feed keyset indexes. These are partial because every public
-- read excludes soft-deleted cases, and DESC id matches the stable cursor.
CREATE INDEX IF NOT EXISTS rescue_cases_public_recent_idx
  ON public.rescue_cases (lost_at DESC, id DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS rescue_cases_public_status_recent_idx
  ON public.rescue_cases (status, lost_at DESC, id DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS rescue_cases_public_species_recent_idx
  ON public.rescue_cases (species, lost_at DESC, id DESC)
  WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS rescue_cases_public_species_status_recent_idx
  ON public.rescue_cases (species, status, lost_at DESC, id DESC)
  WHERE deleted_at IS NULL;

COMMIT;
