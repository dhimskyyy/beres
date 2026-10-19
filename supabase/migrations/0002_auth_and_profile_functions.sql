-- ============================================================================
-- BERES PLATFORM - MIGRATION 0002: AUTH, 1 EMAIL 1 PERAN, PROFILE & HAPUS AKUN
-- Selaras dengan docs/PRD.md v1.4.0 (FR-001, FR-002, FR-004, FR-037, BR-42, BR-44, BR-45)
-- ============================================================================

-- 1. FUNGSI CEK KONFLIK PERAN & STATUS SUSPEND SEBELUM / SAAT AUTH (BR-44, BR-42)
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
      'message', 'Akun dengan email ini telah dinonaktifkan/dihapus (BR-45). Silakan gunakan email lain atau hubungi ' || v_profile.appeal_email_info
    );
  END IF;

  -- Penegakan Aturan Mutlak BR-44: 1 Email = 1 Peran
  IF v_profile.role <> p_target_role THEN
    RETURN jsonb_build_object(
      'status', 'ROLE_MISMATCH',
      'current_role', v_profile.role,
      'target_role', p_target_role,
      'message', 'Email ini sudah terdaftar sebagai ' || 
        CASE 
          WHEN v_profile.role = 'USER' THEN 'Pelanggan (USER)'
          WHEN v_profile.role = 'TUKANG' THEN 'Mitra Tukang (TUKANG)'
          ELSE 'Admin'
        END || '. Berdasarkan aturan resmi Beres (BR-44), 1 alamat email hanya boleh digunakan untuk 1 peran.'
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

  -- Akun aktif dan peran sesuai
  RETURN jsonb_build_object(
    'status', 'ALLOWED_EXISTING_USER',
    'profile_id', v_profile.id,
    'full_name', v_profile.full_name,
    'role', v_profile.role
  );
END;
$$;

-- 2. FUNGSI INISIALISASI / SINKRONISASI PROFIL SETELAH OTP VERIFIED
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
BEGIN
  -- Validasi ganda 1 Email = 1 Peran di database
  SELECT * INTO v_existing_profile FROM profiles WHERE id = p_user_id OR LOWER(email) = LOWER(p_email) LIMIT 1;

  IF v_existing_profile IS NOT NULL THEN
    IF v_existing_profile.role <> p_role THEN
      RAISE EXCEPTION 'ROLE_CONFLICT: 1 Email hanya boleh untuk 1 peran (BR-44). Akun terdaftar sebagai %', v_existing_profile.role;
    END IF;

    -- Update nama dan no HP jika ada pembaruan
    UPDATE profiles
    SET full_name = COALESCE(NULLIF(p_full_name, ''), v_existing_profile.full_name),
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

  -- Jika Tukang, pastikan baris di tukang_profiles juga ada
  IF p_role = 'TUKANG' THEN
    INSERT INTO tukang_profiles (user_id)
    VALUES (v_profile.id)
    ON CONFLICT (user_id) DO NOTHING;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'profile', row_to_json(v_profile)
  );
END;
$$;

