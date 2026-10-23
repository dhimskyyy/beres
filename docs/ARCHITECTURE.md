# Arsitektur Teknis & Standar Kode — Project "Beres" (v1.4.0)

Dokumen ini menjelaskan struktur monorepo, arsitektur **Supabase-Only Backend (`D-15`)**, pembagian modul di `mobile/shared`, pola *Map Provider Adapter* (OpenStreetMap $\rightarrow$ Google Maps), mekanisme timer terjadwal (`pg_cron` / Edge Functions), serta pemisahan data privasi sesuai **[`docs/PRD.md`](./PRD.md) (Versi 1.4.0)**.

---

## 1. Struktur Monorepo & Workspace

```text
/Users/mhmmddhimas/project/beres/
├── AGENTS.md                       # Instruksi & aturan mutlak AI Agent (v1.4.0)
├── detail.md                       # Penjelasan menyeluruh ekosistem Beres
├── docs/
│   ├── PRD.md                      # Spesifikasi kebutuhan produk v1.4.0
│   ├── ARCHITECTURE.md             # Arsitektur teknis (File ini)
│   ├── DATABASE_SCHEMA.md          # Skema PostgreSQL + PostGIS (v1.4.0)
│   └── ROADMAP.md                  # Checklist tahapan pembangunan (M0 s/d M8 & Phase 2)
├── mobile/
│   ├── shared/                     # Paket Flutter bersama (beres_shared)
│   │   ├── lib/
│   │   │   ├── models/             # Model Data (Profile, TukangProfile, Job, Bid, Nota, Chat, Strike, Report)
│   │   │   ├── services/           # Supabase Client, Auth OTP, Realtime, Storage, OS Geocoder
│   │   │   ├── map_adapter/        # Abstraksi Peta (OSM/flutter_map -> Google Maps Phase 2)
│   │   │   ├── widgets/            # Komponen UI bersama (ChatRoom, NotaCard, RevisionAlertCard, FaqView)
│   │   │   └── utils/              # Format Rupiah integer, Zona Waktu Lokal (WIB/WITA/WIT), Tema UI
│   │   └── pubspec.yaml
│   ├── user/                       # Aplikasi Flutter "Beres User"
│   │   ├── lib/
│   │   │   ├── features/
│   │   │   │   ├── auth/           # Login Email OTP (Validasi 1 Email = 1 Peran) & Hapus Akun
│   │   │   │   ├── home/           # Katalog kategori dinamis & riwayat pekerjaan
│   │   │   │   ├── create_job/     # Form keluhan, pin peta <= 2km GPS HP, & OS Reverse Geocoding
│   │   │   │   ├── bids/           # Daftar tukang nge-bid (nama, foto, keahlian, hari aktif, rating) & Lock
│   │   │   │   ├── chat_nota/      # Ruang chat, Approve Nota Sah, & Notifikasi Perbandingan Revisi Nota
│   │   │   │   └── tracking/       # Live GPS map, Tombol Cancel >= 3 Jam OTW, Persetujuan Batal, & Rating
│   │   └── pubspec.yaml            # Mengimpor ../shared
│   └── tukang/                     # Aplikasi Flutter "Beres Mitra (Tukang)"
│       ├── lib/
│       │   ├── features/
│       │   │   ├── auth_kyc/       # Login Email OTP, Biodata, Rekening/E-Wallet, Upload KTP & Selfie
│       │   │   ├── job_portal/     # Bursa kerja (maks 50km, tampil area_label) & Lamar (Maks 5 Bid Aktif)
│       │   │   ├── settings/       # Slider Radius (0-50km), Indikator Kuota 5x/Minggu, Info Strike, Hapus Akun
│       │   │   ├── chat_nota/      # Ruang chat, Form Buat Nota Sah, Form Revisi Nota, & Tarik Revisi Nota
│       │   │   └── active_job/     # Timer 30m Berangkat, Auto/Manual Arrived (50m/200m), Slide-to-Cancel,
│       │   │                       # Form Penyelesaian (Foto Kerja, Metode Bayar Aktual, Bukti Transfer),
│       │   │                       # & Tombol Khusus "Laporkan Masalah Pembayaran"
│       └── pubspec.yaml            # Mengimpor ../shared
├── web/
│   └── admin/                      # Dashboard Web Admin (Next.js App Router + Tailwind + shadcn/ui)
│       ├── src/
│       │   ├── app/
│       │   │   ├── auth/           # Login Admin dengan Wajib MFA (Email + Password + OTP 2 Langkah)
│       │   │   ├── live-map/       # Peta monitoring real-time seluruh tukang (ON_THE_WAY, ARRIVED, WORKING)
│       │   │   ├── jobs/           # Tabel 10 status + Audit Chat, Nota/Revisi, Foto Kerusakan, Hasil & Bukti Bayar
│       │   │   ├── payment-reports/# Antrean Prioritas Laporan Masalah Pembayaran (Vonis & Suspend Langsung User)
│       │   │   ├── cancel-queue/   # Antrean Permintaan Pembatalan Tukang & Pantauan Strike User/Tukang
│       │   │   ├── kyc/            # Verifikasi KTP & Selfie Tukang baru (Signed URL Privat)
│       │   │   ├── categories/     # CRUD kategori pekerjaan dinamis & konfigurasi parameter (app_configs)
│       │   │   └── accounts/       # Manajemen Akun User & Tukang, Suspend Permanen, & Pencabutan Suspend 2 Hari
└── supabase/
    └── migrations/                 # Skema SQL PostgreSQL + PostGIS, Fungsi RPC Atomik, Trigger, & RLS
```

