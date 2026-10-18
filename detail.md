# DETAIL LENGKAP PROYEK: EKOSISTEM APLIKASI "BERES"

Dokumen ini (`detail.md`) adalah panduan menyeluruh yang menjelaskan dari A sampai Z mengenai pengertian, latar belakang, maksud dan tujuan, fitur lengkap, aturan bisnis, alur kerja, hingga teknologi (*tech stack*) yang digunakan dalam proyek **Beres**.

---

## 1. Pengertian & Penjelasan Proyek (Apa itu "Beres"?)

**Beres** adalah platform *marketplace* dan manajemen jasa pertukangan *on-demand* di Indonesia (serupa dengan konsep *tukang.com* namun dengan mekanisme *bidding*, negosiasi terbuka via **Nota Digital**, dan sistem berlangganan SaaS). 

Platform ini dirancang untuk mempertemukan **Masyarakat/Pelanggan (User)** yang sedang mengalami kendala atau membutuhkan tenaga ahli perbaikan di rumah/kantor/jalan dengan **Mitra Pekerja Ahli (Tukang)** dari berbagai bidang keahlian yang berada di sekitar lokasi pelanggan.

Ekosistem **Beres** terdiri dari **3 aplikasi yang saling terhubung secara *real-time***:
1. **📱 Beres User (Aplikasi Mobile untuk Pelanggan):** Tempat pelanggan mencari tukang, memposting masalah/kerusakan, memilih tukang yang menawar (*bid*), berdiskusi di chat, menyetujui **Nota**, memantau perjalanan GPS tukang, dan memberikan ulasan.
2. **🛠️ Beres Mitra / Tukang (Aplikasi Mobile untuk Tukang):** Tempat para tukang mencari pekerjaan sesuai kategori keahlian dan jarak radius, mengambil tawaran (*bid*), membuat **Nota harga**, memperbarui progres kerja, mengirim lokasi GPS saat bertugas, dan mengunggah foto bukti pekerjaan selesai.
3. **💻 Beres Web Admin (Dashboard Web untuk Pengelola/Admin):** Pusat komando operasional untuk memverifikasi identitas KTP tukang (KYC), memantau peta pergerakan GPS seluruh tukang yang sedang bertugas secara *real-time*, memantau status setiap pekerjaan, mengaudit isi chat/nota/foto bukti kerja, serta mengelola kategori layanan dan langganan mitra.

---

## 2. Maksud & Tujuan Proyek

Proyek **Beres** dibangun untuk menyelesaikan masalah nyata yang sering dialami oleh masyarakat maupun para tukang di Indonesia:

### A. Tujuan untuk Pelanggan (User)
* **Kemudahan Mencari Tukang Terpercaya:** Pelanggan tidak perlu lagi bingung mencari kenalan tukang saat terjadi masalah mendadak (listrik korslet, pipa pecah, atap bocor, motor/mobil mogok, AC kotor, dll.).
* **Transparansi Kualitas & Reputasi:** Sebelum memilih tukang, pelanggan bisa melihat rekam jejak tukang secara lengkap (ulasan pelanggan sebelumnya, rata-rata bintang, lama hari aktif di aplikasi, serta keahliannya).
* **Kepastian & Transparansi Harga Lewat "Nota Digital":** Menghindari kejadian tukang "getok harga" sepihak setelah pekerjaan selesai. Semua harga harus disepakati di dalam **Nota** di ruang chat sebelum tukang mulai bekerja, termasuk jika ada **Revisi Nota** di lapangan.
* **Keamanan & Pemantauan Langsung:** Seluruh tukang telah melewati verifikasi KTP oleh Admin, dan posisi tukang dapat dipantau langsung lewat GPS saat menuju lokasi.

### B. Tujuan untuk Mitra Pekerja (Tukang)
* **Akses Pekerjaan yangMerata Sesuai Lokasi & Keahlian:** Tukang mendapatkan aliran orderan di sekitar lokasinya (radius hingga 50 KM untuk akun standar, dan hingga 100 KM untuk akun Gold) sesuai bidang yang mereka kuasai.
* **Uang Jasa 100% Langsung Diterima Tukang (Tanpa Potongan Komisi per Order):** Berbeda dengan aplikator lain yang memotong 20%–30% dari setiap keringat tukang atau menahan uang di saldo aplikasi, di **Beres** pelanggan membayar **100% langsung ke rekening bank, e-wallet pribadi, atau tunai (cash) ke tangan tukang**.
* **Fleksibilitas Penentuan Harga:** Tukang bisa berdiskusi dulu dengan pelanggan mengenai tingkat kesulitan pekerjaan sebelum menerbitkan **Nota** penawaran harga.

