-- ============================================================================
-- BERES PLATFORM - INITIAL DATABASE SCHEMA v1.4.0 (PostgreSQL + PostGIS)
-- Selaras 100% dengan docs/PRD.md v1.4.0 & docs/DATABASE_SCHEMA.md v1.4.0
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- 1. ENUMS (v1.4.0)
CREATE TYPE user_role AS ENUM ('USER', 'TUKANG', 'ADMIN');
CREATE TYPE suspend_type AS ENUM ('NONE', 'AUTO_2_DAYS', 'MANUAL_PERMANENT');
CREATE TYPE kyc_status AS ENUM ('PENDING', 'APPROVED', 'REJECTED');
CREATE TYPE job_status AS ENUM (
  'OPEN',
  'NEGOTIATING',
  'NOTA_APPROVED',
  'ON_THE_WAY',
  'ARRIVED',
  'WORKING',
  'COMPLETED',
  'CANCELLED',
  'EXPIRED',
  'CANCEL_PENDING'
);
CREATE TYPE bid_status AS ENUM ('ACTIVE', 'LOCKED', 'WITHDRAWN');
CREATE TYPE nota_status AS ENUM ('SENT', 'APPROVED', 'REJECTED', 'SUPERSEDED', 'VOID');
CREATE TYPE payment_method_type AS ENUM ('BANK_TRANSFER', 'E_WALLET', 'CASH');
CREATE TYPE arrival_mode_type AS ENUM ('AUTO', 'MANUAL');
CREATE TYPE photo_type AS ENUM ('DAMAGE', 'WORK_RESULT', 'PAYMENT_PROOF');
CREATE TYPE cancel_request_status AS ENUM ('DRAFT', 'SUBMITTED', 'APPROVED', 'REJECTED', 'ABORTED');
CREATE TYPE strike_type AS ENUM (
  'NO_DEPART_30M',
  'TUKANG_CANCEL_APPROVED',
  'OTW_3H_UNRESPONSIVE',
  'USER_UNRESPONSIVE_OTW_ARRIVED'
);
CREATE TYPE report_category AS ENUM ('PAYMENT_DEFAULT', 'SAFETY_OR_FRAUD', 'FIELD_ISSUE', 'OTHER');
CREATE TYPE report_status AS ENUM ('OPEN', 'IN_REVIEW', 'RESOLVED');

-- 2. PROFILES TABLE (BR-44: 1 Email = 1 Peran)
CREATE TABLE profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT UNIQUE NOT NULL,
  role user_role NOT NULL,
  full_name TEXT NOT NULL,
  phone TEXT,
  avatar_url TEXT,
  timezone TEXT NOT NULL DEFAULT 'Asia/Jakarta' CHECK (timezone IN ('Asia/Jakarta', 'Asia/Makassar', 'Asia/Jayapura')),
  suspend_type suspend_type NOT NULL DEFAULT 'NONE',
  suspended_until TIMESTAMPTZ,
  suspend_reason TEXT,
  appeal_email_info TEXT DEFAULT 'support@beres.id',
  deleted_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. TUKANG PROFILES TABLE
