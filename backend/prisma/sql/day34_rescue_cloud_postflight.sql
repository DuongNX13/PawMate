-- Day 34 cloud postflight. Expected values are enforced by
-- scripts/day34-rescue-schema-proof.cjs.

SELECT 'table_count', count(*)::text
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
    'rescue_case_drafts', 'rescue_cases',
    'rescue_case_private_locations', 'rescue_comments',
    'media_assets', 'rescue_status_events'
  );
SELECT 'enum_count', count(*)::text
FROM pg_type
WHERE typname IN (
  'RescueCaseStatus', 'RescueContactPreference',
  'RescueCommentModerationState', 'MediaPurpose',
  'MediaLifecycleStatus'
);
SELECT 'rls_count', count(*)::text
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN (
    'rescue_case_drafts', 'rescue_cases',
    'rescue_case_private_locations', 'rescue_comments',
    'media_assets', 'rescue_status_events'
  )
  AND c.relrowsecurity;
SELECT 'policy_count', count(*)::text
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'rescue_case_drafts', 'rescue_cases',
    'rescue_case_private_locations', 'rescue_comments',
    'media_assets', 'rescue_status_events'
  );
SELECT 'invalid_constraint_count', count(*)::text
FROM pg_constraint pc
JOIN pg_class c ON c.oid = pc.conrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN (
    'rescue_case_drafts', 'rescue_cases',
    'rescue_case_private_locations', 'rescue_comments',
    'media_assets', 'rescue_status_events'
  )
  AND NOT pc.convalidated;
SELECT 'required_index_count', count(*)::text
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
SELECT 'public_location_generated',
       concat_ws(':', is_generated, udt_name)
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'rescue_cases'
  AND column_name = 'public_location';
SELECT 'public_sensitive_column_count', count(*)::text
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'rescue_cases'
  AND column_name IN (
    'exact_latitude', 'exact_longitude', 'formatted_address',
    'house_number', 'phone'
  );
SELECT 'private_location_column_count', count(*)::text
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'rescue_case_private_locations'
  AND column_name IN ('latitude', 'longitude', 'formatted_address');
SELECT 'comment_location_column_count', count(*)::text
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'rescue_comments'
  AND column_name ILIKE '%location%';
SELECT 'request_user_function_count', count(*)::text
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public' AND p.proname = 'pawmate_request_user_id';
SELECT 'postgrest_base_table_privilege_count', count(*)::text
FROM pg_roles r
CROSS JOIN unnest(ARRAY[
  'public.rescue_case_drafts', 'public.rescue_cases',
  'public.rescue_case_private_locations', 'public.rescue_comments',
  'public.media_assets', 'public.rescue_status_events'
]) AS table_name
WHERE r.rolname IN ('anon', 'authenticated')
  AND has_table_privilege(r.rolname, table_name, 'SELECT,INSERT,UPDATE,DELETE');
