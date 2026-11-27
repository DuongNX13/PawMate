BEGIN;
SET LOCAL lock_timeout = '5s';
SET LOCAL statement_timeout = '60s';

-- The backend runtime is a credential-bearing identity whose password is
-- provisioned outside this migration. Creating it without a password keeps it
-- unusable over password authentication until the deployment secret is set.
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'pawmate_runtime') THEN
    CREATE ROLE pawmate_runtime
      LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_roles WHERE rolname = 'pawmate_reminder_worker'
  ) THEN
    CREATE ROLE pawmate_reminder_worker
      NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'pawmate_scheduler') THEN
    RAISE EXCEPTION
      'pawmate_scheduler must be provisioned before Day 136 migration';
  END IF;
END
$$;

-- Supabase's dashboard postgres role has CREATEROLE but is intentionally not a
-- real superuser. PostgreSQL therefore rejects ALTER ROLE clauses that mention
-- SUPERUSER, REPLICATION or BYPASSRLS, even when the requested value is the
-- already-safe negative value. Enforce those attributes by validation instead
-- of attempting a privileged mutation; fail closed if an existing role is
-- unexpectedly elevated.
DO $$
DECLARE
  unsafe_roles text;
BEGIN
  SELECT string_agg(rolname, ', ' ORDER BY rolname)
  INTO unsafe_roles
  FROM pg_roles
  WHERE rolname IN (
    'pawmate_runtime', 'pawmate_reminder_worker', 'pawmate_scheduler'
  )
    AND (rolsuper OR rolreplication OR rolbypassrls);

  IF unsafe_roles IS NOT NULL THEN
    RAISE EXCEPTION
      'Day 136 refuses elevated role attributes for: %', unsafe_roles;
  END IF;
END
$$;

ALTER ROLE pawmate_runtime LOGIN NOCREATEROLE;
ALTER ROLE pawmate_reminder_worker NOLOGIN NOCREATEROLE;

DO $$
DECLARE
  unsafe_roles text;
BEGIN
  SELECT string_agg(rolname, ', ' ORDER BY rolname)
  INTO unsafe_roles
  FROM pg_roles
  WHERE rolname IN (
    'pawmate_runtime', 'pawmate_reminder_worker', 'pawmate_scheduler'
  )
    AND (rolsuper OR rolcreatedb OR rolcreaterole OR rolreplication OR rolbypassrls);

  IF unsafe_roles IS NOT NULL THEN
    RAISE EXCEPTION
      'Day 136 role hardening verification failed for: %', unsafe_roles;
  END IF;
END
$$;

GRANT pawmate_reminder_worker TO pawmate_scheduler;

GRANT USAGE ON SCHEMA public TO pawmate_runtime, pawmate_reminder_worker;
REVOKE CREATE ON SCHEMA public
  FROM pawmate_runtime, pawmate_reminder_worker, pawmate_scheduler;

DO $$
DECLARE
  app_table text;
  blocked_role text;
  table_names constant text[] := ARRAY[
    'users',
    'notification_preferences',
    'privacy_defaults',
    'sessions',
    'pets',
    'vets',
    'vet_services',
    'reviews',
    'review_helpful_votes',
    'review_reports',
    'health_records',
    'reminders',
    'notifications',
    'rescue_case_drafts',
    'rescue_cases',
    'rescue_case_private_locations',
    'media_assets',
    'idempotency_records',
    'outbox_events',
    'media_upload_sessions',
    'rescue_comments',
    'rescue_status_events',
    'adoption_listings',
    'adoption_decisions',
    'adoption_requests',
    'adoption_chat_threads',
    'adoption_chat_participants',
    'adoption_chat_messages'
  ];
BEGIN
  FOREACH app_table IN ARRAY table_names LOOP
    IF to_regclass(format('public.%I', app_table)) IS NULL THEN
      RAISE EXCEPTION 'Day 136 expected table public.% is missing', app_table;
    END IF;

    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', app_table);

    FOREACH blocked_role IN ARRAY ARRAY[
      'anon',
      'authenticated',
      'service_role',
      'pawmate_scheduler',
      'pawmate_reminder_worker',
      'pawmate_runtime'
    ] LOOP
      IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = blocked_role) THEN
        EXECUTE format(
          'REVOKE ALL PRIVILEGES ON TABLE public.%I FROM %I',
          app_table,
          blocked_role
        );
      END IF;
    END LOOP;

    EXECUTE format(
      'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.%I TO pawmate_runtime',
      app_table
    );

    EXECUTE format(
      'DROP POLICY IF EXISTS %I ON public.%I',
      'day136_runtime_all_' || app_table,
      app_table
    );
    EXECUTE format(
      'CREATE POLICY %I ON public.%I AS PERMISSIVE FOR ALL TO pawmate_runtime USING (true) WITH CHECK (true)',
      'day136_runtime_all_' || app_table,
      app_table
    );
  END LOOP;
END
$$;

-- The scheduled job reads and updates due reminders and upserts notifications.
-- It does not need pet/user reads, deletes, sequences, DDL, or other app tables.
GRANT SELECT, UPDATE ON TABLE public.reminders TO pawmate_reminder_worker;
GRANT SELECT, INSERT, UPDATE ON TABLE public.notifications
  TO pawmate_reminder_worker;

