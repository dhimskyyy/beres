-- 0012: Add created_at to rpc_sync_profile_after_auth return json
CREATE OR REPLACE FUNCTION public.rpc_sync_profile_after_auth(
  p_user_id uuid,
  p_email text,
  p_role user_role,
  p_full_name text,
  p_phone text DEFAULT NULL::text
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
BEGIN
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
        updated_at = NOW()
    WHERE id = v_existing_profile.id
    RETURNING * INTO v_profile;
  ELSE
    INSERT INTO profiles (id, email, role, full_name, phone)
    VALUES (p_user_id, LOWER(p_email), p_role, p_full_name, p_phone)
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
      'created_at', v_profile.created_at
    )
  );
END;
$function$;
