-- Create John in auth.users
INSERT INTO auth.users (
  id, instance_id, email, encrypted_password, email_confirmed_at,
  raw_user_meta_data, created_at, updated_at, role, aud
)
VALUES (
  'aaaaaaaa-1111-1111-1111-111111111111',
  '00000000-0000-0000-0000-000000000000',
  'john@test.local',
  crypt('password123', gen_salt('bf')),
  NOW(),
  '{"full_name": "John Test", "avatar_emoji": "👨"}'::jsonb,
  NOW(), NOW(), 'authenticated', 'authenticated'
)
ON CONFLICT (id) DO NOTHING;

-- Create Jane in auth.users
INSERT INTO auth.users (
  id, instance_id, email, encrypted_password, email_confirmed_at,
  raw_user_meta_data, created_at, updated_at, role, aud
)
VALUES (
  'aaaaaaaa-2222-2222-2222-222222222222',
  '00000000-0000-0000-0000-000000000000',
  'jane@test.local',
  crypt('password123', gen_salt('bf')),
  NOW(),
  '{"full_name": "Jane Test", "avatar_emoji": "👩"}'::jsonb,
  NOW(), NOW(), 'authenticated', 'authenticated'
)
ON CONFLICT (id) DO NOTHING;

-- Create their couple
INSERT INTO couples (id, user1_id, user2_id, created_at, updated_at)
VALUES (
  'cccccccc-1111-1111-1111-111111111111',
  'aaaaaaaa-1111-1111-1111-111111111111',
  'aaaaaaaa-2222-2222-2222-222222222222',
  NOW(), NOW()
)
ON CONFLICT (id) DO NOTHING;

-- Create LP entries (identical for shared pool)
INSERT INTO user_love_points (user_id, total_points, country_code)
VALUES
  ('aaaaaaaa-1111-1111-1111-111111111111', 1200, 'US'),
  ('aaaaaaaa-2222-2222-2222-222222222222', 1200, 'US')
ON CONFLICT (user_id) DO UPDATE SET
  total_points = EXCLUDED.total_points,
  country_code = EXCLUDED.country_code;

-- Recalculate ranks
SELECT recalculate_leaderboard_ranks();

-- Show results
SELECT * FROM couple_leaderboard ORDER BY global_rank;
