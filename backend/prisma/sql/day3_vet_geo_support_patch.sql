-- Day 3 patch for pilot geo-enrichment and nearby vet search support.

CREATE EXTENSION IF NOT EXISTS postgis;

ALTER TABLE public.vets
  ADD COLUMN IF NOT EXISTS external_id text,
  ADD COLUMN IF NOT EXISTS source_rank integer NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS ready_for_map boolean NOT NULL DEFAULT false;

CREATE UNIQUE INDEX IF NOT EXISTS vets_external_id_uidx
  ON public.vets (external_id);

CREATE INDEX IF NOT EXISTS vets_ready_for_map_source_rank_idx
  ON public.vets (ready_for_map, source_rank);

CREATE INDEX IF NOT EXISTS vets_location_gist_idx
  ON public.vets USING GIST (location);
