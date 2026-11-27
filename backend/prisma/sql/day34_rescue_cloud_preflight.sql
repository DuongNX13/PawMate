-- Day 34 cloud preflight. Read-only: stop before migration if any required
-- dependency is missing or the target objects are only partially present.

SELECT 'postgis_extension_count', count(*)::text
FROM pg_extension
WHERE extname = 'postgis';

SELECT 'phase1_users_table_count', count(*)::text
FROM information_schema.tables
WHERE table_schema = 'public' AND table_name = 'users';

SELECT 'users_id_uuid_count', count(*)::text
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'users'
  AND column_name = 'id'
  AND data_type = 'uuid';

SELECT 'pet_species_enum_count', count(*)::text
FROM pg_type t
JOIN pg_namespace n ON n.oid = t.typnamespace
WHERE n.nspname = 'public' AND t.typname = 'PetSpecies';

SELECT 'pet_species_required_label_count', count(*)::text
FROM pg_enum e
JOIN pg_type t ON t.oid = e.enumtypid
JOIN pg_namespace n ON n.oid = t.typnamespace
WHERE n.nspname = 'public'
  AND t.typname = 'PetSpecies'
  AND e.enumlabel IN ('dog', 'cat', 'bird', 'rabbit', 'other');

SELECT 'can_create_public',
       has_schema_privilege(current_user, 'public', 'CREATE')::text;

SELECT 'existing_target_table_count', count(*)::text
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
    'rescue_case_drafts', 'rescue_cases',
    'rescue_case_private_locations', 'rescue_comments',
    'media_assets', 'rescue_status_events'
  );

SELECT 'existing_target_enum_count', count(*)::text
FROM pg_type t
JOIN pg_namespace n ON n.oid = t.typnamespace
WHERE n.nspname = 'public'
  AND t.typname IN (
    'RescueCaseStatus', 'RescueContactPreference',
    'RescueCommentModerationState', 'MediaPurpose',
    'MediaLifecycleStatus'
  );

SELECT 'existing_target_index_count', count(*)::text
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname IN (
    'rescue_cases_status_lost_at_idx',
    'rescue_cases_species_status_lost_at_idx',
    'rescue_cases_owner_created_idx',
    'rescue_cases_public_location_gist_idx',
    'rescue_comments_case_created_idx',
    'media_assets_case_position_key',
    'rescue_status_events_case_version_key'
  );

SELECT 'existing_target_policy_count', count(*)::text
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'rescue_case_drafts', 'rescue_cases',
    'rescue_case_private_locations', 'rescue_comments',
    'media_assets', 'rescue_status_events'
  );

SELECT 'existing_request_user_function_count', count(*)::text
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'pawmate_request_user_id';