-- 3. FUNGSI UPDATE BIODATA, KEAHLIAN, & REKENING TUKANG (FR-002, BR-06)
CREATE OR REPLACE FUNCTION rpc_update_tukang_profile(
  p_tukang_id UUID,
  p_bio TEXT,
  p_radius_km INTEGER,
  p_payment_accounts JSONB,
  p_category_ids UUID[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cat_id UUID;
BEGIN
  -- Validasi radius 0 - 50 km (BR-20)
  IF p_radius_km < 0 OR p_radius_km > 50 THEN
    RAISE EXCEPTION 'Radius harus berada dalam rentang 0 hingga 50 km di MVP (BR-20).';
  END IF;

  -- Validasi minimal 1 kategori dipilih (FR-002)
  IF p_category_ids IS NULL OR array_length(p_category_ids, 1) = 0 THEN
    RAISE EXCEPTION 'Tukang wajib memilih minimal 1 kategori keahlian (FR-002).';
  END IF;

  -- Update tabel tukang_profiles
  UPDATE tukang_profiles
  SET bio = p_bio,
      radius_km = p_radius_km,
      payment_accounts = p_payment_accounts,
      updated_at = NOW()
  WHERE user_id = p_tukang_id;

  -- Sinkronkan kategori keahlian di tabel tukang_categories
  DELETE FROM tukang_categories WHERE tukang_id = p_tukang_id;
  FOREACH v_cat_id IN ARRAY p_category_ids
  LOOP
    INSERT INTO tukang_categories (tukang_id, category_id)
    VALUES (p_tukang_id, v_cat_id)
    ON CONFLICT (tukang_id, category_id) DO NOTHING;
  END LOOP;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- 4. FUNGSI HAPUS AKUN DENGAN VALIDASI JOB BERJALAN & SENGKETA AKTIF (FR-004, BR-45)
CREATE OR REPLACE FUNCTION rpc_delete_account(
  p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_profile RECORD;
  v_active_jobs_count INTEGER := 0;
  v_active_reports_count INTEGER := 0;
BEGIN
  SELECT * INTO v_profile FROM profiles WHERE id = p_user_id;
  IF v_profile IS NULL THEN
    RAISE EXCEPTION 'Profil pengguna tidak ditemukan.';
  END IF;

  IF v_profile.deleted_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', true, 'message', 'Akun sudah dihapus sebelumnya.');
  END IF;

  -- 1. Cek apakah ada pekerjaan berjalan (NEGOTIATING s/d WORKING, CANCEL_PENDING)
  IF v_profile.role = 'USER' THEN
    SELECT COUNT(*) INTO v_active_jobs_count
    FROM jobs
    WHERE user_id = p_user_id
      AND status IN ('NEGOTIATING', 'NOTA_APPROVED', 'ON_THE_WAY', 'ARRIVED', 'WORKING', 'CANCEL_PENDING');
  ELSIF v_profile.role = 'TUKANG' THEN
    SELECT COUNT(*) INTO v_active_jobs_count
    FROM jobs
    WHERE locked_tukang_id = p_user_id
      AND status IN ('NEGOTIATING', 'NOTA_APPROVED', 'ON_THE_WAY', 'ARRIVED', 'WORKING', 'CANCEL_PENDING');
  END IF;

  IF v_active_jobs_count > 0 THEN
    RAISE EXCEPTION 'Gagal menghapus akun: Anda masih memiliki % pekerjaan yang sedang berjalan. Selesaikan atau batalkan pekerjaan terlebih dahulu (BR-45).', v_active_jobs_count;
  END IF;

  -- 2. Cek apakah ada laporan masalah pembayaran / sengketa aktif (BR-45, BR-67)
  SELECT COUNT(*) INTO v_active_reports_count
  FROM reports
  WHERE (reporter_id = p_user_id OR reported_user_id = p_user_id)
    AND status IN ('OPEN', 'IN_REVIEW');

  IF v_active_reports_count > 0 THEN
    RAISE EXCEPTION 'Gagal menghapus akun: Akun Anda sedang terlibat dalam laporan/investigasi aktif oleh Admin. Silakan hubungi support@beres.id (BR-45).';
  END IF;

  -- 3. Bersihkan data aktif (auto-withdraw bid aktif jika tukang, batalkan job OPEN jika user)
  IF v_profile.role = 'TUKANG' THEN
    UPDATE bids
    SET status = 'WITHDRAWN', withdrawn_reason = 'ACCOUNT_DELETED'
    WHERE tukang_id = p_user_id AND status = 'ACTIVE';

    UPDATE tukang_profiles
    SET is_online = FALSE
    WHERE user_id = p_user_id;
  ELSIF v_profile.role = 'USER' THEN
    UPDATE jobs
    SET status = 'CANCELLED', cancel_reason = 'User menghapus akun'
    WHERE user_id = p_user_id AND status = 'OPEN';
  END IF;

  -- 4. Anonimkan data sensitif sesuai kepatuhan UU PDP & tandai deleted_at
  UPDATE profiles
  SET full_name = 'Pengguna Dihapus',
      phone = NULL,
      avatar_url = NULL,
      deleted_at = NOW(),
      updated_at = NOW()
  WHERE id = p_user_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Akun Anda berhasil dihapus dan sesi telah dinonaktifkan.'
  );
END;
$$;
