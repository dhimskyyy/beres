# Spesifikasi Skema Database (PostgreSQL + PostGIS) — Project "Beres" (v1.4.0)

Dokumen ini mendefinisikan struktur tabel, tipe enum, constraint, indeks spasial **PostGIS**, serta fungsi dan trigger aturan bisnis yang selaras 100% dengan **[`docs/PRD.md`](./PRD.md) (Versi 1.4.0)**.

---

## 1. Daftar Enum (Tipe Status Baku v1.4.0)

* **`user_role`**: `'USER'`, `'TUKANG'`, `'ADMIN'`, `'BOTH'` *(Aturan `BR-44`: 1 alamat email dapat memiliki 2 peran `USER` dan `TUKANG` dengan status `BOTH`)*
* **`suspend_type`**: `'NONE'`, `'AUTO_2_DAYS'`, `'MANUAL_PERMANENT'`
* **`kyc_status`**: `'PENDING'`, `'APPROVED'`, `'REJECTED'`
* **`job_status` (10 Status — Bagian 9.1 PRD)**:
  1. `'OPEN'` — Baru diposting atau dilepas kembali ke Job Portal.
  2. `'NEGOTIATING'` — User sudah *lock* 1 tukang (bid tukang tersebut di job lain otomatis `WITHDRAWN`), ruang Chat terbuka.
  3. `'NOTA_APPROVED'` — User menyetujui Nota (menjadi **Nota Sah**); timer **30 menit wajib klik Berangkat** berjalan.
  4. `'ON_THE_WAY'` — Tukang sedang menuju lokasi User (Live GPS aktif; batas 3 jam untuk opsi cancel User).
  5. `'ARRIVED'` — Tukang telah tiba di lokasi ($\le$ 50 m otomatis atau $\le$ 200 m manual).
  6. `'WORKING'` — Tukang sedang bekerja (**DILARANG dibatalkan** oleh User maupun Tukang).
  7. `'COMPLETED'` — Selesai bekerja, foto bukti & konfirmasi bayar lengkap (Kuota mingguan +1).
  8. `'CANCELLED'` — Dibatalkan secara permanen (saat `OPEN` oleh User, atau paksa oleh Admin).
  9. `'EXPIRED'` — Melewati 24 jam di `OPEN` tanpa ada tukang yang di-*lock*.
  10. `'CANCEL_PENDING'` — Permintaan pembatalan telah dikirim (`SUBMITTED`) dan menunggu persetujuan.
* **`bid_status`**: `'ACTIVE'`, `'LOCKED'`, `'WITHDRAWN'`
* **`nota_status` (`BR-07`)**: `'SENT'`, `'APPROVED'`, `'REJECTED'`, `'SUPERSEDED'`, `'VOID'`
* **`payment_method_type` (`BR-02`)**: `'BANK_TRANSFER'`, `'E_WALLET'`, `'CASH'`
* **`arrival_mode_type`**: `'AUTO'`, `'MANUAL'`
* **`photo_type`**: `'DAMAGE'`, `'WORK_RESULT'`, `'PAYMENT_PROOF'`
* **`cancel_request_status`**: `'DRAFT'`, `'SUBMITTED'`, `'APPROVED'`, `'REJECTED'`, `'ABORTED'`
* **`strike_type`**:
  * `'NO_DEPART_30M'` — Tukang tidak klik Berangkat dalam 30 menit setelah `NOTA_APPROVED` (`BR-31`).
  * `'TUKANG_CANCEL_APPROVED'` — Tukang membatalkan saat `NOTA_APPROVED`/`ON_THE_WAY`/`ARRIVED` (`BR-55`).
  * `'OTW_3H_UNRESPONSIVE'` — Tukang `ON_THE_WAY` $\ge$ 3 jam dan di-cancel User tanpa respons 30 menit (`BR-56b`).
  * `'USER_UNRESPONSIVE_OTW_ARRIVED'` — User tidak aktif/tidak membalas chat > 30 menit saat Tukang sudah `ON_THE_WAY` atau `ARRIVED` (`BR-71`).
* **`report_category`**: `'PAYMENT_DEFAULT'` (User tidak mau bayar / bayar kurang — prioritas tinggi `BR-67`), `'SAFETY_OR_FRAUD'`, `'FIELD_ISSUE'`, `'OTHER'`
* **`report_status`**: `'OPEN'`, `'IN_REVIEW'`, `'RESOLVED'`

---

## 2. Struktur Tabel Utama (Selaras Bagian 12.1 PRD v1.4.0)

