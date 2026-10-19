-- ============================================================================
-- BERES MIGRATION 0005: Job Marketplace, Batas 5 Bid, & Atomic Lock (BR-15, BR-16, BR-17)
-- ============================================================================

-- 1. TRIGGER GUARDRAIL: BR-15 (Maksimal 5 Lamaran Aktif)
CREATE OR REPLACE FUNCTION fn_check_bid_limits()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_active_count INTEGER;
  v_max_bids INTEGER := 5;
BEGIN
  IF NEW.status = 'ACTIVE' THEN
    SELECT COALESCE(value_int, 5) INTO v_max_bids
    FROM app_configs WHERE key = 'max_active_bids';

    SELECT COUNT(*) INTO v_active_count
    FROM bids b
    JOIN jobs j ON b.job_id = j.id
    WHERE b.tukang_id = NEW.tukang_id
      AND b.status = 'ACTIVE'
      AND j.status = 'OPEN'
      AND b.id <> COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::UUID);

    IF v_active_count >= v_max_bids THEN
      RAISE EXCEPTION 'BR-15: Batas maksimal % lamaran aktif telah tercapai', v_max_bids;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_check_bid_limits
BEFORE INSERT OR UPDATE OF status ON bids
FOR EACH ROW
EXECUTE FUNCTION fn_check_bid_limits();