### C. Tujuan Bisnis & Operasional Platform (Pengelola Beres)
* **Model Bisnis SaaS yang Bebas Kerumitan Regulasi E-Money/Escrow:** Karena aplikasi tidak menampung dana milik pelanggan maupun tukang (*Zero In-App Wallet*), platform bebas dari beban regulasi izin penyelenggara dompet digital/escrow, dan fokus murni pada pendapatan bersih dari **Langganan Bulanan Tukang (Gold Badge)** serta **Fitur Iklan/Boost Pekerjaan User**.
* **Kontrol & Pengawasan Penuh Lewat Web Admin:** Seluruh aktivitas lapangan (titik lokasi tukang, status tugas, bukti foto hasil kerja, hingga riwayat chat & nota) terpantau secara *real-time* di layar Admin.

---

## 3. Apa Saja yang Ada di Dalam Proyek Ini?

### A. Kategori Pekerjaan Tukang yang Tersedia (Dinamis)
Kategori pekerjaan dikelola secara dinamis dari **Web Admin** (dapat ditambah/diubah kapan saja tanpa perlu update aplikasi di Play Store), meliputi seluruh jenis pekerjaan pertukangan di Indonesia:
1. **🧱 Tukang Bangunan:** Renovasi rumah, pasang keramik, plester/aci tembok, perbaikan atap bocor, pengecatan, pasang plafon/gypsum.
2. **⚡ Tukang Listrik:** Perbaikan korsleting listrik, pasang/ganti MCB, instalasi kabel baru, pasang lampu, saklar, dan stop kontak.
3. **🚰 Tukang Pipa & Air (Plumbing):** Perbaikan pipa bocor/mampet, pasang kran air, servis/pasang pompa air, kuras toren, perbaikan saluran WC/wastafel.
4. **🧹 Cleaning Service & AC:** Bersih-bersih rumah/kos/kantor panggilan, cuci & servis AC, sedot tungau kasur, pembersihan pasca renovasi.
5. **🛵 Bengkel Motor Panggilan:** Bantuan motor mogok darurat, tambal/ganti ban, ganti aki, ganti oli, dan servis ringan panggilan.
6. **🚗 Bengkel Mobil Panggilan:** Jumper/ganti aki mobil mogok, ganti ban serep/tambal ban, pengecekan mesin darurat, ganti oli di rumah.
7. **🪚 Tukang Kayu & Mebel:** Perbaikan kusen/pintu/jendela macet, perbaikan lemari, pembuatan rak, *kitchen set*, dan engsel pintu.
8. **➕ Kategori Lainnya:** Siap ditambahkan kapan saja melalui Web Admin (misal: Tukang Las/Besi, Tukang Taman, Teknisi Elektronik/Kulkas/Mesin Cuci, Kunci/Locksmith, dll.).

---

## 4. Apa yang Bisa Dilakukan oleh Masing-Masing Aplikasi? (Fitur Lengkap)

### 📱 1. Kemampuan Aplikasi `Beres User` (Pelanggan)
* **Memilih Kategori & Memposting Pekerjaan:**
  * Memilih kategori jasa yang dibutuhkan (misal: Listrik).
  * Mengisi form detail masalah, mengunggah foto-foto kerusakan, dan menaruh titik koordinat lokasi di peta.
  * Jangkauan standar otomatis menyebarkan pekerjaan ke tukang dalam radius **50 KM**.
  * *(Fitur Mendatang / Phase 2)* Melakukan **Boost (Iklan Pekerjaan)** agar pekerjaan tersebar hingga radius **100 KM** dan ter-pin paling atas di aplikasi tukang.
* **Menerima Bid & Memilih (Lock) Tukang:**
  * Menerima notifikasi *real-time* setiap ada tukang yang melakukan *bid* pada pekerjaannya.
  * Melihat daftar tukang yang menawar (Tukang berlangganan **Gold Badge** otomatis tampil paling atas).
  * Mengecek detail profil tukang: Foto profil, lencana keahlian, rata-rata rating, ulasan pelanggan sebelumnya, dan berapa hari tukang tersebut sudah aktif di Beres.
  * Memilih (**Lock**) **1 tukang** yang paling cocok.
