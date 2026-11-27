BEGIN;

DROP INDEX IF EXISTS public.rescue_cases_public_species_status_recent_idx;
DROP INDEX IF EXISTS public.rescue_cases_public_species_recent_idx;
DROP INDEX IF EXISTS public.rescue_cases_public_status_recent_idx;
DROP INDEX IF EXISTS public.rescue_cases_public_recent_idx;

COMMIT;
