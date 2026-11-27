-- Development/test seed for Day 34 Rescue persistence.
-- Do not run this file against production or the shared Supabase cloud project.
BEGIN;

INSERT INTO public.users (id, email, display_name, email_verified, created_at, updated_at)
VALUES (
  '34000000-0000-4000-8000-000000000001',
  'day34-rescue-seed@pawmate.local',
  'Day 34 Rescue Seed',
  true,
  '2026-07-17T00:00:00Z',
  '2026-07-17T00:00:00Z'
)
ON CONFLICT (id) DO UPDATE
SET display_name = EXCLUDED.display_name,
    updated_at = EXCLUDED.updated_at;

INSERT INTO public.rescue_case_drafts (
  id,
  owner_user_id,
  source,
  pet_name,
  species,
  breed_or_color,
  lost_at,
  exact_latitude,
  exact_longitude,
  formatted_address,
  area_label,
  privacy_radius_meters,
  identifying_features,
  behavior_hint,
  contact_preference,
  version,
  published_at,
  created_at,
  updated_at
)
VALUES (
  '34000000-0000-4000-8000-000000000002',
  '34000000-0000-4000-8000-000000000001',
  'rescue_home',
  'Milo',
  'dog',
  'Poodle nâu nhạt',
  '2026-07-16T14:30:00Z',
  10.776889,
  106.700806,
  '12 Nguyễn Huệ, Phường Sài Gòn, TP.HCM',
  'Khu vực trung tâm Quận 1, TP.HCM',
  500,
  'Đeo vòng cổ xanh, có đốm trắng ở chân trước.',
  'Phản ứng khi được gọi Milo.',
  'in_app',
  2,
  '2026-07-17T00:05:00Z',
  '2026-07-17T00:00:00Z',
  '2026-07-17T00:05:00Z'
)
ON CONFLICT (id) DO UPDATE
SET updated_at = EXCLUDED.updated_at;

INSERT INTO public.rescue_cases (
  id,
  source_draft_id,
  owner_user_id,
  pet_name,
  species,
  breed_or_color,
  lost_at,
  area_label,
  approximate_latitude,
  approximate_longitude,
  privacy_radius_meters,
  identifying_features,
  behavior_hint,
  contact_preference,
  status,
  version,
  comment_count,
  created_at,
  updated_at
)
VALUES (
  '34000000-0000-4000-8000-000000000003',
  '34000000-0000-4000-8000-000000000002',
  '34000000-0000-4000-8000-000000000001',
  'Milo',
  'dog',
  'Poodle nâu nhạt',
  '2026-07-16T14:30:00Z',
  'Khu vực trung tâm Quận 1, TP.HCM',
  10.777000,
  106.701000,
  500,
  'Đeo vòng cổ xanh, có đốm trắng ở chân trước.',
  'Phản ứng khi được gọi Milo.',
  'in_app',
  'missing',
  1,
  1,
  '2026-07-17T00:05:00Z',
  '2026-07-17T00:05:00Z'
)
ON CONFLICT (id) DO UPDATE
SET updated_at = EXCLUDED.updated_at;

INSERT INTO public.rescue_case_private_locations (
  case_id,
  owner_user_id,
  latitude,
  longitude,
  formatted_address,
  created_at,
  updated_at
)
VALUES (
  '34000000-0000-4000-8000-000000000003',
  '34000000-0000-4000-8000-000000000001',
  10.776889,
  106.700806,
  '12 Nguyễn Huệ, Phường Sài Gòn, TP.HCM',
  '2026-07-17T00:05:00Z',
  '2026-07-17T00:05:00Z'
)
ON CONFLICT (case_id) DO UPDATE
SET updated_at = EXCLUDED.updated_at;

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
  case_id,
  position,
  verified_at,
  created_at,
  updated_at
)
VALUES (
  '34000000-0000-4000-8000-000000000004',
  '34000000-0000-4000-8000-000000000001',
  'rescue_case',
  'image/webp',
  4096,
  repeat('a', 64),
  'attached',
  'day34/rescue-case/milo.webp',
  'https://example.invalid/day34/milo.webp',
  800,
  600,
  '34000000-0000-4000-8000-000000000003',
  0,
  '2026-07-17T00:04:00Z',
  '2026-07-17T00:04:00Z',
  '2026-07-17T00:05:00Z'
)
ON CONFLICT (id) DO UPDATE
SET updated_at = EXCLUDED.updated_at;

INSERT INTO public.rescue_comments (
  id,
  case_id,
  author_user_id,
  body,
  moderation_state,
  created_at,
  updated_at
)
VALUES (
  '34000000-0000-4000-8000-000000000005',
  '34000000-0000-4000-8000-000000000003',
  '34000000-0000-4000-8000-000000000001',
  'Mình sẽ để ý khu vực này và báo lại nếu thấy Milo.',
  'visible',
  '2026-07-17T00:10:00Z',
  '2026-07-17T00:10:00Z'
)
ON CONFLICT (id) DO UPDATE
SET body = EXCLUDED.body,
    updated_at = EXCLUDED.updated_at;

INSERT INTO public.rescue_status_events (
  id,
  case_id,
  changed_by_user_id,
  from_status,
  to_status,
  expected_version,
  new_version,
  created_at
)
VALUES (
  '34000000-0000-4000-8000-000000000006',
  '34000000-0000-4000-8000-000000000003',
  '34000000-0000-4000-8000-000000000001',
  NULL,
  'missing',
  0,
  1,
  '2026-07-17T00:05:00Z'
)
ON CONFLICT (id) DO NOTHING;

COMMIT;

