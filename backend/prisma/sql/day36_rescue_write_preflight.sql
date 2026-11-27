-- Day 36 preflight. Expected first-apply values:
-- source_table_count=2, source_uuid_key_count=2,
-- source_media_position_unique_index_count=3, can_create_public=true,
-- existing_target_table_count=0, existing_verification_version_count=0,
-- existing_target_index_count=0, existing_target_policy_count=0.

SELECT 'source_table_count' AS check_name, count(*)::text AS actual
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('users', 'media_assets');

SELECT 'source_uuid_key_count' AS check_name, count(*)::text AS actual
FROM information_schema.columns
WHERE table_schema = 'public'
  AND (table_name, column_name, udt_name) IN (
    ('users', 'id', 'uuid'),
    ('media_assets', 'id', 'uuid')
  );

SELECT 'source_media_position_unique_index_count' AS check_name,
       count(*)::text AS actual
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname IN (
    'media_assets_draft_position_key',
    'media_assets_case_position_key',
    'media_assets_comment_position_key'
  )
  AND indexdef ILIKE 'CREATE UNIQUE INDEX%';

SELECT 'can_create_public' AS check_name,
       has_schema_privilege(current_user, 'public', 'CREATE')::text AS actual;

SELECT 'existing_target_table_count' AS check_name, count(*)::text AS actual
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
    'idempotency_records', 'outbox_events', 'media_upload_sessions'
  );

SELECT 'existing_verification_version_count' AS check_name,
       count(*)::text AS actual
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'media_assets'
  AND column_name = 'verification_version';

SELECT 'existing_target_index_count' AS check_name, count(*)::text AS actual
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname IN (
    'idempotency_records_scope_key',
    'idempotency_records_expires_idx',
    'idempotency_records_user_created_idx',
    'outbox_events_dedupe_key_key',
    'outbox_events_claim_idx',
    'outbox_events_aggregate_created_idx',
    'media_upload_sessions_staging_storage_key_key',
    'media_upload_sessions_sanitized_storage_key_key',
    'media_upload_sessions_expiry_idx'
  );

SELECT 'existing_target_policy_count' AS check_name, count(*)::text AS actual
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'idempotency_records', 'outbox_events', 'media_upload_sessions'
  );
