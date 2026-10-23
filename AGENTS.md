# AGENTS.md — Panduan & Aturan Utama AI Agent (Project: BERES v1.4.0)

Dokumen ini adalah pedoman operasional wajib bagi seluruh AI Coding Agent yang bekerja di repositori **Beres**. Sumber kebenaran utama (*Single Source of Truth*) untuk spesifikasi produk adalah **[`docs/PRD.md`](./docs/PRD.md) (Versi 1.4.0)**. Setiap baris kode, skema database, dan antarmuka pengguna **WAJIB** mematuhi aturan di bawah ini tanpa terkecuali.

---

## 1. Gambaran Umum Proyek & Struktur Monorepo
**Beres** adalah platform marketplace jasa pertukangan *on-demand* di Indonesia yang terdiri dari 3 aplikasi:
1. **`mobile/user` (Flutter):** Aplikasi pelanggan untuk memposting pekerjaan, melihat tukang yang melakukan *bid*, melakukan *lock* 1 tukang, berdiskusi & menyetujui **Nota Digital** (serta Revisi Nota) di ruang chat, memantau lokasi GPS tukang, dan memberi rating.
2. **`mobile/tukang` (Flutter):** Aplikasi mitra tukang untuk menerima pekerjaan sesuai kategori keahlian & radius (0–50 km), melamar (*bid* maks 5 job sekaligus), membuat **Nota & Revisi Nota**, mengirim lokasi GPS *real-time* saat bertugas, dan mengunggah foto bukti hasil kerja + bukti pembayaran.
3. **`web/admin` (Next.js + Tailwind + shadcn/ui):** Dashboard operasional Admin (dilengkapi **MFA**) untuk verifikasi KTP tukang (KYC), memantau Live Map GPS tukang, memantau 10 status pekerjaan, mengaudit chat/nota/foto, menginvestigasi laporan masalah pembayaran, mengelola kategori dinamis, serta mengelola parameter sistem (`app_configs`).

```text
/Users/mhmmddhimas/project/beres/
├── .github/
│   ├── workflows/ci.yml       # Pipeline GitHub Actions CI (PostGIS, Flutter, Next.js)
│   └── pull_request_template.md # Checklist wajib PR sesuai DoD PRD v1.4.0
├── .gitignore                 # Ignore file rahasia (.env), build Flutter, & Next.js
├── .env.example               # Template variabel environment
├── AGENTS.md                  # Instruksi & aturan wajib untuk AI Agent (File ini)
├── detail.md                  # Penjelasan menyeluruh ekosistem Beres
├── docs/
│   ├── PRD.md                 # Spesifikasi produk v1.4.0 (Source of Truth Utama)
│   ├── ARCHITECTURE.md        # Arsitektur teknis, Supabase, shared package, & Map Adapter
│   ├── DATABASE_SCHEMA.md     # Rancangan tabel PostgreSQL + PostGIS, Trigger, & RLS (v1.4.0)
│   ├── ROADMAP.md             # Checklist tahapan pengerjaan (Milestone M0 - M8 & Phase 2)
│   ├── E2E_TESTING.md         # Strategi, simulasi timer/GPS, & skenario pengujian E2E (E2E-01 s/d E2E-09)
│   └── GIT_AND_CICD.md        # Aturan branching, format commit (FR/BR ID), PR, & CI/CD
├── mobile/
│   ├── shared/                # Flutter Local Package (beres_shared) untuk User & Tukang
│   ├── user/                  # Aplikasi Flutter Beres User
│   └── tukang/                # Aplikasi Flutter Beres Mitra (Tukang)
├── web/
│   └── admin/                 # Aplikasi Web Admin (Next.js + Tailwind + shadcn/ui)
└── supabase/
    └── migrations/            # File SQL migrasi PostgreSQL + PostGIS
```

---

