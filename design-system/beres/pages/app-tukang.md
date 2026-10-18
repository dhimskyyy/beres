# Page Override: Beres App Tukang / Mitra (`mobile/tukang`)

> **Menginduk pada:** [`../MASTER.md`](../MASTER.md)
> **Target Device:** Mobile (`390x844` Field-Optimized High-Contrast UI, Touch Target $\ge 48\text{dp}$–$56\text{dp}$)

## Aturan Spesifik UI/UX Aplikasi Mitra Tukang
1. **Navigasi Bawah (4 Tab Konsisten):**
   - `Bursa Kerja` (Job Portal `OPEN` sesuai kategori keahlian & slider radius `0–50 km`)
   - `Lamaran (Maks 5)` (Daftar maksimal 5 job `OPEN` yang dilamar + status Auto-Clear `WITHDRAWN` saat di-*lock* di 1 job)
   - `Tugas Aktif` (Workspace tunggal untuk 1 job yang sedang di-*lock*: Chat, Nota Digital, Navigasi GPS, & Form Selesaikan Tugas)
   - `Profil & Kuota` (Status KYC KTP, Slider Radius Kerja `0–50 km`, Kuota Mingguan `0–5/5 Job`, Indikator Strike Tukang `[0/3]`, & Hapus Akun)
2. **Kontras Lapangan & Tombol Utama Anti-Salah Pencet:**
   - Tombol operasional utama (**"BERANGKAT KE LOKASI"**, **"SAYA SUDAH TIBA"**, **"MULAI BEKERJA"**, **"SELESAIKAN TUGAS"**) memiliki tinggi minimal `52px`–`56px` dengan kontras AAA.
   - Pembatalan pada tahap `NOTA_APPROVED`, `ON_THE_WAY`, dan `ARRIVED` wajib menggunakan komponen **Slide-to-Cancel** $\rightarrow$ Dialog Ya/Tidak $\rightarrow$ Form Pembatalan (`DRAFT` tidak mengubah tampilan User sebelum tombol **Kirim** ditekan).
3. **Manajemen Nota & Revisi Nota (`BR-04`–`BR-08`):**
   - Selama Revisi Nota masih berstatus `SENT` (belum dijawab User), kartu di ruang chat Tukang menampilkan tombol tegas **"Tarik / Batalkan Revisi Nota"** agar Nota Sah awal kembali berlaku dan tidak mengunci penyelesaian tugas.
4. **Penyelesaian Tugas vs Sengketa Pembayaran (`BR-32`, `BR-67`):**
   - Halaman penyelesaian di status `WORKING` menampilkan 5 syarat wajib + pilihan **Metode Bayar Aktual** (`Transfer Bank`, `E-Wallet`, `Tunai` — input bukti transfer otomatis tersembunyi bila memilih `Tunai`).
   - Menyediakan kartu darurat merah **"Laporkan Masalah Pembayaran (User Tidak Mau Bayar / Bayar Kurang)"** yang langsung melepas kunci job aktif sementara & mengirim laporan ke antrean prioritas Admin.
