# Syarat & Ketentuan Layanan (Terms of Service) — Project "Beres" (v1.4.0)

**Terakhir Diperbarui:** 21 Oktober 2026  
**Versi:** 1.4.0 (Model Pembayaran Langsung Tanpa Dompet In-App)

---

## 1. Ketentuan Umum & Definisi
Selamat datang di **Beres**, platform penghubung jasa pertukangan *on-demand* di Indonesia. Dengan menggunakan aplikasi Beres (Pelanggan maupun Mitra Tukang), Anda mengikatkan diri secara hukum pada Syarat dan Ketentuan ini.

* **"Beres" / "Platform"**: Ekosistem aplikasi perangkat bergerak dan web yang dikelola oleh Pengelola Beres.
* **"Pelanggan" (User)**: Individu yang memposting kebutuhan pekerjaan pertukangan melalui aplikasi Beres User.
* **"Mitra Tukang" (Tukang)**: Tenaga ahli pertukangan independen terverifikasi yang melamar pekerjaan melalui aplikasi Beres Mitra.
* **"Nota Digital"**: Dokumen elektronik yang merinci estimasi biaya jasa dan material yang diterbitkan secara eksklusif oleh Mitra Tukang.
* **"Nota Sah"**: Nota Digital awal yang telah disetujui (*Approved*) oleh Pelanggan di ruang chat resmi Beres.
* **"Revisi Nota"**: Dokumen perubahan biaya yang diajukan oleh Mitra Tukang saat berada di lokasi kerja dan wajib disetujui oleh Pelanggan.

---

## 2. Model Pembayaran Langsung (Zero In-App Wallet / Zero Escrow — `BR-01` s/d `BR-04`)
1. **Tidak Ada Rekening Penampung (Escrow):** Beres **BUKAN** lembaga perbankan, penyedia jasa pembayaran, atau perantara dompet digital (*e-wallet*). Beres tidak menampung, memotong, atau menguasai uang jasa Pelanggan.
2. **Pembayaran 100% Langsung (P2P):** Pelanggan membayar biaya jasa dan material 100% secara langsung kepada Mitra Tukang melalui:
   * **Transfer Bank** langsung ke nomor rekening pribadi Mitra Tukang.
   * **Dompet Digital (E-Wallet)** langsung ke akun Mitra Tukang.
   * **Tunai (Cash)** langsung di lokasi kerja setelah pekerjaan selesai.
3. **Bebas Komisi Transaksi (MVP):** Pada versi MVP v1.4.0, Beres tidak memungut komisi atau potongan persenan dari nilai pekerjaan yang diselesaikan oleh Mitra Tukang.

---

## 3. Kekuatan Hukum Nota Digital & Revisi Nota (`BR-05` s/d `BR-08`)
1. **Nota Terkunci (*Immutable*):** Begitu Pelanggan menekan tombol *"Approve Nota"* di ruang chat, status pekerjaan berubah menjadi `NOTA_APPROVED` dan terbentuk **Nota Sah** yang mengikat kedua belah pihak. Nilai nominal Nota Sah tidak dapat diubah secara sepihak oleh Mitra Tukang.
2. **Larangan Praktik "Getok Harga":** Mitra Tukang dilarang menuntut pembayaran di luar nominal Nota Sah tanpa persetujuan tertulis dari Pelanggan.
3. **Mekanisme Tambahan Biaya Lapangan (Revisi Nota):**
   * Jika saat status `ARRIVED` atau `WORKING` ditemukan kerusakan tersembunyi yang memerlukan biaya tambahan, Mitra Tukang **WAJIB** menerbitkan **Revisi Nota** di dalam aplikasi.
   * Sistem secara otomatis menampilkan komparasi transparan di ruang chat Pelanggan: **Harga Awal vs Pengajuan Harga Baru**.
   * Revisi biaya **HANYA SAH** jika Pelanggan menekan tombol *"Approve"* atas Revisi Nota tersebut.
4. **Penarikan Revisi Nota:** Mitra Tukang berhak menarik kembali (*cancel/superseded*) Revisi Nota yang belum dijawab Pelanggan (`BR-08`) agar pekerjaan dapat segera diselesaikan mengacu pada Nota Sah sebelumnya.

---

## 4. Ketentuan Akun & Pendaftaran (`BR-10`, `BR-44`, `BR-45`)
1. **Aturan 1 Email = 1 Peran (`BR-44`):** Satu alamat email hanya boleh digunakan untuk satu jenis peran (`USER` atau `TUKANG`). Alamat email yang terdaftar sebagai Pelanggan tidak dapat digunakan untuk mendaftar sebagai Mitra Tukang (dan sebaliknya).
2. **Verifikasi Identitas Resmi (KYC):** Mitra Tukang wajib mengunggah foto KTP asli dan foto selfie memegang KTP yang valid sebelum diizinkan menerima pekerjaan.
3. **Hak Hapus Akun (`BR-45`):** Pengguna berhak menghapus akunnya sewaktu-waktu, sepanjang tidak sedang terikat dalam pekerjaan aktif atau sengketa pembayaran yang belum terselesaikan.