## 2. Aturan Disiplin AI Coding Agent (Wajib Dipatuhi)
1. **DILARANG Menambah Fitur di Luar PRD v1.4.0:** Fitur pada Bagian 3.2 (*Non-Goals*) dan Lampiran A (*Phase 2: Gold, Toggle Manual Gold, Boost 100 km, DOKU*) **DILARANG** diimplementasikan pada UI maupun logika MVP. Kolom *Hook Phase 2* di database boleh disiapkan tetapi tidak boleh dipakai di MVP.
2. **Satu Milestone per Sesi:** Kerjakan berurutan sesuai [`docs/ROADMAP.md`](./docs/ROADMAP.md) (M0 s/d M8). Jangan melompat ke milestone berikutnya sebelum *Definition of Done* terpenuhi.
3. **Penegakan di Server/Database:** Seluruh **Business Rules (`BR-xx`)** wajib ditegakkan di sisi database/server (PostgreSQL Trigger, fungsi RPC atomik, Constraint, dan RLS), **bukan hanya di UI klien**.
4. **Jangan Menebak:** Jika menemukan kasus tepi yang ambigu, berhenti dan tanyakan kepada Owner.

---

## 3. Aturan Bisnis Mutlak (Golden Rules v1.4.0 — DILARANG DILANGGAR)

### A. Pembayaran Langsung (Zero In-App Wallet) & Keabsahan Nota (`BR-01` s/d `BR-08`)
* **Tanpa Dompet Digital / Escrow:** Pembayaran jasa dilakukan 100% langsung dari User ke Tukang (`BANK_TRANSFER`, `E_WALLET`, atau `CASH`). Tidak ada komisi per order.
* **Nota Hanya Dibuat oleh Tukang:** Aplikasi User tidak memiliki menu pembuatan Nota.
* **Nota Sah Terkunci (*Immutable*):** Begitu Nota awal disetujui User (`APPROVED`), terbentuk **Nota Sah** yang tidak bisa diedit sepihak oleh Tukang.
* **Revisi Nota Wajib Persetujuan User:** Jika saat `ARRIVED` atau `WORKING` terdapat tambahan biaya, Tukang wajib mengirim **Revisi Nota**. Aplikasi User **wajib menampilkan notifikasi jelas di chat yang membandingkan Harga Nota Awal vs Harga Revisi Baru**, dan perubahan harga tersebut **hanya sah jika User menekan tombol *Approve***.
* **Tarik Revisi Nota:** Tukang dapat menarik kembali (*cancel*) Revisi Nota yang masih berstatus `SENT` (belum dijawab User) menjadi `SUPERSEDED` agar Nota Sah sebelumnya tetap berlaku dan tidak memblokir penyelesaian kerja.

### B. Akun, 1 Email 2 Peran (USER & TUKANG), & Privasi Sebelum Lock (`BR-16`, `BR-44`, `BR-45`)
* **1 Email = 2 Peran (`BR-44`):** Satu alamat email DIPERBOLEHKAN terdaftar sekaligus sebagai `USER` (Pelanggan) dan `TUKANG` (Mitra Tukang), dengan nilai role di database menjadi `BOTH`. Data pesanan pelanggan (`jobs.user_id`) dan data pekerjaan tukang (`job_bids.tukang_id` & `tukang_profiles`) terpisah secara alami di masing-masing aplikasi. Aturan mutlak: Akun dilarang melamar pekerjaannya sendiri (`jobs.user_id != auth.uid()`).
* **Login & Keamanan:** User & Tukang dapat login menggunakan **Email + Password**, **Email OTP 6 digit**, maupun **Google OAuth** (setelah provider diaktifkan). Web Admin wajib menggunakan **Email + Password + MFA (OTP 2 Langkah)**.
* **Fitur Hapus Akun (`BR-45`):** Tersedia di aplikasi User & Tukang (selama tidak ada job berjalan atau sengketa aktif) demi kepatuhan UU PDP & syarat App Store/Play Store.
* **Pin Lokasi & Reverse Geocoding HP (`FR-010`):** Pin lokasi job boleh digeser maksimal **2 km** dari titik GPS HP User saat posting. Nama Kelurahan/Kecamatan (`area_label`) diambil menggunakan geocoder bawaan OS HP User (Rp 0, bebas limit server).
* **Privasi Sebelum Lock (`BR-16`):** Sebelum di-*lock*, Tukang HANYA melihat detail pekerjaan & nama Kelurahan/Kecamatan (`area_label`), tanpa melihat nama/foto/alamat lengkap User. Sebaliknya, pada daftar bid, User HANYA melihat foto profil, nama, keahlian, hari aktif, dan rating/ulasan tukang.

