-- ============================================================================
-- BERES MIGRATION 0007: Eksekusi Kerja, Live GPS, Kedatangan 50m/200m, Penyelesaian & Laporan Pembayaran
-- Selaras dengan docs/PRD.md v1.4.0 (FR-016, FR-017, FR-021, FR-024, FR-025, FR-030; BR-21, BR-32, BR-60, BR-61, BR-62, BR-65, BR-67)
-- ============================================================================

-- 1. REALTIME PUBLICATION SETUP FOR LOCATION PINGS
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'location_pings'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE location_pings;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END;
$$;

-- 2. TRIGGER: PERHITUNGAN RATING RATA-RATA TUKANG (FR-021)
CREATE OR REPLACE FUNCTION fn_update_tukang_rating()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_avg NUMERIC(3, 2);
  v_count INTEGER;
BEGIN
  SELECT
    COALESCE(ROUND(AVG(rating)::NUMERIC, 2), 0.00),
    COUNT(*)
  INTO v_avg, v_count
  FROM reviews
  WHERE tukang_id = NEW.tukang_id;

  UPDATE tukang_profiles
  SET rating_avg = v_avg,
      rating_count = v_count,
      updated_at = NOW()
  WHERE user_id = NEW.tukang_id;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_update_tukang_rating
AFTER INSERT OR UPDATE ON reviews
FOR EACH ROW
EXECUTE FUNCTION fn_update_tukang_rating();


-- 3. RPC: RECORD LOCATION PING & AUTO ARRIVED 50 METER (FR-016, FR-024, BR-60)
CREATE OR REPLACE FUNCTION rpc_record_location_ping(
  p_job_id UUID,
  p_latitude DOUBLE PRECISION,
  p_longitude DOUBLE PRECISION,
  p_accuracy_m DOUBLE PRECISION DEFAULT NULL,
  p_heading DOUBLE PRECISION DEFAULT NULL,
  p_speed DOUBLE PRECISION DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tukang_id UUID;
  v_job jobs%ROWTYPE;
  v_ping_point GEOGRAPHY(POINT, 4326);
  v_distance_m DOUBLE PRECISION := NULL;
  v_auto_arrived BOOLEAN := FALSE;
  v_auto_radius INTEGER := 50;
BEGIN
  v_tukang_id := auth.uid();
  IF v_tukang_id IS NULL THEN
    RAISE EXCEPTION 'Pengguna belum terautentikasi';
  END IF;

  SELECT * INTO v_job FROM jobs WHERE id = p_job_id;
  IF v_job.id IS NULL THEN
    RAISE EXCEPTION 'Pekerjaan tidak ditemukan';
  END IF;

  IF v_job.locked_tukang_id <> v_tukang_id THEN
    RAISE EXCEPTION 'Hanya Mitra Tukang yang bertugas yang dapat mengirimkan koordinat lokasi';
  END IF;

  v_ping_point := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::GEOGRAPHY;

  -- 1. Catat ke tabel location_pings
  INSERT INTO location_pings (
    job_id,
    tukang_id,
    location,
    accuracy_m,
    heading,
    speed,
    recorded_at
  ) VALUES (
    p_job_id,
    v_tukang_id,
    v_ping_point,
    p_accuracy_m,
    p_heading,
    p_speed,
    NOW()
  );

  -- 2. Perbarui last_known_location tukang
  UPDATE tukang_profiles
  SET last_known_location = v_ping_point,
      location_updated_at = NOW(),
      updated_at = NOW()
  WHERE user_id = v_tukang_id;

  -- 3. Hitung jarak ke titik lokasi pekerjaan
  v_distance_m := ST_Distance(v_job.location, v_ping_point);

  -- 4. DETEKSI STATUS ARRIVED OTOMATIS SAAT JARAK <= 50 METER (BR-60)
  -- Syarat: Status saat ini ON_THE_WAY, akurasi GPS <= 30m (bila akurasi tersedia)
  SELECT COALESCE(value_int, 50) INTO v_auto_radius
  FROM app_configs WHERE key = 'arrived_auto_radius_m';

  IF v_job.status = 'ON_THE_WAY' AND v_distance_m <= v_auto_radius THEN
    IF p_accuracy_m IS NULL OR p_accuracy_m <= 30.0 THEN
      UPDATE jobs
      SET status = 'ARRIVED',
          arrival_mode = 'AUTO',
          arrived_at = NOW(),
          updated_at = NOW()
      WHERE id = p_job_id;

      INSERT INTO job_status_history (
        job_id,
        from_status,
        to_status,
        actor_id,
        actor_role,
        reason
      ) VALUES (
        p_job_id,
        'ON_THE_WAY',
        'ARRIVED',
        v_tukang_id,
        'SYSTEM',
        'Deteksi GPS otomatis: Jarak ' || ROUND(v_distance_m::NUMERIC, 1) || ' meter <= ' || v_auto_radius || 'm (BR-60)'
      );

      INSERT INTO chat_messages (
        job_id,
        sender_id,
        message_type,
        content
      ) VALUES (
        p_job_id,
        v_tukang_id,
        'SYSTEM_EVENT',
        'Mitra Tukang telah tiba di lokasi pekerjaan (Terdeteksi otomatis jarak ' || ROUND(v_distance_m::NUMERIC, 1) || ' meter).'
      );

      INSERT INTO notifications (
        user_id,
        title,
        body,
        deep_link
      ) VALUES (
        v_job.user_id,
        'Tukang Telah Tiba!',
        'Mitra Tukang telah sampai di lokasi pekerjaan Anda.',
        'beres://job/' || p_job_id || '/chat'
      );

      v_auto_arrived := TRUE;
      v_job.status := 'ARRIVED';
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'job_id', p_job_id,
    'distance_m', v_distance_m,
    'status', v_job.status,
    'auto_arrived', v_auto_arrived
  );
