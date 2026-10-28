-- ============================================================================
-- BERES PLATFORM - MIGRATION 0016: FIX RPC CHECK EMAIL ROLE & SYNC PROFILE GRANTS
-- Memastikan rpc_check_email_role mengembalikan current_role & role
-- serta grant akses pada rpc_sync_profile_after_auth (8 parameter)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.rpc_check_email_role(
  p_email TEXT,
  p_target_role user_role
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile RECORD;
  v_now TIMESTAMPTZ := NOW();
BEGIN
  SELECT * INTO v_profile FROM profiles WHERE LOWER(email) = LOWER(p_email) LIMIT 1;

  IF v_profile IS NULL THEN
    RETURN jsonb_build_object(
      'status', 'ALLOWED_NEW_USER',
      'email', LOWER(p_email),
      'target_role', p_target_role
    );
  END IF;

  IF v_profile.deleted_at IS NOT NULL THEN
    RETURN jsonb_build_object(
      'status', 'ACCOUNT_DELETED',
      'message', 'Akun dengan email ini telah dinonaktifkan/dihapus. Silakan hubungi ' || v_profile.appeal_email_info
    );
  END IF;

  IF v_profile.suspend_type = 'MANUAL_PERMANENT' THEN
    RETURN jsonb_build_object(
      'status', 'SUSPENDED_PERMANENT',
      'suspend_reason', COALESCE(v_profile.suspend_reason, 'Akun dinonaktifkan oleh Admin karena pelanggaran berat.'),
      'appeal_email', v_profile.appeal_email_info
    );
  END IF;

  IF v_profile.suspend_type = 'AUTO_2_DAYS' AND v_profile.suspended_until IS NOT NULL AND v_profile.suspended_until > v_now THEN
    RETURN jsonb_build_object(
      'status', 'SUSPENDED_AUTO_2_DAYS',
      'suspend_reason', COALESCE(v_profile.suspend_reason, 'Akun ditangguhkan sementara selama 2 hari karena telah melampaui batas toleransi 3x pelanggaran (strike) dalam bulan ini.'),
      'suspended_until', v_profile.suspended_until
    );
  END IF;

  RETURN jsonb_build_object(
    'status', 'ALLOWED_EXISTING_USER',
    'profile_id', v_profile.id,
    'full_name', v_profile.full_name,
    'role', v_profile.role,
    'current_role', v_profile.role
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.rpc_check_email_role(TEXT, user_role) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_sync_profile_after_auth(uuid, text, user_role, text, text, text, text, date) TO anon, authenticated, service_role;
