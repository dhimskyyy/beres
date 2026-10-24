-- ============================================================================
-- BERES PLATFORM - MIGRATION 0015: PROFILE BIRTH PLACE & BIRTH DATE
-- Menambahkan kolom birth_place & birth_date pada tabel profiles
-- ============================================================================

ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS birth_place TEXT,
ADD COLUMN IF NOT EXISTS birth_date DATE;

-- Update rpc_sync_profile_after_auth untuk menyertakan birth_place & birth_date
CREATE OR REPLACE FUNCTION public.rpc_sync_profile_after_auth(
  p_user_id uuid,
  p_email text,
  p_role user_role,
  p_full_name text,
  p_phone text DEFAULT NULL::text,
  p_avatar_url text DEFAULT NULL::text,
  p_birth_place text DEFAULT NULL::text,
  p_birth_date date DEFAULT NULL::date
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
        birth_place = COALESCE(p_birth_place, v_existing_profile.birth_place),
        birth_date = COALESCE(p_birth_date, v_existing_profile.birth_date),
        is_email_verified = CASE WHEN v_existing_profile.is_email_verified THEN TRUE ELSE v_is_verified END,
        email_verified_at = CASE WHEN v_existing_profile.email_verified_at IS NOT NULL THEN v_existing_profile.email_verified_at ELSE v_verified_at END,
        updated_at = NOW()
    WHERE id = v_existing_profile.id
    RETURNING * INTO v_profile;
  ELSE
    INSERT INTO profiles (id, email, role, full_name, phone, avatar_url, birth_place, birth_date, is_email_verified, email_verified_at)
    VALUES (p_user_id, LOWER(p_email), p_role, p_full_name, p_phone, p_avatar_url, p_birth_place, p_birth_date, v_is_verified, v_verified_at)
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
      'birth_place', v_profile.birth_place,
      'birth_date', v_profile.birth_date,
      'is_email_verified', v_profile.is_email_verified,
      'email_verified_at', v_profile.email_verified_at,
      'created_at', v_profile.created_at
    )
  );
END;
$function$;
