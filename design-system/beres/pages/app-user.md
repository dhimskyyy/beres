# Page Override: Beres App User (`mobile/user`)

> **Menginduk pada:** [`../MASTER.md`](../MASTER.md)
> **Target Device:** Mobile (`390x844` iOS / Android, Touch Target $\ge 48\text{dp}$)

## Aturan Spesifik UI/UX Aplikasi Pelanggan (User)
1. **Navigasi Bawah (4 Tab Konsisten):**
   - `Beranda` (Pilih 9 Kategori & Posting Pekerjaan Baru)
   - `Pekerjaan Saya` (Pantau Job Aktif: `OPEN`, `NEGOTIATING`, `NOTA_APPROVED`, `ON_THE_WAY`, `ARRIVED`, `WORKING`, `CANCEL_PENDING` & Riwayat `COMPLETED`/`CANCELLED`/`EXPIRED`)
   - `Pesan & Nota` (Ruang Chat dengan Tukang yang sudah di-*lock* + Riwayat Nota Sah & Revisi Nota)
   - `Profil & Aturan` (Data Akun, Indikator Strike User `[0/3 Bulan Ini]`, Pusat Bantuan/FAQ Aturan Pembayaran, & Hapus Akun `BR-45`)
2. **Peta Pin Lokasi 2 KM (`FR-010`):**
   - Menampilkan lingkaran batas radius `2,0 km` berwarna biru (`#1E40AF`) di sekitar titik GPS HP User.
   - Menampilkan pill otomatis hasil Reverse Geocoding OS HP: `Kel. Tebet Timur, Kec. Tebet` (privasi terjaga sebelum lock).
3. **Kartu Komparasi Revisi Nota (`BR-05`, `BR-08`):**
   - Wajib memiliki header peringatan kuning-oranye: **"PERUBAHAN HARGA NOTA (BUTUH PERSETUJUAN ANDA)"**.
   - Menyandingkan `Harga Nota Awal (Sah)` vs `Harga Revisi Baru` menggunakan font `JetBrains Mono` tebal, disertai tombol **Setujui Revisi** dan **Tolak Revisi**.
4. **Layar Tracking & Aturan Cancel User (`BR-31`, `BR-56`, `BR-71`):**
   - Saat `NOTA_APPROVED` (30 menit tunggu Tukang klik Berangkat) dan `ON_THE_WAY` (< 3 jam), tombol Cancel tidak ditampilkan (diganti informasi edukatif perlindungan mitra).
   - Tombol **"Batalkan Pekerjaan (Tukang Belum Tiba > 3 Jam)"** hanya muncul apabila durasi `ON_THE_WAY` mencapai $\ge 3$ jam.
   - Menampilkan pita pengingat **Strike User (`BR-71`)** agar User membalas chat Tukang maksimal dalam 30 menit saat Tukang sedang `ON_THE_WAY` atau `ARRIVED`.
