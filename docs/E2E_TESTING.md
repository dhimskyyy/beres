# Strategi & Panduan Pengujian End-to-End (E2E Testing) — Project "Beres" (v1.4.0)

Dokumen ini (`docs/E2E_TESTING.md`) mendefinisikan strategi, peralatan (*tooling*), teknik simulasi waktu/GPS, serta skenario pengujian **End-to-End (E2E)**, **Test Negatif**, dan **Test Konkurensi** yang wajib dijalankan untuk memvalidasi seluruh aturan di **[`docs/PRD.md`](./PRD.md) (v1.4.0)**.

---

## 1. Mengapa Strategi E2E Beres Harus Khusus?

Aplikasi **Beres** memiliki 3 tantangan pengujian yang tidak bisa diselesaikan dengan *unit test* biasa:
1. **Interaksi Lintas 3 Aplikasi (Multi-Actor):** Satu pekerjaan melibatkan aksi bergantian antara **User** (`mobile/user`), **Tukang** (`mobile/tukang`), dan **Admin** (`web/admin`).
2. **Aturan Berbasis Waktu (Timer 30 Menit & 3 Jam):** Kita tidak mungkin menunggu 30 menit atau 3 jam sungguhan saat menjalankan *automated test*.
3. **Aturan Berbasis Geospasial (Radius 50 km, Pin 2 km, & Auto-Arrived $\le$ 50 m):** Pengujian membutuhkan injeksi titik koordinat GPS simulasi.

---

## 2. Peralatan Pengujian (Testing Stack)

| Lapisan Pengujian | Tool yang Digunakan | Alasan Pemilihan |
| :--- | :--- | :--- |
| **1. Database, Trigger, Negatif & Konkurensi (`BR-xx`)** | **Vitest / Jest + Supabase Local Client** (atau `pgTAP`) | Menguji langsung fungsi RPC PostgreSQL + PostGIS, RLS, *race condition* (permintaan paralel), dan *test negatif* (menembak API langsung tanpa lewat UI) dalam hitungan detik. |
| **2. E2E Mobile (`mobile/user` & `mobile/tukang`)** | **Patrol** (di atas Flutter `integration_test`) | Berbeda dengan `integration_test` standar Flutter yang macet saat muncul pop-up izin OS, **Patrol** dapat menekan tombol *"Izinkan Lokasi GPS"* dan *"Izinkan Kamera"* asli di Android/iOS serta mensimulasikan koordinat lokasi. |
| **3. E2E Web Admin (`web/admin`)** | **Playwright** | Standar industri tercepat untuk menguji Next.js: login MFA Admin, klik *Approve* KYC KTP, memantau marker Live Map, dan memvonis laporan pembayaran. |

---

## 3. Teknik Simulasi "Time-Travel" & "Mock GPS" (Tanpa Menunggu 30 Menit / 3 Jam)

Agar pengujian timer (`30 menit` chat, `30 menit` klik berangkat, `3 jam` on-the-way, `24 jam` expired) dapat diuji dalam **< 5 detik** saat E2E test:

### A. Simulasi Waktu (Time-Travel via Tabel `app_configs` atau Geser Timestamp)
* Seluruh fungsi terjadwal membaca batas waktu dari tabel `app_configs` dan membandingkannya dengan kolom timestamp di tabel `jobs` (`nota_approved_at`, `on_the_way_at`, `last_chat_at`).
* Saat menjalankan E2E Test di *environment local/test*, skrip test cukup menjalankan helper khusus:
  ```sql
  -- Contoh simulasi: memundurkan waktu nota_approved_at sejauh 31 menit ke belakang
  UPDATE jobs SET nota_approved_at = NOW() - INTERVAL '31 minutes' WHERE id = '<job_id>';
  -- Lalu panggil fungsi cron pemeriksa timer secara langsung:
  SELECT fn_process_scheduled_timeouts();
  ```
* Dengan cara ini, aturan **30 menit** dan **3 jam** teruji **100% akurat di kode produksi yang sama** dalam waktu kurang dari 1 detik!

### B. Simulasi Pergerakan GPS Tukang (`ON_THE_WAY` $\rightarrow$ `ARRIVED` $\le$ 50 m)
* Skrip E2E mengirimkan urutan titik koordinat dari lokasi awal Tukang menuju titik koordinat `jobs.location`:
  1. **Ping 1 (Jarak 1.200 m):** Status tetap `ON_THE_WAY`, tombol "Mulai Bekerja" & "Saya Sudah Tiba" terkunci.
  2. **Ping 2 (Jarak 150 m, Akurasi 15 m):** Status masih `ON_THE_WAY`, namun tombol fallback manual **"Saya Sudah Tiba"** ($\le$ 200 m, `BR-61`) menjadi aktif.
  3. **Ping 3 (Jarak 25 m, Akurasi 10 m):** Server otomatis mengubah status job menjadi **`ARRIVED`** (`arrival_mode = 'AUTO'`, `BR-60`) dan mengirim notifikasi ke User.

