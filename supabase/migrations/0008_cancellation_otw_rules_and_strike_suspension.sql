-- ============================================================================
-- BERES PLATFORM - MIGRATION 0008: CANCELLATIONS, OTW 3-HOUR RULES, & STRIKES
-- Selaras 100% dengan docs/PRD.md v1.4.0 (BR-50 s/d BR-57, BR-71, FR-018, FR-026, FR-028)
-- ============================================================================

-- 1. RPC: TUKANG CREATE CANCEL DRAFT (BR-50, BR-51)
-- Tahap slide-to-cancel -> dialog Ya/Tidak -> halaman form pembatalan
-- BR-51: Selama masih DRAFT, status pekerjaan di jobs TIDAK BERUBAH agar tampilan User tidak berubah!
CREATE OR REPLACE FUNCTION rpc_tukang_create_cancel_draft(
  p_job_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_job RECORD;
  v_tukang_id UUID;
  v_existing_rejected BOOLEAN := FALSE;
  v_draft_id UUID;
BEGIN
  v_tukang_id := auth.uid();

  -- 1. Validasi pekerjaan dan hak akses tukang
  SELECT * INTO v_job
  FROM jobs
  WHERE id = p_job_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pekerjaan tidak ditemukan.';
  END IF;

  IF v_job.locked_tukang_id != v_tukang_id THEN
    RAISE EXCEPTION 'Hanya mitra tukang yang ditugaskan yang dapat mengajukan pembatalan.';
  END IF;

  -- 2. Validasi status: hanya NOTA_APPROVED, ON_THE_WAY, ARRIVED (BR-50)
  -- Dari WORKING DILARANG KERAS (BR-65)
  IF v_job.status NOT IN ('NOTA_APPROVED', 'ON_THE_WAY', 'ARRIVED') THEN
    RAISE EXCEPTION 'Pembatalan oleh tukang hanya diizinkan pada status NOTA_APPROVED, ON_THE_WAY, atau ARRIVED (Status saat ini: %).', v_job.status;
  END IF;

  -- 3. Cek apakah pernah ditolak sebelumnya pada job ini (BR-55: jika pernah ditolak User, tukang tidak boleh mengajukan batal lagi)
  SELECT EXISTS(
    SELECT 1 FROM cancel_requests
    WHERE job_id = p_job_id
      AND requester_id = v_tukang_id
      AND status = 'REJECTED'
  ) INTO v_existing_rejected;

  IF v_existing_rejected THEN
    RAISE EXCEPTION 'Pengajuan pembatalan sebelumnya telah ditolak oleh pelanggan. Anda tidak dapat mengajukan pembatalan lagi pada pekerjaan ini (Gunakan jalur Laporkan Kendala jika darurat).';
  END IF;

  -- 4. Batalkan draft lama jika ada yang berstatus DRAFT
  UPDATE cancel_requests
  SET status = 'ABORTED'
  WHERE job_id = p_job_id
    AND requester_id = v_tukang_id
    AND status = 'DRAFT';

  -- 5. Buat baris DRAFT baru (status pekerjaan di jobs TETAP TIDAK BERUBAH - BR-51)
  INSERT INTO cancel_requests (
    job_id,
    requester_id,
    requester_role,
    status,
    status_before_cancel
  ) VALUES (
    p_job_id,
    v_tukang_id,
    'TUKANG',
    'DRAFT',
    v_job.status
  ) RETURNING id INTO v_draft_id;

  RETURN jsonb_build_object(
    'success', true,
    'draft_id', v_draft_id,
    'job_id', p_job_id,
    'status_before_cancel', v_job.status
  );
END;
$$;


-- 2. RPC: TUKANG ABORT CANCEL DRAFT (BR-51)
-- Jika tukang menekan Kembali pada form pembatalan
CREATE OR REPLACE FUNCTION rpc_tukang_abort_cancel_draft(
  p_cancel_request_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_req RECORD;
BEGIN
  SELECT * INTO v_req
  FROM cancel_requests
  WHERE id = p_cancel_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Draft pembatalan tidak ditemukan.';
  END IF;

  IF v_req.requester_id != auth.uid() THEN
    RAISE EXCEPTION 'Anda bukan pengaju draft ini.';
  END IF;

  IF v_req.status = 'DRAFT' THEN
    UPDATE cancel_requests
    SET status = 'ABORTED'
    WHERE id = p_cancel_request_id;
  END IF;

  RETURN jsonb_build_object('success', true, 'status', 'ABORTED');
END;
$$;


-- 3. RPC: TUKANG SUBMIT CANCEL REQUEST (BR-53)
-- Saat tukang klik "Kirim": status job berubah menjadi CANCEL_PENDING, User menerima alasan ringkas, Admin menerima seluruh field
CREATE OR REPLACE FUNCTION rpc_tukang_submit_cancel_request(
  p_cancel_request_id UUID,
  p_reason_category TEXT,
  p_reason_text TEXT,
  p_admin_notes TEXT DEFAULT NULL,
  p_evidence_photos TEXT[] DEFAULT '{}',
  p_latitude DOUBLE PRECISION DEFAULT NULL,
  p_longitude DOUBLE PRECISION DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_req RECORD;
  v_job RECORD;
  v_tukang_name TEXT;
  v_location GEOGRAPHY(POINT, 4326) := NULL;
  v_distance_m DOUBLE PRECISION := NULL;
BEGIN
  -- 1. Validasi teks alasan min 10 karakter
  IF length(trim(p_reason_text)) < 10 THEN
    RAISE EXCEPTION 'Alasan pembatalan wajib diisi minimal 10 karakter.';
  END IF;

  -- 2. Kunci baris cancel_request
  SELECT * INTO v_req
  FROM cancel_requests
  WHERE id = p_cancel_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Permintaan pembatalan tidak ditemukan.';
  END IF;

  IF v_req.requester_id != auth.uid() THEN
    RAISE EXCEPTION 'Anda bukan pemilik pengajuan pembatalan ini.';
  END IF;

  IF v_req.status != 'DRAFT' THEN
    RAISE EXCEPTION 'Pengajuan pembatalan ini sudah tidak berstatus DRAFT (Status: %).', v_req.status;
  END IF;

  -- 3. Kunci baris job
  SELECT * INTO v_job
  FROM jobs
  WHERE id = v_req.job_id
  FOR UPDATE;

  IF v_job.status NOT IN ('NOTA_APPROVED', 'ON_THE_WAY', 'ARRIVED') THEN
    RAISE EXCEPTION 'Status pekerjaan saat ini tidak dapat dibatalkan (%).', v_job.status;
  END IF;

  -- 4. Hitung lokasi dan jarak jika koordinat diberikan
  IF p_latitude IS NOT NULL AND p_longitude IS NOT NULL THEN
    v_location := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::GEOGRAPHY;
    IF v_job.location IS NOT NULL THEN
      v_distance_m := ST_Distance(v_job.location, v_location);
    END IF;
  END IF;

  -- 5. Perbarui cancel_requests menjadi SUBMITTED
  UPDATE cancel_requests
  SET status = 'SUBMITTED',
      reason_category = trim(p_reason_category),
      reason_text = trim(p_reason_text),
      admin_notes = trim(p_admin_notes),
      evidence_photos = p_evidence_photos,
      requester_location = v_location,
      distance_to_job_m = v_distance_m,
      submitted_at = NOW()
  WHERE id = p_cancel_request_id;

  -- 6. Ubah status job menjadi CANCEL_PENDING (BR-53)
  UPDATE jobs
  SET status = 'CANCEL_PENDING',
      updated_at = NOW()
  WHERE id = v_job.id;

  -- 7. Catat history
  INSERT INTO job_status_history (
    job_id,
    from_status,
    to_status,
    actor_id,
    notes
  ) VALUES (
    v_job.id,
    v_job.status,
    'CANCEL_PENDING',
    auth.uid(),
    'Pengajuan pembatalan oleh Tukang: ' || trim(p_reason_category)
  );

  -- 8. Ambil nama tukang untuk notifikasi
  SELECT full_name INTO v_tukang_name
  FROM profiles WHERE id = auth.uid();

  -- 9. Kirim notifikasi ke User (HANYA berisi alasan pembatalan ringkas - BR-53)
  INSERT INTO notifications (
    user_id,
    title,
    body,
    deep_link
  ) VALUES (
    v_job.user_id,
    'Permintaan Pembatalan dari Tukang',
    COALESCE(v_tukang_name, 'Mitra Tukang') || ' mengajukan pembatalan: "' || trim(p_reason_category) || ' - ' || trim(p_reason_text) || '". Mohon tinjau di aplikasi.',
    'beres://jobs/' || v_job.id
  );

  -- 10. Sisipkan event ke ruang chat
  INSERT INTO chat_messages (
    job_id,
    sender_id,
    message_type,
    content
  ) VALUES (
    v_job.id,
    auth.uid(),
    'SYSTEM_EVENT',
    'Tukang mengajukan pembatalan pekerjaan: [' || trim(p_reason_category) || '] ' || trim(p_reason_text)
  );

  RETURN jsonb_build_object(
    'success', true,
    'status', 'CANCEL_PENDING',
    'job_id', v_job.id
  );
END;
$$;


-- 4. RPC: USER RESPOND TO TUKANG CANCEL (BR-55, BR-57)
-- Keputusan User atas pengajuan pembatalan Tukang
CREATE OR REPLACE FUNCTION rpc_user_respond_to_tukang_cancel(
  p_job_id UUID,
  p_approved BOOLEAN,
  p_decision_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_job RECORD;
  v_req RECORD;
  v_user_id UUID;
BEGIN
  v_user_id := auth.uid();

  -- 1. Validasi dan kunci job
  SELECT * INTO v_job
  FROM jobs
  WHERE id = p_job_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pekerjaan tidak ditemukan.';
  END IF;

  IF v_job.user_id != v_user_id THEN
    RAISE EXCEPTION 'Hanya pelanggan pemilik pekerjaan yang berhak menanggapi pembatalan ini.';
  END IF;

  IF v_job.status != 'CANCEL_PENDING' THEN
    RAISE EXCEPTION 'Status pekerjaan bukan CANCEL_PENDING (Status: %).', v_job.status;
  END IF;

  -- 2. Ambil permintaan pembatalan aktif
  SELECT * INTO v_req
  FROM cancel_requests
  WHERE job_id = p_job_id
    AND requester_role = 'TUKANG'
    AND status = 'SUBMITTED'
  ORDER BY created_at DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tidak ada pengajuan pembatalan dari tukang yang sedang menunggu persetujuan.';
  END IF;

  -- 3. JIKA USER MENYETUJUI (BR-55):
  IF p_approved THEN
    -- Update cancel request menjadi APPROVED
    UPDATE cancel_requests
    SET status = 'APPROVED',
        resolved_by = v_user_id,
        resolved_at = NOW()
    WHERE id = v_req.id;

    -- Job dilepas kembali ke Job Portal (OPEN), locked_tukang_id dilepas, timer 24 jam direset
    UPDATE jobs
    SET status = 'OPEN',
        locked_tukang_id = NULL,
        expires_at = NOW() + INTERVAL '24 hours',
        updated_at = NOW()
    WHERE id = p_job_id;

    -- Batalkan Nota aktif pada job ini menjadi VOID
    UPDATE notas
    SET status = 'VOID',
        updated_at = NOW()
    WHERE job_id = p_job_id
      AND status IN ('SENT', 'APPROVED');

    -- Catat history
    INSERT INTO job_status_history (
      job_id,
      from_status,
      to_status,
      actor_id,
      notes
    ) VALUES (
      p_job_id,
      'CANCEL_PENDING',
      'OPEN',
      v_user_id,
      'User menyetujui pembatalan tukang. Job dilepas kembali ke portal. Tukang menerima 1 Strike (BR-55).'
    );

    -- TUKANG TERKENA +1 STRIKE TUKANG (BR-55, BR-57)
    -- Trigger trg_record_strike_and_check_auto_suspend otomatis menghitung strike & menerapkan suspend 2 hari jika > 3x!
    INSERT INTO strikes (
      user_id,
      role,
      job_id,
      strike_type,
      description
    ) VALUES (
      v_req.requester_id,
      'TUKANG',
      p_job_id,
      'TUKANG_CANCEL_APPROVED',
      'Pembatalan sepihak oleh Tukang setelah Nota disetujui / saat perjalanan / di lokasi (BR-55)'
    );

    -- Notifikasi ke Tukang
    INSERT INTO notifications (
      user_id,
      title,
      body,
      deep_link
    ) VALUES (
      v_req.requester_id,
      'Pembatalan Disetujui (+1 Strike)',
      'Pelanggan telah menyetujui pembatalan Anda. Sesuai aturan BR-55, Anda menerima 1 Strike Tukang dan pekerjaan telah dilepas kembali ke portal.',
      'beres://profile'
    );

    -- Pesan chat sistem
    INSERT INTO chat_messages (
      job_id,
      sender_id,
      message_type,
      content
    ) VALUES (
      p_job_id,
      v_user_id,
      'SYSTEM_EVENT',
      'Pelanggan telah menyetujui pembatalan. Pekerjaan kembali dibuka ke Job Portal.'
    );

    RETURN jsonb_build_object(
      'success', true,
      'decision', 'APPROVED',
      'new_job_status', 'OPEN',
      'strike_applied_to_tukang', true
    );

  -- 4. JIKA USER MENOLAK (BR-55):
  ELSE
    -- Update cancel request menjadi REJECTED
    UPDATE cancel_requests
    SET status = 'REJECTED',
        resolved_by = v_user_id,
        resolved_at = NOW()
    WHERE id = v_req.id;

    -- Kembalikan status job ke status_before_cancel
    UPDATE jobs
    SET status = v_req.status_before_cancel,
        updated_at = NOW()
    WHERE id = p_job_id;

    -- Catat history
    INSERT INTO job_status_history (
      job_id,
      from_status,
      to_status,
      actor_id,
      notes
    ) VALUES (
      p_job_id,
      'CANCEL_PENDING',
      v_req.status_before_cancel,
      v_user_id,
      'User menolak pembatalan tukang. Status dipulihkan ke: ' || v_req.status_before_cancel::TEXT
    );

    -- Notifikasi ke Tukang
    INSERT INTO notifications (
      user_id,
      title,
      body,
      deep_link
    ) VALUES (
      v_req.requester_id,
      'Pembatalan Ditolak Pelanggan',
      'Pelanggan menolak pengajuan pembatalan Anda. Harap lanjutkan tugas sesuai Nota Sah. Anda tidak dapat mengajukan pembatalan lagi pada job ini (BR-55).',
      'beres://jobs/' || p_job_id
    );

    -- Pesan chat sistem
    INSERT INTO chat_messages (
      job_id,
      sender_id,
      message_type,
      content
    ) VALUES (
      p_job_id,
      v_user_id,
      'SYSTEM_EVENT',
      'Pelanggan menolak pembatalan. Pekerjaan dilanjutkan pada status: ' || v_req.status_before_cancel::TEXT
    );

    RETURN jsonb_build_object(
      'success', true,
      'decision', 'REJECTED',
      'new_job_status', v_req.status_before_cancel
    );
  END IF;
END;
$$;


-- 5. RPC: USER REQUEST CANCEL OTW >= 3 JAM (FR-018, BR-56b)
-- Tombol Cancel hanya muncul di User jika ON_THE_WAY >= 3 jam dan belum tiba
CREATE OR REPLACE FUNCTION rpc_user_request_cancel_otw_3h(
  p_job_id UUID,
  p_reason_category TEXT,
  p_reason_text TEXT,
  p_action_after_cancel TEXT DEFAULT 'OPEN' -- 'OPEN' (lepas ke bursa lagi) atau 'CANCELLED' (tutup job permanen)
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_job RECORD;
  v_otw_start TIMESTAMPTZ;
  v_elapsed_hours DOUBLE PRECISION;
  v_req_id UUID;
  v_user_name TEXT;
BEGIN
  -- 1. Validasi dan kunci job
  SELECT * INTO v_job
  FROM jobs
  WHERE id = p_job_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pekerjaan tidak ditemukan.';
  END IF;

  IF v_job.user_id != auth.uid() THEN
    RAISE EXCEPTION 'Hanya pelanggan pemilik pekerjaan yang berhak mengajukan pembatalan ini.';
  END IF;

  IF v_job.status != 'ON_THE_WAY' THEN
    RAISE EXCEPTION 'Pembatalan ini hanya berlaku saat status ON_THE_WAY (Status saat ini: %).', v_job.status;
  END IF;

  -- 2. Cari kapan status ON_THE_WAY dimulai dari job_status_history
  SELECT created_at INTO v_otw_start
  FROM job_status_history
  WHERE job_id = p_job_id
    AND to_status = 'ON_THE_WAY'
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_otw_start IS NULL THEN
    -- Fallback ke jobs.updated_at
    v_otw_start := v_job.updated_at;
  END IF;

  v_elapsed_hours := EXTRACT(EPOCH FROM (NOW() - v_otw_start)) / 3600.0;

  -- 3. Penegakan mutlak BR-56: minimal 3 jam ON_THE_WAY!
  IF v_elapsed_hours < 3.0 THEN
    RAISE EXCEPTION 'Pelanggan belum dapat membatalkan pekerjaan. Tombol Cancel baru aktif setelah tukang berstatus ON_THE_WAY minimal 3 jam (Waktu berjalan: % jam).', round(v_elapsed_hours::NUMERIC, 2);
  END IF;

  -- 4. Buat baris cancel_requests dari USER
  INSERT INTO cancel_requests (
    job_id,
    requester_id,
    requester_role,
    status,
    status_before_cancel,
    reason_category,
    reason_text,
    admin_notes,
    submitted_at
  ) VALUES (
    p_job_id,
    auth.uid(),
    'USER',
    'SUBMITTED',
    'ON_THE_WAY',
    trim(p_reason_category),
    trim(p_reason_text),
    trim(p_action_after_cancel),
    NOW()
  ) RETURNING id INTO v_req_id;

  -- 5. Ubah status pekerjaan menjadi CANCEL_PENDING
  UPDATE jobs
  SET status = 'CANCEL_PENDING',
      updated_at = NOW()
  WHERE id = p_job_id;

  -- 6. Catat history
  INSERT INTO job_status_history (
    job_id,
    from_status,
    to_status,
    actor_id,
    notes
  ) VALUES (
    p_job_id,
    'ON_THE_WAY',
    'CANCEL_PENDING',
    auth.uid(),
    'User mengajukan pembatalan karena Tukang ON_THE_WAY >= 3 jam belum tiba (BR-56b): ' || trim(p_reason_category)
  );

  SELECT full_name INTO v_user_name
  FROM profiles WHERE id = auth.uid();

  -- 7. Kirim notifikasi ke Tukang (wajib respons dalam 30 menit)
  INSERT INTO notifications (
    user_id,
    title,
    body,
    deep_link
  ) VALUES (
    v_job.locked_tukang_id,
    'Konfirmasi Pembatalan dari Pelanggan',
    'Pelanggan mengajukan pembatalan karena Anda belum tiba setelah 3 jam perjalanan. Harap respons dalam 30 menit (tanpa respons = auto-cancel & +1 Strike).',
    'beres://jobs/' || p_job_id
  );

  -- 8. Pesan chat sistem
  INSERT INTO chat_messages (
    job_id,
    sender_id,
    message_type,
    content
  ) VALUES (
    p_job_id,
    auth.uid(),
    'SYSTEM_EVENT',
    'Pelanggan mengajukan pembatalan (Tukang ON_THE_WAY >= 3 jam). Menunggu konfirmasi Tukang (Maks 30 menit).'
  );

  RETURN jsonb_build_object(
    'success', true,
    'cancel_request_id', v_req_id,
    'status', 'CANCEL_PENDING',
    'elapsed_hours', round(v_elapsed_hours::NUMERIC, 2)
  );
END;
$$;


-- 6. RPC: TUKANG RESPOND TO USER CANCEL OTW 3H (BR-56b)
CREATE OR REPLACE FUNCTION rpc_tukang_respond_to_user_cancel(
  p_job_id UUID,
  p_approved BOOLEAN
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_job RECORD;
  v_req RECORD;
  v_tukang_id UUID;
  v_target_status job_status := 'OPEN';
BEGIN
  v_tukang_id := auth.uid();

  -- 1. Validasi dan kunci job
  SELECT * INTO v_job
  FROM jobs
  WHERE id = p_job_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pekerjaan tidak ditemukan.';
  END IF;

  IF v_job.locked_tukang_id != v_tukang_id THEN
    RAISE EXCEPTION 'Hanya tukang yang bertugas yang dapat menanggapi permintaan ini.';
  END IF;

  IF v_job.status != 'CANCEL_PENDING' THEN
    RAISE EXCEPTION 'Status pekerjaan bukan CANCEL_PENDING (Status: %).', v_job.status;
  END IF;

  -- 2. Ambil permintaan pembatalan aktif dari USER
  SELECT * INTO v_req
  FROM cancel_requests
  WHERE job_id = p_job_id
    AND requester_role = 'USER'
    AND status = 'SUBMITTED'
  ORDER BY created_at DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Tidak ada pengajuan pembatalan dari pelanggan yang sedang menunggu tanggapan.';
  END IF;

  -- 3. JIKA TUKANG MENYETUJUI:
  IF p_approved THEN
    UPDATE cancel_requests
    SET status = 'APPROVED',
        resolved_by = v_tukang_id,
        resolved_at = NOW()
    WHERE id = v_req.id;

    -- Tentukan target status berdasarkan preferensi User di admin_notes ('OPEN' atau 'CANCELLED')
    IF v_req.admin_notes = 'CANCELLED' THEN
      v_target_status := 'CANCELLED';
    ELSE
      v_target_status := 'OPEN';
    END IF;

    UPDATE jobs
    SET status = v_target_status,
        locked_tukang_id = CASE WHEN v_target_status = 'OPEN' THEN NULL ELSE v_job.locked_tukang_id END,
        expires_at = CASE WHEN v_target_status = 'OPEN' THEN NOW() + INTERVAL '24 hours' ELSE v_job.expires_at END,
        updated_at = NOW()
    WHERE id = p_job_id;

    -- Void Nota
    UPDATE notas
    SET status = 'VOID', updated_at = NOW()
    WHERE job_id = p_job_id AND status IN ('SENT', 'APPROVED');

    -- Catat history
    INSERT INTO job_status_history (
      job_id,
      from_status,
      to_status,
      actor_id,
      notes
    ) VALUES (
      p_job_id,
      'CANCEL_PENDING',
      v_target_status,
      v_tukang_id,
      'Tukang menyetujui pembatalan 3 jam OTW dari User secara sukarela.'
    );

    -- Notifikasi ke User
    INSERT INTO notifications (
      user_id,
      title,
      body,
      deep_link
    ) VALUES (
      v_job.user_id,
      'Pembatalan Disetujui Tukang',
      'Tukang telah menyetujui pembatalan. Pekerjaan status: ' || v_target_status::TEXT,
      'beres://jobs/' || p_job_id
    );

    RETURN jsonb_build_object(
      'success', true,
      'decision', 'APPROVED',
      'new_status', v_target_status
    );

  -- 4. JIKA TUKANG MENOLAK:
  ELSE
    UPDATE cancel_requests
    SET status = 'REJECTED',
        resolved_by = v_tukang_id,
        resolved_at = NOW()
    WHERE id = v_req.id;

    UPDATE jobs
    SET status = 'ON_THE_WAY',
        updated_at = NOW()
    WHERE id = p_job_id;

    INSERT INTO job_status_history (
      job_id,
      from_status,
      to_status,
      actor_id,
      notes
    ) VALUES (
      p_job_id,
      'CANCEL_PENDING',
      'ON_THE_WAY',
      v_tukang_id,
      'Tukang menolak pembatalan 3 jam OTW dan melanjutkan perjalanan.'
    );

    INSERT INTO notifications (
      user_id,
      title,
      body,
      deep_link
    ) VALUES (
      v_job.user_id,
      'Tukang Menolak Pembatalan',
      'Tukang mengonfirmasi sedang dalam perjalanan mendekati lokasi Anda. Status kembali ke ON_THE_WAY.',
      'beres://jobs/' || p_job_id
    );

    RETURN jsonb_build_object(
      'success', true,
      'decision', 'REJECTED',
      'new_status', 'ON_THE_WAY'
    );
  END IF;
END;
$$;


-- 7. RPC: TUKANG REPORT USER UNRESPONSIVE ON OTW / ARRIVED (> 30 MENIT) (BR-71)
-- Jika User tidak aktif / tidak balas chat > 30 menit saat Tukang ON_THE_WAY / ARRIVED
CREATE OR REPLACE FUNCTION rpc_tukang_report_user_unresponsive(
  p_job_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_job RECORD;
  v_last_tukang_msg TIMESTAMPTZ;
  v_last_user_msg TIMESTAMPTZ;
  v_elapsed_minutes DOUBLE PRECISION;
  v_tukang_id UUID;
BEGIN
  v_tukang_id := auth.uid();

  -- 1. Validasi pekerjaan dan status
  SELECT * INTO v_job
  FROM jobs
  WHERE id = p_job_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pekerjaan tidak ditemukan.';
  END IF;

  IF v_job.locked_tukang_id != v_tukang_id THEN
    RAISE EXCEPTION 'Hanya tukang yang bertugas yang dapat melaporkan hal ini.';
  END IF;

  IF v_job.status NOT IN ('ON_THE_WAY', 'ARRIVED') THEN
    RAISE EXCEPTION 'Laporan pelanggan tidak aktif hanya dapat dilakukan saat status ON_THE_WAY atau ARRIVED (Status: %).', v_job.status;
  END IF;

  -- 2. Cek pesan terakhir dari Tukang
  SELECT created_at INTO v_last_tukang_msg
  FROM chat_messages
  WHERE job_id = p_job_id
    AND sender_id = v_tukang_id
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_last_tukang_msg IS NULL THEN
    RAISE EXCEPTION 'Anda belum pernah mengirim pesan chat ke pelanggan pada pekerjaan ini.';
  END IF;

  -- 3. Cek apakah ada balasan dari User setelah pesan terakhir Tukang
  SELECT created_at INTO v_last_user_msg
  FROM chat_messages
  WHERE job_id = p_job_id
    AND sender_id = v_job.user_id
    AND created_at > v_last_tukang_msg
  ORDER BY created_at DESC
  LIMIT 1;

  IF v_last_user_msg IS NOT NULL THEN
    RAISE EXCEPTION 'Pelanggan telah membalas chat Anda. Pelanggan masih aktif.';
  END IF;

  -- 4. Hitung durasi sejak pesan terakhir Tukang tanpa balasan
  v_elapsed_minutes := EXTRACT(EPOCH FROM (NOW() - v_last_tukang_msg)) / 60.0;

  IF v_elapsed_minutes < 30.0 THEN
    RAISE EXCEPTION 'Batas waktu tunggu respons adalah 30 menit (Baru berjalan % menit). Mohon tunggu pelanggan membalas (BR-71).', round(v_elapsed_minutes::NUMERIC, 1);
  END IF;

  -- 5. Lepas job kembali ke Job Portal (OPEN) agar tukang bebas mencari pekerjaan lain
  UPDATE jobs
  SET status = 'OPEN',
      locked_tukang_id = NULL,
      expires_at = NOW() + INTERVAL '24 hours',
      updated_at = NOW()
  WHERE id = p_job_id;

  -- Void Nota
  UPDATE notas
  SET status = 'VOID', updated_at = NOW()
  WHERE job_id = p_job_id AND status IN ('SENT', 'APPROVED');

  -- Catat history
  INSERT INTO job_status_history (
    job_id,
    from_status,
    to_status,
    actor_id,
    notes
  ) VALUES (
    p_job_id,
    v_job.status,
    'OPEN',
    v_tukang_id,
    'Tukang melepas job karena User tidak merespons chat > 30 menit saat ' || v_job.status::TEXT || '. User terkena +1 Strike (BR-71).'
  );

  -- 6. PENCATATAN +1 STRIKE USER (BR-71)
  -- trg_record_strike_and_check_auto_suspend otomatis menghitung strike & menerapkan suspend jika > 3x!
  INSERT INTO strikes (
    user_id,
    role,
    job_id,
    strike_type,
    description
  ) VALUES (
    v_job.user_id,
    'USER',
    p_job_id,
    'USER_UNRESPONSIVE_OTW_ARRIVED',
    'Pelanggan tidak aktif / tidak membalas chat tukang selama > 30 menit saat tukang ' || v_job.status::TEXT || ' (BR-71)'
  );

  -- 7. Notifikasi ke User & Tukang
  INSERT INTO notifications (
    user_id,
    title,
    body,
    deep_link
  ) VALUES (
    v_job.user_id,
    'Peringatan: 1 Strike Diterima',
    'Pekerjaan dilepas karena Anda tidak merespons chat tukang > 30 menit saat tukang dalam perjalanan / di lokasi (BR-71). Anda menerima 1 Strike.',
    'beres://profile'
  );

  INSERT INTO notifications (
    user_id,
    title,
    body,
    deep_link
  ) VALUES (
    v_tukang_id,
    'Pekerjaan Telah Dilepas',
    'Laporan diterima. Ikatan tugas telah dilepas dan Anda dapat melamar pekerjaan lain di Bursa Pekerjaan.',
    'beres://job-portal'
  );

  RETURN jsonb_build_object(
    'success', true,
    'job_status', 'OPEN',
    'strike_applied_to_user', true
  );
END;
$$;


-- 8. RPC: AUTO-CANCEL RESOLUTION FOR TIMER EXPIRY (BR-56b & BR-55)
-- Dapat dipanggil berkala (cron / background task / periodic check)
CREATE OR REPLACE FUNCTION rpc_check_unresponsive_cancellations()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_req RECORD;
  v_count INTEGER := 0;
  v_job RECORD;
  v_target_status job_status := 'OPEN';
BEGIN
  -- 1. Scan permintaan pembatalan dari USER (OTW 3 Jam) yang sudah SUBMITTED > 30 menit tanpa respons Tukang (BR-56b)
  FOR v_req IN
    SELECT cr.*
    FROM cancel_requests cr
    JOIN jobs j ON cr.job_id = j.id
    WHERE cr.requester_role = 'USER'
      AND cr.status = 'SUBMITTED'
      AND j.status = 'CANCEL_PENDING'
      AND cr.submitted_at <= NOW() - INTERVAL '30 minutes'
    FOR UPDATE OF cr
  LOOP
    SELECT * INTO v_job FROM jobs WHERE id = v_req.job_id FOR UPDATE;

    -- Update cancel request menjadi APPROVED (Auto-Cancel sistem)
    UPDATE cancel_requests
    SET status = 'APPROVED',
        resolved_by = NULL,
        resolved_at = NOW()
    WHERE id = v_req.id;

    IF v_req.admin_notes = 'CANCELLED' THEN
      v_target_status := 'CANCELLED';
    ELSE
      v_target_status := 'OPEN';
    END IF;

    UPDATE jobs
    SET status = v_target_status,
        locked_tukang_id = CASE WHEN v_target_status = 'OPEN' THEN NULL ELSE v_job.locked_tukang_id END,
        expires_at = CASE WHEN v_target_status = 'OPEN' THEN NOW() + INTERVAL '24 hours' ELSE v_job.expires_at END,
        updated_at = NOW()
    WHERE id = v_job.id;

    -- Void Nota
    UPDATE notas
    SET status = 'VOID', updated_at = NOW()
    WHERE job_id = v_job.id AND status IN ('SENT', 'APPROVED');

    -- TUKANG MENDAPATKAN +1 STRIKE TUKANG (BR-56b)
    INSERT INTO strikes (
      user_id,
      role,
      job_id,
      strike_type,
      description
    ) VALUES (
      v_job.locked_tukang_id,
      'TUKANG',
      v_job.id,
      'OTW_3H_UNRESPONSIVE',
      'Tukang tidak merespons pengajuan pembatalan 3 jam ON_THE_WAY dari pelanggan dalam 30 menit (Auto-Cancel BR-56b)'
    );

    -- Catat history
    INSERT INTO job_status_history (
      job_id,
      from_status,
      to_status,
      actor_id,
      notes
    ) VALUES (
      v_job.id,
      'CANCEL_PENDING',
      v_target_status,
      NULL,
      'Auto-Cancel oleh Sistem: Tukang tidak merespons pembatalan 3 jam OTW dalam 30 menit. Tukang menerima +1 Strike (BR-56b).'
    );

    -- Notifikasi
    INSERT INTO notifications (
      user_id,
      title,
      body,
      deep_link
    ) VALUES (
      v_job.locked_tukang_id,
      'Auto-Cancel: 1 Strike Diterima',
      'Pekerjaan dibatalkan otomatis karena Anda tidak merespons dalam 30 menit. Anda menerima 1 Strike Tukang (BR-56b).',
      'beres://profile'
    );

    INSERT INTO notifications (
      user_id,
      title,
      body,
      deep_link
    ) VALUES (
      v_job.user_id,
      'Pembatalan Berhasil (Auto-Cancel)',
      'Tukang tidak merespons dalam 30 menit. Pekerjaan telah dibatalkan otomatis oleh sistem sesuai aturan BR-56b.',
      'beres://jobs/' || v_job.id
    );

    v_count := v_count + 1;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'resolved_auto_cancellations', v_count
  );
END;
$$;


-- 9. RPC ADMIN: EXCUSE STRIKE & RE-EVALUATE SUSPENSION (FR-033, FR-039)
CREATE OR REPLACE FUNCTION rpc_admin_excuse_strike(
  p_strike_id UUID,
  p_excuse_reason TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_strike RECORD;
  v_active_strikes INTEGER := 0;
  v_max_strikes INTEGER := 3;
  v_tz TEXT := 'Asia/Jakarta';
  v_now_in_tz TIMESTAMPTZ;
  v_month_start TIMESTAMPTZ;
  v_month_end TIMESTAMPTZ;
  v_profile RECORD;
BEGIN
  -- Validasi strike
  SELECT * INTO v_strike
  FROM strikes
  WHERE id = p_strike_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Strike tidak ditemukan.';
  END IF;

  IF v_strike.is_excused THEN
    RAISE EXCEPTION 'Strike ini sudah pernah diampuni sebelumnya.';
  END IF;

  -- Update strike menjadi dimaafkan
  UPDATE strikes
  SET is_excused = TRUE
  WHERE id = p_strike_id;

  -- Catat ke audit_logs
  INSERT INTO audit_logs (
    actor_id,
    action,
    target_type,
    target_id,
    metadata
  ) VALUES (
    auth.uid(),
    'EXCUSE_STRIKE',
    'strikes',
    p_strike_id::TEXT,
    jsonb_build_object(
      'user_id', v_strike.user_id,
      'role', v_strike.role,
      'strike_type', v_strike.strike_type,
      'reason', trim(p_excuse_reason)
    )
  );

  -- Cek profil pengguna
  SELECT * INTO v_profile
  FROM profiles
  WHERE id = v_strike.user_id
  FOR UPDATE;

  -- Jika akun saat ini sedang AUTO_2_DAYS, cek apakah sisa strike aktif <= 3
  IF v_profile.suspend_type = 'AUTO_2_DAYS' THEN
    v_tz := COALESCE(v_profile.timezone, 'Asia/Jakarta');
    SELECT COALESCE(value_int, 3) INTO v_max_strikes
    FROM app_configs WHERE key = 'max_monthly_strikes';

    v_now_in_tz := NOW() AT TIME ZONE v_tz;
    v_month_start := (date_trunc('month', v_now_in_tz)) AT TIME ZONE v_tz;
    v_month_end := (date_trunc('month', v_now_in_tz) + INTERVAL '1 month') AT TIME ZONE v_tz;

    SELECT COUNT(*) INTO v_active_strikes
    FROM strikes
    WHERE user_id = v_strike.user_id
      AND is_excused = FALSE
      AND created_at >= v_month_start
      AND created_at < v_month_end;

    IF v_active_strikes <= v_max_strikes THEN
      UPDATE profiles
      SET suspend_type = 'NONE',
          suspended_until = NULL,
          suspend_reason = NULL,
          updated_at = NOW()
      WHERE id = v_strike.user_id;

      INSERT INTO notifications (
        user_id,
        title,
        body,
        deep_link
      ) VALUES (
        v_strike.user_id,
        'Penangguhan Akun Dicabut',
        'Strike Anda telah ditinjau dan dimaafkan oleh Admin (' || trim(p_excuse_reason) || '). Pembekuan akun Anda telah dicabut.',
        'beres://profile'
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'strike_id', p_strike_id,
    'is_excused', true,
    'remaining_active_strikes', v_active_strikes
  );
END;
$$;


-- 10. RPC: GET ACCOUNT STRIKE DETAILS (FR-039)
CREATE OR REPLACE FUNCTION rpc_get_account_strikes(
  p_user_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_results JSONB;
BEGIN
  SELECT COALESCE(jsonb_agg(item), '[]'::JSONB) INTO v_results
  FROM (
    SELECT
      s.id,
      s.user_id,
      s.role,
      s.job_id,
      s.strike_type,
      s.description,
      s.is_excused,
      s.created_at,
      j.description AS job_description
    FROM strikes s
    LEFT JOIN jobs j ON s.job_id = j.id
    WHERE s.user_id = p_user_id
    ORDER BY s.created_at DESC
  ) item;

  RETURN v_results;
END;
$$;


-- Amankan search_path & izin eksekusi
ALTER FUNCTION rpc_tukang_create_cancel_draft(UUID) SET search_path = public;
ALTER FUNCTION rpc_tukang_abort_cancel_draft(UUID) SET search_path = public;
ALTER FUNCTION rpc_tukang_submit_cancel_request(UUID, TEXT, TEXT, TEXT, TEXT[], DOUBLE PRECISION, DOUBLE PRECISION) SET search_path = public;
ALTER FUNCTION rpc_user_respond_to_tukang_cancel(UUID, BOOLEAN, TEXT) SET search_path = public;
ALTER FUNCTION rpc_user_request_cancel_otw_3h(UUID, TEXT, TEXT, TEXT) SET search_path = public;
ALTER FUNCTION rpc_tukang_respond_to_user_cancel(UUID, BOOLEAN) SET search_path = public;
ALTER FUNCTION rpc_tukang_report_user_unresponsive(UUID) SET search_path = public;
ALTER FUNCTION rpc_check_unresponsive_cancellations() SET search_path = public;
ALTER FUNCTION rpc_admin_excuse_strike(UUID, TEXT) SET search_path = public;
ALTER FUNCTION rpc_get_account_strikes(UUID) SET search_path = public;

GRANT EXECUTE ON FUNCTION rpc_tukang_create_cancel_draft(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_tukang_abort_cancel_draft(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_tukang_submit_cancel_request(UUID, TEXT, TEXT, TEXT, TEXT[], DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_user_respond_to_tukang_cancel(UUID, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_user_request_cancel_otw_3h(UUID, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_tukang_respond_to_user_cancel(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_tukang_report_user_unresponsive(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_check_unresponsive_cancellations() TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_admin_excuse_strike(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_get_account_strikes(UUID) TO authenticated;
