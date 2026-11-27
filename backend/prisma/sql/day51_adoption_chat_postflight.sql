\set ON_ERROR_STOP on

DO $$
DECLARE
  missing_tables text[];
  rls_count integer;
  expected_participants bigint;
  actual_participants bigint;
BEGIN
  SELECT array_agg(required_table)
  INTO missing_tables
  FROM (
    VALUES
      ('public.adoption_chat_participants'),
      ('public.adoption_chat_messages')
  ) AS required(required_table)
  WHERE to_regclass(required_table) IS NULL;

  IF missing_tables IS NOT NULL THEN
    RAISE EXCEPTION
      'Day 51 postflight failed; missing tables: %',
      array_to_string(missing_tables, ', ');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'media_assets'
      AND column_name = 'adoption_chat_message_id'
      AND data_type = 'uuid'
  ) THEN
    RAISE EXCEPTION
      'Day 51 postflight failed; media chat binding column is missing';
  END IF;

  IF pg_get_functiondef(
    'public.enforce_adoption_chat_participant_role()'::regprocedure
  ) NOT LIKE '%Chat read sequence cannot move backwards%' THEN
    RAISE EXCEPTION
      'Day 51 postflight failed; monotonic read-sequence guard is missing';
  END IF;

  IF (
    SELECT count(*)
    FROM pg_constraint
    WHERE conname IN (
      'adoption_chat_participants_thread_role_key',
      'adoption_chat_participants_last_read_sequence_check',
      'adoption_chat_messages_sender_participant_fkey',
      'adoption_chat_messages_body_check',
      'media_assets_adoption_chat_message_fkey',
      'media_assets_entity_count_check',
      'media_assets_purpose_entity_check'
    )
  ) <> 7 THEN
    RAISE EXCEPTION
      'Day 51 postflight failed; one or more integrity constraints are missing';
  END IF;

  IF (
    SELECT count(*)
    FROM pg_indexes
    WHERE schemaname = 'public'
      AND indexname IN (
        'adoption_chat_participants_user_updated_idx',
        'adoption_chat_messages_thread_sequence_idx',
        'media_assets_adoption_chat_message_position_idx',
        'media_assets_adoption_chat_message_position_key'
      )
  ) <> 4 THEN
    RAISE EXCEPTION
      'Day 51 postflight failed; one or more indexes are missing';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'adoption_chat_participants_role_guard'
      AND NOT tgisinternal
  ) THEN
    RAISE EXCEPTION
      'Day 51 postflight failed; participant role guard trigger is missing';
  END IF;

  SELECT count(*)
  INTO rls_count
  FROM pg_class c
  JOIN pg_namespace n ON n.oid = c.relnamespace
  WHERE n.nspname = 'public'
    AND c.relname IN (
      'adoption_chat_participants',
      'adoption_chat_messages'
    )
    AND c.relrowsecurity;

  IF rls_count <> 2 THEN
    RAISE EXCEPTION
      'Day 51 postflight failed; deny-by-default RLS is not enabled';
  END IF;

  SELECT count(*) * 2
  INTO expected_participants
  FROM public.adoption_chat_threads;

  SELECT count(*)
  INTO actual_participants
  FROM public.adoption_chat_participants;

  IF actual_participants <> expected_participants THEN
    RAISE EXCEPTION
      'Day 51 postflight failed; participant backfill mismatch: expected %, actual %',
      expected_participants,
      actual_participants;
  END IF;
END
$$;

SELECT
  'DAY51_ADOPTION_CHAT_POSTFLIGHT_PASS' AS status,
  (SELECT count(*) FROM public.adoption_chat_participants) AS participant_count,
  (SELECT count(*) FROM public.adoption_chat_messages) AS message_count,
  (
    SELECT count(*)
    FROM public.media_assets
    WHERE adoption_chat_message_id IS NOT NULL
  ) AS attached_media_count;
