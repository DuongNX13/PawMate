-- Day 50 rollback. Destructive and intentionally fail-closed.
-- Set `SET LOCAL pawmate.allow_destructive_rollback = 'on';` in the same
-- transaction only after exporting/backing up all Adoption data.
BEGIN;

DO $$
DECLARE
  row_count bigint;
  table_row_count bigint;
  table_name text;
  allow_destructive boolean :=
    coalesce(current_setting('pawmate.allow_destructive_rollback', true), 'off')
      = 'on';
BEGIN
  row_count := 0;
  FOREACH table_name IN ARRAY ARRAY[
    'public.adoption_listings',
    'public.adoption_decisions',
    'public.adoption_requests',
    'public.adoption_chat_threads'
  ]
  LOOP
    IF to_regclass(table_name) IS NOT NULL THEN
      EXECUTE format('SELECT count(*) FROM %s', table_name)
        INTO table_row_count;
      row_count := row_count + table_row_count;
    END IF;
  END LOOP;

  IF row_count > 0 AND NOT allow_destructive THEN
    RAISE EXCEPTION
      'Day 50 rollback refused: % Adoption rows exist; export data and explicitly enable pawmate.allow_destructive_rollback',
      row_count;
  END IF;
END $$;

DROP TABLE IF EXISTS public.adoption_chat_threads;
DROP TABLE IF EXISTS public.adoption_requests;
DROP TABLE IF EXISTS public.adoption_decisions;
DROP TABLE IF EXISTS public.adoption_listings;
DROP TYPE IF EXISTS "AdoptionRequestStatus";
DROP TYPE IF EXISTS "AdoptionDecision";
DROP TYPE IF EXISTS "AdoptionListingStatus";

COMMIT;