DROP POLICY IF EXISTS day136_worker_select_reminders ON public.reminders;
CREATE POLICY day136_worker_select_reminders
  ON public.reminders
  AS PERMISSIVE
  FOR SELECT
  TO pawmate_reminder_worker
  USING (true);

DROP POLICY IF EXISTS day136_worker_update_reminders ON public.reminders;
CREATE POLICY day136_worker_update_reminders
  ON public.reminders
  AS PERMISSIVE
  FOR UPDATE
  TO pawmate_reminder_worker
  USING (true)
  WITH CHECK (true);

DROP POLICY IF EXISTS day136_worker_select_notifications ON public.notifications;
CREATE POLICY day136_worker_select_notifications
  ON public.notifications
  AS PERMISSIVE
  FOR SELECT
  TO pawmate_reminder_worker
  USING (true);

DROP POLICY IF EXISTS day136_worker_insert_notifications ON public.notifications;
CREATE POLICY day136_worker_insert_notifications
  ON public.notifications
  AS PERMISSIVE
  FOR INSERT
  TO pawmate_reminder_worker
  WITH CHECK (true);

DROP POLICY IF EXISTS day136_worker_update_notifications ON public.notifications;
CREATE POLICY day136_worker_update_notifications
  ON public.notifications
  AS PERMISSIVE
  FOR UPDATE
  TO pawmate_reminder_worker
  USING (true)
  WITH CHECK (true);

-- Remove direct PostgREST/RPC access to app-owned functions. Trigger and event
-- trigger execution is unaffected by revoking direct EXECUTE from callers.
DO $$
DECLARE
  fn record;
  blocked_role text;
BEGIN
  FOR fn IN
    SELECT p.oid::regprocedure AS signature
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND NOT EXISTS (
        SELECT 1
        FROM pg_depend d
        JOIN pg_extension e ON e.oid = d.refobjid
        WHERE d.classid = 'pg_proc'::regclass
          AND d.objid = p.oid
          AND d.deptype = 'e'
      )
  LOOP
    EXECUTE format('REVOKE ALL PRIVILEGES ON FUNCTION %s FROM PUBLIC', fn.signature);
    FOREACH blocked_role IN ARRAY ARRAY[
      'anon', 'authenticated', 'service_role',
      'pawmate_runtime', 'pawmate_reminder_worker', 'pawmate_scheduler'
    ] LOOP
      IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = blocked_role) THEN
        EXECUTE format(
          'REVOKE ALL PRIVILEGES ON FUNCTION %s FROM %I',
          fn.signature,
          blocked_role
        );
      END IF;
    END LOOP;
  END LOOP;
END
$$;

DO $$
DECLARE
  seq record;
  blocked_role text;
BEGIN
  FOR seq IN
    SELECT c.relname
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relkind = 'S'
  LOOP
    FOREACH blocked_role IN ARRAY ARRAY[
      'anon', 'authenticated', 'service_role',
      'pawmate_scheduler', 'pawmate_reminder_worker', 'pawmate_runtime'
    ] LOOP
      IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = blocked_role) THEN
        EXECUTE format(
          'REVOKE ALL PRIVILEGES ON SEQUENCE public.%I FROM %I',
          seq.relname,
          blocked_role
        );
      END IF;
    END LOOP;
    EXECUTE format(
      'GRANT USAGE, SELECT ON SEQUENCE public.%I TO pawmate_runtime',
      seq.relname
    );
  END LOOP;
END
$$;

-- Prevent later Prisma/app objects owned by an app-schema owner from silently
-- regaining Supabase's broad default grants. Platform schemas are untouched.
DO $$
DECLARE
  owner_name text;
  blocked_role text;
  grantee_sql text;
BEGIN
  FOR owner_name IN
    SELECT DISTINCT pg_get_userbyid(c.relowner)
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = ANY (ARRAY[
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
  LOOP
    IF owner_name <> current_user
       AND NOT pg_has_role(current_user, owner_name, 'MEMBER') THEN
      RAISE EXCEPTION
        'Current user % cannot alter default privileges for app owner %',
        current_user,
        owner_name;
    END IF;

    FOREACH blocked_role IN ARRAY ARRAY[
      'PUBLIC', 'anon', 'authenticated', 'service_role',
      'pawmate_runtime', 'pawmate_reminder_worker', 'pawmate_scheduler'
    ] LOOP
      IF blocked_role = 'PUBLIC'
         OR EXISTS (SELECT 1 FROM pg_roles WHERE rolname = blocked_role) THEN
        grantee_sql := CASE
          WHEN blocked_role = 'PUBLIC' THEN 'PUBLIC'
          ELSE format('%I', blocked_role)
        END;
        EXECUTE format(
          'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public REVOKE ALL ON TABLES FROM %s',
          owner_name,
          grantee_sql
        );
        EXECUTE format(
          'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public REVOKE ALL ON SEQUENCES FROM %s',
          owner_name,
          grantee_sql
        );
        EXECUTE format(
          'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM %s',
          owner_name,
          grantee_sql
        );
      END IF;
    END LOOP;

    EXECUTE format(
      'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO pawmate_runtime',
      owner_name
    );
    EXECUTE format(
      'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO pawmate_runtime',
      owner_name
    );
  END LOOP;
END
$$;

COMMIT;

SELECT 'DAY136_LEAST_PRIVILEGE_PATCH_PASS' AS status;
