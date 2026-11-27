-- Day 50 Adoption preflight. Read-only and safe on PostgreSQL/Supabase.
DO $$
DECLARE
  missing_objects text[];
BEGIN
  SELECT array_agg(required_object)
  INTO missing_objects
  FROM (
    VALUES
      ('public.users'),
      ('public.media_assets'),
      ('public.idempotency_records'),
      ('public.outbox_events')
  ) AS required(required_object)
  WHERE to_regclass(required_object) IS NULL;

  IF missing_objects IS NOT NULL THEN
    RAISE EXCEPTION
      'Day 50 preflight failed; missing dependencies: %',
      array_to_string(missing_objects, ', ');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'PetSpecies'
  ) THEN
    RAISE EXCEPTION 'Day 50 preflight failed; enum PetSpecies is missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'MediaPurpose'
  ) THEN
    RAISE EXCEPTION 'Day 50 preflight failed; enum MediaPurpose is missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc
    WHERE proname = 'gen_random_uuid'
  ) THEN
    RAISE EXCEPTION
      'Day 50 preflight failed; gen_random_uuid() is unavailable';
  END IF;
END $$;

SELECT
  current_database() AS database_name,
  current_user AS database_user,
  now() AS checked_at,
  'DAY50_ADOPTION_PREFLIGHT_PASS' AS verdict;
