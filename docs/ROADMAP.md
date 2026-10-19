# Roadmap Pengembangan — Project "Beres" (v1.4.0)

Dokumen ini adalah daftar periksa (*checklist*) tahapan pembangunan ekosistem **Beres** yang telah diselaraskan sepenuhnya dengan **Bagian 15 [`docs/PRD.md`](./PRD.md) (Versi 1.4.0)**. 

> **Aturan AI Agent:** Kerjakan **satu milestone per sesi** secara berurutan (`M0` $\rightarrow$ `M8`). Jangan melanjutkan ke milestone berikutnya sebelum seluruh item dan *Definition of Done* (Bagian 16 `PRD.md`) terpenuhi.

---

## Milestone M0: Fondasi, Monorepo, & Skema Database v1.4.0
- [x] Menyusun dan mengunci spesifikasi utama [`docs/PRD.md`](./PRD.md) v1.4.0 (termasuk Lampiran C: FAQ & Aturan Tertulis Resmi).
- [x] Menyinkronkan dokumen panduan teknis: [`AGENTS.md`](../AGENTS.md), [`docs/ARCHITECTURE.md`](./ARCHITECTURE.md), [`docs/DATABASE_SCHEMA.md`](./DATABASE_SCHEMA.md), dan [`docs/ROADMAP.md`](./ROADMAP.md).
- [x] Membuat struktur folder monorepo (`mobile/shared`, `mobile/user`, `mobile/tukang`, `web/admin`, `supabase/migrations`).
- [x] Memperbarui file migrasi SQL awal (`supabase/migrations/0001_initial_schema.sql`) ke skema v1.4.0:
  - [x] 10 status pekerjaan (`OPEN`, `NEGOTIATING`, `NOTA_APPROVED`, `ON_THE_WAY`, `ARRIVED`, `WORKING`, `COMPLETED`, `CANCELLED`, `EXPIRED`, `CANCEL_PENDING`).
  - [x] Seluruh tabel v1.4.0 (`profiles`, `tukang_profiles`, `kyc_documents`, `categories`, `tukang_categories`, `jobs`, `job_status_history`, `job_photos`, `bids`, `notas`, `chat_messages`, `cancel_requests`, `strikes`, `reports`, `location_pings`, `reviews`, `app_configs`, `device_tokens`, `notifications`, `audit_logs`).
  - [x] Fungsi & Trigger penegak aturan bisnis v1.4.0 (1 Email = 1 Peran, Maks 5 Bid Aktif & Auto-Clear Bid Lain saat Lock, Immutability Nota Sah & Alert Revisi Nota, Deteksi Kedatangan 50m/200m, Perhitungan Strike User & Tukang > 3x = Suspend Otomatis 2 Hari, serta Suspend Langsung User Tidak Bayar).
- [x] Inisialisasi proyek Flutter (`mobile/shared`, `mobile/user`, `mobile/tukang`) dan Next.js (`web/admin`) agar seluruh proyek ter-build bersih (`flutter analyze` & `eslint` hijau).

---

## Milestone M1: Autentikasi, Peran Tunggal per Email, MFA Admin, & Profil
- [ ] **FR-001 & BR-44:** Implementasi Registrasi & Login Email OTP (6 digit via Custom SMTP/Resend) untuk `Beres User` dan `Beres Mitra (Tukang)` dengan penegakan **1 Email = 1 Peran** (tolak jika email User dipakai daftar Tukang, dan sebaliknya).
- [ ] **FR-002:** Form biodata Tukang, pemilihan multi-kategori keahlian, dan manajemen rekening bank / e-wallet pribadi.
- [ ] **FR-004 & BR-45:** Fitur **Hapus Akun** di aplikasi User dan Tukang (ditolak bila sedang ada job berjalan atau sengketa pembayaran aktif).
- [ ] **FR-037:** Login Web Admin dengan kewajiban **MFA (Email + Password + OTP 2 Langkah)**.
- [ ] **BR-42:** Tampilan layar akun terkena **Suspend Otomatis 2 Hari** (menampilkan penyebab, rincian strike, & waktu berakhir) vs **Suspend Permanen Admin** (menampilkan alasan & alamat Email Resmi Perusahaan untuk banding).

---