CREATE TABLE tukang_profiles (
  user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  bio TEXT,
  kyc_status kyc_status NOT NULL DEFAULT 'PENDING',
  kyc_approved_at TIMESTAMPTZ,
  is_online BOOLEAN NOT NULL DEFAULT FALSE,
  radius_km INTEGER NOT NULL DEFAULT 20 CHECK (radius_km >= 0 AND radius_km <= 50),
  payment_accounts JSONB NOT NULL DEFAULT '[]'::JSONB,
  last_known_location GEOGRAPHY(POINT, 4326),
  location_updated_at TIMESTAMPTZ,
  rating_avg NUMERIC(3, 2) NOT NULL DEFAULT 0.00,
  rating_count INTEGER NOT NULL DEFAULT 0,
  -- Hook Phase 2 (Dilarang dipakai di UI/logika MVP)
  tier TEXT NOT NULL DEFAULT 'STANDARD',
  gold_until TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_tukang_last_location ON tukang_profiles USING GIST (last_known_location);

-- 4. KYC DOCUMENTS TABLE
CREATE TABLE kyc_documents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tukang_id UUID NOT NULL REFERENCES tukang_profiles(user_id) ON DELETE CASCADE,
  ktp_storage_path TEXT NOT NULL,
  selfie_storage_path TEXT NOT NULL,
  status kyc_status NOT NULL DEFAULT 'PENDING',
  rejection_reason TEXT,
  reviewed_by UUID REFERENCES profiles(id),
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. CATEGORIES & TUKANG CATEGORIES
CREATE TABLE categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  slug TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  icon_name TEXT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE tukang_categories (
  tukang_id UUID NOT NULL REFERENCES tukang_profiles(user_id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (tukang_id, category_id)
);

-- 6. JOBS TABLE (10 Status v1.4.0)
CREATE TABLE jobs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES categories(id),
  locked_tukang_id UUID REFERENCES tukang_profiles(user_id),
  description TEXT NOT NULL CHECK (char_length(description) >= 10),
  location GEOGRAPHY(POINT, 4326) NOT NULL,
  area_label TEXT NOT NULL,
  address_full TEXT NOT NULL,
  broadcast_radius_km INTEGER NOT NULL DEFAULT 50 CHECK (broadcast_radius_km = 50),
  -- Hook Phase 2
  is_boosted BOOLEAN NOT NULL DEFAULT FALSE,
  status job_status NOT NULL DEFAULT 'OPEN',
  status_before_cancel job_status,
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '24 hours'),
  locked_at TIMESTAMPTZ,
  last_chat_at TIMESTAMPTZ,
  last_chat_sender_role user_role,
  nota_approved_at TIMESTAMPTZ,
  on_the_way_at TIMESTAMPTZ,
  arrived_at TIMESTAMPTZ,
  arrival_mode arrival_mode_type,
  work_started_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ,
  agreed_total BIGINT CHECK (agreed_total IS NULL OR agreed_total > 0),
  actual_payment_method payment_method_type,
  user_paid_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
  payment_confirmed_at TIMESTAMPTZ,
  completion_note TEXT,
  payment_dispute_active BOOLEAN NOT NULL DEFAULT FALSE,
  cancelled_by UUID REFERENCES profiles(id),
  cancel_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_jobs_location ON jobs USING GIST (location);
CREATE INDEX idx_jobs_status ON jobs (status);
CREATE INDEX idx_jobs_locked_tukang ON jobs (locked_tukang_id);

-- 7. JOB STATUS HISTORY TABLE
CREATE TABLE job_status_history (
  id BIGSERIAL PRIMARY KEY,
  job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
  from_status job_status,
  to_status job_status NOT NULL,
  actor_id UUID REFERENCES profiles(id),
  actor_role TEXT,
  reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. JOB PHOTOS TABLE (DAMAGE, WORK_RESULT, PAYMENT_PROOF)
CREATE TABLE job_photos (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
  uploaded_by UUID NOT NULL REFERENCES profiles(id),
  type photo_type NOT NULL,
  storage_path TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 9. BIDS TABLE (BR-15: Maks 5 ACTIVE; BR-17: Auto-Withdrawn saat Lock di job lain)
CREATE TABLE bids (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
  tukang_id UUID NOT NULL REFERENCES tukang_profiles(user_id) ON DELETE CASCADE,
  distance_km NUMERIC(5, 2),
  status bid_status NOT NULL DEFAULT 'ACTIVE',
  withdrawn_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (job_id, tukang_id)
);

-- 10. NOTAS TABLE (BR-05: Immutable setelah APPROVED; menyimpan previous_approved_total)
CREATE TABLE notas (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
  tukang_id UUID NOT NULL REFERENCES tukang_profiles(user_id) ON DELETE CASCADE,
  version INTEGER NOT NULL DEFAULT 1,
  revision_of UUID REFERENCES notas(id),
  previous_approved_total BIGINT,
  items JSONB NOT NULL DEFAULT '[]'::JSONB,
  total_amount BIGINT NOT NULL CHECK (total_amount > 0),
  payment_method payment_method_type NOT NULL,
  payment_destination JSONB,
  note TEXT,
  status nota_status NOT NULL DEFAULT 'SENT',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  responded_at TIMESTAMPTZ
);

-- 11. CHAT MESSAGES TABLE
CREATE TABLE chat_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  message_type TEXT NOT NULL DEFAULT 'TEXT' CHECK (
    message_type IN ('TEXT', 'IMAGE', 'NOTA_CARD', 'NOTA_REVISION_ALERT', 'SYSTEM_EVENT')
  ),
  content TEXT,
  image_url TEXT,
  nota_id UUID REFERENCES notas(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 12. CANCEL REQUESTS TABLE (BR-50 s/d BR-56)
CREATE TABLE cancel_requests (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
  requester_id UUID NOT NULL REFERENCES profiles(id),
  requester_role user_role NOT NULL CHECK (requester_role IN ('TUKANG', 'USER')),
  status cancel_request_status NOT NULL DEFAULT 'DRAFT',
  status_before_cancel job_status NOT NULL,
  reason_category TEXT,
  reason_text TEXT,
  admin_notes TEXT,
  evidence_photos TEXT[] NOT NULL DEFAULT '{}',
  requester_location GEOGRAPHY(POINT, 4326),
  distance_to_job_m DOUBLE PRECISION,
  submitted_at TIMESTAMPTZ,
  resolved_by UUID REFERENCES profiles(id),
  resolved_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 13. STRIKES TABLE (BR-57 & BR-71: Maks 3x/Bulan, Strike ke-4 = Suspend Otomatis 2 Hari)
CREATE TABLE strikes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role user_role NOT NULL CHECK (role IN ('TUKANG', 'USER')),
  job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
  strike_type strike_type NOT NULL,
  description TEXT NOT NULL,
  is_excused BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 14. REPORTS TABLE (Termasuk Laporan Masalah Pembayaran BR-67)
CREATE TABLE reports (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
  reporter_id UUID NOT NULL REFERENCES profiles(id),
  reported_user_id UUID NOT NULL REFERENCES profiles(id),
  category report_category NOT NULL,
  is_priority BOOLEAN NOT NULL DEFAULT FALSE,
  description TEXT NOT NULL,
  evidence_photos TEXT[] NOT NULL DEFAULT '{}',
  status report_status NOT NULL DEFAULT 'OPEN',
  admin_resolution_notes TEXT,
  resolved_by UUID REFERENCES profiles(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  resolved_at TIMESTAMPTZ
);

-- 15. LOCATION PINGS, REVIEWS, APP CONFIGS, DEVICE TOKENS, NOTIFICATIONS, AUDIT LOGS
CREATE TABLE location_pings (
  id BIGSERIAL PRIMARY KEY,
  job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
  tukang_id UUID NOT NULL REFERENCES tukang_profiles(user_id) ON DELETE CASCADE,
  location GEOGRAPHY(POINT, 4326) NOT NULL,
  accuracy_m DOUBLE PRECISION,
  heading DOUBLE PRECISION,
  speed DOUBLE PRECISION,
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE reviews (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  job_id UUID UNIQUE NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  tukang_id UUID NOT NULL REFERENCES tukang_profiles(user_id) ON DELETE CASCADE,
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE app_configs (
  key TEXT PRIMARY KEY,
  value_int INTEGER,
  value_text TEXT,
  description TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE device_tokens (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  platform TEXT,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id, fcm_token)
);

CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  deep_link TEXT,
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE audit_logs (
  id BIGSERIAL PRIMARY KEY,
  actor_id UUID REFERENCES profiles(id),
  action TEXT NOT NULL,
  target_type TEXT NOT NULL,
  target_id TEXT,
  metadata JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- SEED APP CONFIGS & INITIAL SERVICE CATEGORIES
-- ============================================================================
INSERT INTO app_configs (key, value_int, description) VALUES
  ('max_active_bids', 5, 'Maksimal lamaran (bid) aktif bersamaan per tukang (BR-15)'),
  ('weekly_completed_quota', 5, 'Maksimal job COMPLETED per minggu per tukang (BR-21)'),
  ('chat_negotiating_timeout_min', 30, 'Batas waktu respons chat saat NEGOTIATING sebelum lepas ke portal tanpa strike (BR-70)'),
  ('depart_after_nota_timeout_min', 30, 'Batas waktu wajib klik Berangkat setelah NOTA_APPROVED sebelum lepas ke portal + 1 strike (BR-31)'),
  ('user_otw_arrived_chat_timeout_min', 30, 'Batas waktu respons chat User saat tukang ON_THE_WAY/ARRIVED sebelum User kena 1 strike (BR-71)'),
  ('otw_user_cancel_threshold_hours', 3, 'Batas jam ON_THE_WAY sebelum tombol Cancel muncul di aplikasi User (BR-56b)'),
  ('arrived_auto_radius_m', 50, 'Jarak otomatis status ARRIVED dalam meter (BR-60)'),
  ('arrived_manual_radius_m', 200, 'Jarak maksimal tombol manual Saya Sudah Tiba dalam meter (BR-61)'),
  ('max_monthly_strikes', 3, 'Toleransi maksimal strike per bulan; strike ke-4 memicu suspend 2 hari (BR-57, BR-71)'),
  ('auto_suspend_hours', 48, 'Durasi suspend otomatis dalam jam (2 hari penuh)')
ON CONFLICT (key) DO NOTHING;

INSERT INTO categories (slug, name, description, icon_name, sort_order) VALUES
  ('bangunan', 'Tukang Bangunan', 'Renovasi rumah, pasang keramik, plester tembok, perbaikan atap bocor, pengecatan', 'construction', 1),
  ('listrik', 'Tukang Listrik', 'Perbaikan korsleting, pasang MCB, instalasi titik lampu, saklar, dan stop kontak', 'electrical_services', 2),
  ('pipa-plumbing', 'Tukang Pipa & Air', 'Perbaikan pipa bocor/mampet, pasang kran, pompa air, kuras toren, dan saluran WC', 'plumbing', 3),
  ('cleaning-service', 'Cleaning Service & AC', 'Bersih rumah panggilan, cuci AC, sedot tungau, pembersihan pasca renovasi', 'cleaning_services', 4),
  ('bengkel-motor', 'Bengkel Motor Panggilan', 'Motor mogok darurat, tambal/ganti ban, ganti aki, servis ringan di rumah/jalan', 'two_wheeler', 5),
  ('bengkel-mobil', 'Bengkel Mobil Panggilan', 'Jumper/ganti aki mobil, ban bocor, cek mesin darurat, ganti oli di rumah', 'directions_car', 6),
  ('tukang-kayu', 'Tukang Kayu & Mebel', 'Perbaikan pintu/kusen, pembuatan lemari, rak, kitchen set, dan engsel jendela', 'carpenter', 7)
ON CONFLICT (slug) DO NOTHING;
