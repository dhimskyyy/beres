# Kebijakan Privasi (Privacy Policy) — Project "Beres" (v1.4.0)

**Terakhir Diperbarui:** 21 Oktober 2026  
**Kepatuhan Regulasi:** Undang-Undang Republik Indonesia Nomor 27 Tahun 2022 tentang Perlindungan Data Pribadi (UU PDP) & Ketentuan Google Play / Apple App Store.

---

## 1. Pendahuluan & Komitmen Privasi
Aplikasi **Beres** (terdiri dari aplikasi *Beres User*, *Beres Mitra Tukang*, dan *Beres Web Admin*) dioperasikan dengan komitmen tertinggi untuk melindungi dan menghormati data pribadi pengguna. Kebijakan ini menjelaskan bagaimana kami mengumpulkan, memproses, menyimpan, dan melindungi data pribadi Anda sesuai dengan **UU PDP No. 27 Tahun 2022**.

Dengan mengunduh, mendaftar, atau menggunakan ekosistem aplikasi Beres, Anda menyatakan telah membaca, memahami, dan menyetujui seluruh ketentuan dalam Kebijakan Privasi ini.

---

## 2. Data Pribadi yang Kami Kumpulkan

### A. Pengguna (Beres User)
1. **Data Identitas & Kontak:** Alamat email, nama lengkap, dan nomor telepon WhatsApp yang valid.
2. **Data Lokasi (Geolokasi):** Koordinat GPS perangkat saat membuat postingan pekerjaan dan label wilayah kelurahan/kecamatan (`area_label`). Pin lokasi postingan hanya dapat digeser maksimal **2 km** dari titik GPS fisik saat memposting (`FR-010`).
3. **Data Komunikasi:** Riwayat percakapan teks, gambar/foto kerusakan yang dikirimkan di dalam ruang chat resmi Beres (`chat_messages`).
4. **Data Transaksi:** Riwayat pekerjaan, Nota Digital yang disetujui, metode pembayaran yang dipilih, dan bukti pembayaran (jika non-tunai).

### B. Mitra (Beres Mitra / Tukang)
1. **Data Identitas Resmi (KYC):** Foto Kartu Tanda Penduduk (KTP) dan foto *selfie* memegang KTP (`kyc_documents`).
2. **Data Keahlian & Rekening:** Kategori keahlian pertukangan yang dipilih, biografi keahlian, nomor rekening bank pribadi, dan akun dompet digital (e-wallet) untuk tujuan penerimaan pembayaran langsung dari pelanggan.
3. **Data Lokasi Real-Time & Latar Belakang (Background Location):** Koordinat GPS perangkat saat berstatus `Online`, serta pelacakan real-time kontinu saat sedang menjalankan tugas berstatus `ON_THE_WAY`, `ARRIVED`, dan `WORKING` (`location_pings`).
4. **Bukti Pekerjaan:** Foto bukti hasil kerja fisik dan dokumentasi lapangan (`job_photos`).

---

## 3. Prinsip Perlindungan & Kerahasiaan Data (Data Minimization)

### A. Kerahasiaan Alamat Sebelum Penguncian Tukang (Lock Tukang — `BR-16`)
Sebelum Pelanggan secara resmi memilih dan mengunci satu Mitra Tukang (*Lock Tukang*):
* Mitra Tukang yang melihat pekerjaan di Bursa Kerja **HANYA** dapat melihat deskripsi pekerjaan, kategori, foto kerusakan, dan nama Kelurahan/Kecamatan (`area_label`).
* Alamat lengkap, nomor rumah, nama lengkap, foto profil, dan nomor kontak Pelanggan **SEPENUHNYA DISEMBUNYIKAN** dan tidak dapat diakses oleh Mitra Tukang maupun pihak ketiga.
* Sebaliknya, Pelanggan hanya melihat data profesional Mitra Tukang (nama panggilan, keahlian, hari aktif, dan ulasan rating).

