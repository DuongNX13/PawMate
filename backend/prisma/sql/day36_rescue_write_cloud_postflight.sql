-- Day 36 cloud proof: one result set so Supabase SQL Editor captures every
-- required invariant in a single screenshot. This query is read-only.
SELECT check_name, actual
FROM (
  VALUES
    (
      'table_count',
      (SELECT count(*)::text FROM information_schema.tables
       WHERE table_schema = 'public'
         AND table_name IN ('idempotency_records', 'outbox_events', 'media_upload_sessions'))
    ),
    (
      'verification_version_contract',
      (SELECT concat_ws(':', is_nullable, data_type, column_default)
       FROM information_schema.columns
       WHERE table_schema = 'public'
         AND table_name = 'media_assets'
         AND column_name = 'verification_version')
    ),
    (
      'idempotency_hash_column_count',
      (SELECT count(*)::text FROM information_schema.columns
       WHERE table_schema = 'public'
         AND table_name = 'idempotency_records'
         AND column_name IN ('key_hash', 'request_hash')
         AND data_type = 'character'
         AND character_maximum_length = 64)
    ),
    (
      'plaintext_idempotency_key_count',
      (SELECT count(*)::text FROM information_schema.columns
       WHERE table_schema = 'public'
         AND table_name = 'idempotency_records'
         AND column_name IN ('key', 'idempotency_key', 'raw_key'))
    ),
    (
      'idempotency_response_jsonb_count',
      (SELECT count(*)::text FROM information_schema.columns
       WHERE table_schema = 'public'
         AND table_name = 'idempotency_records'
         AND column_name = 'response_body'
         AND udt_name = 'jsonb')
    ),
    (
      'upload_audit_column_count',
      (SELECT count(*)::text FROM information_schema.columns
       WHERE table_schema = 'public'
         AND table_name = 'media_upload_sessions'
         AND column_name IN (
           'staging_storage_key', 'upload_expires_at',
           'detected_mime_type', 'detected_size_bytes',
           'sanitized_storage_key', 'sanitized_sha256', 'storage_etag',
           'verification_started_at', 'lease_until',
           'completed_at', 'rejected_at', 'rejection_code'
         ))
    ),
    (
      'outbox_delivery_column_count',
      (SELECT count(*)::text FROM information_schema.columns
       WHERE table_schema = 'public'
         AND table_name = 'outbox_events'
         AND column_name IN (
           'available_at', 'locked_at', 'lock_expires_at', 'locked_by',
           'attempts', 'processed_at', 'last_error'
         ))
    ),
    (
      'rls_count',
      (SELECT count(*)::text FROM pg_class c
       JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE n.nspname = 'public'
         AND c.relname IN ('idempotency_records', 'outbox_events', 'media_upload_sessions')
         AND c.relrowsecurity)
    ),
    (
      'policy_count',
      (SELECT count(*)::text FROM pg_policies
       WHERE schemaname = 'public'
         AND tablename IN ('idempotency_records', 'outbox_events', 'media_upload_sessions'))
    ),
    (
      'foreign_key_count',
      (SELECT count(*)::text FROM pg_constraint pc
       JOIN pg_class c ON c.oid = pc.conrelid
       JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE n.nspname = 'public'
         AND pc.conname IN (
           'idempotency_records_user_fkey',
           'outbox_events_actor_fkey',
           'media_upload_sessions_media_fkey'
         )
         AND pc.contype = 'f')
    ),
    (
      'critical_check_constraint_count',
      (SELECT count(*)::text FROM pg_constraint pc
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
         AND pc.contype = 'c')
    ),
    (
      'media_size_50mb_constraint_count',
      (SELECT count(*)::text FROM pg_constraint pc
       JOIN pg_class c ON c.oid = pc.conrelid
       JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE n.nspname = 'public'
         AND pc.conname IN (
           'media_assets_size_check',
           'media_upload_sessions_detected_size_check'
         )
         AND pg_get_constraintdef(pc.oid) LIKE '%52428800%'
         AND pg_get_constraintdef(pc.oid) NOT LIKE '%104857600%')
    ),
    (
      'legacy_100mb_constraint_count',
      (SELECT count(*)::text FROM pg_constraint pc
       JOIN pg_class c ON c.oid = pc.conrelid
       JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE n.nspname = 'public'
         AND pc.conname IN (
           'media_assets_size_check',
           'media_upload_sessions_detected_size_check'
         )
         AND pg_get_constraintdef(pc.oid) LIKE '%104857600%')
    ),
    (
      'invalid_constraint_count',
      (SELECT count(*)::text FROM pg_constraint pc
       JOIN pg_class c ON c.oid = pc.conrelid
       JOIN pg_namespace n ON n.oid = c.relnamespace
       WHERE n.nspname = 'public'
         AND c.relname IN (
           'media_assets', 'idempotency_records',
           'outbox_events', 'media_upload_sessions'
         )
         AND NOT pc.convalidated)
    ),
    (
      'required_index_count',
      (SELECT count(*)::text FROM pg_indexes
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
         ))
    ),
    (
      'valid_required_index_count',
      (SELECT count(*)::text FROM pg_index i
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
         AND i.indisready)
    ),
    (
      'partial_index_count',
      (SELECT count(*)::text FROM pg_indexes
       WHERE schemaname = 'public'
         AND indexname IN (
           'outbox_events_claim_idx',
           'media_upload_sessions_expiry_idx',
           'media_assets_draft_position_key',
           'media_assets_case_position_key',
           'media_assets_comment_position_key'
         )
         AND indexdef ILIKE '% WHERE %')
    ),
    (
      'postgrest_base_table_privilege_count',
      (SELECT count(*)::text
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
         ))
    )
) AS checks(check_name, actual)
ORDER BY check_name;
