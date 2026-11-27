-- Day 36 postflight. Expected values:
-- table_count=3, rls_count=3, policy_count=0,
-- invalid_constraint_count=0, foreign_key_count=3,
-- required_index_count=12, valid_required_index_count=12,
-- partial_index_count=5, plaintext_idempotency_key_count=0,
-- upload_audit_column_count=12, outbox_delivery_column_count=7,
-- postgrest_base_table_privilege_count=0.

SELECT 'table_count' AS check_name, count(*)::text AS actual
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
    'idempotency_records', 'outbox_events', 'media_upload_sessions'
  );

SELECT 'verification_version_contract' AS check_name,
       concat_ws(':', is_nullable, data_type, column_default) AS actual
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'media_assets'
  AND column_name = 'verification_version';

SELECT 'idempotency_hash_column_count' AS check_name,
       count(*)::text AS actual
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'idempotency_records'
  AND column_name IN ('key_hash', 'request_hash')
  AND data_type = 'character'
  AND character_maximum_length = 64;

SELECT 'plaintext_idempotency_key_count' AS check_name,
       count(*)::text AS actual
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'idempotency_records'
  AND column_name IN ('key', 'idempotency_key', 'raw_key');

SELECT 'idempotency_response_jsonb_count' AS check_name,
       count(*)::text AS actual
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'idempotency_records'
  AND column_name = 'response_body'
  AND udt_name = 'jsonb';

SELECT 'upload_audit_column_count' AS check_name, count(*)::text AS actual
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'media_upload_sessions'
  AND column_name IN (
    'staging_storage_key', 'upload_expires_at',
    'detected_mime_type', 'detected_size_bytes',
    'sanitized_storage_key', 'sanitized_sha256', 'storage_etag',
    'verification_started_at', 'lease_until',
    'completed_at', 'rejected_at', 'rejection_code'
  );

SELECT 'outbox_delivery_column_count' AS check_name, count(*)::text AS actual
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'outbox_events'
  AND column_name IN (
    'available_at', 'locked_at', 'lock_expires_at', 'locked_by',
    'attempts', 'processed_at', 'last_error'
  );

SELECT 'rls_count' AS check_name, count(*)::text AS actual
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN (
    'idempotency_records', 'outbox_events', 'media_upload_sessions'
  )
  AND c.relrowsecurity;

SELECT 'policy_count' AS check_name, count(*)::text AS actual
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'idempotency_records', 'outbox_events', 'media_upload_sessions'
  );

SELECT 'foreign_key_count' AS check_name, count(*)::text AS actual
FROM pg_constraint pc
JOIN pg_class c ON c.oid = pc.conrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND pc.conname IN (
    'idempotency_records_user_fkey',
    'outbox_events_actor_fkey',
    'media_upload_sessions_media_fkey'
  )
  AND pc.contype = 'f';

SELECT 'critical_check_constraint_count' AS check_name,
       count(*)::text AS actual
FROM pg_constraint pc
JOIN pg_class c ON c.oid = pc.conrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND pc.conname IN (
    'media_assets_size_check',
    'media_assets_verification_version_check',
    'idempotency_records_key_hash_check',
    'idempotency_records_request_hash_check',
    'idempotency_records_retention_check',
    'outbox_events_payload_check',
    'outbox_events_lock_state_check',
    'media_upload_sessions_detected_pair_check',
    'media_upload_sessions_detected_mime_check',
    'media_upload_sessions_detected_size_check',
    'media_upload_sessions_sanitized_pair_check',
    'media_upload_sessions_sanitized_sha256_check',
    'media_upload_sessions_lease_check',
    'media_upload_sessions_completion_check'
  )
  AND pc.contype = 'c';

SELECT 'media_size_50mb_constraint_count' AS check_name,
       count(*)::text AS actual
FROM pg_constraint pc
JOIN pg_class c ON c.oid = pc.conrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND pc.conname IN (
    'media_assets_size_check',
    'media_upload_sessions_detected_size_check'
  )
  AND pg_get_constraintdef(pc.oid) LIKE '%52428800%'
  AND pg_get_constraintdef(pc.oid) NOT LIKE '%104857600%';

SELECT 'legacy_100mb_constraint_count' AS check_name,
       count(*)::text AS actual
FROM pg_constraint pc
JOIN pg_class c ON c.oid = pc.conrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND pc.conname IN (
    'media_assets_size_check',
    'media_upload_sessions_detected_size_check'
  )
  AND pg_get_constraintdef(pc.oid) LIKE '%104857600%';

SELECT 'invalid_constraint_count' AS check_name, count(*)::text AS actual
FROM pg_constraint pc
JOIN pg_class c ON c.oid = pc.conrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN (
    'media_assets', 'idempotency_records',
    'outbox_events', 'media_upload_sessions'
  )
  AND NOT pc.convalidated;

SELECT 'required_index_count' AS check_name, count(*)::text AS actual
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
    'media_upload_sessions_expiry_idx',
    'media_assets_draft_position_key',
    'media_assets_case_position_key',
    'media_assets_comment_position_key'
  );

SELECT 'valid_required_index_count' AS check_name, count(*)::text AS actual
FROM pg_index i
JOIN pg_class c ON c.oid = i.indexrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN (
    'idempotency_records_scope_key',
    'idempotency_records_expires_idx',
    'idempotency_records_user_created_idx',
    'outbox_events_dedupe_key_key',
    'outbox_events_claim_idx',
    'outbox_events_aggregate_created_idx',
    'media_upload_sessions_staging_storage_key_key',
    'media_upload_sessions_sanitized_storage_key_key',
    'media_upload_sessions_expiry_idx',
    'media_assets_draft_position_key',
    'media_assets_case_position_key',
    'media_assets_comment_position_key'
  )
  AND i.indisvalid
  AND i.indisready;

SELECT 'partial_index_count' AS check_name, count(*)::text AS actual
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname IN (
    'outbox_events_claim_idx',
    'media_upload_sessions_expiry_idx',
    'media_assets_draft_position_key',
    'media_assets_case_position_key',
    'media_assets_comment_position_key'
  )
  AND indexdef ILIKE '% WHERE %';

SELECT 'postgrest_base_table_privilege_count' AS check_name,
       count(*)::text AS actual
FROM pg_roles r
CROSS JOIN unnest(ARRAY[
  'public.idempotency_records',
  'public.outbox_events',
  'public.media_upload_sessions'
]) AS table_name
WHERE r.rolname IN ('anon', 'authenticated')
  AND has_table_privilege(
    r.rolname,
    table_name,
    'SELECT,INSERT,UPDATE,DELETE'
  );
