# Panduan Review Toko Aplikasi (Store Review Guidelines) — Project "Beres" (v1.4.0)

Dokumen ini disusun untuk Tim Reviewer **Google Play Console** dan **Apple App Store Review** yang memvalidasi aplikasi **Beres User** dan **Beres Mitra (Tukang)**.

---

## 1. Justifikasi Izin Lokasi Latar Belakang (Background Location Justification)

### A. Aplikasi yang Terdampak
* **Nama Aplikasi:** Beres Mitra (Tukang)
* **Paket Android:** `id.beres.tukang`
* **Bundle ID iOS:** `id.beres.tukang`
* **Izin yang Diminta:**
  * Android: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE_LOCATION`
  * iOS: `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, Background Mode: `location`

### B. Alasan Fungsional Wajib (Core Feature Justification)
Beres adalah platform marketplace jasa perbaikan pertukangan *on-demand*. Ketika seorang Mitra Tukang telah menerima tugas dan berstatus **`ON_THE_WAY` (Menuju Lokasi)**, **`ARRIVED` (Tiba di Lokasi)**, dan **`WORKING` (Sedang Bekerja)**:
1. **Pembaruan Live Tracking & ETA Pelanggan (`FR-016`, `FR-030`):**
   * Pelanggan perlu memantau pergerakan fisik tukang secara real-time pada peta interaktif untuk mengetahui estimasi waktu kedatangan (*ETA*).
   * Selama berkendara (sepeda motor), layar ponsel Mitra Tukang seringkali dalam keadaan mati atau berada di dalam saku/tas. Tanpa izin lokasi latar belakang (*Background Location*), pengiriman koordinat GPS akan terhenti, membingungkan pelanggan, dan berpotensi memicu pembatalan sepihak yang merugikan.
2. **Verifikasi Kedatangan Geospasial Otomatis $\le$ 50 Meter (`BR-60`):**
   * Server Beres memvalidasi kedatangan Mitra Tukang secara objektif dan otomatis ketika posisi GPS tukang terdeteksi berada pada radius $\le$ 50 meter dari titik pekerjaan.
   * Hal ini mencegah manipulasi klaim sepihak dan memastikan tukang benar-benar telah sampai di depan rumah pelanggan.
3. **Keamanan & Perlindungan Pengguna (Safety Guardrail):**
   * Apabila terjadi insiden darurat di jalan atau sengketa keterlambatan lebih dari 3 jam (`BR-56`), log lokasi latar belakang menjadi bukti forensik tunggal yang diverifikasi oleh tim admin (`FR-031`).

### C. Pembatasan Privasi (Privacy Safeguards)
* Lokasi latar belakang **HANYA** aktif ketika ada pekerjaan aktif yang sedang berjalan (`ON_THE_WAY`, `ARRIVED`, `WORKING`).
* Begitu pekerjaan berstatus `COMPLETED` atau `CANCELLED`, pelacakan latar belakang **SEKETIKA BERHENTI**.
* Saat Mitra Tukang berstatus `Offline` atau berada di luar penugasan, sistem **TIDAK PERNAH** meminta atau merekam data lokasi latar belakang.

---

## 2. Kepatuhan Penghapusan Akun & Data (Account Deletion Compliance)
Sesuai **App Store Review Guideline 5.1.1(v)** dan **Google Play Data Safety Policy**:
* Fitur penghapusan akun mandiri tersedia langsung di dalam aplikasi bagi Pelanggan dan Mitra Tukang:
  * Masuk ke tab **Profil / Pengaturan** $\rightarrow$ Gulir ke bagian bawah $\rightarrow$ Tekan tombol **"Hapus Akun Saya"** (`FR-004`, `BR-45`).
  * Konfirmasi dialog persetujuan akan langsung menganonimkan dan menghapus data pribadi pengguna dari sistem aktif.
  * Tautan formulir web penghapusan data publik juga disediakan di portal resmi: `https://beres.id/account-deletion`.

---

## 3. Akun Pengujian untuk Reviewer (Reviewer Demo Credentials)

Untuk mempermudah verifikasi fungsional oleh tim reviewer tanpa memerlukan nomor ponsel Indonesia atau pembayaran riil:

### A. Pengujian Beres User (Pelanggan)
* **Email Uji User:** `reviewer.user@beres.id`
* **Metode Login:** Email OTP (Gunakan kode OTP bypass untuk akun pengujian: `123456`).
* **Langkah Uji:**
  1. Masukkan email $\rightarrow$ masukkan OTP `123456`.
  2. Klik tombol *"Posting Pekerjaan"* $\rightarrow$ pilih kategori *"Listrik"* $\rightarrow$ atur pin peta $\rightarrow$ klik *"Posting Sekarang"*.
  3. Buka halaman tawaran tukang $\rightarrow$ lakukan *"Lock Tukang"*.
  4. Buka ruang chat $\rightarrow$ terima Nota Digital yang dikirimkan tukang demo.

### B. Pengujian Beres Mitra (Tukang)
* **Email Uji Tukang:** `reviewer.tukang@beres.id`
* **Metode Login:** Email OTP (Gunakan kode OTP bypass: `123456`).
* **Status Akun:** Telah disetujui KYC (`KYC = APPROVED`).
* **Langkah Uji:**
  1. Masukkan email $\rightarrow$ masukkan OTP `123456`.
  2. Buka tab *"Bursa Kerja"* $\rightarrow$ lihat pekerjaan terbuka $\rightarrow$ klik *"Lamar Pekerjaan (Bid)"*.
  3. Setelah di-lock oleh User, buka Chat $\rightarrow$ buat Nota Digital $\rightarrow$ klik *"Berangkat ke Lokasi"*.
  4. Tekan tombol simulasi tiba *"Saya Sudah Tiba"* $\rightarrow$ *"Mulai Bekerja"*.
  5. Unggah foto bukti hasil kerja $\rightarrow$ pilih metode bayar *"Tunai"* $\rightarrow$ centang *"User sudah bayar"* $\rightarrow$ klik *"Selesaikan Tugas"*.

### C. Pengujian Beres Web Admin
* **URL Admin:** `https://admin.beres.id` (atau `localhost:3000` pada lingkungan lokal).
* **Akun Admin:** `admin@beres.id`
* **Password:** `AdminBeres2026!`
* **MFA Code:** `123456`
