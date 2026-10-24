-- ============================================================================
-- BERES PLATFORM - MIGRATION 0014: PROFILE AVATAR & EMAIL VERIFICATION
-- Menambahkan kolom is_email_verified & email_verified_at pada tabel profiles,
-- Menyiapkan bucket avatars di storage Supabase, serta menambahkan RPC verifikasi email
-- ============================================================================

-- 1. Tambah kolom verifikasi email pada public.profiles
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS is_email_verified BOOLEAN NOT NULL DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS email_verified_at TIMESTAMP WITH TIME ZONE;

-- 2. Update fungsi rpc_sync_profile_after_auth agar mengembalikan status avatar & verifikasi
CREATE OR REPLACE FUNCTION public.rpc_sync_profile_after_auth(
  p_user_id uuid,
  p_email text,
  p_role user_role,
  p_full_name text,
  p_phone text DEFAULT NULL::text,
  p_avatar_url text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_existing_profile RECORD;
  v_profile RECORD;
  v_new_role user_role := p_role;
  v_is_verified boolean := false;
  v_verified_at timestamptz := NULL;
  v_auth_user RECORD;
BEGIN
  -- Cek status email confirmed di auth.users jika ada
  SELECT * INTO v_auth_user FROM auth.users WHERE id = p_user_id;
  IF v_auth_user.email_confirmed_at IS NOT NULL OR (v_auth_user.raw_app_meta_data->>'provider') = 'google' THEN
    v_is_verified := true;
    v_verified_at := COALESCE(v_auth_user.email_confirmed_at, NOW());
  END IF;

  SELECT * INTO v_existing_profile FROM profiles WHERE id = p_user_id OR LOWER(email) = LOWER(p_email) LIMIT 1;

  IF v_existing_profile.id IS NOT NULL THEN
    IF v_existing_profile.role <> p_role AND v_existing_profile.role <> 'BOTH' AND v_existing_profile.role <> 'ADMIN' THEN
      v_new_role := 'BOTH';
    ELSE
      v_new_role := v_existing_profile.role;
    END IF;

    UPDATE profiles
    SET role = v_new_role,
        full_name = COALESCE(NULLIF(p_full_name, ''), v_existing_profile.full_name),
        phone = COALESCE(p_phone, v_existing_profile.phone),
        avatar_url = COALESCE(p_avatar_url, v_existing_profile.avatar_url),
        is_email_verified = CASE WHEN v_existing_profile.is_email_verified THEN TRUE ELSE v_is_verified END,
        email_verified_at = CASE WHEN v_existing_profile.email_verified_at IS NOT NULL THEN v_existing_profile.email_verified_at ELSE v_verified_at END,
        updated_at = NOW()
    WHERE id = v_existing_profile.id
    RETURNING * INTO v_profile;
  ELSE
    INSERT INTO profiles (id, email, role, full_name, phone, avatar_url, is_email_verified, email_verified_at)
    VALUES (p_user_id, LOWER(p_email), p_role, p_full_name, p_phone, p_avatar_url, v_is_verified, v_verified_at)
    RETURNING * INTO v_profile;
  END IF;

  IF p_role = 'TUKANG' OR v_new_role = 'BOTH' THEN
    INSERT INTO tukang_profiles (user_id)
    VALUES (v_profile.id)
    ON CONFLICT (user_id) DO NOTHING;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'profile', jsonb_build_object(
      'id', v_profile.id,
      'email', v_profile.email,
      'role', v_profile.role,
      'full_name', v_profile.full_name,
      'phone', v_profile.phone,
      'avatar_url', v_profile.avatar_url,
      'is_email_verified', v_profile.is_email_verified,
      'email_verified_at', v_profile.email_verified_at,
      'created_at', v_profile.created_at
    )
  );
END;
$function$;

-- 3. Fungsi RPC verifikasi email saat pengguna mengonfirmasi tautan / OTP
CREATE OR REPLACE FUNCTION public.rpc_verify_profile_email()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_uid UUID := auth.uid();
  v_profile RECORD;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Pengguna belum terautentikasi');
  END IF;

  UPDATE profiles
  SET is_email_verified = TRUE,
      email_verified_at = NOW(),
      updated_at = NOW()
  WHERE id = v_uid
  RETURNING * INTO v_profile;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Profil pengguna tidak ditemukan');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Email berhasil diverifikasi',
    'profile', row_to_json(v_profile)
  );
END;
$function$;

-- 4. Setup bucket avatars
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'avatars',
  'avatars',
  true,
  5242880, -- 5MB limit
  ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/gif'];

-- 5. Storage RLS policies untuk avatars
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Public read avatars'
  ) THEN
    CREATE POLICY "Public read avatars" ON storage.objects
      FOR SELECT USING (bucket_id = 'avatars');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Auth users can upload avatars'
  ) THEN
    CREATE POLICY "Auth users can upload avatars" ON storage.objects
      FOR INSERT WITH CHECK (bucket_id = 'avatars' AND auth.role() = 'authenticated');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Auth users can update avatars'
  ) THEN
    CREATE POLICY "Auth users can update avatars" ON storage.objects
      FOR UPDATE USING (bucket_id = 'avatars' AND auth.role() = 'authenticated');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = 'storage' AND tablename = 'objects' AND policyname = 'Auth users can delete avatars'
  ) THEN
    CREATE POLICY "Auth users can delete avatars" ON storage.objects
      FOR DELETE USING (bucket_id = 'avatars' AND auth.role() = 'authenticated');
  END IF;
END $$;
