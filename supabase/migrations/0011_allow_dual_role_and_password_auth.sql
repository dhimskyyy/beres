-- ============================================================================
-- BERES PLATFORM - MIGRATION 0011: 1 EMAIL 2 ROLE (USER & TUKANG) & PASSWORD AUTH
-- ============================================================================

-- 1. Tambah enum value BOTH ke user_role jika belum ada
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'BOTH';

-- 2. Update rpc_check_email_role: hilangkan penolakan ROLE_MISMATCH
CREATE OR REPLACE FUNCTION rpc_check_email_role(
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
  -- Cari profil dengan email yang sama (case insensitive)
  SELECT * INTO v_profile FROM profiles WHERE LOWER(email) = LOWER(p_email) LIMIT 1;

  IF v_profile IS NULL THEN
    -- Email belum pernah terdaftar, diizinkan untuk registrasi
    RETURN jsonb_build_object(
      'status', 'ALLOWED_NEW_USER',
      'email', LOWER(p_email),
      'target_role', p_target_role
    );
  END IF;

  -- Cek apakah akun sudah dihapus (soft delete)
  IF v_profile.deleted_at IS NOT NULL THEN
    RETURN jsonb_build_object(
      'status', 'ACCOUNT_DELETED',
      'message', 'Akun dengan email ini telah dinonaktifkan/dihapus. Silakan hubungi ' || v_profile.appeal_email_info
    );
  END IF;

  -- Cek Status Suspend Permanen Admin (BR-42a)
  IF v_profile.suspend_type = 'MANUAL_PERMANENT' THEN
    RETURN jsonb_build_object(
      'status', 'SUSPENDED_PERMANENT',
      'suspend_reason', COALESCE(v_profile.suspend_reason, 'Akun dinonaktifkan oleh Admin karena pelanggaran berat.'),
      'appeal_email', v_profile.appeal_email_info
    );
  END IF;

  -- Cek Status Suspend Otomatis 2 Hari (> 3x Strike) (BR-42b, BR-57, BR-71)
  IF v_profile.suspend_type = 'AUTO_2_DAYS' AND v_profile.suspended_until IS NOT NULL AND v_profile.suspended_until > v_now THEN
    RETURN jsonb_build_object(
      'status', 'SUSPENDED_AUTO_2_DAYS',
      'suspend_reason', COALESCE(v_profile.suspend_reason, 'Akun ditangguhkan sementara selama 2 hari karena telah melampaui batas toleransi 3x pelanggaran (strike) dalam bulan ini.'),
      'suspended_until', v_profile.suspended_until
    );
  END IF;

  -- Akun aktif dan diizinkan (1 Email dapat memiliki peran USER dan TUKANG)
  RETURN jsonb_build_object(
    'status', 'ALLOWED_EXISTING_USER',
    'profile_id', v_profile.id,
    'full_name', v_profile.full_name,
    'role', v_profile.role
  );
END;
$$;

-- 3. Update rpc_sync_profile_after_auth: dukung 1 email 2 peran (USER + TUKANG)
CREATE OR REPLACE FUNCTION rpc_sync_profile_after_auth(
  p_user_id UUID,
  p_email TEXT,
  p_role user_role,
  p_full_name TEXT,
  p_phone TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_existing_profile RECORD;
  v_profile RECORD;
  v_new_role user_role := p_role;
BEGIN
  SELECT * INTO v_existing_profile FROM profiles WHERE id = p_user_id OR LOWER(email) = LOWER(p_email) LIMIT 1;

  IF v_existing_profile.id IS NOT NULL THEN
    -- Jika sudah terdaftar dengan peran berbeda (misal USER daftar TUKANG atau sebaliknya), jadikan BOTH
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
    -- Buat profil baru
    INSERT INTO profiles (id, email, role, full_name, phone)
    VALUES (p_user_id, LOWER(p_email), p_role, p_full_name, p_phone)
    RETURNING * INTO v_profile;
  END IF;

  -- Jika mendaftar sebagai Tukang (atau BOTH), pastikan tukang_profiles ada
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
      'phone', v_profile.phone
    )
  );
END;
$$;

-- 4. Pastikan User tidak dapat melamar (bid) pekerjaannya sendiri
CREATE OR REPLACE FUNCTION rpc_submit_bid(
  p_job_id UUID,
  p_tukang_id UUID,
  p_message TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_job RECORD;
  v_active_bids_count INTEGER;
  v_tukang_profile RECORD;
  v_bid RECORD;
BEGIN
  -- Ambil data job
  SELECT * INTO v_job FROM jobs WHERE id = p_job_id FOR UPDATE;
  IF v_job IS NULL THEN
    RAISE EXCEPTION 'JOB_NOT_FOUND: Pekerjaan tidak ditemukan.';
  END IF;

  IF v_job.status <> 'OPEN' THEN
    RAISE EXCEPTION 'JOB_NOT_OPEN: Pekerjaan tidak lagi berstatus OPEN.';
  END IF;

  -- Validasi: Tukang tidak boleh melamar pekerjaan yang dibuatnya sendiri
  IF v_job.user_id = p_tukang_id THEN
    RAISE EXCEPTION 'CANNOT_BID_OWN_JOB: Anda tidak dapat melamar pekerjaan yang Anda buat sendiri sebagai pelanggan.';
  END IF;

  -- Cek status tukang
  SELECT * INTO v_tukang_profile FROM tukang_profiles WHERE user_id = p_tukang_id;
  IF v_tukang_profile IS NULL OR v_tukang_profile.kyc_status <> 'APPROVED' THEN
    RAISE EXCEPTION 'TUKANG_NOT_KYC: Mitra belum terverifikasi KYC.';
  END IF;

  -- Cek kuota lamaran aktif (maksimal 5 bid)
  SELECT COUNT(*) INTO v_active_bids_count
  FROM bids b
  JOIN jobs j ON b.job_id = j.id
  WHERE b.tukang_id = p_tukang_id
    AND b.status = 'ACTIVE'
    AND j.status = 'OPEN';

  IF v_active_bids_count >= 5 THEN
    RAISE EXCEPTION 'MAX_BIDS_EXCEEDED: Batas maksimal 5 lamaran aktif telah tercapai.';
  END IF;

  -- Buat bid baru
  INSERT INTO bids (job_id, tukang_id, message, status)
  VALUES (p_job_id, p_tukang_id, p_message, 'ACTIVE')
  ON CONFLICT (job_id, tukang_id) DO UPDATE
    SET status = 'ACTIVE',
        message = COALESCE(p_message, bids.message),
        created_at = NOW()
  RETURNING * INTO v_bid;

  RETURN jsonb_build_object(
    'success', true,
    'bid_id', v_bid.id,
    'job_id', v_bid.job_id,
    'status', v_bid.status
  );
END;
$$;