---

## 5. Tata Tertib Penawaran & Pekerjaan (`BR-15`, `BR-17`, `BR-65`)
1. **Batas Lamar Maksimal 5 Pekerjaan (`BR-15`):** Mitra Tukang hanya diperbolehkan melamar (*bid*) maksimal **5 pekerjaan terbuka** dalam satu waktu.
2. **Auto-Withdraw Lamaran Lain Saat Di-Lock (`BR-17`):** Saat Mitra Tukang dipilih dan di-lock oleh salah satu Pelanggan (misal Job C), seluruh lamaran aktif Mitra Tukang di pekerjaan lain (Job A, B, D, E) **SEKETIKA GUGUR DAN DITARIK OTOMATIS** oleh sistem. Mitra Tukang diwajibkan fokus pada satu pekerjaan hingga tuntas.
3. **Larangan Pembatalan Sepihak Saat Bekerja (`BR-65`):** Ketika status pekerjaan telah mencapai **`WORKING` (Sedang Dikerjakan)**, baik Pelanggan maupun Mitra Tukang **DILARANG KERAS** membatalkan pekerjaan. Mitra Tukang wajib menyelesaikan perbaikan sesuai kesepakatan Nota Sah.

---

## 6. Sistem Disiplin Strike & Sanksi Suspend Otomatis 48 Jam (`BR-57`, `BR-71`)
Demi menjamin kenyamanan bersama, Beres menerapkan sistem poin pelanggaran (**Strike**):
1. **Pemicu Strike Mitra Tukang:**
   * Tidak menekan tombol *"Berangkat ke Lokasi"* dalam waktu 30 menit setelah Nota disetujui (`BR-31`).
   * Membatalkan pekerjaan pada tahap `NOTA_APPROVED`, `ON_THE_WAY`, atau `ARRIVED` yang disetujui Pelanggan (`BR-55`).
   * Tidak sampai ke lokasi dalam waktu $\ge$ 3 jam dan di-cancel oleh Pelanggan tanpa respons 30 menit (`BR-56`).
2. **Pemicu Strike Pelanggan:**
   * Tidak aktif atau tidak merespons chat/panggilan Mitra Tukang selama lebih dari 30 menit saat Mitra Tukang sudah dalam perjalanan (`ON_THE_WAY`) atau tiba di lokasi (`ARRIVED`) (`BR-71`).
3. **Batas Toleransi & Sanksi Suspend:**
   * Toleransi maksimal adalah **3x Strike** dalam 1 bulan kalender lokal.
   * Pada **Strike ke-4 (lebih dari 3x)**, sistem secara otomatis memberlakukan **Sanksi Suspend 2 Hari Penuh (48 Jam)**. Selama periode suspend, akun tidak dapat melakukan aktivitas transaksi apapun.

---

## 7. Kebijakan Tegas Wanprestasi Pembayaran (`BR-67`)
1. **Kewajiban Pembayaran Pelanggan:** Pelanggan wajib melunasi pembayaran jasa dan material sesuai total nominal pada Nota Sah begitu pekerjaan fisik selesai (`COMPLETED`).
2. **Laporan Masalah Pembayaran:** Jika Pelanggan menolak membayar atau membayar kurang dari Nota Sah, Mitra Tukang berhak menekan tombol **"Laporkan Masalah Pembayaran"** (`BR-67`).
3. **Sanksi Suspend Permanen Langsung:**
   * Tim Investigasi Admin akan mengaudit bukti transkrip Chat, Nota Sah, dan Foto Hasil Kerja.
   * Jika Pelanggan terbukti bersalah melakukan wanprestasi, Admin akan **LANGSUNG MEMBERIKAN SANKSI SUSPEND PERMANEN (PEMBLOKIRAN SEUMUR HIDUP)** terhadap akun Pelanggan tersebut **TANPA PERINGATAN ATAU TOLERANSI 3X**.
   * Pengajuan banding hanya dapat dilakukan melalui surat resmi ke email operasional perusahaan.

---

## 8. Batasan Tanggung Jawab (Disclaimer of Warranties)
1. Mitra Tukang adalah penyedia jasa independen dan bukan merupakan karyawan, agen, atau perwakilan dari Beres.
2. Beres berupaya semaksimal mungkin memverifikasi identitas Mitra Tukang (KYC) dan menyediakan alat pencatatan yang mengikat (Nota Sah & Live Map GPS), namun mutu hasil perbaikan fisik merupakan tanggung jawab profesional Mitra Tukang yang bersangkutan.
3. Kerusakan lanjutan yang timbul akibat kelalaian teknis di luar lingkup yang disepakati pada Nota Sah diselesaikan secara musyawarah antara Pelanggan dan Mitra Tukang dengan merujuk pada bukti digital yang tercatat di Beres.