END;
$$;


-- 4. RPC: CONFIRM ARRIVAL MANUAL SAAT <= 200 METER (FR-024, BR-61)
CREATE OR REPLACE FUNCTION rpc_confirm_arrival_manual(
  p_job_id UUID,
  p_latitude DOUBLE PRECISION,
  p_longitude DOUBLE PRECISION
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tukang_id UUID;
  v_job jobs%ROWTYPE;
  v_current_point GEOGRAPHY(POINT, 4326);
  v_distance_m DOUBLE PRECISION;
  v_manual_radius INTEGER := 200;
BEGIN
  v_tukang_id := auth.uid();
  IF v_tukang_id IS NULL THEN
    RAISE EXCEPTION 'Pengguna belum terautentikasi';
  END IF;

  SELECT * INTO v_job FROM jobs WHERE id = p_job_id FOR UPDATE;
  IF v_job.id IS NULL THEN
    RAISE EXCEPTION 'Pekerjaan tidak ditemukan';
  END IF;

  IF v_job.locked_tukang_id <> v_tukang_id THEN
    RAISE EXCEPTION 'Hanya Mitra Tukang yang ditugaskan yang dapat menekan tombol kedatangan';
  END IF;

  IF v_job.status <> 'ON_THE_WAY' THEN
    RAISE EXCEPTION 'Konfirmasi kedatangan hanya dapat dilakukan saat status ON_THE_WAY (Status saat ini: %)', v_job.status;
  END IF;

  SELECT COALESCE(value_int, 200) INTO v_manual_radius
  FROM app_configs WHERE key = 'arrived_manual_radius_m';

  v_current_point := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::GEOGRAPHY;
  v_distance_m := ST_Distance(v_job.location, v_current_point);

  IF v_distance_m > v_manual_radius THEN
    RAISE EXCEPTION 'BR-61: Jarak Anda (% meter) masih melebihi batas maksimal % meter untuk konfirmasi kedatangan manual',
      ROUND(v_distance_m::NUMERIC, 1), v_manual_radius;
  END IF;

  -- Update ke ARRIVED manual
  UPDATE jobs
  SET status = 'ARRIVED',
      arrival_mode = 'MANUAL',
      arrived_at = NOW(),
      updated_at = NOW()
  WHERE id = p_job_id;

  INSERT INTO job_status_history (
    job_id,
    from_status,
    to_status,
    actor_id,
    actor_role,
    reason
  ) VALUES (
    p_job_id,
    'ON_THE_WAY',
    'ARRIVED',
    v_tukang_id,
    'TUKANG',
    'Tukang menekan tombol manual Saya Sudah Tiba pada jarak ' || ROUND(v_distance_m::NUMERIC, 1) || ' meter (BR-61)'
  );

  INSERT INTO chat_messages (
    job_id,
    sender_id,
    message_type,
    content
  ) VALUES (
    p_job_id,
    v_tukang_id,
    'SYSTEM_EVENT',
    'Mitra Tukang telah tiba di lokasi (Konfirmasi Manual jarak ' || ROUND(v_distance_m::NUMERIC, 1) || ' meter).'
  );

  INSERT INTO notifications (
    user_id,
    title,
    body,
    deep_link
  ) VALUES (
    v_job.user_id,
    'Tukang Telah Tiba!',
    'Mitra Tukang telah mengonfirmasi kedatangan di lokasi Anda.',
    'beres://job/' || p_job_id || '/chat'
  );

  RETURN jsonb_build_object(
    'success', true,
    'job_id', p_job_id,
    'status', 'ARRIVED',
    'arrival_mode', 'MANUAL',
    'distance_m', v_distance_m
  );
END;
$$;


-- 5. RPC: START WORK (FR-024, BR-62)
-- Mengubah status dari ARRIVED menjadi WORKING
CREATE OR REPLACE FUNCTION rpc_start_work(
  p_job_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tukang_id UUID;
  v_job jobs%ROWTYPE;
BEGIN
  v_tukang_id := auth.uid();
  IF v_tukang_id IS NULL THEN
    RAISE EXCEPTION 'Pengguna belum terautentikasi';
  END IF;

  SELECT * INTO v_job FROM jobs WHERE id = p_job_id FOR UPDATE;
  IF v_job.id IS NULL THEN
    RAISE EXCEPTION 'Pekerjaan tidak ditemukan';
  END IF;

  IF v_job.locked_tukang_id <> v_tukang_id THEN
    RAISE EXCEPTION 'Hanya Mitra Tukang yang bertugas yang dapat menekan Mulai Bekerja';
  END IF;

  IF v_job.status <> 'ARRIVED' THEN
    RAISE EXCEPTION 'Status pekerjaan harus ARRIVED sebelum mulai bekerja (Status saat ini: %)', v_job.status;
  END IF;

  UPDATE jobs
  SET status = 'WORKING',
      work_started_at = NOW(),
      updated_at = NOW()
  WHERE id = p_job_id;

  INSERT INTO job_status_history (
    job_id,
    from_status,
    to_status,
    actor_id,
    actor_role,
    reason
  ) VALUES (
    p_job_id,
    'ARRIVED',
    'WORKING',
    v_tukang_id,
    'TUKANG',
    'Tukang menekan tombol Mulai Bekerja (BR-62)'
  );

  INSERT INTO chat_messages (
    job_id,
    sender_id,
    message_type,
    content
  ) VALUES (
    p_job_id,
    v_tukang_id,
    'SYSTEM_EVENT',
    'Mitra Tukang telah mulai mengerjakan pekerjaan. Sesuai aturan BR-65, pekerjaan tidak dapat dibatalkan pada tahap ini.'
  );

  INSERT INTO notifications (
    user_id,
    title,
    body,
    deep_link
  ) VALUES (
    v_job.user_id,
    'Pekerjaan Dimulai',
    'Mitra Tukang telah mulai mengerjakan pesanan Anda. Pekerjaan tidak dapat dibatalkan (BR-65).',
    'beres://job/' || p_job_id || '/chat'
  );

  RETURN jsonb_build_object(
    'success', true,
    'job_id', p_job_id,
    'status', 'WORKING',
    'work_started_at', NOW()
  );
END;
$$;


-- 6. RPC: COMPLETE JOB (FR-025, BR-21, BR-32, BR-65)
-- Syarat wajib: min 1 foto bukti kerja, pilih metode bayar aktual, centang user sudah bayar, upload bukti transfer bila non-tunai, tidak ada revisi nota SENT
CREATE OR REPLACE FUNCTION rpc_complete_job(
  p_job_id UUID,
  p_actual_payment_method payment_method_type,
  p_user_paid_confirmed BOOLEAN,
  p_work_photos TEXT[],
  p_payment_proof_photo TEXT DEFAULT NULL,
  p_completion_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tukang_id UUID;
  v_job jobs%ROWTYPE;
  v_photo_url TEXT;
  v_photo_count INTEGER := 0;
BEGIN
  v_tukang_id := auth.uid();
  IF v_tukang_id IS NULL THEN
    RAISE EXCEPTION 'Pengguna belum terautentikasi';
  END IF;

  SELECT * INTO v_job FROM jobs WHERE id = p_job_id FOR UPDATE;
  IF v_job.id IS NULL THEN
    RAISE EXCEPTION 'Pekerjaan tidak ditemukan';
  END IF;

  IF v_job.locked_tukang_id <> v_tukang_id THEN
    RAISE EXCEPTION 'Hanya Mitra Tukang yang bertugas yang dapat menyelesaikan pekerjaan';
  END IF;

  IF v_job.status <> 'WORKING' THEN
    RAISE EXCEPTION 'Pekerjaan hanya dapat diselesaikan jika berstatus WORKING (Status saat ini: %)', v_job.status;
  END IF;

  -- 1. Validasi Syarat BR-32: Foto Bukti Hasil Kerja (Wajib >= 1, Maks 5)
  IF p_work_photos IS NULL OR array_length(p_work_photos, 1) = 0 THEN
    RAISE EXCEPTION 'BR-32: Wajib mengunggah minimal 1 Foto Bukti Hasil Kerja';
  END IF;

  IF array_length(p_work_photos, 1) > 5 THEN
    RAISE EXCEPTION 'Maksimal 5 Foto Bukti Hasil Kerja yang dapat dilampirkan';
  END IF;

  -- 2. Validasi Syarat BR-32: Centang User Sudah Membayar
  IF p_user_paid_confirmed IS NOT TRUE THEN
    RAISE EXCEPTION 'BR-32: Anda wajib mencentang konfirmasi bahwa Pelanggan telah membayar sesuai Nota Sah';
  END IF;

  -- 3. Validasi Syarat BR-32: Screenshot Bukti Bayar wajib untuk Non-Tunai
  IF p_actual_payment_method IN ('BANK_TRANSFER', 'E_WALLET') THEN
    IF p_payment_proof_photo IS NULL OR trim(p_payment_proof_photo) = '' THEN
      RAISE EXCEPTION 'BR-32: Wajib mengunggah Screenshot Bukti Pembayaran untuk metode Transfer Bank / E-Wallet';
    END IF;
  END IF;

  -- 4. Validasi Syarat BR-32: Tidak boleh ada Revisi Nota berstatus SENT yang menggantung
  IF EXISTS (SELECT 1 FROM notas WHERE job_id = p_job_id AND status = 'SENT') THEN
    RAISE EXCEPTION 'BR-32: Masih ada pengajuan Revisi Nota yang belum disetujui Pelanggan. Tarik revisi atau tunggu persetujuan.';
  END IF;

  -- 5. Simpan Foto Hasil Kerja ke job_photos
  FOREACH v_photo_url IN ARRAY p_work_photos LOOP
    IF trim(v_photo_url) <> '' THEN
      INSERT INTO job_photos (
        job_id,
        uploaded_by,
        type,
        storage_path
      ) VALUES (
        p_job_id,
        v_tukang_id,
        'WORK_RESULT',
        trim(v_photo_url)
      );
      v_photo_count := v_photo_count + 1;
    END IF;
  END LOOP;

  -- 6. Simpan Foto Bukti Bayar bila ada
  IF p_payment_proof_photo IS NOT NULL AND trim(p_payment_proof_photo) <> '' THEN
    INSERT INTO job_photos (
      job_id,
      uploaded_by,
      type,
      storage_path
    ) VALUES (
      p_job_id,
      v_tukang_id,
      'PAYMENT_PROOF',
      trim(p_payment_proof_photo)
    );
  END IF;

  -- 7. Update status ke COMPLETED
  UPDATE jobs
  SET status = 'COMPLETED',
      completed_at = NOW(),
      actual_payment_method = p_actual_payment_method,
      user_paid_confirmed = TRUE,
      payment_confirmed_at = NOW(),
      completion_note = trim(p_completion_note),
      updated_at = NOW()
  WHERE id = p_job_id;

  INSERT INTO job_status_history (
    job_id,
    from_status,
    to_status,
    actor_id,
    actor_role,
    reason
  ) VALUES (
    p_job_id,
    'WORKING',
    'COMPLETED',
    v_tukang_id,
    'TUKANG',
    'Pekerjaan selesai. Metode pembayaran aktual: ' || p_actual_payment_method || ' (BR-32)'
  );

  INSERT INTO chat_messages (
    job_id,
    sender_id,
    message_type,
    content
  ) VALUES (
    p_job_id,
    v_tukang_id,
    'SYSTEM_EVENT',
    'Pekerjaan telah diselesaikan oleh Mitra Tukang. Pembayaran telah dikonfirmasi (' || p_actual_payment_method || '). Terima kasih telah menggunakan Beres!'
  );

  INSERT INTO notifications (
    user_id,
    title,
    body,
    deep_link
  ) VALUES (
    v_job.user_id,
    'Pekerjaan Selesai!',
    'Tukang telah menyelesaikan pekerjaan. Berikan penilaian bintang dan ulasan pengalaman Anda.',
    'beres://job/' || p_job_id || '/review'
  );

  RETURN jsonb_build_object(
    'success', true,
    'job_id', p_job_id,
    'status', 'COMPLETED',
    'completed_at', NOW(),
    'photos_uploaded_count', v_photo_count
  );
END;
$$;


-- 7. RPC: REPORT PAYMENT DISPUTE (FR-025, BR-67)
-- Tombol khusus tukang jika User menolak membayar atau bayar kurang saat WORKING
CREATE OR REPLACE FUNCTION rpc_report_payment_dispute(
  p_job_id UUID,
  p_description TEXT,
  p_work_photos TEXT[],
  p_evidence_photos TEXT[] DEFAULT '{}'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tukang_id UUID;
  v_job jobs%ROWTYPE;
  v_report_id UUID;
  v_photo_url TEXT;
  v_all_evidence TEXT[];
BEGIN
  v_tukang_id := auth.uid();
  IF v_tukang_id IS NULL THEN
    RAISE EXCEPTION 'Pengguna belum terautentikasi';
  END IF;

  SELECT * INTO v_job FROM jobs WHERE id = p_job_id FOR UPDATE;
  IF v_job.id IS NULL THEN
    RAISE EXCEPTION 'Pekerjaan tidak ditemukan';
  END IF;

  IF v_job.locked_tukang_id <> v_tukang_id THEN
    RAISE EXCEPTION 'Hanya Mitra Tukang yang bertugas yang dapat melaporkan masalah pembayaran';
  END IF;

  IF v_job.status <> 'WORKING' THEN
    RAISE EXCEPTION 'Laporan masalah pembayaran hanya dapat diajukan saat tahap WORKING (Status saat ini: %)', v_job.status;
  END IF;

  IF p_description IS NULL OR length(trim(p_description)) < 10 THEN
    RAISE EXCEPTION 'Kronologi kendala pembayaran harus diisi minimal 10 karakter';
  END IF;

  IF p_work_photos IS NULL OR array_length(p_work_photos, 1) = 0 THEN
    RAISE EXCEPTION 'Wajib melampirkan minimal 1 Foto Bukti Hasil Kerja bahwa pekerjaan fisik telah Anda selesaikan';
  END IF;

  -- Simpan foto ke job_photos
  FOREACH v_photo_url IN ARRAY p_work_photos LOOP
    IF trim(v_photo_url) <> '' THEN
      INSERT INTO job_photos (
        job_id,
        uploaded_by,
        type,
        storage_path
      ) VALUES (
        p_job_id,
        v_tukang_id,
        'WORK_RESULT',
        trim(v_photo_url)
      );
    END IF;
  END LOOP;

  v_all_evidence := array_cat(p_work_photos, COALESCE(p_evidence_photos, '{}'::TEXT[]));

  -- 1. Buat Laporan Prioritas Tinggi di tabel reports (BR-67)
  INSERT INTO reports (
    job_id,
    reporter_id,
    reported_user_id,
    category,
    is_priority,
    description,
    evidence_photos,
    status
  ) VALUES (
    p_job_id,
    v_tukang_id,
    v_job.user_id,
    'PAYMENT_DEFAULT',
    TRUE,
    trim(p_description),
    v_all_evidence,
    'OPEN'
  )
  RETURNING id INTO v_report_id;

  -- 2. Lepas ikatan job aktif tukang sementara agar tukang dapat melamar pekerjaan lain (BR-67)
  UPDATE jobs
  SET payment_dispute_active = TRUE,
      updated_at = NOW()
  WHERE id = p_job_id;

  -- 3. Catat ke chat & kirim notifikasi
  INSERT INTO chat_messages (
    job_id,
    sender_id,
    message_type,
    content
  ) VALUES (
    p_job_id,
    v_tukang_id,
    'SYSTEM_EVENT',
    'Mitra Tukang telah melaporkan masalah pembayaran ke Tim Operasional Beres (BR-67). Tim Admin akan melakukan audit Chat, Nota Sah, dan Foto Hasil Kerja.'
  );

  INSERT INTO notifications (
    user_id,
    title,
    body,
    deep_link
  ) VALUES (
    v_job.user_id,
    'Peringatan Laporan Pembayaran',
    'Mitra Tukang melaporkan bahwa Anda belum melakukan pembayaran. Tim Admin Beres sedang menginvestigasi bukti transaksi.',
    'beres://job/' || p_job_id || '/chat'
  );

  RETURN jsonb_build_object(
    'success', true,
    'report_id', v_report_id,
    'job_id', p_job_id,
    'status', 'DISPUTED_IN_REVIEW',
    'is_priority', true
  );
END;
$$;


-- 8. RPC: ADMIN SUSPEND PAYMENT DEFAULTER (BR-67, FR-033)
-- Admin memvonis User yang terbukti bersalah: langsung Suspend Permanen tanpa toleransi 3x
CREATE OR REPLACE FUNCTION rpc_admin_suspend_payment_defaulter(
  p_report_id UUID,
  p_admin_notes TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_id UUID;
  v_admin_role user_role;
  v_report reports%ROWTYPE;
  v_job jobs%ROWTYPE;
BEGIN
  v_admin_id := auth.uid();
  IF v_admin_id IS NULL THEN
    RAISE EXCEPTION 'Pengguna belum terautentikasi';
  END IF;

  SELECT role INTO v_admin_role FROM profiles WHERE id = v_admin_id;
  IF v_admin_role <> 'ADMIN' THEN
    RAISE EXCEPTION 'Hanya akun Admin yang memiliki wewenang memvonis laporan pembayaran';
  END IF;

  SELECT * INTO v_report FROM reports WHERE id = p_report_id FOR UPDATE;
  IF v_report.id IS NULL THEN
    RAISE EXCEPTION 'Laporan tidak ditemukan';
  END IF;

  IF v_report.category <> 'PAYMENT_DEFAULT' THEN
    RAISE EXCEPTION 'Fungsi ini khusus untuk laporan wanprestasi pembayaran (PAYMENT_DEFAULT)';
  END IF;

  SELECT * INTO v_job FROM jobs WHERE id = v_report.job_id FOR UPDATE;

  -- 1. Vonis User: Suspend Permanen Langsung TANPA Pemakluman 3x (BR-67)
  UPDATE profiles
  SET suspend_type = 'MANUAL_PERMANENT',
      suspend_reason = 'Akun dinonaktifkan permanen oleh Admin karena terbukti melakukan wanprestasi/tidak membayar biaya jasa sesuai Nota Sah (BR-67). Catatan investigasi: ' || trim(p_admin_notes),
      updated_at = NOW()
  WHERE id = v_report.reported_user_id;

  -- 2. Selesaikan Laporan
  UPDATE reports
  SET status = 'RESOLVED',
      resolved_by = v_admin_id,
      resolved_at = NOW(),
      admin_resolution_notes = trim(p_admin_notes)
  WHERE id = p_report_id;

  -- 3. Tutup status job tukang agar tercatat COMPLETED & selesai
  UPDATE jobs
  SET status = 'COMPLETED',
      completed_at = COALESCE(completed_at, NOW()),
      payment_dispute_active = FALSE,
      completion_note = 'Diselesaikan lewat vonis Admin: User terbukti wanprestasi dan di-suspend permanen',
      updated_at = NOW()
  WHERE id = v_report.job_id;

  -- 4. Audit Log
  INSERT INTO audit_logs (
    actor_id,
    action,
    target_type,
    target_id,
    metadata
  ) VALUES (
    v_admin_id,
    'ADMIN_VONIS_PAYMENT_DEFAULT_SUSPEND',
    'PROFILES',
    v_report.reported_user_id::TEXT,
    jsonb_build_object(
      'report_id', p_report_id,
      'job_id', v_report.job_id,
      'admin_notes', p_admin_notes
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'report_id', p_report_id,
    'user_id', v_report.reported_user_id,
    'suspend_type', 'MANUAL_PERMANENT'
  );
END;
$$;


-- 9. RPC: SUBMIT REVIEW (FR-021)
CREATE OR REPLACE FUNCTION rpc_submit_review(
  p_job_id UUID,
  p_rating INTEGER,
  p_comment TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_job jobs%ROWTYPE;
  v_review_id UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Pengguna belum terautentikasi';
  END IF;

  SELECT * INTO v_job FROM jobs WHERE id = p_job_id;
  IF v_job.id IS NULL THEN
    RAISE EXCEPTION 'Pekerjaan tidak ditemukan';
  END IF;

  IF v_job.user_id <> v_user_id THEN
    RAISE EXCEPTION 'Hanya Pelanggan pemilik pekerjaan yang dapat memberikan ulasan';
  END IF;

  IF v_job.status <> 'COMPLETED' THEN
    RAISE EXCEPTION 'Ulasan hanya dapat diberikan setelah pekerjaan berstatus COMPLETED';
  END IF;

  IF p_rating < 1 OR p_rating > 5 THEN
    RAISE EXCEPTION 'Rating harus bernilai antara 1 sampai 5 bintang';
  END IF;

  IF EXISTS (SELECT 1 FROM reviews WHERE job_id = p_job_id) THEN
    RAISE EXCEPTION 'Anda sudah memberikan ulasan untuk pekerjaan ini sebelumnya';
  END IF;

  INSERT INTO reviews (
    job_id,
    user_id,
    tukang_id,
    rating,
    comment
  ) VALUES (
    p_job_id,
    v_user_id,
    v_job.locked_tukang_id,
    p_rating,
    trim(p_comment)
  )
  RETURNING id INTO v_review_id;

  INSERT INTO notifications (
    user_id,
    title,
    body,
    deep_link
  ) VALUES (
    v_job.locked_tukang_id,
    'Ulasan Baru (' || p_rating || ' Bintang)',
    'Pelanggan telah memberikan ulasan untuk pekerjaan yang Anda selesaikan.',
    'beres://profile'
  );

  RETURN jsonb_build_object(
    'success', true,
    'review_id', v_review_id,
    'rating', p_rating
  );
END;
$$;


-- 10. RPC: GET LIVE TRACKING LOCATIONS FOR ADMIN (FR-030)
CREATE OR REPLACE FUNCTION rpc_get_live_tracking_locations()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_admin_id UUID;
  v_admin_role user_role;
  v_results JSONB;
BEGIN
  v_admin_id := auth.uid();
  IF v_admin_id IS NULL THEN
    RAISE EXCEPTION 'Pengguna belum terautentikasi';
  END IF;

  SELECT role INTO v_admin_role FROM profiles WHERE id = v_admin_id;
  IF v_admin_role <> 'ADMIN' THEN
    RAISE EXCEPTION 'Hanya akun Admin yang berhak mengakses Live Map Tracking';
  END IF;

  SELECT COALESCE(jsonb_agg(item), '[]'::JSONB) INTO v_results
  FROM (
    SELECT
      j.id AS job_id,
      j.status,
      j.description,
      j.area_label,
      ST_Y(j.location::GEOMETRY) AS job_lat,
      ST_X(j.location::GEOMETRY) AS job_lng,
      tp.user_id AS tukang_id,
      p_tkg.full_name AS tukang_name,
      p_tkg.phone AS tukang_phone,
      ST_Y(tp.last_known_location::GEOMETRY) AS tukang_lat,
      ST_X(tp.last_known_location::GEOMETRY) AS tukang_lng,
      tp.location_updated_at,
      p_usr.id AS user_id,
      p_usr.full_name AS user_name,
      ST_Distance(j.location, tp.last_known_location) AS distance_meters
    FROM jobs j
    JOIN tukang_profiles tp ON j.locked_tukang_id = tp.user_id
    JOIN profiles p_tkg ON tp.user_id = p_tkg.id
    JOIN profiles p_usr ON j.user_id = p_usr.id
    WHERE j.status IN ('ON_THE_WAY', 'ARRIVED', 'WORKING')
      AND tp.last_known_location IS NOT NULL
    ORDER BY j.updated_at DESC
  ) item;

  RETURN v_results;
END;
$$;

-- Amankan permissions dan search_path
ALTER FUNCTION fn_update_tukang_rating() SET search_path = public;
ALTER FUNCTION rpc_record_location_ping(UUID, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION) SET search_path = public;
ALTER FUNCTION rpc_confirm_arrival_manual(UUID, DOUBLE PRECISION, DOUBLE PRECISION) SET search_path = public;
ALTER FUNCTION rpc_start_work(UUID) SET search_path = public;
ALTER FUNCTION rpc_complete_job(UUID, payment_method_type, BOOLEAN, TEXT[], TEXT, TEXT) SET search_path = public;
ALTER FUNCTION rpc_report_payment_dispute(UUID, TEXT, TEXT[], TEXT[]) SET search_path = public;
ALTER FUNCTION rpc_admin_suspend_payment_defaulter(UUID, TEXT) SET search_path = public;
ALTER FUNCTION rpc_submit_review(UUID, INTEGER, TEXT) SET search_path = public;
ALTER FUNCTION rpc_get_live_tracking_locations() SET search_path = public;

GRANT EXECUTE ON FUNCTION rpc_record_location_ping(UUID, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_confirm_arrival_manual(UUID, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_start_work(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_complete_job(UUID, payment_method_type, BOOLEAN, TEXT[], TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_report_payment_dispute(UUID, TEXT, TEXT[], TEXT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_admin_suspend_payment_defaulter(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_submit_review(UUID, INTEGER, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_get_live_tracking_locations() TO authenticated;