### 2.1. `profiles` (Identitas Dasar, Peran Tunggal, & Status Suspend)
| Kolom | Tipe Data | Keterangan |
| :--- | :--- | :--- |
| `id` | `UUID (PK)` | Terhubung 1-1 dengan `auth.users.id` |
| `email` | `TEXT UNIQUE NOT NULL` | Alamat email unik (terhubung ke `auth.users`) |
| `role` | `user_role NOT NULL` | `'USER'`, `'TUKANG'`, `'ADMIN'`, atau `'BOTH'` (`BR-44`) |
| `full_name` | `TEXT NOT NULL` | Nama lengkap |
| `phone` | `TEXT` | Nomor HP kontak |
| `avatar_url` | `TEXT` | URL foto profil |
| `is_email_verified` | `BOOLEAN NOT NULL` | Default `false`, status verifikasi email |
| `email_verified_at` | `TIMESTAMPTZ` | Waktu diverifikasinya email via tautan atau OTP |
| `timezone` | `TEXT NOT NULL` | Default `'Asia/Jakarta'` (`'Asia/Jakarta'`, `'Asia/Makassar'`, `'Asia/Jayapura'` — `BR-75`) |
| `suspend_type` | `suspend_type NOT NULL` | Default `'NONE'` (`'AUTO_2_DAYS'` atau `'MANUAL_PERMANENT'` — `BR-42`) |
| `suspended_until` | `TIMESTAMPTZ` | Waktu berakhirnya suspend otomatis 2 hari (48 jam) |
| `suspend_reason` | `TEXT` | Keterangan jelas penyebab suspend yang ditampilkan di aplikasi (`BR-42`, `BR-58`) |
| `appeal_email_info` | `TEXT` | Alamat email resmi perusahaan untuk banding bila terkena `MANUAL_PERMANENT` |
| `deleted_at` | `TIMESTAMPTZ` | Penanda hapus akun (`FR-004`, `BR-45`) |
| `created_at` | `TIMESTAMPTZ` | Waktu pendaftaran |

### 2.2. `tukang_profiles` (Data Mitra Tukang, Radius, & Lokasi Dasar)
| Kolom | Tipe Data | Keterangan |
| :--- | :--- | :--- |
| `user_id` | `UUID (PK, FK)` | Referensi ke `profiles.id` |
| `bio` | `TEXT` | Deskripsi pengalaman tukang |
| `kyc_status` | `kyc_status NOT NULL` | Default `'PENDING'` (Wajib `'APPROVED'` sebelum bisa melihat portal & bid — `BR-10`) |
| `kyc_approved_at` | `TIMESTAMPTZ` | Digunakan untuk menghitung **"berapa hari aktif di Beres"** (`FR-011`) |
| `is_online` | `BOOLEAN NOT NULL` | Default `false` |
| `radius_km` | `INTEGER NOT NULL` | Default `20`, rentang wajib `0–50` di MVP (`BR-20`) |
| `payment_accounts` | `JSONB NOT NULL` | Daftar rekening bank & e-wallet pribadi tukang untuk dicantumkan otomatis di Nota (`BR-06`) |
| `last_known_location` | `GEOGRAPHY(POINT, 4326)`| **Lokasi Dasar** tukang saat `Online` untuk filter radius (`BR-26`) |
| `location_updated_at` | `TIMESTAMPTZ` | Jika `> 60 menit` yang lalu, tukang dianggap `Offline` (`BR-27`) |
| `rating_avg` | `NUMERIC(3,2) NOT NULL`| Default `0.00` |
| `rating_count` | `INTEGER NOT NULL` | Default `0` |
| `tier` | `TEXT NOT NULL` | **Hook Phase 2:** Default `'STANDARD'` (Tidak dipakai di MVP) |
| `gold_until` | `TIMESTAMPTZ` | **Hook Phase 2:** `NULL` di MVP |

### 2.3. `kyc_documents` (Dokumen Verifikasi KTP & Selfie Tukang)
| Kolom | Tipe Data | Keterangan |
| :--- | :--- | :--- |
| `id` | `UUID (PK)` | ID Dokumen KYC |
| `tukang_id` | `UUID (FK)` | Referensi ke `tukang_profiles.user_id` |
| `ktp_storage_path` | `TEXT NOT NULL` | Path di bucket privat `kyc-private` |
| `selfie_storage_path`| `TEXT NOT NULL` | Path di bucket privat `kyc-private` |
| `status` | `kyc_status NOT NULL` | `'PENDING'`, `'APPROVED'`, `'REJECTED'` |
| `rejection_reason` | `TEXT` | Wajib diisi Admin bila `REJECTED` (`FR-032`) |
| `reviewed_by` | `UUID (FK)` | Admin yang memeriksa (`profiles.id`) |
| `reviewed_at` | `TIMESTAMPTZ` | Waktu keputusan KYC |
| `created_at` | `TIMESTAMPTZ` | Waktu submit oleh tukang |