## Milestone M2: Kategori Dinamis, Verifikasi KYC, & Konfigurasi Sistem
- [ ] **FR-003:** Alur unggah Foto KTP dan Selfie memegang KTP di aplikasi Tukang ke bucket privat `kyc-private`.
- [ ] **FR-032:** Panel Verifikasi KYC di Web Admin (akses dokumen via *Signed URL* berumur pendek, tombol *Approve* & *Reject* dengan alasan wajib).
- [ ] **FR-033:** Fitur Suspend / Ban manual oleh Admin beserta pencatatan di `audit_logs`.
- [ ] **FR-035:** CRUD Kategori Pekerjaan Dinamis dan pengaturan parameter operasional (`app_configs`) di Web Admin yang langsung tercermin di aplikasi mobile.

---

## Milestone M3: Posting Job, Batas 5 Bid, Auto-Clear Saat Lock, & FCM Dasar
- [ ] **FR-010 & BR-16:** Form Posting Pekerjaan di `Beres User` (validasi pin lokasi $\le$ 2 km dari GPS HP User, pengambilan `area_label` Kelurahan/Kecamatan via OS Reverse Geocoding HP, dan fitur edit job selama masih `OPEN`).
- [ ] **FR-020 & FR-027:** Toggle `Online`/`Offline`, slider radius `0–50 km`, dan pengiriman Lokasi Dasar tukang saat aplikasi di foreground.
- [ ] **FR-022 & BR-15:** Job Portal di `Beres Mitra` (hanya menampilkan detail job & `area_label` kecamatan, batas melamar maksimal **5 job `OPEN` sekaligus**, serta fitur tarik lamaran *Withdraw Bid*).
- [ ] **FR-011, FR-012, & BR-17:** Daftar bid di `Beres User` (menampilkan nama, foto profil, keahlian, hari aktif, & rating tukang) dan aksi **Lock Tukang** yang secara atomik **menarik/menghapus seluruh lamaran aktif tukang tersebut di job lain (Job A, B, D, E otomatis `WITHDRAWN`)**.
- [ ] **FR-040 (Dasar):** Integrasi Firebase Cloud Messaging (FCM) dengan satu bunyi notifikasi standar yang seragam.

---

## Milestone M4: Ruang Chat, Nota Sah, Revisi Nota, & Timer 30 Menit
- [ ] **FR-013 & BR-70:** Ruang Chat *real-time* (teks & foto) beserta **Timer 30 Menit di tahap `NEGOTIATING`** (jika User atau Tukang tidak membalas $> 30$ menit, job otomatis dilepas kembali ke Job Portal `OPEN` + tombol Cancel ke portal, **tanpa Strike** bagi siapa pun).
- [ ] **FR-014, FR-023, & BR-05:** Pembuatan Nota di aplikasi Tukang dan persetujuan oleh User menjadi **Nota Sah yang terkunci (*immutable*)**.
- [ ] **FR-015 & BR-05:** Fitur **Revisi Nota** saat di lokasi (`ARRIVED`/`WORKING`) yang memunculkan **notifikasi jelas di ruang chat User (perbandingan Harga Nota Awal vs Harga Revisi Baru)** dan wajib menunggu klik *Approve* dari User.
- [ ] **BR-08:** Tombol **"Tarik / Batalkan Revisi Nota"** di aplikasi Tukang untuk membatalkan Revisi Nota yang belum dijawab User.
- [ ] **BR-31 (`T4a`):** **Timer 30 Menit Wajib Klik "Berangkat"** setelah `NOTA_APPROVED` (selama 30 menit User menunggu; jika lewat 30 menit Tukang tidak klik Berangkat $\rightarrow$ job otomatis dilepas kembali ke Job Portal `OPEN` dan **Tukang terkena +1 Strike**).

---

## Milestone M5: Eksekusi Kerja, Live GPS, Kedatangan 50m/200m, Penyelesaian, & Lapor Pembayaran
- [ ] **FR-016, FR-024, & FR-030:** Pengiriman Live GPS Tracking saat `ON_THE_WAY`, `ARRIVED`, dan `WORKING` yang tampil *real-time* di peta User dan **Live Map Web Admin**.
- [ ] **BR-60 & BR-61:** Deteksi status `ARRIVED` otomatis di server saat jarak **$\le$ 50 meter** (akurasi $\le$ 30 m) + tombol fallback manual **"Saya Sudah Tiba"** saat jarak **$\le$ 200 meter**, dilanjutkan tombol manual **"Mulai Bekerja"** (`WORKING`).
- [ ] **BR-65:** Penegakan larangan pembatalan oleh User maupun Tukang saat status `WORKING`.
- [ ] **FR-025 & BR-32:** Form Penyelesaian Tugas di aplikasi Tukang: unggah **Foto Bukti Hasil Kerja** ($\ge 1$), pilih **Metode Bayar Aktual** (`CASH`, `BANK_TRANSFER`, `E_WALLET`), centang **"User sudah membayar"**, dan unggah **Screenshot Bukti Bayar** bila metode aktual non-tunai.
- [ ] **BR-67 & FR-033:** Tombol khusus **"Laporkan Masalah Pembayaran (User Tidak Membayar / Kurang)"** di aplikasi Tukang $\rightarrow$ melepas ikatan job aktif tukang sementara $\rightarrow$ masuk Antrean Investigasi Prioritas di Web Admin $\rightarrow$ fitur **Suspend Permanen Langsung terhadap User yang terbukti bersalah tanpa toleransi 3x**.
- [ ] **FR-017 & FR-021:** Perhitungan otomatis kuota mingguan 5 job `COMPLETED` (berdasarkan zona waktu lokal tukang `BR-75`) serta form **Rating & Review** bagi User.

