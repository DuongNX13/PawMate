-- Development/test seed only. Do not run this file against production.
\set ON_ERROR_STOP on

BEGIN;

INSERT INTO public.adoption_chat_participants (
  thread_id,
  user_id,
  role,
  last_read_at,
  last_read_sequence,
  created_at,
  updated_at
)
SELECT
  t.id,
  t.adopter_user_id,
  'adopter',
  t.created_at,
  0,
  t.created_at,
  t.updated_at
FROM public.adoption_chat_threads t
ON CONFLICT (thread_id, user_id) DO NOTHING;

INSERT INTO public.adoption_chat_participants (
  thread_id,
  user_id,
  role,
  last_read_at,
  last_read_sequence,
  created_at,
  updated_at
)
SELECT
  t.id,
  t.shelter_id,
  'shelter',
  t.created_at,
  0,
  t.created_at,
  t.updated_at
FROM public.adoption_chat_threads t
ON CONFLICT (thread_id, user_id) DO NOTHING;

INSERT INTO public.media_assets (
  id,
  owner_user_id,
  purpose,
  mime_type,
  size_bytes,
  sha256,
  status,
  storage_key,
  public_url,
  width,
  height,
  verification_version,
  verified_at,
  created_at,
  updated_at
)
SELECT
  '52000000-0000-4000-8000-000000000003',
  t.adopter_user_id,
  'adoption_chat',
  'image/webp',
  4096,
  repeat('6', 64),
  'verified',
  'day51/adoption/chat/proof.webp',
  'https://example.invalid/day51/adoption/chat/proof.webp',
  800,
  600,
  1,
  '2026-07-27T11:00:00Z',
  '2026-07-27T11:00:00Z',
  '2026-07-27T11:00:00Z'
FROM public.adoption_chat_threads t
ORDER BY t.created_at
LIMIT 1
ON CONFLICT (id) DO NOTHING;

WITH target_thread AS (
  SELECT *
  FROM public.adoption_chat_threads
  ORDER BY created_at
  LIMIT 1
),
inserted_message AS (
  INSERT INTO public.adoption_chat_messages (
    id,
    thread_id,
    sender_user_id,
    body,
    created_at,
    updated_at
  )
  SELECT
    '52000000-0000-4000-8000-000000000001',
    id,
    adopter_user_id,
    'Toi co the hen phong van vao thu Bay khong?',
    '2026-07-27T11:01:00Z',
    '2026-07-27T11:01:00Z'
  FROM target_thread
  ON CONFLICT (id) DO NOTHING
  RETURNING id
)
UPDATE public.media_assets
SET adoption_chat_message_id =
      '52000000-0000-4000-8000-000000000001',
    position = 0,
    status = 'attached',
    updated_at = '2026-07-27T11:01:00Z'
WHERE id = '52000000-0000-4000-8000-000000000003'
  AND EXISTS (
    SELECT 1
    FROM public.adoption_chat_messages
    WHERE id = '52000000-0000-4000-8000-000000000001'
  );

COMMIT;

SELECT 'DAY51_ADOPTION_CHAT_SEED_PASS' AS status;