* **Diskusi di Ruang Chat & Persetujuan Nota:**
  * Begitu tukang di-*lock*, **Ruang Chat** otomatis terbuka (bisa berkirim pesan teks dan foto tambahan).
  * Menerima kartu **Nota Digital** yang dikirim oleh tukang di dalam chat (berisi rincian biaya dan metode pembayaran: Transfer Bank, E-Wallet, atau Cash).
  * Menekan tombol **Approve Nota** (jika setuju dengan harga agar tukang bisa mulai jalan), **Nego Ulang** (jika ingin menawar harga), atau **"Batalkan & Pilih Tukang Lain"** (jika tidak menemukan kata sepakat, sehingga bisa langsung memilih tukang lain yang sudah nge-bid tadi tanpa membuat postingan ulang).
  * Menyetujui **Revisi Nota (Adendum)** apabila saat pengerjaan di lokasi terdapat tambahan alat/pekerjaan yang disepakati bersama.
* **Memantau Lokasi Tukang (Live Tracking) & Memberi Rating:**
  * Melihat pergerakan titik GPS tukang secara langsung di peta saat tukang sedang menuju lokasi (`ON_THE_WAY`).
  * Melihat foto bukti hasil pekerjaan yang diunggah tukang, melakukan pembayaran langsung ke rekening/e-wallet/tunai tukang, dan memberikan **Rating (Bintang 1–5) & Review** setelah pekerjaan selesai (`COMPLETED`).

---

### 🛠️ 2. Kemampuan Aplikasi `Beres Mitra / Tukang` (Pekerja)
* **Pendaftaran & Verifikasi Identitas (KYC):**
  * Mengisi biodata, memilih satu atau lebih kategori keahlian yang dikuasai, dan memasukkan nomor rekening bank / e-wallet pribadi (untuk dicantumkan otomatis pada Nota).
  * Mengunggah **Foto KTP** dan **Foto Selfie memegang KTP** untuk diverifikasi oleh Admin.
* **Pengaturan Radius Kerja & Pemantauan Kuota Mingguan:**
  * Mengaktifkan/menonaktifkan status ketersediaan kerja (`Online` / `Offline`).
  * Mengatur **Slider Radius Pekerjaan**:
    * **Tukang Standar (Free):** Bisa mengatur radius **0 – 50 KM**.
    * **Tukang Gold (Langganan Bulanan):** Bisa mengatur radius lebih luas hingga **0 – 100 KM**.
  * Melihat sisa kuota kerja mingguan:
    * **Tukang Standar (Free):** Maksimal menyelesaikan **5 pekerjaan per minggu** (direset otomatis setiap awal minggu). Kuota **hanya terpotong jika pekerjaan berhasil diselesaikan (`COMPLETED`)**; jika batal negosiasi atau dicancel user, kuota **tidak hangus**.
    * **Tukang Gold:** Kuota pekerjaan **Unlimited** (tanpa batas), mendapat **Gold Badge**, di-pin paling atas di layar User, serta mendapat notifikasi pekerjaan baru lebih cepat (*headstart* 1–2 menit).
* **Portal Pekerjaan (Job Portal) & Bidding:**
  * Melihat daftar pekerjaan terbuka (`OPEN`) di sekitar lokasi yang sesuai dengan keahlian dan radius tukang.
  * Melakukan **Bid / Ambil Tugas** pada pekerjaan yang diminati.
* **Ruang Chat & Pembuatan Nota (Khusus Aplikasi Tukang):**
  * Mengobrol dengan User setelah dipilih (*locked*).
  * **Membuat Nota & Revisi Nota:** Fitur pembuatan Nota **hanya ada di aplikasi Tukang** (tidak ada di aplikasi User). Tukang memasukkan rincian pekerjaan/material, total harga, serta memilih metode pembayaran hasil kesepakatan (**Bank Transfer**, **E-Wallet**, atau **Cash**).