### C. Batas Lamar Maksimal 5 Job & Auto-Clear Saat Di-Lock (`BR-15`, `BR-17`)
* Tukang dapat melamar (*bid*) maksimal **5 pekerjaan terbuka (`OPEN`)** sekaligus (misal Job A, B, C, D, E).
* **Auto-Clear Saat Lock (`BR-17`):** Begitu Tukang di-*lock* oleh User pada satu pekerjaan (misal Job C), maka **seluruh lamaran aktif Tukang tersebut di pekerjaan lain (Job A, B, D, E) OTOMATIS ditarik (`WITHDRAWN`) dan hilang dari daftar lamaran aktif tukang**.
* Dengan aturan ini, 1 Tukang dijamin hanya menangani **tepat 1 pekerjaan** sejak tahap `NEGOTIATING` hingga selesai. Jika Job C nantinya batal, Tukang mulai melamar lagi dari awal di Job Portal.

### D. State Machine (10 Status) & Timer Operasional (`BR-31`, `BR-50` s/d `BR-71`)
10 Status Pekerjaan: `OPEN`, `NEGOTIATING`, `NOTA_APPROVED`, `ON_THE_WAY`, `ARRIVED`, `WORKING`, `COMPLETED`, `CANCELLED`, `EXPIRED`, `CANCEL_PENDING`.

1. **Tahap `NEGOTIATING` (Timer Chat 30 Menit — Tanpa Strike, `BR-70`):**
   * Jika User chat duluan dan Tukang tidak membalas > 30 menit, **ATAU** jika Tukang chat/kirim Nota duluan dan User tidak membalas > 30 menit $\rightarrow$ Job otomatis dilepas kembali ke Job Portal (`OPEN`) + masing-masing pihak punya tombol Cancel untuk melepas job ke portal. **TIDAK ADA STRIKE** untuk User maupun Tukang.
2. **Tahap `NOTA_APPROVED` (Timer 30 Menit Wajib Klik "Berangkat", `BR-31`):**
   * Setelah Nota disetujui, Tukang wajib menekan tombol **"Berangkat ke Lokasi"** dalam waktu maksimal **30 menit** (selama 30 menit ini User menunggu dan tidak bisa cancel sepihak).
   * Jika dalam 30 menit Tukang tidak klik Berangkat $\rightarrow$ Job otomatis dilepas kembali ke Job Portal (`OPEN`), User & Tukang diberi notifikasi, dan **Tukang terkena +1 Strike Tukang**.
3. **Tahap `ON_THE_WAY` & Deteksi Sampai `ARRIVED` (`BR-56`, `BR-60`, `BR-61`):**
   * Status berubah otomatis menjadi `ARRIVED` saat jarak GPS tukang ke titik job **$\le$ 50 meter** (akurasi $\le$ 30 m), ditambah tombol fallback manual **"Saya Sudah Tiba"** pada jarak **$\le$ 200 meter**.
   * Selama `ON_THE_WAY` di **bawah 3 jam** dan saat `ARRIVED`, **User TIDAK memiliki tombol Cancel sepihak**.
   * Jika `ON_THE_WAY` sudah berlangsung **$\ge$ 3 jam** dan tukang belum sampai, di aplikasi User muncul tombol **Cancel** (meminta persetujuan Tukang; jika Tukang tidak merespons dalam 30 menit maka **Auto-Cancel** dan **Tukang terkena +1 Strike Tukang**).
