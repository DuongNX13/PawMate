WITH app_tables(table_name) AS (
  SELECT unnest(ARRAY[
    'users', 'notification_preferences', 'privacy_defaults', 'sessions',
    'pets', 'vets', 'vet_services', 'reviews', 'review_helpful_votes',
    'review_reports', 'health_records', 'reminders', 'notifications',
    'rescue_case_drafts', 'rescue_cases',
    'rescue_case_private_locations', 'media_assets',
    'idempotency_records', 'outbox_events', 'media_upload_sessions',
    'rescue_comments', 'rescue_status_events', 'adoption_listings',
    'adoption_decisions', 'adoption_requests', 'adoption_chat_threads',
    'adoption_chat_participants', 'adoption_chat_messages'
  ])
), role_state AS (
  SELECT rolname, rolcanlogin, rolsuper, rolcreatedb, rolcreaterole,
         rolreplication, rolbypassrls
  FROM pg_roles
  WHERE rolname IN (
    'pawmate_runtime', 'pawmate_reminder_worker', 'pawmate_scheduler'
  )
), forbidden_direct AS (
  SELECT g.grantee, g.table_name, g.privilege_type
  FROM information_schema.role_table_grants g
  JOIN app_tables a USING (table_name)
  WHERE g.table_schema = 'public'
    AND g.grantee IN ('anon', 'authenticated', 'service_role')
), runtime_bad AS (
  SELECT a.table_name
  FROM app_tables a
  WHERE NOT (
    has_table_privilege('pawmate_runtime', format('public.%I', a.table_name), 'SELECT')
    AND has_table_privilege('pawmate_runtime', format('public.%I', a.table_name), 'INSERT')
    AND has_table_privilege('pawmate_runtime', format('public.%I', a.table_name), 'UPDATE')
    AND has_table_privilege('pawmate_runtime', format('public.%I', a.table_name), 'DELETE')
  )
  OR has_table_privilege('pawmate_runtime', format('public.%I', a.table_name), 'TRUNCATE')
), worker_bad AS (
  SELECT a.table_name
  FROM app_tables a
  WHERE a.table_name NOT IN ('reminders', 'notifications')
    AND has_any_column_privilege(
      'pawmate_reminder_worker',
      format('public.%I', a.table_name),
      'SELECT,INSERT,UPDATE'
    )
), missing_runtime_policies AS (
  SELECT a.table_name
  FROM app_tables a
  WHERE NOT EXISTS (
    SELECT 1 FROM pg_policies p
    WHERE p.schemaname = 'public'
      AND p.tablename = a.table_name
      AND p.policyname = 'day136_runtime_all_' || a.table_name
      AND p.cmd = 'ALL'
      AND 'pawmate_runtime' = ANY (p.roles)
  )
)
SELECT jsonb_build_object(
  'status', CASE WHEN
    (SELECT count(*) FROM role_state) = 3
    AND NOT EXISTS (
      SELECT 1 FROM role_state
      WHERE rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls
    )
    AND NOT EXISTS (SELECT 1 FROM forbidden_direct)
    AND NOT EXISTS (SELECT 1 FROM runtime_bad)
    AND NOT EXISTS (SELECT 1 FROM worker_bad)
    AND NOT EXISTS (SELECT 1 FROM missing_runtime_policies)
    AND has_table_privilege('pawmate_reminder_worker', 'public.reminders', 'SELECT,UPDATE')
    AND has_table_privilege('pawmate_reminder_worker', 'public.notifications', 'SELECT,INSERT,UPDATE')
    AND NOT has_table_privilege('pawmate_reminder_worker', 'public.reminders', 'INSERT,DELETE,TRUNCATE')
    AND NOT has_table_privilege('pawmate_reminder_worker', 'public.notifications', 'DELETE,TRUNCATE')
    THEN 'PASS' ELSE 'FAIL' END,
  'roles', (SELECT jsonb_agg(to_jsonb(r) ORDER BY rolname) FROM role_state r),
  'forbidden_direct_grants', COALESCE((SELECT jsonb_agg(to_jsonb(f)) FROM forbidden_direct f), '[]'::jsonb),
  'runtime_bad_tables', COALESCE((SELECT jsonb_agg(table_name) FROM runtime_bad), '[]'::jsonb),
  'worker_bad_tables', COALESCE((SELECT jsonb_agg(table_name) FROM worker_bad), '[]'::jsonb),
  'missing_runtime_policies', COALESCE((SELECT jsonb_agg(table_name) FROM missing_runtime_policies), '[]'::jsonb)
) AS day136_postflight;