### 2.4. `categories` & `tukang_categories` (Kategori Dinamis & Keahlian)
* **`categories`**: `id (UUID PK)`, `slug (TEXT UNIQUE)`, `name (TEXT)`, `description (TEXT)`, `icon_name (TEXT)`, `is_active (BOOLEAN)`, `sort_order (INTEGER)`, `created_at (TIMESTAMPTZ)`.
* **`tukang_categories`**: `tukang_id (UUID FK)`, `category_id (UUID FK)`, `PRIMARY KEY (tukang_id, category_id)`.

### 2.5. `jobs` (Tiket Pekerjaan — 10 Status & Timer Operasional)
| Kolom | Tipe Data | Keterangan |
| :--- | :--- | :--- |
| `id` | `UUID (PK)` | ID Pekerjaan |
| `user_id` | `UUID (FK NOT NULL)` | Pemilik job (`profiles.id`) |
| `category_id` | `UUID (FK NOT NULL)` | Kategori (`categories.id`) |
| `locked_tukang_id` | `UUID (FK NULL)` | Tukang yang sedang di-*lock* (`tukang_profiles.user_id` — `BR-12`) |
| `description` | `TEXT NOT NULL` | Deskripsi masalah (minimal 10 karakter — `FR-010`) |
| `location` | `GEOGRAPHY(POINT, 4326)`| Titik lokasi job (validasi $\le$ 2 km dari GPS HP User saat posting — `FR-010`) |
| `area_label` | `TEXT NOT NULL` | Nama Kelurahan/Kecamatan hasil OS Reverse Geocoding HP User (tampil sebelum lock — `BR-16`) |
| `address_full` | `TEXT NOT NULL` | Alamat lengkap (HANYA terbuka bagi tukang yang sedang di-*lock* — `BR-16`) |
| `broadcast_radius_km`| `INTEGER NOT NULL` | Default `50` di MVP (`BR-11`) |
| `is_boosted` | `BOOLEAN NOT NULL` | **Hook Phase 2:** Default `false` |
| `status` | `job_status NOT NULL` | 10 Status (`OPEN` s/d `CANCEL_PENDING`) |
| `status_before_cancel`| `job_status NULL` | Menyimpan status sebelum `CANCEL_PENDING` (`NOTA_APPROVED`/`ON_THE_WAY`/`ARRIVED`) |
| `expires_at` | `TIMESTAMPTZ NOT NULL` | Waktu kedaluwarsa 24 jam saat `OPEN` |
| `locked_at` | `TIMESTAMPTZ` | Waktu User melakukan *lock* |
| `last_chat_at` | `TIMESTAMPTZ` | Waktu aktivitas chat terakhir (untuk timer 30 menit `BR-70` & `BR-71`) |
| `last_chat_sender_role`| `user_role` | Pengirim pesan terakhir (`'USER'` atau `'TUKANG'`) |
| `nota_approved_at` | `TIMESTAMPTZ` | Waktu Nota disetujui (awal timer **30 menit wajib klik Berangkat** — `BR-31`) |
| `on_the_way_at` | `TIMESTAMPTZ` | Waktu klik Berangkat (awal perhitungan **3 jam `ON_THE_WAY`** — `BR-56b`) |
| `arrived_at` | `TIMESTAMPTZ` | Waktu sampai di lokasi |
| `arrival_mode` | `arrival_mode_type` | `'AUTO'` ($\le$ 50 m) atau `'MANUAL'` ($\le$ 200 m) |
| `work_started_at` | `TIMESTAMPTZ` | Waktu klik "Mulai Bekerja" (`WORKING`) |
| `completed_at` | `TIMESTAMPTZ` | Waktu tugas selesai (**dasar perhitungan kuota 5x/minggu** — `BR-21`) |
| `agreed_total` | `BIGINT` | Nominal Rupiah integer sesuai **Nota Sah** terakhir |
| `actual_payment_method`| `payment_method_type` | Metode bayar aktual yang dipilih tukang saat penyelesaian (`BR-32`) |
| `user_paid_confirmed`| `BOOLEAN NOT NULL` | Default `false` (Centang "User sudah membayar" — `BR-32`) |
| `payment_confirmed_at`| `TIMESTAMPTZ` | Waktu konfirmasi pembayaran |
| `completion_note` | `TEXT` | Catatan penyelesaian opsional dari tukang |
| `payment_dispute_active`| `BOOLEAN NOT NULL` | Default `false` (Jika `true`, melonggarkan ikatan tukang sambil diinvestigasi Admin — `BR-67`) |
| `cancelled_by` | `UUID (FK)` | Pelaku pembatalan permanen (`USER` saat `OPEN` atau `ADMIN`) |
| `cancel_reason` | `TEXT` | Alasan pembatalan |
| `created_at` | `TIMESTAMPTZ` | Waktu pembuatan |

