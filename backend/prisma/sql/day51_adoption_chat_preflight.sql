\set ON_ERROR_STOP on

DO $$
DECLARE
  missing_tables text[];
  partial_objects integer;
BEGIN
  SELECT array_agg(required_table)
  INTO missing_tables
  FROM (
    VALUES
      ('public.users'),
      ('public.media_assets'),
      ('public.idempotency_records'),
      ('public.outbox_events'),
      ('public.adoption_requests'),
      ('public.adoption_chat_threads')
  ) AS required(required_table)
  WHERE to_regclass(required_table) IS NULL;

  IF missing_tables IS NOT NULL THEN
    RAISE EXCEPTION
      'Day 51 preflight failed; missing base tables: %',
      array_to_string(missing_tables, ', ');
  END IF;

  SELECT
    (CASE WHEN to_regclass('public.adoption_chat_participants') IS NOT NULL THEN 1 ELSE 0 END)
    + (CASE WHEN to_regclass('public.adoption_chat_messages') IS NOT NULL THEN 1 ELSE 0 END)
    + (CASE WHEN EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'AdoptionChatParticipantRole'
      ) THEN 1 ELSE 0 END)
    + (CASE WHEN EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'media_assets'
          AND column_name = 'adoption_chat_message_id'
      ) THEN 1 ELSE 0 END)
  INTO partial_objects;

  IF partial_objects <> 0 THEN
    RAISE EXCEPTION
      'Day 51 preflight failed; partial or previously applied chat schema detected (% objects)',
      partial_objects;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'MediaPurpose'
  ) OR NOT EXISTS (
    SELECT 1
    FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typname = 'MediaPurpose'
      AND e.enumlabel = 'adoption_chat'
  ) THEN
    RAISE EXCEPTION
      'Day 51 preflight failed; MediaPurpose.adoption_chat is missing';
  END IF;
END
$$;

SELECT 'DAY51_ADOPTION_CHAT_PREFLIGHT_PASS' AS status;