---

## 2. Arsitektur Backend: Full Supabase (`D-15`)

Sesuai keputusan `D-15`, MVP menggunakan **Supabase secara penuh** tanpa server Node.js terpisah:
1. **Supabase Auth + Custom SMTP (Resend):**
   * Menangani pengiriman kode OTP 6 digit ke email User dan Tukang (`FR-001`).
   * Mendukung aturan **1 Email = 2 Peran (`BR-44`)** di mana 1 email dapat digunakan di aplikasi User dan Tukang (role `BOTH`) dengan data pesanan dan pekerjaan terisolasi aman.
   * Menegakkan **MFA (Multi-Factor Authentication)** wajib untuk akun berperan `ADMIN` (`FR-037`).
2. **PostgreSQL + PostGIS + Fungsi RPC Atomik (`NFR-18`):**
   * Seluruh transisi status kritis dijalankan melalui fungsi PostgreSQL (`SECURITY DEFINER` dengan validasi peran) di dalam transaksi atomik:
     * `rpc_submit_bid`: Memastikan tukang belum memiliki 5 bid `ACTIVE` (`BR-15`) dan kuota selesai minggu ini $< 5$ (`BR-23`).
     * `rpc_lock_tukang`: Mengunci 1 tukang pada job yang dipilih sekaligus **otomatis menarik (`WITHDRAWN`) seluruh bid aktif tukang tersebut di job lain (`BR-17`)**.
     * `rpc_approve_nota` & `rpc_submit_nota_revision`: Menjamin Nota yang sudah `APPROVED` bersifat *immutable* (`BR-05`) dan menyisipkan pesan peringatan perbandingan harga lama vs baru ke ruang chat.
     * `rpc_withdraw_nota_revision`: Mengizinkan tukang menarik kembali Revisi Nota yang masih `SENT` (`BR-08`).
     * `rpc_complete_job`: Memvalidasi foto hasil kerja, metode bayar aktual, centang pembayaran, dan bukti transfer bila metode aktual non-tunai (`BR-32`).
     * `rpc_report_payment_default`: Membuat laporan prioritas masalah pembayaran (`BR-67`) dan melepas ikatan job aktif tukang sementara.