---

## Milestone M6: Alur Pembatalan, Aturan 3 Jam `ON_THE_WAY`, & Sistem Strike/Suspend 2 Hari
- [ ] **FR-026, FR-028, & BR-50 s/d BR-55:** Alur pembatalan oleh Tukang pada `NOTA_APPROVED`/`ON_THE_WAY`/`ARRIVED`: *slide-to-cancel* $\rightarrow$ dialog Ya/Tidak $\rightarrow$ halaman form pembatalan (`DRAFT` tidak mengubah tampilan User) $\rightarrow$ klik **Kirim** (`CANCEL_PENDING`, User hanya melihat alasan, Admin melihat semua field). Jika disetujui User $\rightarrow$ job dilepas kembali ke Job Portal (`OPEN`) dan **Tukang terkena +1 Strike**.
- [ ] **FR-018 & BR-56:** Aturan pembatalan oleh User:
  - Tidak ada tombol Cancel bagi User saat `ON_THE_WAY` $< 3$ jam dan saat `ARRIVED`.
  - Muncul tombol **Cancel** bagi User jika `ON_THE_WAY` sudah berlangsung **$\ge$ 3 jam** belum sampai (meminta persetujuan Tukang; otomatis disetujui + **1 Strike Tukang** jika Tukang tidak merespons dalam 30 menit).
- [ ] **BR-71:** Pencatatan **+1 Strike User** apabila saat Tukang sudah `ON_THE_WAY` atau `ARRIVED`, User tidak aktif / tidak membalas chat Tukang selama $> 30$ menit.
- [ ] **BR-57, BR-71, & FR-039:** Otomatisasi **Suspend 2 Hari Penuh (48 Jam)** ketika Strike Tukang atau Strike User mencapai **lebih dari 3x (Strike ke-4)** dalam 1 bulan kalender lokal, beserta panel pantauan Strike di Web Admin.

---

## Milestone M7: Admin Lengkap, Audit Log, & Halaman FAQ / Aturan Tertulis In-App
- [ ] **FR-031 & FR-036:** Panel Audit Lengkap di Web Admin (riwayat transisi 10 status, isi chat, versi Nota & Revisi, foto kerusakan, foto hasil kerja, bukti transfer, & `audit_logs`) serta Dashboard Analitik.
- [ ] **Lampiran C PRD:** Menampilkan halaman **FAQ & Aturan Tertulis Resmi** di dalam aplikasi `Beres User` dan `Beres Mitra (Tukang)` (mencakup aturan pembayaran langsung, kekuatan Nota Sah, Revisi Nota, batas 5 lamaran, serta aturan Strike & Suspend).

---

## Milestone M8: Hardening, Pengujian Konkurensi/Negatif, & Persiapan Rilis
- [ ] Penulisan & eksekusi **Test Negatif** dan **Test Konkurensi** sesuai Bagian 16 `PRD.md` (*Definition of Done*).
- [ ] Penyiapan dokumen Kebijakan Privasi (UU PDP), Syarat & Ketentuan, serta penjelasan izin *Background Location* untuk review Google Play Store dan Apple App Store.

---

## Phase 2 (Post-Launch — DILARANG Dikerjakan di MVP)
- [ ] Aktivasi fitur **Langganan Tukang Gold** (Radius 100 km, Kuota Unlimited, Gold Badge, Pin Teratas, Headstart 60 detik, & Toggle Manual Admin) beserta pembayaran otomatis via **DOKU**.
- [ ] Aktivasi fitur **Boost Pekerjaan oleh User** (Radius 100 km & Pin Teratas) via **DOKU**.
- [ ] Migrasi *Map Provider Adapter* dari OpenStreetMap ke **Google Maps Platform**.
