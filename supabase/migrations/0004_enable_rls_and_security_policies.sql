-- ============================================================================
-- BERES PLATFORM - MIGRATION 0004: ENABLE ROW LEVEL SECURITY & HARDEN RPCs
-- Menyelesaikan seluruh peringatan Supabase Database Linter & Security Advisor
-- ============================================================================

-- 1. AKTIFKAN ROW LEVEL SECURITY (RLS) DI SELURUH TABEL PUBLIC
ALTER TABLE IF EXISTS spatial_ref_sys ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS tukang_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS kyc_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS tukang_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS bids ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS notas ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS tracking_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS job_photos ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS job_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS cancel_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS location_pings ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS strikes ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS app_configs ENABLE ROW LEVEL SECURITY;

-- 2. HELPER FUNCTION UNTUK MENGECEK ROLE ADMIN DI RLS
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'ADMIN'
  );
$$;

-- 3. POLICIES: spatial_ref_sys (PostGIS)
DROP POLICY IF EXISTS "Public read spatial_ref_sys" ON spatial_ref_sys;
CREATE POLICY "Public read spatial_ref_sys" ON spatial_ref_sys
  FOR SELECT USING (true);

-- 4. POLICIES: categories & app_configs (Publik Boleh Baca, Admin Boleh Edit)
DROP POLICY IF EXISTS "Allow public read categories" ON categories;
CREATE POLICY "Allow public read categories" ON categories
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow admin write categories" ON categories;
CREATE POLICY "Allow admin write categories" ON categories
  FOR ALL USING (is_admin() OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "Allow public read app_configs" ON app_configs;
CREATE POLICY "Allow public read app_configs" ON app_configs
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow admin write app_configs" ON app_configs;
CREATE POLICY "Allow admin write app_configs" ON app_configs
  FOR ALL USING (is_admin() OR auth.role() = 'service_role');

-- 5. POLICIES: profiles (Publik baca info dasar, User ubah profil sendiri, Admin akses semua)
DROP POLICY IF EXISTS "Allow read profiles" ON profiles;
CREATE POLICY "Allow read profiles" ON profiles
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow self insert profile" ON profiles;
CREATE POLICY "Allow self insert profile" ON profiles
  FOR INSERT WITH CHECK (id = auth.uid() OR auth.role() = 'service_role' OR is_admin());

DROP POLICY IF EXISTS "Allow self update profile" ON profiles;
CREATE POLICY "Allow self update profile" ON profiles
  FOR UPDATE USING (id = auth.uid() OR auth.role() = 'service_role' OR is_admin());

-- 6. POLICIES: tukang_profiles & tukang_categories
DROP POLICY IF EXISTS "Allow read tukang_profiles" ON tukang_profiles;
CREATE POLICY "Allow read tukang_profiles" ON tukang_profiles
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow tukang update own profile" ON tukang_profiles;
CREATE POLICY "Allow tukang update own profile" ON tukang_profiles
  FOR UPDATE USING (user_id = auth.uid() OR auth.role() = 'service_role' OR is_admin());

DROP POLICY IF EXISTS "Allow tukang insert own profile" ON tukang_profiles;
CREATE POLICY "Allow tukang insert own profile" ON tukang_profiles
  FOR INSERT WITH CHECK (user_id = auth.uid() OR auth.role() = 'service_role' OR is_admin());

DROP POLICY IF EXISTS "Allow read tukang_categories" ON tukang_categories;
CREATE POLICY "Allow read tukang_categories" ON tukang_categories
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow tukang manage own categories" ON tukang_categories;
CREATE POLICY "Allow tukang manage own categories" ON tukang_categories
  FOR ALL USING (tukang_id = auth.uid() OR auth.role() = 'service_role' OR is_admin());

-- 7. POLICIES: kyc_documents (Tukang baca/unggah milik sendiri, Admin kelola semua)
DROP POLICY IF EXISTS "Allow tukang read own kyc" ON kyc_documents;
CREATE POLICY "Allow tukang read own kyc" ON kyc_documents
  FOR SELECT USING (tukang_id = auth.uid() OR is_admin() OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "Allow tukang insert own kyc" ON kyc_documents;
CREATE POLICY "Allow tukang insert own kyc" ON kyc_documents
  FOR INSERT WITH CHECK (tukang_id = auth.uid() OR is_admin() OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "Allow admin update kyc" ON kyc_documents;
CREATE POLICY "Allow admin update kyc" ON kyc_documents
  FOR UPDATE USING (is_admin() OR auth.role() = 'service_role');

-- 8. POLICIES: jobs, job_status_history, job_photos
DROP POLICY IF EXISTS "Allow read jobs" ON jobs;
CREATE POLICY "Allow read jobs" ON jobs
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow user create jobs" ON jobs;
CREATE POLICY "Allow user create jobs" ON jobs
  FOR INSERT WITH CHECK (user_id = auth.uid() OR is_admin() OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "Allow user or locked tukang update jobs" ON jobs;
CREATE POLICY "Allow user or locked tukang update jobs" ON jobs
  FOR UPDATE USING (user_id = auth.uid() OR locked_tukang_id = auth.uid() OR is_admin() OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "Allow read job_status_history" ON job_status_history;
CREATE POLICY "Allow read job_status_history" ON job_status_history
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow insert job_status_history" ON job_status_history;
CREATE POLICY "Allow insert job_status_history" ON job_status_history
  FOR INSERT WITH CHECK (auth.role() = 'authenticated' OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "Allow read job_photos" ON job_photos;
CREATE POLICY "Allow read job_photos" ON job_photos
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow insert job_photos" ON job_photos;
CREATE POLICY "Allow insert job_photos" ON job_photos
  FOR INSERT WITH CHECK (uploaded_by = auth.uid() OR is_admin() OR auth.role() = 'service_role');

-- 9. POLICIES: bids & cancel_requests
DROP POLICY IF EXISTS "Allow read bids" ON bids;
CREATE POLICY "Allow read bids" ON bids
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow tukang manage own bids" ON bids;
CREATE POLICY "Allow tukang manage own bids" ON bids
  FOR ALL USING (tukang_id = auth.uid() OR is_admin() OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "Allow read cancel_requests" ON cancel_requests;
CREATE POLICY "Allow read cancel_requests" ON cancel_requests
  FOR SELECT USING (requester_id = auth.uid() OR is_admin() OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "Allow insert cancel_requests" ON cancel_requests;
CREATE POLICY "Allow insert cancel_requests" ON cancel_requests
  FOR ALL USING (requester_id = auth.uid() OR is_admin() OR auth.role() = 'service_role');

-- 10. POLICIES: notas, chat_rooms, chat_messages, tracking_locations
DROP POLICY IF EXISTS "Allow read notas" ON notas;
CREATE POLICY "Allow read notas" ON notas
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow tukang manage notas" ON notas;
CREATE POLICY "Allow tukang manage notas" ON notas
  FOR ALL USING (tukang_id = auth.uid() OR is_admin() OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "Allow participants read chat_rooms" ON chat_rooms;
CREATE POLICY "Allow participants read chat_rooms" ON chat_rooms
  FOR SELECT USING (user_id = auth.uid() OR tukang_id = auth.uid() OR is_admin() OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "Allow participants insert chat_rooms" ON chat_rooms;
CREATE POLICY "Allow participants insert chat_rooms" ON chat_rooms
  FOR INSERT WITH CHECK (user_id = auth.uid() OR is_admin() OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "Allow participants chat_messages" ON chat_messages;
CREATE POLICY "Allow participants chat_messages" ON chat_messages
  FOR ALL USING (sender_id = auth.uid() OR is_admin() OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "Allow tracking_locations" ON tracking_locations;
CREATE POLICY "Allow tracking_locations" ON tracking_locations
  FOR ALL USING (tukang_id = auth.uid() OR is_admin() OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "Allow location_pings" ON location_pings;
CREATE POLICY "Allow location_pings" ON location_pings
  FOR ALL USING (tukang_id = auth.uid() OR is_admin() OR auth.role() = 'service_role');

-- 11. POLICIES: reviews, strikes, reports, device_tokens, notifications, audit_logs
DROP POLICY IF EXISTS "Allow read reviews" ON reviews;
CREATE POLICY "Allow read reviews" ON reviews
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "Allow user create reviews" ON reviews;
CREATE POLICY "Allow user create reviews" ON reviews
  FOR INSERT WITH CHECK (user_id = auth.uid() OR is_admin() OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "Allow read own strikes" ON strikes;
CREATE POLICY "Allow read own strikes" ON strikes
  FOR SELECT USING (user_id = auth.uid() OR is_admin() OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "Allow reports" ON reports;
CREATE POLICY "Allow reports" ON reports
  FOR ALL USING (reporter_id = auth.uid() OR is_admin() OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "Allow device_tokens" ON device_tokens;
CREATE POLICY "Allow device_tokens" ON device_tokens
  FOR ALL USING (user_id = auth.uid() OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "Allow notifications" ON notifications;
CREATE POLICY "Allow notifications" ON notifications
  FOR ALL USING (user_id = auth.uid() OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "Allow audit_logs insert" ON audit_logs;
CREATE POLICY "Allow audit_logs insert" ON audit_logs
  FOR INSERT WITH CHECK (true);

DROP POLICY IF EXISTS "Allow admin read audit_logs" ON audit_logs;
CREATE POLICY "Allow admin read audit_logs" ON audit_logs
  FOR SELECT USING (is_admin() OR auth.role() = 'service_role');

-- 12. HARDEN PRIVILEGES ON SECURITY DEFINER FUNCTIONS
-- Menghilangkan peringatan "Public Can Execute SECURITY DEFINER Function"
REVOKE EXECUTE ON FUNCTION rpc_check_email_role(TEXT, user_role) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION rpc_check_email_role(TEXT, user_role) TO anon, authenticated, service_role;

REVOKE EXECUTE ON FUNCTION rpc_sync_profile_after_auth(UUID, TEXT, user_role, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION rpc_sync_profile_after_auth(UUID, TEXT, user_role, TEXT, TEXT) TO anon, authenticated, service_role;

REVOKE EXECUTE ON FUNCTION rpc_update_tukang_profile(UUID, TEXT, INTEGER, JSONB, UUID[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION rpc_update_tukang_profile(UUID, TEXT, INTEGER, JSONB, UUID[]) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION rpc_delete_account(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION rpc_delete_account(UUID) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION rpc_submit_kyc_document(UUID, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION rpc_submit_kyc_document(UUID, TEXT, TEXT) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION rpc_review_kyc(UUID, UUID, kyc_status, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION rpc_review_kyc(UUID, UUID, kyc_status, TEXT) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION rpc_admin_update_app_config(UUID, TEXT, INTEGER, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION rpc_admin_update_app_config(UUID, TEXT, INTEGER, TEXT) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION rpc_admin_save_category(UUID, UUID, TEXT, TEXT, TEXT, TEXT, BOOLEAN, INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION rpc_admin_save_category(UUID, UUID, TEXT, TEXT, TEXT, TEXT, BOOLEAN, INTEGER) TO authenticated, service_role;