---

## 4. Daftar Skenario E2E Wajib (Master Test Scenarios v1.4.0)

Setiap skenario di bawah ini wajib memiliki file test otomatis sebelum masuk tahap rilis (**Milestone M8**):

### 🟢 E2E-01: Alur Sukses Penuh (Happy Path: Posting $\rightarrow$ Bid $\rightarrow$ Lock $\rightarrow$ Nota Sah $\rightarrow$ Kerja $\rightarrow$ Selesai & Rating)
1. **User** login via Email OTP $\rightarrow$ memposting pekerjaan Listrik (pin lokasi $\le$ 2 km dari GPS HP, `area_label` kecamatan terisi otomatis).
2. **Tukang** (yang sudah `KYC = APPROVED` & `Online` dalam radius $\le$ 50 km) melihat job di Job Portal (hanya melihat `area_label` kecamatan, alamat lengkap masih tersembunyi `BR-16`) $\rightarrow$ klik **Bid**.
3. **User** melihat profil Tukang (nama, foto, keahlian, hari aktif, rating) $\rightarrow$ klik **Lock Tukang** (`NEGOTIATING`).
4. **Tukang** melihat alamat lengkap User terbuka $\rightarrow$ berdiskusi di Chat $\rightarrow$ membuat **Nota Awal Rp 100.000** (metode: `BANK_TRANSFER`).
5. **User** menekan **Approve Nota** $\rightarrow$ terbentuk **Nota Sah**, status menjadi `NOTA_APPROVED`, timer 30 menit berangkat berjalan.
6. **Tukang** menekan **"Berangkat ke Lokasi"** (`ON_THE_WAY`) $\rightarrow$ mengirim ping GPS hingga jarak $\le$ 50 m $\rightarrow$ status otomatis berubah menjadi **`ARRIVED`**.
7. **Tukang** menekan **"Mulai Bekerja"** (`WORKING`).
8. **Tukang** mengisi Form Penyelesaian: unggah 1 Foto Hasil Kerja + pilih metode bayar aktual `BANK_TRANSFER` + centang *"User sudah membayar"* + unggah 1 Screenshot Bukti Transfer $\rightarrow$ menekan **"Selesaikan Tugas"** (`COMPLETED`).
9. **Verifikasi Akhir:** Kuota selesai mingguan Tukang bertambah `+1` (`BR-21`), Live GPS berhenti, dan **User** berhasil mengirim Rating bintang 5.

---

### 🟢 E2E-02: Aturan Lamar Maks 5 Job & Auto-Clear Saat Di-Lock (`BR-15` & `BR-17`)
1. Tersedia 6 pekerjaan terbuka (`OPEN`): **Job A, B, C, D, E, dan F**.
2. **Tukang** melamar **Job A, B, C, D, dan E** (5 bid `ACTIVE` berhasil).
3. **Tukang** mencoba melamar **Job F** (ke-6) $\rightarrow$ **Ditolak server** (`BR-15`).
4. Pemilik **Job C** melakukan **Lock** terhadap Tukang tersebut.
5. **Verifikasi Atomik:**
   * Status Job C menjadi `NEGOTIATING`.
   * Status bid Tukang pada **Job A, B, D, dan E otomatis berubah menjadi `WITHDRAWN`** dan hilang dari daftar lamaran aktif Tukang (`BR-17`).
6. Jika kemudian negosiasi di Job C dibatalkan (kembali ke `OPEN`), daftar lamaran aktif Tukang menjadi `0` dan Tukang harus melamar ulang dari awal.

---