4. **Pembatalan oleh Tukang (`NOTA_APPROVED`, `ON_THE_WAY`, `ARRIVED` — `BR-50` s/d `BR-55`):**
   * Melalui tombol geser (*slide-to-cancel*) $\rightarrow$ dialog Ya/Tidak $\rightarrow$ halaman form pembatalan (`DRAFT`). Selama masih `DRAFT` (belum klik Kirim), **tampilan di aplikasi User tidak boleh berubah**.
   * Saat klik **Kirim** (`SUBMITTED`), status menjadi `CANCEL_PENDING`. Admin menerima seluruh field, sedangkan **User HANYA menerima alasan pembatalan**.
   * Jika User menyetujui, job dilepas kembali ke Job Portal (`OPEN`) dan **Tukang terkena +1 Strike Tukang**.
5. **Tahap `WORKING` (Dilarang Batal, `BR-65`):**
   * Baik User maupun Tukang **TIDAK DAPAT membatalkan pekerjaan** pada status `WORKING`. Tukang wajib menyelesaikan pekerjaan.

### E. Penyelesaian, Masalah Pembayaran, & Sistem Strike/Suspend (`BR-32`, `BR-57`, `BR-67`, `BR-71`)
1. **Syarat Wajib Sebelum `COMPLETED` (`BR-32`):**
   * Tombol **"Selesaikan Tugas"** wajib terkunci (*disabled* & ditolak server) sebelum Tukang: (a) mengunggah $\ge$ 1 **Foto Hasil Kerja**, (b) memilih **Metode Bayar Aktual**, (c) mencentang **"User sudah membayar"**, (d) mengunggah **Screenshot Bukti Bayar** bila metode aktual adalah `BANK_TRANSFER`/`E_WALLET` (bila `CASH`, opsi unggah tidak tampil), dan (e) tidak ada Revisi Nota berstatus `SENT`.
2. **Kasus User Tidak Mau Bayar / Bayar Kurang (`BR-67`):**
   * Tukang menekan tombol khusus **"Laporkan Masalah Pembayaran"** $\rightarrow$ masuk antrean prioritas Admin (ikatan job aktif tukang dilepas sementara agar tukang bisa cari kerja lain) $\rightarrow$ Admin menginvestigasi bukti Chat, Nota Sah, dan Foto Hasil Kerja.
   * Jika User terbukti bersalah, **Admin langsung men-suspend permanen akun User tersebut TANPA pemakluman 3x** (pengajuan banding hanya melalui Email Resmi Admin/Perusahaan).
3. **Aturan Strike Tukang & Strike User (Maks 3x, Lebih dari 3x = Suspend Otomatis 2 Hari):**
   * **Strike Tukang (`BR-57`):** Didapat jika (1) tidak klik Berangkat dalam 30 menit setelah `NOTA_APPROVED`, (2) melakukan cancel saat `NOTA_APPROVED`/`ON_THE_WAY`/`ARRIVED` yang disetujui, atau (3) `ON_THE_WAY` $\ge$ 3 jam di-cancel User tanpa respons 30 menit.
   * **Strike User (`BR-71`):** Didapat jika pada saat Tukang sudah `ON_THE_WAY` atau `ARRIVED`, **User off / tidak aktif / tidak membalas chat Tukang selama > 30 menit**.
   * **Sanksi Otomatis:** Maksimal toleransi adalah **3x Strike** dalam 1 bulan kalender (zona waktu lokal `WIB`/`WITA`/`WIT`). Pada **Strike ke-4 (> 3x)**, akun (Tukang maupun User) **otomatis ter-suspend selama 2 hari penuh (48 jam)**.
4. **Kuota Mingguan Tukang (`BR-21`):**
   * Maksimal **5 pekerjaan `COMPLETED` per minggu** (Senin 00:00 s/d Minggu 23:59 zona waktu lokal tukang), dihitung langsung dari `jobs.completed_at` tanpa kolom counter/cron.
