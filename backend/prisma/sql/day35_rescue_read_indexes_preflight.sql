SELECT 'rescue_cases_table_count' AS check_name, COUNT(*)::text AS actual
FROM information_schema.tables
WHERE table_schema = 'public' AND table_name = 'rescue_cases';

SELECT 'required_enum_count' AS check_name, COUNT(*)::text AS actual
FROM pg_type t
JOIN pg_namespace n ON n.oid = t.typnamespace
WHERE n.nspname = 'public'
  AND t.typname IN ('RescueCaseStatus', 'PetSpecies');

SELECT 'existing_day35_index_count' AS check_name, COUNT(*)::text AS actual
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname IN (
    'rescue_cases_public_recent_idx',
    'rescue_cases_public_status_recent_idx',
    'rescue_cases_public_species_recent_idx',
    'rescue_cases_public_species_status_recent_idx'
  );