* **Eksekusi Pekerjaan, Live GPS, & Syarat Wajib Foto Selesai:**
  * Sebelum Nota di-*Approve* oleh User, tombol mulai/berangkat kerja terkunci.
  * Setelah Nota di-*Approve*, tukang menekan **"Berangkat ke Lokasi"** (`ON_THE_WAY`) $\rightarrow$ GPS HP tukang otomatis mengirimkan titik lokasi *real-time* ke layar User dan Web Admin.
  * Saat tiba di lokasi, tukang menekan **"Mulai Bekerja"** (`WORKING`), dan dapat mengajukan **Revisi Nota** jika ada tambahan biaya di lapangan.
  * **Aturan Wajib Foto Hasil Kerja:** Saat pekerjaan fisik beres, tukang **WAJIB memfoto hasil pekerjaannya** terlebih dahulu. Sebelum foto hasil pekerjaan diunggah, tombol **"Pembayaran Diterima & Selesaikan Tugas"** tidak akan bisa diklik (*disabled*).
  * Setelah foto hasil kerja diunggah dan pembayaran diterima langsung dari User, tukang menekan tombol selesai (`COMPLETED`).

---

### 💻 3. Kemampuan `Beres Web Admin` (Dashboard Pengelola)
* **Live Map Monitoring (Pusat Pantau GPS):**
  * Peta layar penuh yang menampilkan posisi GPS *real-time* seluruh tukang yang sedang dalam perjalanan (`ON_THE_WAY`) maupun sedang bekerja (`WORKING`), lengkap dengan titik lokasi User dan detail tugasnya.
* **Monitoring Status Pekerjaan & Audit Sengketa:**
  * Memantau seluruh tiket pekerjaan di setiap tahap (`OPEN` $\rightarrow$ `NEGOTIATING` $\rightarrow$ `NOTA_APPROVED` $\rightarrow$ `ON_THE_WAY` $\rightarrow$ `WORKING` $\rightarrow$ `COMPLETED`).
  * Mengintip/mengaudit isi **Ruang Chat**, rincian **Nota & Revisi Nota**, **Foto Kerusakan Awal**, serta **Foto Bukti Hasil Kerja** jika terjadi laporan atau komplain.
* **Verifikasi KYC Tukang & Manajemen Akun:**
  * Memeriksa dan menyetujui (*Approve* / *Reject*) pendaftaran KTP & Selfie tukang baru sebelum mereka diizinkan mengambil pekerjaan.
  * Melakukan *Suspend / Ban* pada akun User atau Tukang yang melanggar aturan.
  * **Manual Gold Badge Toggle:** Mengaktifkan atau menonaktifkan status langganan **Gold Badge** tukang secara manual (sangat berguna di tahap awal rilis sebelum pembayaran otomatis diaktifkan).
* **Manajemen Kategori Pekerjaan Dinamis:**
  * Menambah, mengedit, mengurutkan, atau menonaktifkan kategori pekerjaan tukang secara langsung tanpa perlu mengubah kode aplikasi Flutter.
* **Dashboard Analitik:**
  * Melihat statistik operasional harian/bulanan (jumlah order masuk, tingkat penyelesaian pekerjaan, kategori jasa paling diminati, dan jumlah tukang aktif).

---

## 5. Urutan Status Pekerjaan (6 Tahap State Machine)

Seluruh aplikasi (`User`, `Tukang`, dan `Web Admin`) bergerak mengikuti satu aturan status yang sama:

1. **`OPEN`** $\rightarrow$ User baru saja memposting pekerjaan; tukang-tukang dalam radius melakukan *Bid*.
2. **`NEGOTIATING`** $\rightarrow$ User sudah memilih (*Lock*) 1 tukang; ruang Chat terbuka; proses diskusi & pengiriman **Nota** oleh tukang. *(Jika batal sepakat, User bisa kembali ke `OPEN` untuk pilih tukang lain tanpa memotong kuota tukang).*
3. **`NOTA_APPROVED`** $\rightarrow$ User menekan tombol *Approve* pada Nota; kesepakatan harga sah; tombol *"Berangkat ke Lokasi"* di aplikasi Tukang terbuka.
4. **`ON_THE_WAY`** $\rightarrow$ Tukang sedang menuju lokasi User; **Live GPS Tracking menyala** di aplikasi User dan Web Admin. *(Tukang hanya boleh memiliki 1 pekerjaan aktif berjalan dalam satu waktu).*
5. **`WORKING`** $\rightarrow$ Tukang sudah sampai dan sedang mengerjakan tugas; Live GPS tetap terpantau; fitur **Revisi Nota (Adendum)** tersedia jika ada tambahan pekerjaan.
6. **`COMPLETED`** $\rightarrow$ Tukang sudah mengunggah **Foto Bukti Hasil Pekerjaan**, pembayaran langsung telah diterima tukang, kuota Tukang Free terpotong 1x, Live GPS berhenti, dan User memberikan **Rating & Review**.

