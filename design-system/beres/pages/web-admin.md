# Page Override: Beres Web Admin Console (`web/admin`)

> **Menginduk pada:** [`../MASTER.md`](../MASTER.md)
> **Target Device:** Desktop (`1440x900` High-Density Enterprise Operational Console, `density: 8/10`)

## Aturan Spesifik UI/UX Dashboard Web Admin
1. **Arsitektur Layout (`12-Column Fluid Grid + Persistent Sidebar 240px`):**
   - Sidebar kiri menampilkan navigasi langsung ke seluruh modul operasional dengan indikator badge real-time:
     1. `Command Center & Live Map` (Peta GPS Tukang Full-Screen + KPI 10 Status Job)
     2. `Sengketa & Laporan Prioritas` (Badge merah jumlah kasus User tidak bayar / komplain)
     3. `Verifikasi KYC Tukang` (Badge jumlah pengajuan KTP `PENDING`)
     4. `Monitor Pekerjaan & Audit` (Tabel 10 status pekerjaan, riwayat chat, Nota Sah vs Revisi, & log lokasi)
     5. `Manajemen Akun & Strike` (Daftar User & Tukang, riwayat Strike `1-3/3`, status Suspend 48 Jam / Suspend Permanen)
     6. `Kategori & Parameter Sistem` (CRUD Kategori Dinamis & editor `app_configs`)
2. **Meja Investigasi Sengketa Pembayaran (`BR-67`):**
   - Tampilan 3 panel berdampingan (*Tri-Pane Audit View*):
     - **Panel 1:** Transkrip Chat Lengkap + Riwayat **Nota Sah vs Revisi Nota** + Metode Bayar Aktual.
     - **Panel 2:** Galeri Bukti Visual (**Foto Keluhan Awal User** vs **Foto Hasil Kerja Tukang** vs **Bukti Bayar**).
     - **Panel 3:** Panel Eksekusi Keputusan Admin dengan tombol tegas **"Suspend Permanen Akun User (Terbukti Tidak Bayar — Tanpa Toleransi 3x)"**, tombol pengaturan Strike/Suspend, dan catatan audit.