### 🟢 E2E-03: Keabsahan Nota, Revisi Nota Anti-Getok Harga, & Tarik Revisi (`BR-05` & `BR-08`)
1. Pada status `NOTA_APPROVED` dengan **Nota Sah Rp 100.000**, **Tukang** mencoba memanggil API edit langsung nominal Nota menjadi Rp 150.000 $\rightarrow$ **Ditolak server** (*immutable*, `BR-05`).
2. Saat status `WORKING`, **Tukang** mengajukan **Revisi Nota #1** menjadi **Rp 150.000**.
3. **Verifikasi di Layar User:** Muncul pesan khusus di chat yang menampilkan perbandingan jelas: **Harga Awal Rp 100.000 $\rightarrow$ Pengajuan Harga Baru Rp 150.000**. Sebelum di-Approve User, nilai `jobs.agreed_total` tetap **Rp 100.000**.
4. Saat Revisi Nota #1 masih berstatus `SENT` (belum dijawab User), **Tukang** mencoba menekan "Selesaikan Tugas" $\rightarrow$ **Ditolak server** karena masih ada revisi menggantung.
5. **Tukang** menekan tombol **"Tarik / Batalkan Revisi Nota"** (`BR-08`) $\rightarrow$ status Revisi Nota #1 menjadi `SUPERSEDED`, harga sah tetap Rp 100.000, dan Tukang kini dapat menyelesaikan tugas.
6. *(Cabang kedua)* Jika Tukang mengirim Revisi Nota #2 Rp 150.000 dan **User menekan Approve**, barulah `jobs.agreed_total` resmi berubah menjadi **Rp 150.000**.

---

### 🟢 E2E-04: Timer 30 Menit Chat di `NEGOTIATING` — Lepas ke Portal Tanpa Strike (`BR-70`)
1. **Kasus A (User Chat Duluan):** User me-*lock* Tukang dan mengirim pesan chat. Waktu dimajukan 31 menit tanpa balasan Tukang $\rightarrow$ Job otomatis kembali ke `OPEN` di Job Portal, dan **jumlah Strike Tukang tetap `0` (Tidak Kena Strike)**.
2. **Kasus B (Tukang Chat Duluan):** Tukang mengirim pesan/Nota duluan. Waktu dimajukan 31 menit tanpa balasan User $\rightarrow$ Job otomatis kembali ke `OPEN` (melanjutkan sisa waktu 24 jam tanpa reset), dan **jumlah Strike User tetap `0` (Tidak Kena Strike)**.

---

### 🟢 E2E-05: Timer 30 Menit Wajib Klik "Berangkat" & Akumulasi Strike Tukang (`BR-31` & `BR-57`)
1. User menyetujui Nota (`NOTA_APPROVED`).
2. Selama 30 menit pertama, User mencoba membatalkan sepihak $\rightarrow$ **Tombol tidak ada & API menolak**.
3. Waktu dimajukan 31 menit tanpa Tukang menekan tombol "Berangkat":
   * Job otomatis kembali menjadi `OPEN` di Job Portal (`T4a`).
   * User menerima notif *"Tukang tidak aktif dalam beberapa menit, silakan cari tukang yang lain"*.
   * Tukang menerima notif *"Job tidak dapat diselesaikan"*.
   * Tabel `strikes` mencatat **+1 Strike Tukang** (`NO_DEPART_30M`).

---

### 🟢 E2E-06: Pembatalan Tukang (`DRAFT` Tidak Bocor), Cancel User $\ge$ 3 Jam `ON_THE_WAY`, & Suspend Otomatis 2 Hari (`BR-50` s/d `BR-58`)
1. Saat `ON_THE_WAY`, **Tukang** menggeser tombol Batal $\rightarrow$ klik **Ya** $\rightarrow$ masuk halaman form (`DRAFT`):
   * **Test Negatif `BR-51`:** Query dari sesi **User** memastikan status job yang terlihat oleh User masih `ON_THE_WAY` (belum berubah menjadi `CANCEL_PENDING`).
   * **Tukang** menekan tombol **Kembali** $\rightarrow$ `DRAFT` menjadi `ABORTED` tanpa notifikasi ke User dan tanpa Strike.
2. **Tukang** menggeser lagi $\rightarrow$ isi form lengkap (termasuk catatan Admin & foto bukti) $\rightarrow$ klik **Kirim** (`SUBMITTED`):
   * **Test Negatif `BR-53` (`NFR-20`):** Respons API yang diterima **User** HANYA berisi kategori & teks alasan pembatalan; kolom `admin_notes`, `evidence_photos`, dan koordinat GPS tukang dipastikan `null`/tidak ada.
   * **User** menekan **Setujui Pembatalan** $\rightarrow$ Job kembali `OPEN` di portal dan **Tukang terkena +1 Strike Tukang**.
3. **Uji Cancel User pada `ON_THE_WAY`:**
   * Pada menit ke-60 (1 jam `ON_THE_WAY`), User mencoba membatalkan $\rightarrow$ **Ditolak server** (karena $< 3$ jam, `BR-56a`).
   * Waktu `on_the_way_at` dimundurkan menjadi 3 jam 5 menit yang lalu $\rightarrow$ tombol **Cancel** muncul di layar User (`BR-56b`). User klik Cancel, lalu Tukang tidak merespons selama 31 menit $\rightarrow$ **Auto-Cancel berhasil** dan **Tukang terkena +1 Strike Tukang**.