3. **Mekanisme Timer Terjadwal (`pg_cron` & Edge Functions — `NFR-21`):**
   * Menjalankan pemeriksaan berkala setiap menit dengan membaca parameter dari tabel `app_configs`:
     * **Timer 30 Menit Chat di `NEGOTIATING` (`BR-70`):** Jika salah satu pihak tidak membalas $> 30$ menit, job dilepas kembali ke `OPEN` **tanpa Strike** bagi siapa pun.
     * **Timer 30 Menit Klik "Berangkat" di `NOTA_APPROVED` (`BR-31`, `T4a`):** Jika tukang tidak klik Berangkat dalam 30 menit, job otomatis dilepas kembali ke `OPEN` dan mencatat **+1 Strike Tukang** (`NO_DEPART_30M`).
     * **Timer 30 Menit Respons Chat User saat `ON_THE_WAY` / `ARRIVED` (`BR-71`):** Jika tukang mengirim chat saat sudah di jalan/sampai dan User tidak aktif/membalas $> 30$ menit, mencatat **+1 Strike User** (`USER_UNRESPONSIVE_OTW_ARRIVED`).
     * **Timer 30 Menit Auto-Cancel pada `ON_THE_WAY` $\ge$ 3 Jam (`BR-56b`):** Jika User menekan Cancel setelah 3 jam `ON_THE_WAY` dan tukang tidak merespons dalam 30 menit, otomatis menyetujui pembatalan dan mencatat **+1 Strike Tukang** (`OTW_3H_UNRESPONSIVE`).
     * **Timer 10 Menit `DRAFT` Pembatalan (`BR-52`) & 24 Jam Expiry `OPEN` (`T11`).**
4. **Supabase Storage (3 Bucket Terpisah — Bagian 13 PRD):**
   * `job-photos`: Foto kerusakan awal & foto hasil kerja.
   * `kyc-private` (**Privat**): Foto KTP & Selfie tukang, diakses hanya via *Signed URL* berumur pendek.
   * `proof-photos` (**Privat**): Screenshot bukti transfer pembayaran non-tunai & foto bukti form pembatalan internal Admin.

---

## 3. Strategi Geospasial, Reverse Geocoding HP, & Deteksi Sampai (`50m` / `200m`)

1. **Reverse Geocoding Gratis via OS Perangkat (`FR-010`, `NFR-03`):**
   * Saat User menggeser pin lokasi pekerjaan di peta (dibatasi maksimal **2 km** dari titik GPS HP User), aplikasi `mobile/user` memanggil geocoder bawaan Android/iOS untuk mendapatkan nama **Kelurahan & Kecamatan** (`area_label`).
   * Sebelum tukang di-*lock*, Job Portal hanya menampilkan `area_label` dan jarak perkiraan (`BR-16`). Alamat lengkap (`address_full`) dan koordinat presisi hanya dikirim oleh server kepada 1 tukang yang sedang di-*lock*.
2. **Deteksi Kedatangan `ARRIVED` di Server (`BR-60`, `BR-61`, `NFR-22`):**
   * Selama `ON_THE_WAY`, aplikasi `mobile/tukang` mengirim koordinat Live GPS.
   * Jika jarak PostGIS ke titik job **$\le$ 50 meter** (dengan akurasi GPS $\le$ 30 m), server otomatis mengubah status job menjadi `ARRIVED` (`arrival_mode = 'AUTO'`).
   * Jika tukang berada di jarak **$\le$ 200 meter**, tombol fallback manual **"Saya Sudah Tiba"** aktif di aplikasi Tukang (`arrival_mode = 'MANUAL'`).
3. **Map Provider Adapter (`NFR-15`):**
   * Seluruh tampilan peta di `mobile/shared` dan `web/admin` dibungkus dalam abstraksi `BeresMapView` yang menggunakan **OpenStreetMap (`flutter_map` / `MapLibre`)** di MVP dan siap diganti ke **Google Maps Platform** di Phase 2 hanya dengan mengubah 1 file adapter.
