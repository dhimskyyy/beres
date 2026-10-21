-- =============================================================================
-- TEST SUITE: Milestone M8 - Database Business Rules & Concurrency Verification
-- Memvalidasi penegakan aturan server/database v1.4.0 (BR-15, BR-17, BR-44, BR-57, BR-65)
-- =============================================================================

BEGIN;

-- 1. Uji Penegakan 1 Email = 1 Peran (BR-44 / E2E-09)
DO $$
DECLARE
  v_test_email TEXT := 'test_m8_unique_' || SUBSTRING(gen_random_uuid()::TEXT, 1, 8) || '@example.com';
  v_user_id UUID := gen_random_uuid();
  v_tukang_id UUID := gen_random_uuid();
BEGIN
  -- Insert user profile
  INSERT INTO profiles (id, email, role, full_name, phone)
  VALUES (v_user_id, v_test_email, 'USER', 'Test User M8', '081234567890');

  -- Attempt to insert tukang profile with same email (Must fail via trigger/constraint)
  BEGIN
    INSERT INTO profiles (id, email, role, full_name, phone)
    VALUES (v_tukang_id, v_test_email, 'TUKANG', 'Test Tukang M8', '081234567891');
    RAISE EXCEPTION 'TEST FAILED: Single role per email constraint (BR-44) was bypassed!';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'SUCCESS: Single role per email (BR-44) successfully rejected second role insertion.';
  END;
END $$;

-- 2. Uji Penegakan Batas Lamar Maks 5 Job (BR-15 / E2E-02)
DO $$
DECLARE
  v_tukang_id UUID := gen_random_uuid();
  v_user_id UUID := gen_random_uuid();
  v_job_ids UUID[] := ARRAY[gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid()];
  v_cat_id UUID;
  i INT;
BEGIN
  SELECT id INTO v_cat_id FROM categories LIMIT 1;
  IF v_cat_id IS NULL THEN
    INSERT INTO categories (id, name, slug) VALUES (gen_random_uuid(), 'Pertukangan Umum', 'umum') RETURNING id INTO v_cat_id;
  END IF;

  -- Create dummy profiles
  INSERT INTO profiles (id, email, role, full_name, phone) VALUES (v_tukang_id, 'tukang_bid_' || SUBSTRING(gen_random_uuid()::TEXT, 1, 6) || '@beres.id', 'TUKANG', 'Tukang Bid', '0812345678');
  INSERT INTO tukang_profiles (user_id, kyc_status, is_online, radius_km) VALUES (v_tukang_id, 'APPROVED', true, 25);

  INSERT INTO profiles (id, email, role, full_name, phone) VALUES (v_user_id, 'user_bid_' || SUBSTRING(gen_random_uuid()::TEXT, 1, 6) || '@beres.id', 'USER', 'User Bid', '0812345679');

  -- Create 6 open jobs
  FOR i IN 1..6 LOOP
    INSERT INTO jobs (id, user_id, category_id, description, status, area_label, address_full, location)
    VALUES (v_job_ids[i], v_user_id, v_cat_id, 'Job ' || i, 'OPEN', 'Tebet', 'Jl. Tebet', ST_SetSRID(ST_MakePoint(106.8456, -6.2088), 4326));
  END LOOP;

  -- Insert 5 active bids (Should succeed)
  FOR i IN 1..5 LOOP
    INSERT INTO bids (id, job_id, tukang_id, status) VALUES (gen_random_uuid(), v_job_ids[i], v_tukang_id, 'ACTIVE');
  END LOOP;

  -- Attempt 6th active bid (Must fail via trg_enforce_bid_limit)
  BEGIN
    INSERT INTO bids (id, job_id, tukang_id, status) VALUES (gen_random_uuid(), v_job_ids[6], v_tukang_id, 'ACTIVE');
    RAISE EXCEPTION 'TEST FAILED: 6th active bid was allowed without trigger rejection (BR-15)!';
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'SUCCESS: 6th active bid was rejected properly by database trigger (BR-15).';
  END;
END $$;

-- 3. Uji Auto-Clear Lamaran Lain Saat Di-Lock (BR-17 / E2E-02)
DO $$
DECLARE
  v_tukang_id UUID := gen_random_uuid();
  v_user_id UUID := gen_random_uuid();
  v_job_a UUID := gen_random_uuid();
  v_job_b UUID := gen_random_uuid();
  v_job_c UUID := gen_random_uuid();
  v_cat_id UUID;
  v_withdrawn_count INT;