### 2.6. `job_status_history` (Audit Riwayat Perubahan Status)
* Menyimpan `id (BIGSERIAL PK)`, `job_id (UUID FK)`, `from_status (job_status)`, `to_status (job_status)`, `actor_id (UUID FK)`, `actor_role ( TEXT )`, `reason (TEXT)`, `created_at (TIMESTAMPTZ)`.

### 2.7. `job_photos` (Foto Kerusakan, Foto Hasil Kerja, & Bukti Bayar)
* Menyimpan `id (UUID PK)`, `job_id (UUID FK)`, `uploaded_by (UUID FK)`, `type (photo_type: 'DAMAGE' | 'WORK_RESULT' | 'PAYMENT_PROOF')`, `storage_path (TEXT)`, `created_at (TIMESTAMPTZ)`.
* **Aturan `BR-32` & `BR-64`:** Untuk `COMPLETED`, wajib ada $\ge 1$ baris `'WORK_RESULT'`, dan bila `actual_payment_method IN ('BANK_TRANSFER', 'E_WALLET')` wajib ada $\ge 1$ baris `'PAYMENT_PROOF'` (sedangkan bila `'CASH'`, dilarang ada `'PAYMENT_PROOF'`).

### 2.8. `bids` (Lamaran Tukang — Maksimal 5 `ACTIVE` & Auto-Clear Saat Lock)
| Kolom | Tipe Data | Keterangan |
| :--- | :--- | :--- |
| `id` | `UUID (PK)` | ID Bid |
| `job_id` | `UUID (FK NOT NULL)` | Referensi ke `jobs.id` |
| `tukang_id` | `UUID (FK NOT NULL)` | Referensi ke `tukang_profiles.user_id` |
| `distance_km` | `NUMERIC(5,2)` | Perkiraan jarak saat melamar |
| `status` | `bid_status NOT NULL` | `'ACTIVE'`, `'LOCKED'`, `'WITHDRAWN'` |
| `withdrawn_reason` | `TEXT` | `'MANUAL_BY_TUKANG'`, `'AUTO_LOCKED_ON_OTHER_JOB'` (`BR-17`), `'CANCELLED_OR_TIMEOUT'` |
| `created_at` | `TIMESTAMPTZ` | Waktu bid |
* `UNIQUE (job_id, tukang_id)`

### 2.9. `notas` (Nota Sah & Revisi Nota Anti-Getok Harga)
| Kolom | Tipe Data | Keterangan |
| :--- | :--- | :--- |
| `id` | `UUID (PK)` | ID Nota |
| `job_id` | `UUID (FK NOT NULL)` | Referensi ke `jobs.id` |
| `tukang_id` | `UUID (FK NOT NULL)` | Pembuat Nota (`BR-04`: Hanya Tukang) |
| `version` | `INTEGER NOT NULL` | `1` untuk Nota Awal, `2+` untuk Revisi Nota |
| `revision_of` | `UUID (FK NULL)` | Merujuk ke `notas.id` yang sedang berlaku (`APPROVED`) |
| `previous_approved_total`| `BIGINT NULL` | Menyimpan nominal Nota Sah sebelumnya untuk ditampilkan berdampingan di notifikasi chat User (`BR-05`) |
| `items` | `JSONB NOT NULL` | Daftar lengkap item pekerjaan/material (`[{ "name", "qty", "unit_price" }]`) |
| `total_amount` | `BIGINT NOT NULL` | Total harga dalam Rupiah integer ($\ge 1$) |
| `payment_method` | `payment_method_type` | Rencana metode bayar (`BANK_TRANSFER`, `E_WALLET`, `CASH`) |
| `payment_destination`| `JSONB` | Snapshot rekening/e-wallet tukang dari profil (`BR-06`) |
| `note` | `TEXT` | Catatan garansi/keterangan tukang |
| `status` | `nota_status NOT NULL` | `'SENT'`, `'APPROVED'`, `'REJECTED'`, `'SUPERSEDED'`, `'VOID'` |
| `created_at` | `TIMESTAMPTZ` | Waktu kirim |
| `responded_at` | `TIMESTAMPTZ` | Waktu User klik Approve / Tolak, atau Tukang tarik revisi (`BR-08`) |