4. **Uji Ambang Suspend Otomatis 2 Hari (`BR-57`):**
   * Saat Tukang menerima **Strike ke-4 (lebih dari 3x)** dalam bulan kalender lokal yang sama $\rightarrow$ `profiles.suspend_type` otomatis berubah menjadi `'AUTO_2_DAYS'` dengan `suspended_until = NOW() + 48 hours`. Tukang tidak dapat `Online` atau melakukan bid, namun dapat melihat halaman keterangan penyebab suspend di aplikasi.

---

### 🟢 E2E-07: Strike User Saat Menghilang di `ON_THE_WAY` / `ARRIVED` (`BR-71`)
1. Status job berada pada `ON_THE_WAY` (atau `ARRIVED`).
2. **Tukang** mengirim pesan chat kepada User: *"Pak, saya sudah di depan gang, rumah nomor berapa?"*.
3. Waktu dimajukan 31 menit tanpa User membalas chat:
   * Sistem mencatat **+1 Strike User** (`USER_UNRESPONSIVE_OTW_ARRIVED`, `BR-71`).
4. Setelah kejadian ini berulang hingga **Strike ke-4 (lebih dari 3x)** dalam bulan yang sama, akun **User otomatis terkena Suspend 2 Hari (`AUTO_2_DAYS`)**.

---

### 🟢 E2E-08: Kasus User Tidak Mau Bayar / Bayar Kurang $\rightarrow$ Investigasi Admin & Suspend Permanen Tanpa Toleransi 3x (`BR-67`)
1. Status job berada pada `WORKING` dengan Nota Sah Rp 200.000. Pekerjaan fisik sudah selesai, namun User menolak membayar.
2. Baik User maupun Tukang mencoba menekan tombol Batal biasa $\rightarrow$ **Ditolak server** (`WORKING` tidak dapat dibatalkan, `BR-65`).
3. **Tukang** menekan tombol khusus **"Laporkan Masalah Pembayaran"** (`BR-67`), mengunggah foto bukti hasil kerja, dan menulis kronologi:
   * Laporan masuk ke Web Admin dengan `category = 'PAYMENT_DEFAULT'` dan `is_priority = true`.
   * Flag `payment_dispute_active` aktif sehingga Tukang tidak terkunci dan sudah bisa melamar pekerjaan lain untuk mencari nafkah.
4. **Admin** membuka laporan di **Web Admin (`web/admin`)** $\rightarrow$ mengaudit riwayat Chat, Nota Sah Rp 200.000, dan Foto Hasil Kerja $\rightarrow$ menekan tombol **"Vonis Bersalah & Suspend Permanen User"**.
5. **Verifikasi Akhir:**
   * Akun **User** langsung berubah menjadi `suspend_type = 'MANUAL_PERMANENT'` **sekali jalan (tanpa menunggu 3x strike)**.
   * Saat User membuka aplikasi, seluruh fitur transaksi diblokir dan layar menampilkan alasan suspend beserta alamat **Email Resmi Admin/Perusahaan** untuk pengajuan banding.

---

### 🟢 E2E-09: Aturan Satu Email Satu Peran (`BR-44`) & Perubahan Metode Bayar Aktual (`BR-32`)
1. **Satu Email Satu Peran:** Email `budi@contoh.com` didaftarkan sebagai `USER`. Ketika email `budi@contoh.com` digunakan mendaftar di aplikasi Tukang (`TUKANG`), server menolak pendaftaran (`BR-44`).
2. **Perubahan Metode Bayar Aktual di Lapangan:** Nota Sah awal menggunakan metode `BANK_TRANSFER`, tetapi saat pekerjaan selesai User membayar dengan uang tunai (`CASH`). Pada form penyelesaian, Tukang mengubah pilihan **Metode Bayar Aktual** menjadi `CASH` $\rightarrow$ kolom unggah bukti transfer otomatis disembunyikan dan Tukang berhasil menyelesaikan pekerjaan (`COMPLETED`) dengan mengunggah foto hasil kerja + centang *"User sudah membayar"*.

---

## 5. Cara Menjalankan Pengujian (Command Reference)

Saat kode aplikasi dan migrasi pada Milestone terkait selesai dibangun, pengujian dijalankan dengan perintah berikut:

```bash
# 1. Menjalankan Database, RPC, Negative & Concurrency Tests (Supabase Local)
npx supabase start
npm --prefix supabase/tests test

# 2. Menjalankan E2E Web Admin (Playwright)
npm --prefix web/admin run test:e2e

# 3. Menjalankan E2E Mobile User & Tukang (Flutter Patrol)
cd mobile/user && patrol test
cd mobile/tukang && patrol test
```