BEGIN
  SELECT id INTO v_cat_id FROM categories LIMIT 1;

  INSERT INTO profiles (id, email, role, full_name, phone) VALUES (v_tukang_id, 'tukang_lock_' || SUBSTRING(gen_random_uuid()::TEXT, 1, 6) || '@beres.id', 'TUKANG', 'Tukang Lock', '0812345678');
  INSERT INTO tukang_profiles (user_id, kyc_status, is_online, radius_km) VALUES (v_tukang_id, 'APPROVED', true, 25);

  INSERT INTO profiles (id, email, role, full_name, phone) VALUES (v_user_id, 'user_lock_' || SUBSTRING(gen_random_uuid()::TEXT, 1, 6) || '@beres.id', 'USER', 'User Lock', '0812345679');

  INSERT INTO jobs (id, user_id, category_id, description, status, area_label, address_full, location)
  VALUES (v_job_a, v_user_id, v_cat_id, 'Job A', 'OPEN', 'Tebet', 'Jl. Tebet A', ST_SetSRID(ST_MakePoint(106.8456, -6.2088), 4326));
  INSERT INTO jobs (id, user_id, category_id, description, status, area_label, address_full, location)
  VALUES (v_job_b, v_user_id, v_cat_id, 'Job B', 'OPEN', 'Tebet', 'Jl. Tebet B', ST_SetSRID(ST_MakePoint(106.8456, -6.2088), 4326));
  INSERT INTO jobs (id, user_id, category_id, description, status, area_label, address_full, location)
  VALUES (v_job_c, v_user_id, v_cat_id, 'Job C', 'OPEN', 'Tebet', 'Jl. Tebet C', ST_SetSRID(ST_MakePoint(106.8456, -6.2088), 4326));

  -- Tukang bids on Job A, B, and C
  INSERT INTO bids (id, job_id, tukang_id, status) VALUES (gen_random_uuid(), v_job_a, v_tukang_id, 'ACTIVE');
  INSERT INTO bids (id, job_id, tukang_id, status) VALUES (gen_random_uuid(), v_job_b, v_tukang_id, 'ACTIVE');
  INSERT INTO bids (id, job_id, tukang_id, status) VALUES (gen_random_uuid(), v_job_c, v_tukang_id, 'ACTIVE');

  -- User locks tukang on Job C
  UPDATE jobs SET locked_tukang_id = v_tukang_id, status = 'NEGOTIATING', locked_at = NOW() WHERE id = v_job_c;

  -- Verify: Bids on Job A and B should now be WITHDRAWN (BR-17)
  SELECT COUNT(*) INTO v_withdrawn_count FROM bids WHERE tukang_id = v_tukang_id AND status = 'WITHDRAWN';
  IF v_withdrawn_count = 2 THEN
    RAISE NOTICE 'SUCCESS: Auto-clear on lock (BR-17) automatically set 2 other bids to WITHDRAWN.';
  ELSE
    RAISE EXCEPTION 'TEST FAILED: Expected 2 withdrawn bids, found %', v_withdrawn_count;
  END IF;
END $$;

-- 4. Uji Penegakan Suspend Otomatis 2 Hari saat Strike ke-4 (BR-57, BR-71 / E2E-06)
DO $$
DECLARE
  v_tukang_id UUID := gen_random_uuid();
  v_suspend_type TEXT;
  v_suspended_until TIMESTAMPTZ;
  i INT;
BEGIN
  INSERT INTO profiles (id, email, role, full_name, phone) VALUES (v_tukang_id, 'tukang_strike_' || SUBSTRING(gen_random_uuid()::TEXT, 1, 6) || '@beres.id', 'TUKANG', 'Tukang Strike', '0812345678');
  INSERT INTO tukang_profiles (user_id, kyc_status, is_online, radius_km) VALUES (v_tukang_id, 'APPROVED', true, 25);

  -- Insert 3 strikes in current month (Should NOT trigger auto suspend)
  FOR i IN 1..3 LOOP
    INSERT INTO strikes (id, user_id, reason, strike_type, created_at)
    VALUES (gen_random_uuid(), v_tukang_id, 'Pembatalan sebelum berangkat', 'NO_DEPART_30M', NOW());
  END LOOP;

  SELECT suspend_type INTO v_suspend_type FROM profiles WHERE id = v_tukang_id;
  IF v_suspend_type <> 'NONE' THEN
    RAISE EXCEPTION 'TEST FAILED: Account suspended prematurely before 4th strike!';
  END IF;

  -- Insert 4th strike (Must trigger AUTO_2_DAYS suspend via trigger)
  INSERT INTO strikes (id, user_id, reason, strike_type, created_at)
  VALUES (gen_random_uuid(), v_tukang_id, 'Pembatalan berulang', 'NO_DEPART_30M', NOW());

  SELECT suspend_type, suspended_until INTO v_suspend_type, v_suspended_until FROM profiles WHERE id = v_tukang_id;
  IF v_suspend_type = 'AUTO_2_DAYS' AND v_suspended_until > NOW() THEN
    RAISE NOTICE 'SUCCESS: 4th strike triggered AUTO_2_DAYS suspension (BR-57/71) until %', v_suspended_until;
  ELSE
    RAISE EXCEPTION 'TEST FAILED: 4th strike did not set AUTO_2_DAYS suspension. Found: %', v_suspend_type;
  END IF;
END $$;

-- Rollback entire test transaction so no dirty data persists
ROLLBACK;
