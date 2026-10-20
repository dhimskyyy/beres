-- ============================================================================
-- BERES PLATFORM - MIGRATION 0009: ADMIN AUDIT & ANALYTICS DASHBOARD
-- Selaras 100% dengan docs/PRD.md v1.4.0 (FR-031, FR-036, Milestone M7)
-- ============================================================================

-- 1. RPC: ADMIN GET JOB AUDIT DETAILS (FR-031)
-- Mengambil seluruh jejak digital pekerjaan: riwayat 10 status, chat, nota & revisi, foto bukti, dan pembatalan
CREATE OR REPLACE FUNCTION rpc_admin_get_job_audit_details(
  p_job_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_job JSONB;
  v_history JSONB;
  v_chat JSONB;
  v_notas JSONB;
  v_photos JSONB;
  v_cancel_requests JSONB;
  v_reports JSONB;
  v_reviews JSONB;
  v_audit_logs JSONB;
BEGIN
  -- 1. Data Utama Pekerjaan + Profil Pelanggan & Tukang
  SELECT to_jsonb(j_data) INTO v_job
  FROM (
    SELECT
      j.id,
      j.status,
      j.description,
      j.area_label,
      j.address_full,
      j.broadcast_radius_km,
      j.agreed_total,
      j.actual_payment_method,
      j.user_paid_confirmed,
      j.payment_dispute_active,
      j.created_at,
      j.expires_at,
      j.locked_at,
      j.nota_approved_at,
      j.on_the_way_at,
      j.arrived_at,
      j.arrival_mode,
      j.work_started_at,
      j.completed_at,
      c.name AS category_name,
      pu.id AS user_id,
      pu.full_name AS user_name,
      pu.email AS user_email,
      pu.phone AS user_phone,
      pt.id AS tukang_id,
      pt.full_name AS tukang_name,
      pt.email AS tukang_email,
      pt.phone AS tukang_phone
    FROM jobs j
    LEFT JOIN categories c ON j.category_id = c.id
    LEFT JOIN profiles pu ON j.user_id = pu.id
    LEFT JOIN profiles pt ON j.locked_tukang_id = pt.id
    WHERE j.id = p_job_id
  ) j_data;

  IF v_job IS NULL THEN
    RAISE EXCEPTION 'Pekerjaan tidak ditemukan.';
  END IF;

  -- 2. Riwayat Transisi Status (10 Status History)
  SELECT COALESCE(jsonb_agg(h ORDER BY h.created_at ASC), '[]'::JSONB) INTO v_history
  FROM (
    SELECT
      jsh.id,
      jsh.from_status,
      jsh.to_status,
      jsh.actor_id,
      p.full_name AS actor_name,
      p.role AS actor_role,
      jsh.notes,
      jsh.created_at
    FROM job_status_history jsh
    LEFT JOIN profiles p ON jsh.actor_id = p.id
    WHERE jsh.job_id = p_job_id
  ) h;

  -- 3. Histori Chat Lengkap
  SELECT COALESCE(jsonb_agg(m ORDER BY m.created_at ASC), '[]'::JSONB) INTO v_chat
  FROM (
    SELECT
      cm.id,
      cm.sender_id,
      p.full_name AS sender_name,
      p.role AS sender_role,
      cm.message_type,
      cm.content,
      cm.image_url,
      cm.nota_id,
      cm.created_at
    FROM chat_messages cm
    LEFT JOIN profiles p ON cm.sender_id = p.id
    WHERE cm.job_id = p_job_id
  ) m;

  -- 4. Riwayat Versi Nota & Revisi (Immutability check)
  SELECT COALESCE(jsonb_agg(n ORDER BY n.version ASC), '[]'::JSONB) INTO v_notas
  FROM (
    SELECT
      id,
      version,
      status,
      items,
      total_amount,
      payment_method,
      note,
      previous_approved_total,
      created_at,
      responded_at
    FROM notas
    WHERE job_id = p_job_id
  ) n;

  -- 5. Galeri Foto Pekerjaan (Kerusakan, Hasil Kerja, Bukti Transfer)
  SELECT COALESCE(jsonb_agg(ph ORDER BY ph.created_at ASC), '[]'::JSONB) INTO v_photos
  FROM (
    SELECT
      id,
      photo_type,
      photo_url,
      created_at
    FROM job_photos
    WHERE job_id = p_job_id
  ) ph;

  -- 6. Riwayat Permintaan Pembatalan
  SELECT COALESCE(jsonb_agg(cr ORDER BY cr.created_at DESC), '[]'::JSONB) INTO v_cancel_requests
  FROM (
    SELECT
      cr.id,
      cr.requester_role,
      cr.status,
      cr.status_before_cancel,
      cr.reason_category,
      cr.reason_text,
      cr.admin_notes,
      cr.evidence_photos,
      cr.distance_to_job_m,
      cr.submitted_at,
      cr.resolved_at,
      p.full_name AS resolved_by_name
    FROM cancel_requests cr
    LEFT JOIN profiles p ON cr.resolved_by = p.id
    WHERE cr.job_id = p_job_id
  ) cr;

  -- 7. Laporan Sengketa / Masalah Pembayaran (BR-67)
  SELECT COALESCE(jsonb_agg(r ORDER BY r.created_at DESC), '[]'::JSONB) INTO v_reports
  FROM (
    SELECT
      r.id,
      r.category,
      r.is_priority,
      r.description,
      r.evidence_photos,
      r.status,
      r.admin_resolution_notes,
      r.created_at,
      r.resolved_at,
      p.full_name AS reporter_name
    FROM reports r
    LEFT JOIN profiles p ON r.reporter_id = p.id
    WHERE r.job_id = p_job_id
  ) r;

  -- 8. Ulasan & Bintang
  SELECT to_jsonb(rw) INTO v_reviews
  FROM (
    SELECT
      rating,
      comment,
      created_at
    FROM reviews
    WHERE job_id = p_job_id
    LIMIT 1
  ) rw;

  -- 9. Log Audit Relevan
  SELECT COALESCE(jsonb_agg(al ORDER BY al.created_at DESC), '[]'::JSONB) INTO v_audit_logs
  FROM (
    SELECT
      id,
      action,
      target_type,
      metadata,
      created_at
    FROM audit_logs
    WHERE target_id = p_job_id::TEXT
    LIMIT 20
  ) al;

  RETURN jsonb_build_object(
    'job', v_job,
    'status_history', v_history,
    'chat_messages', v_chat,
    'notas', v_notas,
    'photos', v_photos,
    'cancel_requests', v_cancel_requests,
    'reports', v_reports,
    'review', v_reviews,
    'audit_logs', v_audit_logs
  );
END;
$$;


-- 2. RPC: ADMIN GET ANALYTICS SUMMARY (FR-036)
-- Dashboard analitik performa operasional Beres
CREATE OR REPLACE FUNCTION rpc_admin_get_analytics_summary()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_jobs INTEGER := 0;
  v_completed_jobs INTEGER := 0;
  v_total_volume_idr BIGINT := 0;
  v_total_users INTEGER := 0;
  v_total_tukangs INTEGER := 0;
  v_online_tukangs INTEGER := 0;
  v_active_disputes INTEGER := 0;
  v_active_strikes INTEGER := 0;
  v_avg_rating NUMERIC := 0.0;
  v_status_distribution JSONB;
  v_category_distribution JSONB;
  v_recent_audit_logs JSONB;
BEGIN
  -- 1. Metrik Dasar Pekerjaan
  SELECT COUNT(*) INTO v_total_jobs FROM jobs;
  SELECT COUNT(*) INTO v_completed_jobs FROM jobs WHERE status = 'COMPLETED';
  SELECT COALESCE(SUM(agreed_total), 0) INTO v_total_volume_idr FROM jobs WHERE status = 'COMPLETED';

  -- 2. Pengguna & Mitra
  SELECT COUNT(*) INTO v_total_users FROM profiles WHERE role = 'USER';
  SELECT COUNT(*) INTO v_total_tukangs FROM profiles WHERE role = 'TUKANG';
  SELECT COUNT(*) INTO v_online_tukangs FROM tukang_profiles WHERE is_online = TRUE;

  -- 3. Sengketa & Pelanggaran
  SELECT COUNT(*) INTO v_active_disputes FROM jobs WHERE payment_dispute_active = TRUE;
  SELECT COUNT(*) INTO v_active_strikes FROM strikes WHERE is_excused = FALSE;

  -- 4. Rata-rata Rating
  SELECT COALESCE(ROUND(AVG(rating)::NUMERIC, 2), 0.0) INTO v_avg_rating FROM reviews;

  -- 5. Distribusi 10 Status Pekerjaan
  SELECT COALESCE(jsonb_object_agg(status_val, job_count), '{}'::JSONB) INTO v_status_distribution
  FROM (
    SELECT status::TEXT AS status_val, COUNT(*) AS job_count
    FROM jobs
    GROUP BY status
  ) s;

  -- 6. Distribusi per Kategori Layanan
  SELECT COALESCE(jsonb_agg(cat_row ORDER BY cat_row.count DESC), '[]'::JSONB) INTO v_category_distribution
  FROM (
    SELECT c.name, COUNT(j.id) AS count
    FROM categories c
    LEFT JOIN jobs j ON c.id = j.category_id
    GROUP BY c.id, c.name
  ) cat_row;

  -- 7. Log Audit Terbaru
  SELECT COALESCE(jsonb_agg(log_row ORDER BY log_row.created_at DESC), '[]'::JSONB) INTO v_recent_audit_logs
  FROM (
    SELECT
      al.id,
      al.action,
      al.target_type,
      al.target_id,
      al.metadata,
      al.created_at,
      p.full_name AS actor_name,
      p.email AS actor_email
    FROM audit_logs al
    LEFT JOIN profiles p ON al.actor_id = p.id
    ORDER BY al.created_at DESC
    LIMIT 10
  ) log_row;

  RETURN jsonb_build_object(
    'total_jobs', v_total_jobs,
    'completed_jobs', v_completed_jobs,
    'completion_rate_percent', CASE WHEN v_total_jobs > 0 THEN ROUND((v_completed_jobs::NUMERIC / v_total_jobs::NUMERIC) * 100, 1) ELSE 0.0 END,
    'total_volume_idr', v_total_volume_idr,
    'total_users', v_total_users,
    'total_tukangs', v_total_tukangs,
    'online_tukangs', v_online_tukangs,
    'active_disputes', v_active_disputes,
    'active_strikes', v_active_strikes,
    'avg_rating', v_avg_rating,
    'status_distribution', v_status_distribution,
    'category_distribution', v_category_distribution,
    'recent_audit_logs', v_recent_audit_logs
  );
END;
$$;

ALTER FUNCTION rpc_admin_get_job_audit_details(UUID) SET search_path = public;
ALTER FUNCTION rpc_admin_get_analytics_summary() SET search_path = public;

GRANT EXECUTE ON FUNCTION rpc_admin_get_job_audit_details(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_admin_get_analytics_summary() TO authenticated;
