SELECT 'day35_index_count' AS check_name, COUNT(*)::text AS actual
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname IN (
    'rescue_cases_public_recent_idx',
    'rescue_cases_public_status_recent_idx',
    'rescue_cases_public_species_recent_idx',
    'rescue_cases_public_species_status_recent_idx'
  );

SELECT 'day35_index_valid_count' AS check_name, COUNT(*)::text AS actual
FROM pg_index i
JOIN pg_class c ON c.oid = i.indexrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN (
    'rescue_cases_public_recent_idx',
    'rescue_cases_public_status_recent_idx',
    'rescue_cases_public_species_recent_idx',
    'rescue_cases_public_species_status_recent_idx'
  )
  AND i.indisvalid
  AND i.indisready;

SELECT 'day35_partial_index_count' AS check_name, COUNT(*)::text AS actual
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname IN (
    'rescue_cases_public_recent_idx',
    'rescue_cases_public_status_recent_idx',
    'rescue_cases_public_species_recent_idx',
    'rescue_cases_public_species_status_recent_idx'
  )
  AND indexdef ILIKE '%WHERE (deleted_at IS NULL)%';
