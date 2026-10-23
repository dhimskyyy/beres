-- ============================================================================
-- BERES PLATFORM - RESET TEST USERS & HANDYMEN SCRIPT
-- Menghapus seluruh akun testing (User & Tukang) dari Supabase Auth dan tabel profiles
-- Akun Admin (admin@beres.id), kategori, dan konfigurasi sistem TETAP AMAN.
-- ============================================================================

-- 1. Hapus data relasi tukang testing
DELETE FROM kyc_documents WHERE tukang_id IN (SELECT id FROM profiles WHERE email != 'admin@beres.id');
DELETE FROM tukang_categories WHERE tukang_id IN (SELECT id FROM profiles WHERE email != 'admin@beres.id');
DELETE FROM tukang_profiles WHERE user_id IN (SELECT id FROM profiles WHERE email != 'admin@beres.id');

-- 2. Hapus data transaksi & aktivitas testing
DELETE FROM reviews WHERE user_id IN (SELECT id FROM profiles WHERE email != 'admin@beres.id');
DELETE FROM strikes WHERE user_id IN (SELECT id FROM profiles WHERE email != 'admin@beres.id');
DELETE FROM notifications WHERE user_id IN (SELECT id FROM profiles WHERE email != 'admin@beres.id');
DELETE FROM device_tokens WHERE user_id IN (SELECT id FROM profiles WHERE email != 'admin@beres.id');
DELETE FROM chat_messages WHERE sender_id IN (SELECT id FROM profiles WHERE email != 'admin@beres.id');
DELETE FROM notas WHERE job_id IN (SELECT id FROM jobs WHERE user_id IN (SELECT id FROM profiles WHERE email != 'admin@beres.id'));
DELETE FROM job_photos WHERE uploaded_by IN (SELECT id FROM profiles WHERE email != 'admin@beres.id');
DELETE FROM bids WHERE tukang_id IN (SELECT id FROM profiles WHERE email != 'admin@beres.id');
DELETE FROM location_pings WHERE job_id IN (SELECT id FROM jobs WHERE user_id IN (SELECT id FROM profiles WHERE email != 'admin@beres.id'));
DELETE FROM cancel_requests WHERE requester_id IN (SELECT id FROM profiles WHERE email != 'admin@beres.id');
DELETE FROM jobs WHERE user_id IN (SELECT id FROM profiles WHERE email != 'admin@beres.id');

-- 3. Hapus profil testing dari tabel public.profiles
DELETE FROM profiles WHERE email != 'admin@beres.id';

-- 4. Hapus akun testing dari Supabase Auth (auth.users)
DELETE FROM auth.users WHERE email != 'admin@beres.id';