-- 2. RPC: CREATE JOB (FR-010, BR-16)
CREATE OR REPLACE FUNCTION rpc_create_job(
  p_category_id UUID,
  p_description TEXT,
  p_latitude DOUBLE PRECISION,
  p_longitude DOUBLE PRECISION,
  p_area_label TEXT,
  p_address_full TEXT,
  p_photo_urls TEXT[] DEFAULT '{}',
  p_device_lat DOUBLE PRECISION DEFAULT NULL,
  p_device_lng DOUBLE PRECISION DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_user_role user_role;
  v_is_active BOOLEAN;
  v_distance_to_device DOUBLE PRECISION;
  v_job_location GEOGRAPHY(POINT, 4326);
  v_job_id UUID;
  v_photo_url TEXT;
  v_photo_count INTEGER := 0;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Pengguna belum terautentikasi';
  END IF;

  SELECT role INTO v_user_role FROM profiles WHERE id = v_user_id;
  IF v_user_role <> 'USER' THEN
    RAISE EXCEPTION 'Hanya akun User yang berhak memposting pekerjaan';
  END IF;

  IF char_length(trim(p_description)) < 10 THEN
    RAISE EXCEPTION 'Deskripsi kerusakan minimal 10 karakter';
  END IF;

  SELECT is_active INTO v_is_active FROM categories WHERE id = p_category_id;
  IF v_is_active IS NULL OR NOT v_is_active THEN
    RAISE EXCEPTION 'Kategori pekerjaan tidak aktif atau tidak ditemukan';
  END IF;

  v_job_location := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography;

  -- Validasi pin peta maks 2 km dari GPS HP User (FR-010)
  IF p_device_lat IS NOT NULL AND p_device_lng IS NOT NULL THEN
    v_distance_to_device := ST_Distance(
      v_job_location,
      ST_SetSRID(ST_MakePoint(p_device_lng, p_device_lat), 4326)::geography
    );
    IF v_distance_to_device > 2000 THEN
      RAISE EXCEPTION 'Pin lokasi melebihi batas maksimal 2 km dari posisi GPS Anda (jarak: % meter)', round(v_distance_to_device::numeric, 0);
    END IF;
  END IF;

  -- Insert Job
  INSERT INTO jobs (
    user_id,
    category_id,
    description,
    location,
    area_label,
    address_full,
    broadcast_radius_km,
    status,
    expires_at
  ) VALUES (
    v_user_id,
    p_category_id,
    trim(p_description),
    v_job_location,
    trim(p_area_label),
    trim(p_address_full),
    50,
    'OPEN',
    NOW() + INTERVAL '24 hours'
  ) RETURNING id INTO v_job_id;

  -- Insert Job Photos (maksimal 3 foto)
  IF p_photo_urls IS NOT NULL THEN
    FOREACH v_photo_url IN ARRAY p_photo_urls LOOP
      IF v_photo_count < 3 AND trim(v_photo_url) <> '' THEN
        INSERT INTO job_photos (
          job_id,
          uploaded_by,
          type,
          storage_path
        ) VALUES (
          v_job_id,
          v_user_id,
          'DAMAGE',
          trim(v_photo_url)
        );
        v_photo_count := v_photo_count + 1;
      END IF;
    END LOOP;
  END IF;

  -- Status History
  INSERT INTO job_status_history (
    job_id,
    from_status,
    to_status,
    actor_id,
    actor_role,
    reason
  ) VALUES (
    v_job_id,
    NULL,
    'OPEN',
    v_user_id,
    'USER',
    'Posting pekerjaan baru'
  );

  RETURN jsonb_build_object(
    'job_id', v_job_id,
    'status', 'OPEN',
    'area_label', p_area_label,
    'photo_count', v_photo_count
  );
END;
$$;

-- 3. RPC: UPDATE JOB (Hanya jika status masih OPEN)
CREATE OR REPLACE FUNCTION rpc_update_job(
  p_job_id UUID,
  p_category_id UUID,
  p_description TEXT,
  p_latitude DOUBLE PRECISION,
  p_longitude DOUBLE PRECISION,
  p_area_label TEXT,
  p_address_full TEXT,
  p_photo_urls TEXT[] DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_current_status job_status;
  v_job_location GEOGRAPHY(POINT, 4326);
  v_photo_url TEXT;
  v_photo_count INTEGER := 0;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Pengguna belum terautentikasi';
  END IF;

  SELECT status INTO v_current_status
  FROM jobs
  WHERE id = p_job_id AND user_id = v_user_id;

  IF v_current_status IS NULL THEN
    RAISE EXCEPTION 'Pekerjaan tidak ditemukan atau bukan milik Anda';
  END IF;

  IF v_current_status <> 'OPEN' THEN
    RAISE EXCEPTION 'Pekerjaan hanya dapat diedit ketika masih berstatus OPEN';
  END IF;

  IF char_length(trim(p_description)) < 10 THEN
    RAISE EXCEPTION 'Deskripsi kerusakan minimal 10 karakter';
  END IF;

  v_job_location := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography;

  UPDATE jobs
  SET category_id = p_category_id,
      description = trim(p_description),
      location = v_job_location,
      area_label = trim(p_area_label),
      address_full = trim(p_address_full),
      updated_at = NOW()
  WHERE id = p_job_id;

  IF p_photo_urls IS NOT NULL THEN
    DELETE FROM job_photos WHERE job_id = p_job_id AND type = 'DAMAGE';
    FOREACH v_photo_url IN ARRAY p_photo_urls LOOP
      IF v_photo_count < 3 AND trim(v_photo_url) <> '' THEN
        INSERT INTO job_photos (job_id, uploaded_by, type, storage_path)
        VALUES (p_job_id, v_user_id, 'DAMAGE', trim(v_photo_url));
        v_photo_count := v_photo_count + 1;
      END IF;
    END LOOP;
  END IF;

  RETURN jsonb_build_object(
    'job_id', p_job_id,
    'status', 'OPEN',
    'updated', true
  );
END;
$$;

-- 4. RPC: UPDATE TUKANG STATUS & LOCATION (FR-020, FR-027)
CREATE OR REPLACE FUNCTION rpc_update_tukang_status_and_location(
  p_is_online BOOLEAN DEFAULT NULL,
  p_radius_km INTEGER DEFAULT NULL,
  p_latitude DOUBLE PRECISION DEFAULT NULL,
  p_longitude DOUBLE PRECISION DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tukang_id UUID;
  v_new_location GEOGRAPHY(POINT, 4326) := NULL;
BEGIN
  v_tukang_id := auth.uid();
  IF v_tukang_id IS NULL THEN
    RAISE EXCEPTION 'Pengguna belum terautentikasi';
  END IF;

  IF p_radius_km IS NOT NULL AND (p_radius_km < 0 OR p_radius_km > 50) THEN
    RAISE EXCEPTION 'Radius kerja harus berada antara 0 sampai 50 km';
  END IF;

  IF p_latitude IS NOT NULL AND p_longitude IS NOT NULL THEN
    v_new_location := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::geography;
  END IF;

  UPDATE tukang_profiles
  SET is_online = COALESCE(p_is_online, is_online),
      radius_km = COALESCE(p_radius_km, radius_km),
      last_known_location = COALESCE(v_new_location, last_known_location),
      location_updated_at = CASE WHEN v_new_location IS NOT NULL THEN NOW() ELSE location_updated_at END,
      updated_at = NOW()
  WHERE user_id = v_tukang_id;

  RETURN jsonb_build_object(
    'tukang_id', v_tukang_id,
    'is_online', COALESCE(p_is_online, (SELECT is_online FROM tukang_profiles WHERE user_id = v_tukang_id)),
    'radius_km', COALESCE(p_radius_km, (SELECT radius_km FROM tukang_profiles WHERE user_id = v_tukang_id)),
    'location_updated', v_new_location IS NOT NULL
  );
END;
$$;

-- 5. RPC: GET OPEN JOBS FOR TUKANG (FR-022, BR-16 Privasi Sebelum Lock)
CREATE OR REPLACE FUNCTION rpc_get_open_jobs_for_tukang(
  p_limit INTEGER DEFAULT 20,
  p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
  job_id UUID,
  category_id UUID,
  category_name TEXT,
  category_icon TEXT,
  description TEXT,
  area_label TEXT,
  distance_km NUMERIC(5, 2),
  created_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  damage_photos TEXT[],
  has_bid BOOLEAN,
  bid_status TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tukang_id UUID;
  v_tukang_loc GEOGRAPHY(POINT, 4326);
  v_radius_m DOUBLE PRECISION;
  v_is_online BOOLEAN;
  v_kyc_status kyc_status;
BEGIN
  v_tukang_id := auth.uid();
  IF v_tukang_id IS NULL THEN
    RAISE EXCEPTION 'Pengguna belum terautentikasi';
  END IF;

  SELECT last_known_location, (radius_km * 1000)::DOUBLE PRECISION, is_online, kyc_status
  INTO v_tukang_loc, v_radius_m, v_is_online, v_kyc_status
  FROM tukang_profiles
  WHERE user_id = v_tukang_id;

  RETURN QUERY
  SELECT
    j.id AS job_id,
    c.id AS category_id,
    c.name AS category_name,
    c.icon_name AS category_icon,
    j.description,
    j.area_label, -- BR-16: Hanya kelurahan/kecamatan, BUKAN alamat lengkap atau nama user!
    round((ST_Distance(j.location, COALESCE(v_tukang_loc, j.location)) / 1000.0)::numeric, 2) AS distance_km,
    j.created_at,
    j.expires_at,
    COALESCE(
      (SELECT array_agg(jp.storage_path) FROM job_photos jp WHERE jp.job_id = j.id AND jp.type = 'DAMAGE'),
      ARRAY[]::TEXT[]
    ) AS damage_photos,
    (b.id IS NOT NULL) AS has_bid,
    b.status::TEXT AS bid_status
  FROM jobs j
  JOIN categories c ON j.category_id = c.id
  JOIN tukang_categories tc ON tc.category_id = j.category_id AND tc.tukang_id = v_tukang_id
  LEFT JOIN bids b ON b.job_id = j.id AND b.tukang_id = v_tukang_id
  WHERE j.status = 'OPEN'
    AND j.expires_at > NOW()
    AND (
      v_tukang_loc IS NULL
      OR ST_DWithin(j.location, v_tukang_loc, LEAST(v_radius_m, 50000.0))
    )
  ORDER BY j.created_at DESC
  LIMIT p_limit OFFSET p_offset;
END;
$$;

-- 6. RPC: SUBMIT BID (BR-10 KYC, BR-15 Maks 5 Bid, BR-21 Kuota Mingguan)
CREATE OR REPLACE FUNCTION rpc_submit_bid(
  p_job_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tukang_id UUID;
  v_role user_role;
  v_suspend_type suspend_type;
  v_kyc_status kyc_status;
  v_job_status job_status;
  v_job_user_id UUID;
  v_job_location GEOGRAPHY(POINT, 4326);
  v_tukang_loc GEOGRAPHY(POINT, 4326);
  v_distance_km NUMERIC(5, 2);
  v_timezone TEXT;
  v_week_start TIMESTAMPTZ;
  v_completed_count INTEGER;
  v_active_bids_count INTEGER;
  v_max_bids INTEGER := 5;
  v_weekly_quota INTEGER := 5;
  v_bid_id UUID;
BEGIN
  v_tukang_id := auth.uid();
  IF v_tukang_id IS NULL THEN
    RAISE EXCEPTION 'Pengguna belum terautentikasi';
  END IF;

  -- 1. Validasi Profil & Role
  SELECT role, suspend_type, timezone INTO v_role, v_suspend_type, v_timezone
  FROM profiles WHERE id = v_tukang_id;

  IF v_role <> 'TUKANG' THEN
    RAISE EXCEPTION 'Hanya akun Mitra Tukang yang dapat melamar pekerjaan';
  END IF;

  IF v_suspend_type <> 'NONE' THEN
    RAISE EXCEPTION 'Akun Anda sedang dibekukan/suspend';
  END IF;

  -- 2. Validasi KYC (BR-10)
  SELECT kyc_status, last_known_location INTO v_kyc_status, v_tukang_loc
  FROM tukang_profiles WHERE user_id = v_tukang_id;

  IF v_kyc_status <> 'APPROVED' THEN
    RAISE EXCEPTION 'BR-10: Anda harus menyelesaikan verifikasi KTP (KYC) dan disetujui Admin sebelum dapat melamar pekerjaan';
  END IF;

  -- 3. Validasi Status Job
  SELECT status, user_id, location INTO v_job_status, v_job_user_id, v_job_location
  FROM jobs WHERE id = p_job_id;

  IF v_job_status IS NULL THEN
    RAISE EXCEPTION 'Pekerjaan tidak ditemukan';
  END IF;

  IF v_job_status <> 'OPEN' THEN
    RAISE EXCEPTION 'Pekerjaan sudah tidak berstatus OPEN';
  END IF;

  -- 4. Validasi Kuota Mingguan Maks 5 Pekerjaan Selesai (BR-21)
  SELECT COALESCE(value_int, 5) INTO v_weekly_quota
  FROM app_configs WHERE key = 'weekly_completed_quota';

  v_week_start := date_trunc('week', NOW() AT TIME ZONE COALESCE(v_timezone, 'Asia/Jakarta')) AT TIME ZONE COALESCE(v_timezone, 'Asia/Jakarta');

  SELECT COUNT(*) INTO v_completed_count
  FROM jobs
  WHERE locked_tukang_id = v_tukang_id
    AND status = 'COMPLETED'
    AND completed_at >= v_week_start;

  IF v_completed_count >= v_weekly_quota THEN
    RAISE EXCEPTION 'BR-21: Anda telah mencapai batas kuota maksimal % pekerjaan selesai untuk minggu ini', v_weekly_quota;
  END IF;

  -- 5. Validasi Maksimal 5 Lamaran Aktif (BR-15)
  SELECT COALESCE(value_int, 5) INTO v_max_bids
  FROM app_configs WHERE key = 'max_active_bids';

  SELECT COUNT(*) INTO v_active_bids_count
  FROM bids b
  JOIN jobs j ON b.job_id = j.id
  WHERE b.tukang_id = v_tukang_id
    AND b.status = 'ACTIVE'
    AND j.status = 'OPEN';

  IF v_active_bids_count >= v_max_bids THEN
    RAISE EXCEPTION 'BR-15: Anda sudah memiliki % lamaran aktif. Tunggu respons atau tarik lamaran sebelum melamar job lain', v_max_bids;
  END IF;

  -- 6. Hitung Jarak
  IF v_tukang_loc IS NOT NULL AND v_job_location IS NOT NULL THEN
    v_distance_km := round((ST_Distance(v_job_location, v_tukang_loc) / 1000.0)::numeric, 2);
  ELSE
    v_distance_km := NULL;
  END IF;

  -- 7. Insert or Re-activate Bid
  INSERT INTO bids (
    job_id,
    tukang_id,
    distance_km,
    status
  ) VALUES (
    p_job_id,
    v_tukang_id,
    v_distance_km,
    'ACTIVE'
  )
  ON CONFLICT (job_id, tukang_id) DO UPDATE
  SET status = 'ACTIVE',
      distance_km = EXCLUDED.distance_km,
      withdrawn_reason = NULL,
      updated_at = NOW()
  RETURNING id INTO v_bid_id;

  -- 8. Notifikasi ke User (FR-040 Dasar)
  INSERT INTO notifications (
    user_id,
    title,
    body,
    deep_link
  ) VALUES (
    v_job_user_id,
    'Tukang Baru Melamar!',
    'Seorang mitra tukang baru saja mengajukan penawaran untuk pekerjaan Anda.',
    'beres://job/' || p_job_id || '/bids'
  );

  RETURN jsonb_build_object(
    'bid_id', v_bid_id,
    'job_id', p_job_id,
    'status', 'ACTIVE',
    'distance_km', v_distance_km
  );
END;
$$;

-- 7. RPC: WITHDRAW BID (Tarik Lamaran)
CREATE OR REPLACE FUNCTION rpc_withdraw_bid(
  p_bid_id UUID,
  p_reason TEXT DEFAULT 'Ditarik oleh mitra'
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_tukang_id UUID;
  v_job_status job_status;
  v_bid_status bid_status;
  v_job_id UUID;
BEGIN
  v_tukang_id := auth.uid();
  IF v_tukang_id IS NULL THEN
    RAISE EXCEPTION 'Pengguna belum terautentikasi';
  END IF;

  SELECT b.job_id, b.status, j.status
  INTO v_job_id, v_bid_status, v_job_status
  FROM bids b
  JOIN jobs j ON b.job_id = j.id
  WHERE b.id = p_bid_id AND b.tukang_id = v_tukang_id;

  IF v_bid_status IS NULL THEN
    RAISE EXCEPTION 'Lamaran tidak ditemukan atau bukan milik Anda';
  END IF;

  IF v_bid_status = 'LOCKED' THEN
    RAISE EXCEPTION 'Lamaran yang sudah di-lock oleh pelanggan tidak dapat ditarik sepihak';
  END IF;

  IF v_bid_status = 'WITHDRAWN' THEN
    RETURN jsonb_build_object('bid_id', p_bid_id, 'status', 'WITHDRAWN', 'already_withdrawn', true);
  END IF;

  UPDATE bids
  SET status = 'WITHDRAWN',
      withdrawn_reason = trim(p_reason),
      updated_at = NOW()
  WHERE id = p_bid_id;

  RETURN jsonb_build_object(
    'bid_id', p_bid_id,
    'job_id', v_job_id,
    'status', 'WITHDRAWN'
  );
END;
$$;

-- 8. RPC: GET JOB BIDS FOR USER (FR-011, BR-16 Privasi Sebelum Lock)
CREATE OR REPLACE FUNCTION rpc_get_job_bids_for_user(
  p_job_id UUID
)
RETURNS TABLE (
  bid_id UUID,
  bid_status TEXT,
  distance_km NUMERIC(5, 2),
  created_at TIMESTAMPTZ,
  tukang_id UUID,
  tukang_name TEXT,
  tukang_avatar TEXT,
  rating_avg NUMERIC(3, 2),
  rating_count INTEGER,
  active_days INTEGER,
  completed_jobs_count BIGINT,
  skills TEXT[]
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_job_owner UUID;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Pengguna belum terautentikasi';
  END IF;

  SELECT user_id INTO v_job_owner FROM jobs WHERE id = p_job_id;
  IF v_job_owner IS NULL THEN
    RAISE EXCEPTION 'Pekerjaan tidak ditemukan';
  END IF;

  IF v_job_owner <> v_user_id AND NOT is_admin() THEN
    RAISE EXCEPTION 'Hanya pemilik pekerjaan yang dapat melihat daftar penawaran';
  END IF;

  RETURN QUERY
  SELECT
    b.id AS bid_id,
    b.status::TEXT AS bid_status,
    b.distance_km,
    b.created_at,
    tp.user_id AS tukang_id,
    p.full_name AS tukang_name,
    p.avatar_url AS tukang_avatar,
    tp.rating_avg,
    tp.rating_count,
    GREATEST(1, EXTRACT(DAY FROM (NOW() - p.created_at))::INTEGER) AS active_days,
    (SELECT COUNT(*) FROM jobs j_comp WHERE j_comp.locked_tukang_id = tp.user_id AND j_comp.status = 'COMPLETED') AS completed_jobs_count,
    COALESCE(
      (SELECT array_agg(c.name)
       FROM tukang_categories tc
       JOIN categories c ON tc.category_id = c.id
       WHERE tc.tukang_id = tp.user_id),
      ARRAY[]::TEXT[]
    ) AS skills
  FROM bids b
  JOIN tukang_profiles tp ON b.tukang_id = tp.user_id
  JOIN profiles p ON tp.user_id = p.id
  WHERE b.job_id = p_job_id
  ORDER BY
    CASE WHEN b.status = 'LOCKED' THEN 1
         WHEN b.status = 'ACTIVE' THEN 2
         ELSE 3 END,
    b.distance_km ASC NULLS LAST,
    b.created_at ASC;
END;
$$;

-- 9. RPC: ATOMIC LOCK TUKANG & AUTO-CLEAR OTHER BIDS (FR-012, BR-17)
CREATE OR REPLACE FUNCTION rpc_lock_tukang(
  p_job_id UUID,
  p_bid_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID;
  v_job jobs%ROWTYPE;
  v_bid bids%ROWTYPE;
  v_tukang_id UUID;
  v_cleared_bids_count INTEGER := 0;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Pengguna belum terautentikasi';
  END IF;

  -- 1. Kunci baris job secara atomik (FOR UPDATE)
  SELECT * INTO v_job
  FROM jobs
  WHERE id = p_job_id
  FOR UPDATE;

  IF v_job.id IS NULL THEN
    RAISE EXCEPTION 'Pekerjaan tidak ditemukan';
  END IF;

  IF v_job.user_id <> v_user_id THEN
    RAISE EXCEPTION 'Hanya pemilik pekerjaan yang dapat melakukan lock tukang';
  END IF;

  IF v_job.status <> 'OPEN' THEN
    RAISE EXCEPTION 'Pekerjaan sudah tidak berstatus OPEN (Status saat ini: %)', v_job.status;
  END IF;

  -- 2. Kunci baris bid (FOR UPDATE)
  SELECT * INTO v_bid
  FROM bids
  WHERE id = p_bid_id AND job_id = p_job_id
  FOR UPDATE;

  IF v_bid.id IS NULL THEN
    RAISE EXCEPTION 'Lamaran tidak ditemukan pada pekerjaan ini';
  END IF;

  IF v_bid.status <> 'ACTIVE' THEN
    RAISE EXCEPTION 'Lamaran ini sudah tidak berstatus ACTIVE (Status saat ini: %)', v_bid.status;
  END IF;

  v_tukang_id := v_bid.tukang_id;

  -- 3. Update status job menjadi NEGOTIATING
  UPDATE jobs
  SET status = 'NEGOTIATING',
      locked_tukang_id = v_tukang_id,
      locked_at = NOW(),
      updated_at = NOW()
  WHERE id = p_job_id;

  -- 4. Update status bid terpilih menjadi LOCKED
  UPDATE bids
  SET status = 'LOCKED',
      updated_at = NOW()
  WHERE id = p_bid_id;

  -- 5. Tolak bid lain pada job yang sama
  UPDATE bids
  SET status = 'REJECTED',
      withdrawn_reason = 'User memilih mitra lain pada pekerjaan ini',
      updated_at = NOW()
  WHERE job_id = p_job_id
    AND id <> p_bid_id
    AND status = 'ACTIVE';

  -- 6. ATURAN BISNIS MUTLAK BR-17: AUTO-CLEAR SELURUH LAMARAN LAIN TUKANG TERPILIH
  -- Seluruh lamaran aktif tukang di pekerjaan lain (Job A, B, D, E) OTOMATIS ditarik (WITHDRAWN)
  WITH cleared AS (
    UPDATE bids
    SET status = 'WITHDRAWN',
        withdrawn_reason = 'AUTO_LOCKED_ON_OTHER_JOB',
        updated_at = NOW()
    WHERE tukang_id = v_tukang_id
      AND id <> p_bid_id
      AND status = 'ACTIVE'
    RETURNING id
  )
  SELECT COUNT(*) INTO v_cleared_bids_count FROM cleared;

  -- 7. Catat ke Status History
  INSERT INTO job_status_history (
    job_id,
    from_status,
    to_status,
    actor_id,
    actor_role,
    reason
  ) VALUES (
    p_job_id,
    'OPEN',
    'NEGOTIATING',
    v_user_id,
    'USER',
    'User memilih dan mengunci mitra tukang (BR-17)'
  );

  -- 8. Kirim Notifikasi ke Tukang Terpilih (FR-040 Dasar)
  INSERT INTO notifications (
    user_id,
    title,
    body,
    deep_link
  ) VALUES (
    v_tukang_id,
    'Selamat! Anda Dipilih Pelanggan',
    'Pelanggan telah memilih Anda untuk pekerjaan ini. Silakan buka chat dan buat Nota Kesepakatan.',
    'beres://job/' || p_job_id || '/chat'
  );

  -- 9. Kirim Pesan Sistem Awal ke Chat Room (FR-013 Dasar)
  INSERT INTO chat_messages (
    job_id,
    sender_id,
    message_type,
    content
  ) VALUES (
    p_job_id,
    v_user_id,
    'SYSTEM_EVENT',
    'Pelanggan telah memilih Mitra Tukang. Silakan berdiskusi dan Tukang dapat membuat Nota Digital untuk disetujui.'
  );

  RETURN jsonb_build_object(
    'success', true,
    'job_id', p_job_id,
    'locked_tukang_id', v_tukang_id,
    'bid_id', p_bid_id,
    'status', 'NEGOTIATING',
    'other_bids_cleared_count', v_cleared_bids_count
  );
END;
$$;

-- Berikan permission eksekusi ke authenticated users dan amankan search_path
ALTER FUNCTION fn_check_bid_limits() SET search_path = public;
REVOKE EXECUTE ON FUNCTION fn_check_bid_limits() FROM anon, authenticated, public;

ALTER FUNCTION rpc_create_job(UUID, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT, TEXT[], DOUBLE PRECISION, DOUBLE PRECISION) SET search_path = public;
REVOKE EXECUTE ON FUNCTION rpc_create_job(UUID, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT, TEXT[], DOUBLE PRECISION, DOUBLE PRECISION) FROM anon;
GRANT EXECUTE ON FUNCTION rpc_create_job(UUID, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT, TEXT[], DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;

ALTER FUNCTION rpc_update_job(UUID, UUID, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT, TEXT[]) SET search_path = public;
REVOKE EXECUTE ON FUNCTION rpc_update_job(UUID, UUID, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT, TEXT[]) FROM anon;
GRANT EXECUTE ON FUNCTION rpc_update_job(UUID, UUID, TEXT, DOUBLE PRECISION, DOUBLE PRECISION, TEXT, TEXT, TEXT[]) TO authenticated;

ALTER FUNCTION rpc_update_tukang_status_and_location(BOOLEAN, INTEGER, DOUBLE PRECISION, DOUBLE PRECISION) SET search_path = public;
REVOKE EXECUTE ON FUNCTION rpc_update_tukang_status_and_location(BOOLEAN, INTEGER, DOUBLE PRECISION, DOUBLE PRECISION) FROM anon;
GRANT EXECUTE ON FUNCTION rpc_update_tukang_status_and_location(BOOLEAN, INTEGER, DOUBLE PRECISION, DOUBLE PRECISION) TO authenticated;

ALTER FUNCTION rpc_get_open_jobs_for_tukang(INTEGER, INTEGER) SET search_path = public;
REVOKE EXECUTE ON FUNCTION rpc_get_open_jobs_for_tukang(INTEGER, INTEGER) FROM anon;
GRANT EXECUTE ON FUNCTION rpc_get_open_jobs_for_tukang(INTEGER, INTEGER) TO authenticated;

ALTER FUNCTION rpc_submit_bid(UUID) SET search_path = public;
REVOKE EXECUTE ON FUNCTION rpc_submit_bid(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION rpc_submit_bid(UUID) TO authenticated;

ALTER FUNCTION rpc_withdraw_bid(UUID, TEXT) SET search_path = public;
REVOKE EXECUTE ON FUNCTION rpc_withdraw_bid(UUID, TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION rpc_withdraw_bid(UUID, TEXT) TO authenticated;

ALTER FUNCTION rpc_get_job_bids_for_user(UUID) SET search_path = public;
REVOKE EXECUTE ON FUNCTION rpc_get_job_bids_for_user(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION rpc_get_job_bids_for_user(UUID) TO authenticated;

ALTER FUNCTION rpc_lock_tukang(UUID, UUID) SET search_path = public;
REVOKE EXECUTE ON FUNCTION rpc_lock_tukang(UUID, UUID) FROM anon;
GRANT EXECUTE ON FUNCTION rpc_lock_tukang(UUID, UUID) TO authenticated;