### B. Keamanan Dokumen KYC & Bucket Privat (`NFR-03`, `NFR-04`)
* Dokumen identitas KTP Mitra Tukang disimpan di dalam media penyimpanan terenkripsi khusus (`kyc-private`).
* Akses ke dokumen ini dibatasi ketat melalui otorisasi *Row-Level Security* (RLS) PostgreSQL dan hanya dapat dilihat oleh Tim Verifikasi Admin melalui tautan sementara (*Signed URL*) berumur pendek (maksimal 15 menit).

---

## 4. Penggunaan Izin Lokasi Latar Belakang (Background Location Disclosure)
Aplikasi **Beres Mitra (Tukang)** memerlukan izin lokasi latar belakang (*Background Location Permission*):
* **Tujuan Penggunaan:**
  1. Memberikan perkiraan waktu kedatangan (*ETA*) yang akurat kepada Pelanggan saat Tukang dalam perjalanan (`ON_THE_WAY`).
  2. Memicu deteksi kedatangan otomatis secara objektif ketika jarak fisik Tukang berada pada radius $\le$ **50 meter** dari lokasi kerja (`BR-60`).
  3. Memastikan transparansi keberadaan Tukang saat berada di lokasi kerja (`WORKING`) demi keamanan Pelanggan dan Tukang.
* **Jaminan:** Kami **TIDAK** melacak atau merekam lokasi latar belakang Tukang saat aplikasi berstatus `Offline` atau saat Tukang tidak sedang memiliki tugas berjalan aktif.

---

## 5. Penyimpanan & Keamanan Data (Security & Encryption)
1. **Transmisi Data:** Seluruh komunikasi data antara aplikasi mobile, web admin, dan server dilindungi menggunakan enkripsi standar industri **TLS 1.3 / HTTPS**.
2. **Basis Data Terisolasi:** Basis data kami menerapkan arsitektur *Role-Based Access Control* (RBAC) dan *Row-Level Security* (RLS) pada tingkat baris database, menjamin Pengguna hanya dapat membaca dan menulis data miliknya sendiri.
3. **Autentikasi Multi-Faktor (MFA):** Seluruh akses administratif ke Web Admin diwajibkan menggunakan MFA (Password + One-Time Password 2 Langkah).

---

## 6. Hak-Hak Pemilik Data Pribadi (Sesuai UU PDP)
Sebagai pemilik data pribadi, Anda memiliki hak-hak yang dijamin oleh undang-undang:
1. **Hak untuk Mendapatkan Informasi:** Mengetahui tujuan pemrosesan data pribadi Anda melalui Kebijakan Privasi ini.
2. **Hak Pembaruan Data:** Memperbarui data profil, nomor telepon, dan nomor rekening melalui menu Profil di aplikasi.
3. **Hak Penghapusan Akun & Data (Right to Erasure — `BR-45` / `FR-004`):**
   * Pengguna (User maupun Tukang) dapat mengajukan penghapusan akun mandiri langsung melalui tombol **"Hapus Akun"** di dalam menu Pengaturan aplikasi.
   * **Syarat:** Permintaan penghapusan akun akan diproses selama tidak terdapat pekerjaan yang sedang berjalan aktif (`NEGOTIATING`, `NOTA_APPROVED`, `ON_THE_WAY`, `ARRIVED`, `WORKING`) atau sengketa pembayaran aktif yang belum selesai.
   * Setelah akun dihapus, data identitas pribadi Anda akan dianonimkan secara permanen dari sistem aktif kami.

---

## 7. Retensi & Penyimpanan Log Audit
Untuk keperluan audit operasional, pembuktian sengketa hukum, dan penegakan keadilan sengketa pembayaran (`BR-67`), data transkrip chat, Nota Sah, dan histori pekerjaan disimpan secara aman dalam log audit selama batas waktu wajar yang diatur oleh peraturan perundang-undangan di Indonesia sebelum diarsipkan atau dianonimkan.

---

## 8. Kontak Petugas Perlindungan Data (Data Protection Officer / DPO)
Jika Anda memiliki pertanyaan, keberatan, atau ingin menggunakan hak-hak perlindungan data pribadi Anda, silakan hubungi Tim Kepatuhan Privasi kami melalui:
* **Email Resmi:** `privacy@beres.id` / `dpo@beres.id`
* **Alamat Operasional:** Beres Indonesia — PT Aplikasi Tukang Nusantara, Jakarta, Indonesia.