### 2.10. `chat_messages` (Pesan Ruang Chat & Notifikasi Perubahan Harga Nota)
* Menyimpan `id (UUID PK)`, `job_id (UUID FK)`, `sender_id (UUID FK)`, `message_type ('TEXT' | 'IMAGE' | 'NOTA_CARD' | 'NOTA_REVISION_ALERT' | 'SYSTEM_EVENT')`, `content (TEXT)`, `image_url (TEXT)`, `nota_id (UUID FK NULL)`, `created_at (TIMESTAMPTZ)`.

### 2.11. `cancel_requests` (Permintaan Pembatalan Tukang & User $\ge$ 3 Jam OTW)
| Kolom | Tipe Data | Keterangan |
| :--- | :--- | :--- |
| `id` | `UUID (PK)` | ID Permintaan Pembatalan |
| `job_id` | `UUID (FK NOT NULL)` | Referensi ke `jobs.id` |
| `requester_id` | `UUID (FK NOT NULL)` | Pengaju (`profiles.id`) |
| `requester_role` | `user_role NOT NULL` | `'TUKANG'` (`BR-50`) atau `'USER'` (saat OTW $\ge$ 3 jam — `BR-56b`) |
| `status` | `cancel_request_status`| `'DRAFT'`, `'SUBMITTED'`, `'APPROVED'`, `'REJECTED'`, `'ABORTED'` |
| `status_before_cancel`| `job_status NOT NULL` | Status job saat pembatalan diajukan |
| `reason_category` | `TEXT` | Kategori alasan (Tampil ke lawan bicara & Admin — `BR-53`) |
| `reason_text` | `TEXT` | Alasan detail min 10 karakter (Tampil ke lawan bicara & Admin — `BR-53`) |
| `admin_notes` | `TEXT` | **Khusus Admin** (Dilarang bocor ke User — `BR-53`) |
| `evidence_photos` | `TEXT[]` | **Khusus Admin** (Dilarang bocor ke User — `BR-53`) |
| `requester_location` | `GEOGRAPHY(POINT, 4326)`| **Khusus Admin** |
| `distance_to_job_m` | `DOUBLE PRECISION` | **Khusus Admin** |
| `submitted_at` | `TIMESTAMPTZ` | Waktu klik **Kirim** (saat status job berubah ke `CANCEL_PENDING` — `BR-51`) |
| `resolved_by` | `UUID (FK)` | Pihak yang menyetujui/menolak (atau `NULL` bila auto-approve sistem) |
| `resolved_at` | `TIMESTAMPTZ` | Waktu selesai |

### 2.12. `strikes` (Pencatatan Strike Tukang & Strike User — Maks 3x/Bulan)
| Kolom | Tipe Data | Keterangan |
| :--- | :--- | :--- |
| `id` | `UUID (PK)` | ID Strike |
| `user_id` | `UUID (FK NOT NULL)` | Akun yang terkena strike (`profiles.id`) |
| `role` | `user_role NOT NULL` | `'TUKANG'` (`BR-57`) atau `'USER'` (`BR-71`) |
| `job_id` | `UUID (FK NOT NULL)` | Job tempat terjadinya pelanggaran |
| `strike_type` | `strike_type NOT NULL` | Jenis pelanggaran |
| `description` | `TEXT NOT NULL` | Penjelasan pelanggaran untuk ditampilkan di layar pengguna & Admin |
| `is_excused` | `BOOLEAN NOT NULL` | Default `false` (Jika dicabut Admin karena darurat sah) |
| `created_at` | `TIMESTAMPTZ NOT NULL` | Waktu pelanggaran (dihitung per bulan kalender zona waktu lokal pengguna — `BR-75`) |

### 2.13. `reports` (Laporan Kendala & Laporan Masalah Pembayaran `BR-67`)
* Menyimpan `id (UUID PK)`, `job_id (UUID FK)`, `reporter_id (UUID FK)`, `reported_user_id (UUID FK)`, `category (report_category)`, `is_priority (BOOLEAN — true untuk 'PAYMENT_DEFAULT')`, `description (TEXT)`, `evidence_photos (TEXT[])`, `status (report_status)`, `admin_resolution_notes (TEXT)`, `resolved_by (UUID FK)`, `created_at (TIMESTAMPTZ)`, `resolved_at (TIMESTAMPTZ)`.