---

## 6. Tech Stack yang Digunakan

Seluruh komponen teknologi dipilih agar **modern, cepat, mudah dirawat (*maintainable*), dan hemat biaya server di awal namun siap untuk skala besar**:

| Lapisan Sistem | Teknologi yang Dipakai | Kegunaan & Alasan Pemilihan |
| :--- | :--- | :--- |
| **Aplikasi Mobile (`User` & `Tukang`)** | **Flutter (Dart)** | Menggunakan arsitektur **Monorepo** dengan paket bersama (`mobile/shared`) sehingga model data, ruang chat, kartu nota, dan peta cukup ditulis 1 kali untuk kedua aplikasi (`mobile/user` & `mobile/tukang`). |
| **Aplikasi Web Admin** | **Next.js (React) + Tailwind CSS + Shadcn UI** | Memberikan performa dashboard web yang sangat cepat, responsif, tabel data yang ringan, serta tampilan peta monitoring layar penuh yang mulus. |
| **Backend, Auth, & Realtime** | **Supabase (Auth, Realtime WebSocket, Storage) / Node.js** | Menangani autentikasi pengguna, percakapan chat *real-time*, pembaruan status Nota instan, *streaming* koordinat GPS tukang, serta penyimpanan file foto (Kerusakan, KTP, Bukti Kerja). |
| **Database & Perhitungan Jarak** | **PostgreSQL + Ekstensi PostGIS** | Standar industri terbaik untuk menyimpan titik koordinat bumi dan menghitung filter radius jarak **50 KM / 100 KM** secara instan di sisi database dengan biaya Rp 0. |
| **Layanan Peta (Maps)** | **OpenStreetMap (`flutter_map` / `MapLibre`) $\rightarrow$ Siap ke Google Maps Platform** | Dibungkus dengan *Map Provider Adapter*. Di tahap awal memakai OpenStreetMap yang **100% gratis**, dan ketika pengguna sudah ramai dapat langsung dialihkan ke **Google Maps Platform** hanya dengan mengganti 1 file adapter. |
| **Push Notification** | **Firebase Cloud Messaging (FCM)** | Mengirim notifikasi order baru (dengan logika *headstart* untuk Tukang Gold), notifikasi bid masuk, pesan chat, dan status Nota dengan satu bunyi notifikasi standar yang seragam. |
| **Payment Gateway SaaS (Phase 2)** | **DOKU Payment Gateway** | Disiapkan untuk tahap pengembangan berikutnya (Phase 2) guna memproses pembayaran otomatis **Langganan Bulanan Tukang Gold** dan **User Boosting**. |

---

## 7. Struktur Folder Proyek (Monorepo)

Seluruh kode proyek tersimpan rapi di `/Users/mhmmddhimas/project/beres`:

```text
/Users/mhmmddhimas/project/beres/
├── AGENTS.md                  # Panduan & aturan mutlak untuk AI Coding Agent
├── detail.md                  # Penjelasan lengkap proyek dari A - Z (File ini)
├── docs/
│   ├── PRD.md                 # Spesifikasi kebutuhan produk & alur pengguna
│   ├── ARCHITECTURE.md        # Arsitektur teknis, shared package, & Map Adapter
│   ├── DATABASE_SCHEMA.md     # Rancangan tabel PostgreSQL + PostGIS
│   └── ROADMAP.md             # Checklist tahapan pengerjaan proyek
├── mobile/
│   ├── shared/                # Kode Flutter bersama (Model, Chat, Nota, Map Adapter)
│   ├── user/                  # Aplikasi Flutter "Beres User"
│   └── tukang/                # Aplikasi Flutter "Beres Mitra (Tukang)"
├── web/
│   └── admin/                 # Aplikasi Web Admin (Next.js + Tailwind + Shadcn UI)
└── supabase/
    └── migrations/
        └── 0001_initial_schema.sql  # Skema database SQL + Trigger aturan bisnis
```
