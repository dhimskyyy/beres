-- ============================================================================
-- BERES MIGRATION 0006: Chat Real-Time, Nota Sah Immutable, Revisi Nota, & Timers
-- Selaras dengan docs/PRD.md v1.4.0 (FR-013, FR-014, FR-015, FR-023; BR-05, BR-08, BR-31, BR-57, BR-70, BR-71)
-- ============================================================================

-- 1. REALTIME PUBLICATION SETUP
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'chat_messages'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND tablename = 'notas'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE notas;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    NULL;
END;
$$;

-- 2. RLS POLICIES FOR CHAT & NOTAS PARTICIPANTS
-- Memastikan kedua belah pihak (User & Tukang yang di-lock) dapat membaca pesan & nota
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'chat_messages' AND policyname = 'Allow job participants read chat_messages'
  ) THEN
    CREATE POLICY "Allow job participants read chat_messages" ON chat_messages
      FOR SELECT USING (
        job_id IN (
          SELECT id FROM jobs WHERE user_id = auth.uid() OR locked_tukang_id = auth.uid()
        )
        OR (SELECT role FROM profiles WHERE id = auth.uid()) = 'ADMIN'
        OR auth.role() = 'service_role'
      );
  END IF;
END;
$$;

-- 3. TRIGGER GUARDRAIL: NOTA IMMUTABILITY (BR-05, BR-08)
-- Nota Sah yang telah disetujui (APPROVED) terkunci permanen, tidak dapat diubah nominal & itemnya
CREATE OR REPLACE FUNCTION fn_enforce_nota_immutability()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Jika Nota sudah APPROVED, dilarang mengubah total_amount, items, job_id, tukang_id, atau version
  IF OLD.status = 'APPROVED' THEN
    IF NEW.total_amount <> OLD.total_amount OR NEW.items <> OLD.items OR NEW.version <> OLD.version THEN
      RAISE EXCEPTION 'BR-05: Nota Sah bersifat terkunci (immutable) dan tidak dapat diubah harganya atau rincian itemnya sepihak.';
    END IF;

    -- Nota APPROVED hanya dapat bertransisi status menjadi SUPERSEDED (jika ada revisi baru yang di-approve) atau VOID (jika job dibatalkan)
    IF NEW.status NOT IN ('APPROVED', 'SUPERSEDED', 'VOID') THEN
      RAISE EXCEPTION 'BR-05: Status Nota Sah yang telah disetujui tidak dapat dikembalikan menjadi %', NEW.status;
    END IF;
  END IF;

  -- Jika Nota sudah berstatus terminal (REJECTED, SUPERSEDED, VOID), tidak dapat diutak-atik lagi
  IF OLD.status IN ('REJECTED', 'SUPERSEDED', 'VOID') AND NEW.status <> OLD.status THEN
    RAISE EXCEPTION 'Nota yang telah ditolak/digantikan/dibatalkan tidak dapat diubah kembali.';
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_enforce_nota_immutability
BEFORE UPDATE ON notas
FOR EACH ROW
EXECUTE FUNCTION fn_enforce_nota_immutability();


-- 4. TRIGGER GUARDRAIL: STRIKE ACCUMULATION & AUTO-SUSPEND 48 JAM (BR-57, BR-71, BR-75)
-- Menghitung strike aktif dalam 1 bulan kalender lokal; jika > 3x (strike ke-4), otomatis suspend 2 hari
CREATE OR REPLACE FUNCTION fn_record_strike_and_check_auto_suspend()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tz TEXT := 'Asia/Jakarta';
  v_now_in_tz TIMESTAMPTZ;
  v_month_start TIMESTAMPTZ;
  v_month_end TIMESTAMPTZ;
  v_strike_count INTEGER := 0;
  v_max_strikes INTEGER := 3;
BEGIN
  -- 1. Ambil zona waktu lokal pengguna
  SELECT COALESCE(timezone, 'Asia/Jakarta') INTO v_tz
  FROM profiles WHERE id = NEW.user_id;

  SELECT COALESCE(value_int, 3) INTO v_max_strikes
  FROM app_configs WHERE key = 'max_monthly_strikes';

  -- 2. Hitung awal & akhir bulan kalender sesuai zona waktu lokal
  v_now_in_tz := NOW() AT TIME ZONE v_tz;
  v_month_start := (date_trunc('month', v_now_in_tz)) AT TIME ZONE v_tz;
  v_month_end := (date_trunc('month', v_now_in_tz) + INTERVAL '1 month') AT TIME ZONE v_tz;

  -- 3. Hitung jumlah strike aktif (tidak dimaafkan / is_excused = false) pada bulan berjalan
  SELECT COUNT(*) INTO v_strike_count
  FROM strikes
  WHERE user_id = NEW.user_id
    AND is_excused = FALSE
    AND created_at >= v_month_start
    AND created_at < v_month_end;

  -- 4. Jika strike mencapai lebih dari toleransi (> 3x), terapkan suspend otomatis 48 jam (BR-57, BR-71)
  IF v_strike_count > v_max_strikes THEN
    UPDATE profiles
    SET suspend_type = 'AUTO_2_DAYS',
        suspended_until = NOW() + INTERVAL '48 hours',
        suspend_reason = 'Akun dibekukan sementara selama 2 hari karena telah melewati batas maksimal 3 kali pelanggaran (Strike) dalam bulan ini (BR-57/BR-71).',
        updated_at = NOW()
    WHERE id = NEW.user_id;

    -- Kirim notifikasi darurat suspend
    INSERT INTO notifications (
      user_id,
      title,
      body,
      deep_link
    ) VALUES (
      NEW.user_id,
      'Akun Dibekukan Sementara (48 Jam)',
      'Anda telah menerima ' || v_strike_count || ' Strike bulan ini (melebihi batas toleransi 3x). Akun dibekukan selama 2 hari penuh.',
      'beres://profile'
    );
  ELSE
    -- Kirim peringatan strike biasa
    INSERT INTO notifications (
      user_id,
      title,
      body,
      deep_link
    ) VALUES (
      NEW.user_id,
      'Peringatan Strike (' || v_strike_count || '/' || v_max_strikes || ')',
      'Anda menerima 1 Strike: ' || NEW.description || '. Batas maksimal ' || v_max_strikes || 'x per bulan kalender.',
      'beres://profile'
    );
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_record_strike_and_check_auto_suspend
AFTER INSERT ON strikes
FOR EACH ROW
EXECUTE FUNCTION fn_record_strike_and_check_auto_suspend();


