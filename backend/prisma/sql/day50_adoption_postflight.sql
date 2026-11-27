-- Day 50 Adoption postflight. Read-only verification.
DO $$
DECLARE
  missing_tables text[];
BEGIN
  SELECT array_agg(required_table)
  INTO missing_tables
  FROM (
    VALUES
      ('public.adoption_listings'),
      ('public.adoption_decisions'),
      ('public.adoption_requests'),
      ('public.adoption_chat_threads')
  ) AS required(required_table)
  WHERE to_regclass(required_table) IS NULL;

  IF missing_tables IS NOT NULL THEN
    RAISE EXCEPTION
      'Day 50 postflight failed; missing tables: %',
      array_to_string(missing_tables, ', ');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_index i
    JOIN pg_class c ON c.oid = i.indexrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = 'adoption_requests_active_adopter_listing_key'
      AND i.indisunique
      AND pg_get_expr(i.indpred, i.indrelid) LIKE '%submitted%'
      AND pg_get_expr(i.indpred, i.indrelid) LIKE '%reviewing%'
      AND pg_get_expr(i.indpred, i.indrelid) LIKE '%approved%'
  ) THEN
    RAISE EXCEPTION
      'Day 50 postflight failed; active request partial unique index is missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'adoption_requests_listing_shelter_fkey'
  ) THEN
    RAISE EXCEPTION
      'Day 50 postflight failed; request/listing shelter integrity constraint is missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'adoption_chat_threads_request_participants_fkey'
  ) THEN
    RAISE EXCEPTION
      'Day 50 postflight failed; thread participant integrity constraint is missing';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname IN (
        'adoption_listings',
        'adoption_decisions',
        'adoption_requests',
        'adoption_chat_threads'
      )
      AND NOT c.relrowsecurity
  ) THEN
    RAISE EXCEPTION
      'Day 50 postflight failed; RLS is not enabled on every Adoption table';
  END IF;
END $$;

SELECT
  (SELECT count(*) FROM public.adoption_listings) AS listing_count,
  (SELECT count(*) FROM public.adoption_decisions) AS decision_count,
  (SELECT count(*) FROM public.adoption_requests) AS request_count,
  (SELECT count(*) FROM public.adoption_chat_threads) AS thread_count,
  'DAY50_ADOPTION_POSTFLIGHT_PASS' AS verdict;