### 2.14. Tabel Pendukung Lainnya
* **`location_pings`**: `id (BIGSERIAL PK)`, `job_id (UUID FK)`, `tukang_id (UUID FK)`, `location (GEOGRAPHY(POINT, 4326))`, `accuracy_m (DOUBLE PRECISION)`, `heading (DOUBLE PRECISION)`, `speed (DOUBLE PRECISION)`, `recorded_at (TIMESTAMPTZ)`.
* **`reviews`**: `id (UUID PK)`, `job_id (UUID UNIQUE FK)`, `user_id (UUID FK)`, `tukang_id (UUID FK)`, `rating (INTEGER 1..5)`, `comment (TEXT)`, `created_at (TIMESTAMPTZ)`.
* **`app_configs`**: `key (TEXT PK)`, `value_int (INTEGER)`, `value_text (TEXT)`, `description (TEXT)`, `updated_at (TIMESTAMPTZ)`.
  * Menyimpan parameter: `max_active_bids = 5`, `chat_negotiating_timeout_min = 30`, `depart_after_nota_timeout_min = 30`, `user_otw_arrived_chat_timeout_min = 30`, `otw_user_cancel_threshold_hours = 3`, `arrived_auto_radius_m = 50`, `arrived_manual_radius_m = 200`, `max_monthly_strikes = 3`, `auto_suspend_days = 2`, `weekly_completed_quota = 5`.
* **`device_tokens` & `notifications`**: Menyimpan token FCM perangkat dan daftar notifikasi in-app.
* **`audit_logs`**: Mencatat seluruh aksi Admin dan akses ke dokumen sensitif secara *immutable*.

---

## 3. Fungsi & Trigger Penegak Aturan Bisnis di Server (Database Guardrails)

1. **`fn_lock_tukang_and_clear_other_bids(p_job_id UUID, p_tukang_id UUID)` (`BR-12`, `BR-17`):**
   * Mengunci baris tukang & job secara atomik.
   * Mengubah bid tukang pada `p_job_id` menjadi `'LOCKED'` dan status `p_job_id` menjadi `'NEGOTIATING'`.
   * **Otomatis mengubah seluruh bid `'ACTIVE'` milik `p_tukang_id` pada job lain menjadi `'WITHDRAWN'` (`withdrawn_reason = 'AUTO_LOCKED_ON_OTHER_JOB'`).**
2. **`trg_enforce_nota_immutability` (`BR-05`, `BR-08`):**
   * Menolak `UPDATE` nominal atau item pada baris `notas` yang sudah berstatus `'APPROVED'`.
   * Saat Revisi Nota baru dimasukkan (`version >= 2`), otomatis mengisi `previous_approved_total` dengan nilai Nota `'APPROVED'` sebelumnya dan menyisipkan pesan `'NOTA_REVISION_ALERT'` ke `chat_messages` agar User melihat perbandingan harga lama vs baru.
3. **`fn_record_strike_and_check_auto_suspend` (`BR-57`, `BR-71`, `BR-75`):**
   * Setiap kali baris baru masuk ke tabel `strikes`, fungsi menghitung jumlah strike aktif (`is_excused = false`) milik `user_id` tersebut pada bulan kalender berjalan sesuai `profiles.timezone` (`Asia/Jakarta`, `Asia/Makassar`, atau `Asia/Jayapura`).
   * Jika jumlah strike pada bulan tersebut **$> 3$ (yaitu Strike ke-4 dan seterusnya)**, otomatis meng-update `profiles`:
     * `suspend_type = 'AUTO_2_DAYS'`
     * `suspended_until = NOW() + INTERVAL '48 hours'`
     * `suspend_reason = 'Akun dibekukan sementara selama 2 hari karena telah melewati batas maksimal 3 kali pelanggaran (Strike) dalam bulan ini.'`
4. **`fn_admin_suspend_payment_defaulter` (`BR-67`):**
   * Fungsi khusus Admin saat memvonis User yang terbukti tidak membayar / membayar kurang pada laporan `'PAYMENT_DEFAULT'`: langsung menetapkan `suspend_type = 'MANUAL_PERMANENT'`, mencabut sesi aktif User, dan mencatat di `audit_logs`.
