-- ============================================================================
-- BERES PLATFORM - MIGRATION 0010: STORAGE SECURITY POLICIES (RLS)
-- Selaras dengan docs/PRD.md v1.4.0 (FR-003, FR-012, FR-032, Bagian 13 PRD)
-- ============================================================================

-- 1. Pastikan seluruh bucket storage MVP tersedia
INSERT INTO storage.buckets (id, name, public)
VALUES 
  ('kyc-private', 'kyc-private', false),
  ('proof-photos', 'proof-photos', false),
  ('job-photos', 'job-photos', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Aktifkan RLS pada storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 3. POLICIES: kyc-private (Privat: Hanya Tukang pemilik & Admin)
CREATE POLICY "Allow authenticated upload to kyc-private"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'kyc-private');

CREATE POLICY "Allow owner and admin read kyc-private"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'kyc-private' AND (
    (storage.foldername(name))[2] = auth.uid()::text
    OR public.is_admin()
    OR auth.role() = 'service_role'
  )
);

CREATE POLICY "Allow owner and admin update kyc-private"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'kyc-private' AND (
    (storage.foldername(name))[2] = auth.uid()::text
    OR public.is_admin()
    OR auth.role() = 'service_role'
  )
);

CREATE POLICY "Allow owner and admin delete kyc-private"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'kyc-private' AND (
    (storage.foldername(name))[2] = auth.uid()::text
    OR public.is_admin()
    OR auth.role() = 'service_role'
  )
);

-- 4. POLICIES: job-photos (Publik: Foto Kerusakan, Foto Hasil Kerja)
CREATE POLICY "Allow authenticated upload job-photos"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'job-photos');

CREATE POLICY "Allow authenticated update job-photos"
ON storage.objects
FOR UPDATE
TO authenticated
USING (bucket_id = 'job-photos');

CREATE POLICY "Allow public read job-photos"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'job-photos');

-- 5. POLICIES: proof-photos (Privat: Bukti Bayar Non-Tunai & Pembatalan)
CREATE POLICY "Allow authenticated upload proof-photos"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'proof-photos');

CREATE POLICY "Allow authenticated read proof-photos"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'proof-photos');

CREATE POLICY "Allow authenticated update proof-photos"
ON storage.objects
FOR UPDATE
TO authenticated
USING (bucket_id = 'proof-photos');