-- 5. RPC: SEND CHAT MESSAGE (FR-013)
CREATE OR REPLACE FUNCTION rpc_send_chat_message(
  p_job_id UUID,
  p_content TEXT DEFAULT NULL,
  p_message_type TEXT DEFAULT 'TEXT',
  p_image_url TEXT DEFAULT NULL,
  p_nota_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_sender_id UUID;
  v_sender_role user_role;
  v_job jobs%ROWTYPE;
  v_recipient_id UUID;
  v_recipient_title TEXT;
  v_new_message_id UUID;
  v_created_at TIMESTAMPTZ;
BEGIN
  v_sender_id := auth.uid();
  IF v_sender_id IS NULL THEN
    RAISE EXCEPTION 'Pengguna belum terautentikasi';
  END IF;

  SELECT * INTO v_job FROM jobs WHERE id = p_job_id;
  IF v_job.id IS NULL THEN
    RAISE EXCEPTION 'Pekerjaan tidak ditemukan';
  END IF;

  -- Pastikan pengirim adalah User pemilik job, Tukang terkunci, atau Admin
  SELECT role INTO v_sender_role FROM profiles WHERE id = v_sender_id;

  IF v_sender_id = v_job.user_id THEN
    v_recipient_id := v_job.locked_tukang_id;
    v_recipient_title := 'Pesan Baru dari Pelanggan';
  ELSIF v_sender_id = v_job.locked_tukang_id THEN
    v_recipient_id := v_job.user_id;
    v_recipient_title := 'Pesan Baru dari Mitra Tukang';
  ELSIF v_sender_role = 'ADMIN' THEN
    v_recipient_id := v_job.user_id;
    v_recipient_title := 'Pesan dari Dukungan Operasional Beres';
  ELSE
    RAISE EXCEPTION 'Anda bukan partisipan yang berhak mengirim pesan di ruang chat pekerjaan ini';
  END IF;

  -- Validasi jenis pesan
  IF p_message_type NOT IN ('TEXT', 'IMAGE', 'NOTA_CARD', 'NOTA_REVISION_ALERT', 'SYSTEM_EVENT') THEN
    RAISE EXCEPTION 'Tipe pesan tidak valid: %', p_message_type;
  END IF;

  IF p_message_type = 'TEXT' AND (p_content IS NULL OR trim(p_content) = '') THEN
    RAISE EXCEPTION 'Isi pesan teks tidak boleh kosong';
  END IF;

  -- Insert pesan
  INSERT INTO chat_messages (
    job_id,
    sender_id,
    message_type,
    content,
    image_url,
    nota_id
  ) VALUES (
    p_job_id,
    v_sender_id,
    p_message_type,
    trim(p_content),
    p_image_url,
    p_nota_id
  )
  RETURNING id, created_at INTO v_new_message_id, v_created_at;

  -- Perbarui status waktu chat terakhir di tabel jobs
  UPDATE jobs
  SET last_chat_at = NOW(),
      last_chat_sender_role = v_sender_role,
      updated_at = NOW()
  WHERE id = p_job_id;

  -- Kirim notifikasi jika ada penerima
  IF v_recipient_id IS NOT NULL AND p_message_type <> 'SYSTEM_EVENT' THEN
    INSERT INTO notifications (
      user_id,
      title,
      body,
      deep_link
    ) VALUES (
      v_recipient_id,
      v_recipient_title,
      LEFT(COALESCE(p_content, 'Foto baru dikirim'), 80),
      'beres://job/' || p_job_id || '/chat'
    );
  END IF;

  RETURN jsonb_build_object(
    'id', v_new_message_id,
    'job_id', p_job_id,
    'sender_id', v_sender_id,
    'message_type', p_message_type,
    'content', p_content,
    'image_url', p_image_url,
    'nota_id', p_nota_id,
    'created_at', v_created_at
  );
END;
$$;


-- 6. RPC: CREATE NOTA (FR-014, FR-015, FR-023, BR-04, BR-05)
-- Hanya dapat dibuat oleh Tukang; versi 1 saat NEGOTIATING, versi 2+ (Revisi) saat ARRIVED atau WORKING
CREATE OR REPLACE FUNCTION rpc_create_nota(
  p_job_id UUID,
  p_items JSONB,
  p_total_amount BIGINT,
  p_payment_method payment_method_type,
  p_payment_destination JSONB DEFAULT NULL,
  p_note TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tukang_id UUID;
  v_job jobs%ROWTYPE;
  v_version INTEGER := 1;
  v_revision_of UUID := NULL;
  v_previous_approved_total BIGINT := NULL;
  v_approved_nota_id UUID := NULL;
  v_destination JSONB := p_payment_destination;
  v_new_nota_id UUID;
  v_chat_content TEXT;
  v_chat_type TEXT;
BEGIN
  v_tukang_id := auth.uid();
  IF v_tukang_id IS NULL THEN
    RAISE EXCEPTION 'Pengguna belum terautentikasi';
  END IF;

  -- 1. Kunci dan validasi job
  SELECT * INTO v_job FROM jobs WHERE id = p_job_id FOR UPDATE;
  IF v_job.id IS NULL THEN
    RAISE EXCEPTION 'Pekerjaan tidak ditemukan';
  END IF;

  IF v_job.locked_tukang_id <> v_tukang_id THEN
    RAISE EXCEPTION 'BR-04: Nota hanya dapat dibuat oleh Mitra Tukang yang sedang terkunci di pekerjaan ini';
  END IF;

  -- 2. Validasi input
  IF p_total_amount IS NULL OR p_total_amount <= 0 THEN
    RAISE EXCEPTION 'Total nominal nota harus lebih dari Rp 0';
  END IF;

  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Rincian item pekerjaan/material pada nota tidak boleh kosong';
  END IF;

  -- 3. Cek apakah ada nota yang masih berstatus SENT (menunggu respons user)
  IF EXISTS (SELECT 1 FROM notas WHERE job_id = p_job_id AND status = 'SENT') THEN
    RAISE EXCEPTION 'Masih ada Nota atau Revisi Nota yang sedang menunggu persetujuan Pelanggan';
  END IF;

  -- 4. Tentukan versi & jenis nota berdasarkan status pekerjaan
  IF v_job.status = 'NEGOTIATING' THEN
    -- Nota Awal (Versi 1)
    v_version := 1;
    v_revision_of := NULL;
    v_previous_approved_total := NULL;
  ELSIF v_job.status IN ('ARRIVED', 'WORKING') THEN
    -- Revisi Nota (Versi 2+) — BR-05
    SELECT id, total_amount INTO v_approved_nota_id, v_previous_approved_total
    FROM notas
    WHERE job_id = p_job_id AND status = 'APPROVED'
    ORDER BY version DESC
    LIMIT 1;

    IF v_approved_nota_id IS NULL THEN
      RAISE EXCEPTION 'Belum ada Nota Sah awal yang dapat direvisi';
    END IF;

    SELECT COALESCE(MAX(version), 1) + 1 INTO v_version
    FROM notas WHERE job_id = p_job_id;

    v_revision_of := v_approved_nota_id;
  ELSE
    RAISE EXCEPTION 'Pembuatan Nota hanya diizinkan pada status NEGOTIATING (Nota Awal) atau ARRIVED & WORKING (Revisi Nota)';
  END IF;

  -- 5. Snapshot rekening tujuan pembayaran tukang bila tidak disediakan
  IF v_destination IS NULL THEN
    SELECT payment_accounts INTO v_destination
    FROM tukang_profiles WHERE user_id = v_tukang_id;
  END IF;

  -- 6. Insert ke tabel notas
  INSERT INTO notas (
    job_id,
    tukang_id,
    version,
    revision_of,
    previous_approved_total,
    items,
    total_amount,
    payment_method,
    payment_destination,
    note,
    status
  ) VALUES (
    p_job_id,
    v_tukang_id,
    v_version,
    v_revision_of,
    v_previous_approved_total,
    p_items,
    p_total_amount,
    p_payment_method,
    COALESCE(v_destination, '[]'::JSONB),
    trim(p_note),
    'SENT'
  )
  RETURNING id INTO v_new_nota_id;

  -- 7. Sisipkan pesan ke Chat Room
  IF v_version = 1 THEN
    v_chat_type := 'NOTA_CARD';
    v_chat_content := 'Nota Digital telah diajukan oleh Tukang (Total: Rp ' || p_total_amount || '). Silakan periksa rincian dan tekan Setujui.';
  ELSE
    v_chat_type := 'NOTA_REVISION_ALERT';
    v_chat_content := 'PERINGATAN REVISI NOTA: Tukang mengajukan revisi biaya baru sebesar Rp ' || p_total_amount || ' (Sebelumnya: Rp ' || v_previous_approved_total || '). Wajib disetujui Pelanggan.';
  END IF;

  INSERT INTO chat_messages (
    job_id,
    sender_id,
    message_type,
    content,
    nota_id
  ) VALUES (
    p_job_id,
    v_tukang_id,
    v_chat_type,
    v_chat_content,
    v_new_nota_id
  );

  -- Update last chat di job
  UPDATE jobs
  SET last_chat_at = NOW(),
      last_chat_sender_role = 'TUKANG',
      updated_at = NOW()
  WHERE id = p_job_id;

  -- 8. Kirim notifikasi ke User (FR-040)
  INSERT INTO notifications (
    user_id,
    title,
    body,
    deep_link
  ) VALUES (
    v_job.user_id,
    CASE WHEN v_version = 1 THEN 'Nota Digital Masuk' ELSE 'Pengajuan Revisi Nota' END,
    CASE WHEN v_version = 1
      THEN 'Tukang mengajukan Nota sebesar Rp ' || p_total_amount || '. Buka chat untuk meninjau.'
      ELSE 'Revisi Nota baru: Rp ' || p_total_amount || ' (Sebelumnya Rp ' || v_previous_approved_total || '). Periksa dan konfirmasi di chat.'
    END,
    'beres://job/' || p_job_id || '/chat'
  );

  RETURN jsonb_build_object(
    'nota_id', v_new_nota_id,
    'job_id', p_job_id,
    'version', v_version,
    'revision_of', v_revision_of,
    'previous_approved_total', v_previous_approved_total,
    'total_amount', p_total_amount,
    'status', 'SENT'
  );
END;
$$;


-- 7. RPC: RESPOND NOTA (APPROVE / REJECT) (FR-014, FR-015, BR-05, BR-31)
CREATE OR REPLACE FUNCTION rpc_respond_nota(
  p_nota_id UUID,
  p_action TEXT -- 'APPROVE' atau 'REJECT'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_nota notas%ROWTYPE;
  v_job jobs%ROWTYPE;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Pengguna belum terautentikasi';
  END IF;

  IF p_action NOT IN ('APPROVE', 'REJECT') THEN
    RAISE EXCEPTION 'Aksi tidak valid: harus APPROVE atau REJECT';
  END IF;

  -- 1. Kunci dan validasi nota
  SELECT * INTO v_nota FROM notas WHERE id = p_nota_id FOR UPDATE;
  IF v_nota.id IS NULL THEN
    RAISE EXCEPTION 'Nota tidak ditemukan';
  END IF;

  IF v_nota.status <> 'SENT' THEN
    RAISE EXCEPTION 'Nota ini sudah direspon sebelumnya (Status saat ini: %)', v_nota.status;
  END IF;

  -- 2. Kunci dan validasi job
  SELECT * INTO v_job FROM jobs WHERE id = v_nota.job_id FOR UPDATE;
  IF v_job.id IS NULL THEN
    RAISE EXCEPTION 'Pekerjaan tidak ditemukan';
  END IF;

  IF v_job.user_id <> v_user_id THEN
    RAISE EXCEPTION 'Hanya Pelanggan pemilik pekerjaan yang dapat menanggapi Nota';
  END IF;

  -- 3. Logika APPROVE
  IF p_action = 'APPROVE' THEN
    IF v_nota.version = 1 THEN
      -- Nota Awal Disetujui (Menjadi Nota Sah Terkunci)
      UPDATE notas
      SET status = 'APPROVED',
          responded_at = NOW()
      WHERE id = p_nota_id;

      -- Update status job menjadi NOTA_APPROVED & aktifkan timer 30 menit berangkat (BR-31)
      UPDATE jobs
      SET status = 'NOTA_APPROVED',
          nota_approved_at = NOW(),
          agreed_total = v_nota.total_amount,
          updated_at = NOW()
      WHERE id = v_nota.job_id;

      -- Catat transisi ke status history
      INSERT INTO job_status_history (
        job_id,
        from_status,
        to_status,
        actor_id,
        actor_role,
        reason
      ) VALUES (
        v_nota.job_id,
        'NEGOTIATING',
        'NOTA_APPROVED',
        v_user_id,
        'USER',
        'Pelanggan menyetujui Nota Digital awal (Nota Sah terbentuk)'
      );

      -- Pesan Chat & Notifikasi
      INSERT INTO chat_messages (
        job_id,
        sender_id,
        message_type,
        content,
        nota_id
      ) VALUES (
        v_nota.job_id,
        v_user_id,
        'SYSTEM_EVENT',
        'Nota Sah telah disetujui Pelanggan (Rp ' || v_nota.total_amount || '). Mitra Tukang wajib menekan "Berangkat ke Lokasi" dalam waktu maksimal 30 menit.',
        p_nota_id
      );

      INSERT INTO notifications (
        user_id,
        title,
        body,
        deep_link
      ) VALUES (
        v_job.locked_tukang_id,
        'Nota Sah Disetujui!',
        'Pelanggan telah menyetujui Nota Sah. Anda memiliki waktu 30 menit untuk menekan tombol Berangkat.',
        'beres://job/' || v_nota.job_id || '/chat'
      );

    ELSE
      -- Revisi Nota Disetujui (BR-05)
      -- Nota sah sebelumnya berubah menjadi SUPERSEDED
      UPDATE notas
      SET status = 'SUPERSEDED'
      WHERE job_id = v_nota.job_id
        AND status = 'APPROVED'
        AND id <> p_nota_id;

      -- Revisi ini menjadi Nota Sah APPROVED terbaru
      UPDATE notas
      SET status = 'APPROVED',
          responded_at = NOW()
      WHERE id = p_nota_id;

      -- Perbarui agreed_total pada jobs
      UPDATE jobs
      SET agreed_total = v_nota.total_amount,
          updated_at = NOW()
      WHERE id = v_nota.job_id;

      INSERT INTO chat_messages (
        job_id,
        sender_id,
        message_type,
        content,
        nota_id
      ) VALUES (
        v_nota.job_id,
        v_user_id,
        'SYSTEM_EVENT',
        'Revisi Nota telah disetujui Pelanggan. Nilai Nota Sah terbaru: Rp ' || v_nota.total_amount || '.',
        p_nota_id
      );

      INSERT INTO notifications (
        user_id,
        title,
        body,
        deep_link
      ) VALUES (
        v_job.locked_tukang_id,
        'Revisi Nota Disetujui',
        'Pelanggan telah menyetujui Revisi Nota baru sebesar Rp ' || v_nota.total_amount || '.',
        'beres://job/' || v_nota.job_id || '/chat'
      );
    END IF;

  -- 4. Logika REJECT
  ELSE
    UPDATE notas
    SET status = 'REJECTED',
        responded_at = NOW()
    WHERE id = p_nota_id;

    IF v_nota.version = 1 THEN
      INSERT INTO chat_messages (
        job_id,
        sender_id,
        message_type,
        content,
        nota_id
      ) VALUES (
        v_nota.job_id,
        v_user_id,
        'SYSTEM_EVENT',
        'Nota Digital ditolak oleh Pelanggan. Silakan berdiskusi kembali di ruang chat untuk rincian pekerjaan atau biaya.',
        p_nota_id
      );

      INSERT INTO notifications (
        user_id,
        title,
        body,
        deep_link
      ) VALUES (
        v_job.locked_tukang_id,
        'Nota Ditolak Pelanggan',
        'Pelanggan menolak Nota Digital yang diajukan. Silakan diskusikan kembali di chat.',
        'beres://job/' || v_nota.job_id || '/chat'
      );
    ELSE
      INSERT INTO chat_messages (
        job_id,
        sender_id,
        message_type,
        content,
        nota_id
      ) VALUES (
        v_nota.job_id,
        v_user_id,
        'SYSTEM_EVENT',
        'Revisi Nota ditolak oleh Pelanggan. Nota Sah sebelumnya tetap menjadi acuan kerja.',
        p_nota_id
      );

      INSERT INTO notifications (
        user_id,
        title,
        body,
        deep_link
      ) VALUES (
        v_job.locked_tukang_id,
        'Revisi Nota Ditolak',
        'Pelanggan menolak revisi nota. Pekerjaan dilanjutkan dengan acuan Nota Sah sebelumnya.',
        'beres://job/' || v_nota.job_id || '/chat'
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'nota_id', p_nota_id,
    'action', p_action,
    'version', v_nota.version,
    'status', CASE WHEN p_action = 'APPROVE' THEN 'APPROVED' ELSE 'REJECTED' END
  );
END;
$$;


-- 8. RPC: CANCEL / WITHDRAW NOTA REVISION (BR-08)
-- Tukang dapat menarik kembali revisi nota yang masih SENT agar tidak memblokir penyelesaian tugas
CREATE OR REPLACE FUNCTION rpc_cancel_nota_revision(
  p_nota_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tukang_id UUID;
  v_nota notas%ROWTYPE;
  v_job jobs%ROWTYPE;
BEGIN
  v_tukang_id := auth.uid();
  IF v_tukang_id IS NULL THEN
    RAISE EXCEPTION 'Pengguna belum terautentikasi';
  END IF;

  SELECT * INTO v_nota FROM notas WHERE id = p_nota_id FOR UPDATE;
  IF v_nota.id IS NULL THEN
    RAISE EXCEPTION 'Nota tidak ditemukan';
  END IF;

  IF v_nota.tukang_id <> v_tukang_id THEN
    RAISE EXCEPTION 'Hanya Mitra Tukang yang mengajukan revisi yang dapat menariknya kembali';
  END IF;

  IF v_nota.version <= 1 THEN
    RAISE EXCEPTION 'Fitur tarik revisi hanya berlaku untuk Revisi Nota (versi 2+)';
  END IF;

  IF v_nota.status <> 'SENT' THEN
    RAISE EXCEPTION 'Revisi Nota sudah direspons atau tidak berstatus SENT (Status: %)', v_nota.status;
  END IF;

  -- Ubah status menjadi SUPERSEDED
  UPDATE notas
  SET status = 'SUPERSEDED',
      responded_at = NOW()
  WHERE id = p_nota_id;

  -- Kirim pesan sistem ke Chat
  INSERT INTO chat_messages (
    job_id,
    sender_id,
    message_type,
    content,
    nota_id
  ) VALUES (
    v_nota.job_id,
    v_tukang_id,
    'SYSTEM_EVENT',
    'Tukang telah menarik kembali pengajuan Revisi Nota (BR-08). Nota Sah sebelumnya tetap berlaku penuh.',
    p_nota_id
  );

  SELECT * INTO v_job FROM jobs WHERE id = v_nota.job_id;

  INSERT INTO notifications (
    user_id,
    title,
    body,
    deep_link
  ) VALUES (
    v_job.user_id,
    'Revisi Nota Ditarik Tukang',
    'Mitra Tukang membatalkan pengajuan revisi nota. Pekerjaan berjalan sesuai Nota Sah awal.',
    'beres://job/' || v_nota.job_id || '/chat'
  );

  RETURN jsonb_build_object(
    'success', true,
    'nota_id', p_nota_id,
    'status', 'SUPERSEDED'
  );
END;
$$;


-- 9. RPC: DEPART JOB (BR-31)
-- Tukang wajib menekan tombol Berangkat ke Lokasi dalam 30 menit sejak NOTA_APPROVED
CREATE OR REPLACE FUNCTION rpc_depart_job(
  p_job_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tukang_id UUID;
  v_job jobs%ROWTYPE;
  v_timeout_minutes INTEGER := 30;
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
    RAISE EXCEPTION 'Hanya Mitra Tukang yang ditugaskan yang dapat menekan Berangkat';
  END IF;

  IF v_job.status <> 'NOTA_APPROVED' THEN
    RAISE EXCEPTION 'Pekerjaan tidak berada dalam status NOTA_APPROVED (Status saat ini: %)', v_job.status;
  END IF;

  SELECT COALESCE(value_int, 30) INTO v_timeout_minutes
  FROM app_configs WHERE key = 'depart_after_nota_timeout_min';

  -- Validasi apakah sudah melewati batas 30 menit
  IF NOW() > (v_job.nota_approved_at + (v_timeout_minutes || ' minutes')::INTERVAL) THEN
    -- Panggil logic timeout T4a
    PERFORM rpc_check_depart_timeout(p_job_id);
    RAISE EXCEPTION 'BR-31: Batas waktu % menit untuk berangkat telah berakhir. Pekerjaan telah dilepas kembali ke portal.', v_timeout_minutes;
  END IF;

  -- Update status ke ON_THE_WAY
  UPDATE jobs
  SET status = 'ON_THE_WAY',
      on_the_way_at = NOW(),
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
    'NOTA_APPROVED',
    'ON_THE_WAY',
    v_tukang_id,
    'TUKANG',
    'Tukang menekan Berangkat ke Lokasi (BR-31)'
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
    'Mitra Tukang sedang dalam perjalanan menuju lokasi Anda. Lokasi GPS dapat dipantau secara langsung.'
  );

  INSERT INTO notifications (
    user_id,
    title,
    body,
    deep_link
  ) VALUES (
    v_job.user_id,
    'Tukang Sedang Menuju Lokasi Anda',
    'Mitra Tukang telah berangkat ke lokasi. Buka peta untuk melacak kedatangan.',
    'beres://job/' || p_job_id || '/tracking'
  );

  RETURN jsonb_build_object(
    'success', true,
    'job_id', p_job_id,
    'status', 'ON_THE_WAY',
    'on_the_way_at', NOW()
  );
END;
$$;


-- 10. RPC: CHECK DEPART TIMEOUT (BR-31, T4a)
-- Melepas job ke portal + memberi +1 Strike Tukang jika > 30 menit tidak klik berangkat
CREATE OR REPLACE FUNCTION rpc_check_depart_timeout(
  p_job_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_job jobs%ROWTYPE;
  v_tukang_id UUID;
  v_timeout_minutes INTEGER := 30;
BEGIN
  SELECT * INTO v_job FROM jobs WHERE id = p_job_id FOR UPDATE;
  IF v_job.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Pekerjaan tidak ditemukan');
  END IF;

  IF v_job.status <> 'NOTA_APPROVED' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Pekerjaan bukan status NOTA_APPROVED');
  END IF;

  SELECT COALESCE(value_int, 30) INTO v_timeout_minutes
  FROM app_configs WHERE key = 'depart_after_nota_timeout_min';

  -- Cek apakah sudah melebihi batas waktu
  IF NOW() > (v_job.nota_approved_at + (v_timeout_minutes || ' minutes')::INTERVAL) THEN
    v_tukang_id := v_job.locked_tukang_id;

    -- 1. Lepas job kembali ke OPEN di portal
    UPDATE jobs
    SET status = 'OPEN',
        locked_tukang_id = NULL,
        nota_approved_at = NULL,
        updated_at = NOW()
    WHERE id = p_job_id;

    -- 2. Void nota yang ada
    UPDATE notas
    SET status = 'VOID'
    WHERE job_id = p_job_id AND status IN ('SENT', 'APPROVED');

    -- 3. Tarik bid tukang tersebut
    UPDATE bids
    SET status = 'WITHDRAWN',
        withdrawn_reason = 'DEPART_TIMEOUT_30M',
        updated_at = NOW()
    WHERE job_id = p_job_id AND tukang_id = v_tukang_id;

    -- 4. Catat status history
    INSERT INTO job_status_history (
      job_id,
      from_status,
      to_status,
      actor_id,
      actor_role,
      reason
    ) VALUES (
      p_job_id,
      'NOTA_APPROVED',
      'OPEN',
      v_tukang_id,
      'SYSTEM',
      'Tukang tidak menekan tombol Berangkat dalam 30 menit (T4a, BR-31)'
    );

    -- 5. Beri sanksi +1 Strike Tukang (BR-31, BR-57)
    INSERT INTO strikes (
      user_id,
      role,
      job_id,
      strike_type,
      description
    ) VALUES (
      v_tukang_id,
      'TUKANG',
      p_job_id,
      'NO_DEPART_30M',
      'Tidak menekan tombol Berangkat ke Lokasi dalam 30 menit setelah Nota disetujui (BR-31).'
    );

    -- 6. Notifikasi User & Tukang
    INSERT INTO notifications (
      user_id,
      title,
      body,
      deep_link
    ) VALUES (
      v_job.user_id,
      'Pekerjaan Dilepas ke Portal',
      'Tukang tidak aktif dalam beberapa menit, silakan cari tukang yang lain di portal pekerjaan.',
      'beres://job/' || p_job_id || '/bids'
    );

    INSERT INTO notifications (
      user_id,
      title,
      body,
      deep_link
    ) VALUES (
      v_tukang_id,
      'Job Dibatalkan & Pelanggaran Strike',
      'Job tidak dapat diselesaikan karena Anda tidak menekan Berangkat dalam 30 menit. Anda menerima +1 Strike Tukang.',
      'beres://profile'
    );

    INSERT INTO chat_messages (
      job_id,
      sender_id,
      message_type,
      content
    ) VALUES (
      p_job_id,
      v_job.user_id,
      'SYSTEM_EVENT',
      'Batas waktu 30 menit berangkat telah berakhir tanpa konfirmasi dari Tukang. Pekerjaan otomatis dilepas kembali ke Job Portal.'
    );

    RETURN jsonb_build_object(
      'timed_out', true,
      'job_id', p_job_id,
      'status', 'OPEN',
      'strike_given', true
    );
  END IF;

  RETURN jsonb_build_object(
    'timed_out', false,
    'job_id', p_job_id,
    'status', v_job.status
  );
END;
$$;


-- 11. RPC: CANCEL NEGOTIATION TO PORTAL (BR-70)
-- Jika User atau Tukang tidak aktif > 30 menit di NEGOTIATING, job lepas ke OPEN tanpa Strike bagi siapa pun
CREATE OR REPLACE FUNCTION rpc_cancel_negotiation_to_portal(
  p_job_id UUID,
  p_reason TEXT DEFAULT 'Batas waktu / pembatalan negosiasi'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_id UUID;
  v_caller_role user_role;
  v_job jobs%ROWTYPE;
  v_tukang_id UUID;
BEGIN
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Pengguna belum terautentikasi';
  END IF;

  SELECT * INTO v_job FROM jobs WHERE id = p_job_id FOR UPDATE;
  IF v_job.id IS NULL THEN
    RAISE EXCEPTION 'Pekerjaan tidak ditemukan';
  END IF;

  IF v_job.status <> 'NEGOTIATING' THEN
    RAISE EXCEPTION 'Fitur ini hanya dapat digunakan saat pekerjaan berstatus NEGOTIATING (Status saat ini: %)', v_job.status;
  END IF;

  SELECT role INTO v_caller_role FROM profiles WHERE id = v_caller_id;

  IF v_caller_id <> v_job.user_id AND v_caller_id <> v_job.locked_tukang_id AND v_caller_role <> 'ADMIN' THEN
    RAISE EXCEPTION 'Hanya pemilik pekerjaan atau tukang terkunci yang dapat melepas negosiasi ke portal';
  END IF;

  v_tukang_id := v_job.locked_tukang_id;

  -- 1. Lepas job kembali ke OPEN
  UPDATE jobs
  SET status = 'OPEN',
      locked_tukang_id = NULL,
      locked_at = NULL,
      updated_at = NOW()
  WHERE id = p_job_id;

  -- 2. Void nota yang berstatus SENT
  UPDATE notas
  SET status = 'VOID'
  WHERE job_id = p_job_id AND status = 'SENT';

  -- 3. Tarik bid tukang tersebut
  IF v_tukang_id IS NOT NULL THEN
    UPDATE bids
    SET status = 'WITHDRAWN',
        withdrawn_reason = 'NEGOTIATION_RELEASED_TO_PORTAL',
        updated_at = NOW()
    WHERE job_id = p_job_id AND tukang_id = v_tukang_id;
  END IF;

  -- 4. Catat ke status history — TIDAK ADA STRIKE (BR-70)
  INSERT INTO job_status_history (
    job_id,
    from_status,
    to_status,
    actor_id,
    actor_role,
    reason
  ) VALUES (
    p_job_id,
    'NEGOTIATING',
    'OPEN',
    v_caller_id,
    v_caller_role,
    'Negosiasi dilepas kembali ke portal tanpa sanksi strike (BR-70): ' || trim(p_reason)
  );

  -- 5. Kirim pesan sistem & notifikasi
  INSERT INTO chat_messages (
    job_id,
    sender_id,
    message_type,
    content
  ) VALUES (
    p_job_id,
    v_caller_id,
    'SYSTEM_EVENT',
    'Negosiasi dihentikan. Pekerjaan telah dilepas kembali ke Job Portal (tanpa sanksi strike).'
  );

  INSERT INTO notifications (
    user_id,
    title,
    body,
    deep_link
  ) VALUES (
    v_job.user_id,
    'Pekerjaan Kembali ke Portal',
    'Pekerjaan Anda telah kembali dibuka di Job Portal agar dapat dilamar tukang lain.',
    'beres://job/' || p_job_id || '/bids'
  );

  IF v_tukang_id IS NOT NULL THEN
    INSERT INTO notifications (
      user_id,
      title,
      body,
      deep_link
    ) VALUES (
      v_tukang_id,
      'Negosiasi Selesai',
      'Negosiasi pada pekerjaan telah dilepas kembali ke portal tanpa sanksi strike. Anda dapat mencari pekerjaan lain.',
      'beres://portal'
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'job_id', p_job_id,
    'status', 'OPEN',
    'strike_given', false
  );
END;
$$;


-- 12. RPC: GET JOB CHAT CONTEXT
-- Memberikan data lengkap konteks obrolan, status nota sah aktif, revisi menggantung, dan sisa timer
CREATE OR REPLACE FUNCTION rpc_get_job_chat_context(
  p_job_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_caller_id UUID;
  v_job jobs%ROWTYPE;
  v_other_user_id UUID;
  v_other_profile RECORD;
  v_active_nota RECORD;
  v_pending_nota RECORD;
  v_depart_timeout_sec INTEGER := 0;
  v_negotiating_timeout_sec INTEGER := 0;
  v_timer_depart_min INTEGER := 30;
  v_timer_nego_min INTEGER := 30;
BEGIN
  v_caller_id := auth.uid();
  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'Pengguna belum terautentikasi';
  END IF;

  SELECT * INTO v_job FROM jobs WHERE id = p_job_id;
  IF v_job.id IS NULL THEN
    RAISE EXCEPTION 'Pekerjaan tidak ditemukan';
  END IF;

  IF v_caller_id = v_job.user_id THEN
    v_other_user_id := v_job.locked_tukang_id;
  ELSE
    v_other_user_id := v_job.user_id;
  END IF;

  -- Profil lawan bicara
  SELECT id, full_name, role, avatar_url, phone
  INTO v_other_profile
  FROM profiles WHERE id = v_other_user_id;

  -- Nota Sah aktif (APPROVED)
  SELECT id, version, total_amount, items, payment_method, payment_destination, note, responded_at
  INTO v_active_nota
  FROM notas
  WHERE job_id = p_job_id AND status = 'APPROVED'
  ORDER BY version DESC LIMIT 1;

  -- Revisi Nota menggantung (SENT)
  SELECT id, version, revision_of, previous_approved_total, total_amount, items, payment_method, note, created_at
  INTO v_pending_nota
  FROM notas
  WHERE job_id = p_job_id AND status = 'SENT'
  ORDER BY version DESC LIMIT 1;

  -- Timer Depart (30 menit sejak nota_approved_at)
  IF v_job.status = 'NOTA_APPROVED' AND v_job.nota_approved_at IS NOT NULL THEN
    SELECT COALESCE(value_int, 30) INTO v_timer_depart_min FROM app_configs WHERE key = 'depart_after_nota_timeout_min';
    v_depart_timeout_sec := GREATEST(0, EXTRACT(EPOCH FROM ((v_job.nota_approved_at + (v_timer_depart_min || ' minutes')::INTERVAL) - NOW()))::INTEGER);
  END IF;

  -- Timer Negotiating (30 menit sejak locked_at atau chat terakhir)
  IF v_job.status = 'NEGOTIATING' THEN
    SELECT COALESCE(value_int, 30) INTO v_timer_nego_min FROM app_configs WHERE key = 'chat_negotiating_timeout_min';
    v_negotiating_timeout_sec := GREATEST(0, EXTRACT(EPOCH FROM ((COALESCE(v_job.last_chat_at, v_job.locked_at, NOW()) + (v_timer_nego_min || ' minutes')::INTERVAL) - NOW()))::INTEGER);
  END IF;

  RETURN jsonb_build_object(
    'job_id', v_job.id,
    'status', v_job.status,
    'description', v_job.description,
    'area_label', v_job.area_label,
    'address_full', v_job.address_full,
    'user_id', v_job.user_id,
    'locked_tukang_id', v_job.locked_tukang_id,
    'locked_at', v_job.locked_at,
    'nota_approved_at', v_job.nota_approved_at,
    'agreed_total', v_job.agreed_total,
    'is_user', (v_caller_id = v_job.user_id),
    'is_tukang', (v_caller_id = v_job.locked_tukang_id),
    'other_user', CASE WHEN v_other_profile.id IS NOT NULL THEN
      jsonb_build_object(
        'id', v_other_profile.id,
        'full_name', v_other_profile.full_name,
        'role', v_other_profile.role,
        'avatar_url', v_other_profile.avatar_url,
        'phone', v_other_profile.phone
      ) ELSE NULL END,
    'active_nota', CASE WHEN v_active_nota.id IS NOT NULL THEN
      jsonb_build_object(
        'id', v_active_nota.id,
        'version', v_active_nota.version,
        'total_amount', v_active_nota.total_amount,
        'items', v_active_nota.items,
        'payment_method', v_active_nota.payment_method,
        'payment_destination', v_active_nota.payment_destination,
        'note', v_active_nota.note,
        'responded_at', v_active_nota.responded_at
      ) ELSE NULL END,
    'pending_nota', CASE WHEN v_pending_nota.id IS NOT NULL THEN
      jsonb_build_object(
        'id', v_pending_nota.id,
        'version', v_pending_nota.version,
        'revision_of', v_pending_nota.revision_of,
        'previous_approved_total', v_pending_nota.previous_approved_total,
        'total_amount', v_pending_nota.total_amount,
        'items', v_pending_nota.items,
        'payment_method', v_pending_nota.payment_method,
        'note', v_pending_nota.note,
        'created_at', v_pending_nota.created_at
      ) ELSE NULL END,
    'depart_timer_seconds', v_depart_timeout_sec,
    'negotiating_timer_seconds', v_negotiating_timeout_sec
  );
END;
$$;

-- Amankan permission dan search_path untuk seluruh fungsi baru
ALTER FUNCTION fn_enforce_nota_immutability() SET search_path = public;
ALTER FUNCTION fn_record_strike_and_check_auto_suspend() SET search_path = public;
ALTER FUNCTION rpc_send_chat_message(UUID, TEXT, TEXT, TEXT, UUID) SET search_path = public;
ALTER FUNCTION rpc_create_nota(UUID, JSONB, BIGINT, payment_method_type, JSONB, TEXT) SET search_path = public;
ALTER FUNCTION rpc_respond_nota(UUID, TEXT) SET search_path = public;
ALTER FUNCTION rpc_cancel_nota_revision(UUID) SET search_path = public;
ALTER FUNCTION rpc_depart_job(UUID) SET search_path = public;
ALTER FUNCTION rpc_check_depart_timeout(UUID) SET search_path = public;
ALTER FUNCTION rpc_cancel_negotiation_to_portal(UUID, TEXT) SET search_path = public;
ALTER FUNCTION rpc_get_job_chat_context(UUID) SET search_path = public;

GRANT EXECUTE ON FUNCTION rpc_send_chat_message(UUID, TEXT, TEXT, TEXT, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_create_nota(UUID, JSONB, BIGINT, payment_method_type, JSONB, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_respond_nota(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_cancel_nota_revision(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_depart_job(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_check_depart_timeout(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_cancel_negotiation_to_portal(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION rpc_get_job_chat_context(UUID) TO authenticated;
