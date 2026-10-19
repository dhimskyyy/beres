-- ============================================================================
-- BERES PLATFORM - MIGRATION 0003: KYC VERIFICATION, CATEGORIES CRUD, & APP CONFIGS
-- Selaras dengan docs/PRD.md v1.4.0 (FR-003, FR-032, FR-033, FR-035, BR-10)
-- ============================================================================

-- 1. FUNGSI SUBMIT DOKUMEN KYC TUKANG (FR-003)
CREATE OR REPLACE FUNCTION rpc_submit_kyc_document(
  p_tukang_id UUID,
  p_ktp_storage_path TEXT,
  p_selfie_storage_path TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_doc_id UUID;
BEGIN
  -- Validasi input path tidak boleh kosong
  IF p_ktp_storage_path IS NULL OR length(trim(p_ktp_storage_path)) = 0 THEN
    RAISE EXCEPTION 'Path Foto KTP wajib diunggah (FR-003).';
  END IF;

  IF p_selfie_storage_path IS NULL OR length(trim(p_selfie_storage_path)) = 0 THEN
    RAISE EXCEPTION 'Path Foto Selfie memegang KTP wajib diunggah (FR-003).';
  END IF;

  -- Buat record baru di kyc_documents
  INSERT INTO kyc_documents (
    tukang_id,
    ktp_storage_path,
    selfie_storage_path,
    status
  )
  VALUES (
    p_tukang_id,
    p_ktp_storage_path,
    p_selfie_storage_path,
    'PENDING'
  )
  RETURNING id INTO v_doc_id;

  -- Update status di tukang_profiles
  UPDATE tukang_profiles
  SET kyc_status = 'PENDING',
      updated_at = NOW()
  WHERE user_id = p_tukang_id;

  RETURN jsonb_build_object(
    'success', true,
    'document_id', v_doc_id,
    'status', 'PENDING'
  );
END;
$$;

-- 2. FUNGSI REVIEW KYC OLEH ADMIN (FR-032, BR-10)
CREATE OR REPLACE FUNCTION rpc_review_kyc(
  p_admin_id UUID,
  p_kyc_id UUID,
  p_decision kyc_status,
  p_rejection_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_doc RECORD;
BEGIN
  -- Ambil data KYC
  SELECT * INTO v_doc FROM kyc_documents WHERE id = p_kyc_id FOR UPDATE;
  IF v_doc IS NULL THEN
    RAISE EXCEPTION 'Dokumen KYC tidak ditemukan.';
  END IF;

  IF p_decision = 'REJECTED' AND (p_rejection_reason IS NULL OR length(trim(p_rejection_reason)) = 0) THEN
    RAISE EXCEPTION 'Alasan penolakan wajib diisi bila keputusan REJECTED (FR-032).';
  END IF;

  -- Update kyc_documents
  UPDATE kyc_documents
  SET status = p_decision,
      rejection_reason = CASE WHEN p_decision = 'REJECTED' THEN p_rejection_reason ELSE NULL END,
      reviewed_by = p_admin_id,
      reviewed_at = NOW()
  WHERE id = p_kyc_id;

  -- Update tukang_profiles
  UPDATE tukang_profiles
  SET kyc_status = p_decision,
      kyc_approved_at = CASE WHEN p_decision = 'APPROVED' THEN NOW() ELSE kyc_approved_at END,
      updated_at = NOW()
  WHERE user_id = v_doc.tukang_id;

  -- Catat ke audit_logs (FR-033)
  INSERT INTO audit_logs (actor_id, action, target_type, target_id, metadata)
  VALUES (
    p_admin_id,
    CASE WHEN p_decision = 'APPROVED' THEN 'KYC_APPROVE' ELSE 'KYC_REJECT' END,
    'TUKANG_KYC',
    v_doc.tukang_id::TEXT,
    jsonb_build_object(
      'decision', p_decision,
      'rejection_reason', p_rejection_reason,
      'kyc_id', p_kyc_id
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'status', p_decision
  );
END;
$$;

-- 3. FUNGSI ADMIN UPDATE APP CONFIGS & CATAT AUDIT LOG (FR-035, FR-033)
CREATE OR REPLACE FUNCTION rpc_admin_update_app_config(
  p_admin_id UUID,
  p_key TEXT,
  p_value_int INTEGER,
  p_value_text TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE app_configs
  SET value_int = p_value_int,
      value_text = p_value_text,
      updated_at = NOW()
  WHERE key = p_key;

  INSERT INTO audit_logs (actor_id, action, target_type, target_id, metadata)
  VALUES (
    p_admin_id,
    'CONFIG_UPDATE',
    'APP_CONFIG',
    p_key,
    jsonb_build_object(
      'key', p_key,
      'value_int', p_value_int,
      'value_text', p_value_text
    )
  );

  RETURN jsonb_build_object('success', true);
END;
$$;

-- 4. FUNGSI ADMIN SAVE / UPDATE KATEGORI DINAMIS (FR-035)
CREATE OR REPLACE FUNCTION rpc_admin_save_category(
  p_admin_id UUID,
  p_id UUID,
  p_slug TEXT,
  p_name TEXT,
  p_description TEXT,
  p_icon_name TEXT,
  p_is_active BOOLEAN,
  p_sort_order INTEGER
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_category_id UUID;
BEGIN
  IF p_id IS NOT NULL THEN
    -- Update kategori yang ada
    UPDATE categories
    SET slug = p_slug,
        name = p_name,
        description = p_description,
        icon_name = p_icon_name,
        is_active = p_is_active,
        sort_order = p_sort_order
    WHERE id = p_id
    RETURNING id INTO v_category_id;

    INSERT INTO audit_logs (actor_id, action, target_type, target_id, metadata)
    VALUES (
      p_admin_id,
      'CATEGORY_UPDATE',
      'CATEGORY',
      v_category_id::TEXT,
      jsonb_build_object('slug', p_slug, 'name', p_name, 'is_active', p_is_active)
    );
  ELSE
    -- Tambah kategori baru
    INSERT INTO categories (slug, name, description, icon_name, is_active, sort_order)
    VALUES (p_slug, p_name, p_description, p_icon_name, p_is_active, p_sort_order)
    RETURNING id INTO v_category_id;

    INSERT INTO audit_logs (actor_id, action, target_type, target_id, metadata)
    VALUES (
      p_admin_id,
      'CATEGORY_CREATE',
      'CATEGORY',
      v_category_id::TEXT,
      jsonb_build_object('slug', p_slug, 'name', p_name, 'is_active', p_is_active)
    );
  END IF;

  RETURN jsonb_build_object('success', true, 'id', v_category_id);
END;
$$;
