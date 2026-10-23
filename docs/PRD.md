# PRD: Beres — Marketplace Jasa Pertukangan On-Demand

| Field | Nilai |
| :--- | :--- |
| **Produk** | Ekosistem Beres (Beres User, Beres Mitra, Beres Web Admin) |
| **Versi Dokumen** | 1.4.0 |
| **Status** | Final MVP Baseline — Seluruh OQ 🔴 telah diputuskan & aturan bisnis v1.4 dikunci |
| **Owner** | mhmmddhimas |
| **Sumber** | `detail.md` & Sesi Audit/Review Owner |
| **Dokumen Terkait** | `docs/ARCHITECTURE.md`, `docs/DATABASE_SCHEMA.md`, `docs/ROADMAP.md`, `AGENTS.md` |
| **Terakhir Diperbarui** | 2026-10-18 |

### Riwayat Revisi

| Versi | Tanggal | Perubahan | Penulis |
| :--- | :--- | :--- | :--- |
| 1.0.0 | 2026-10-18 | Draft awal, diturunkan dari `detail.md` | — |
| 1.1.0 | 2026-10-18 | **(1)** Langganan Gold dan Boost **ditunda seluruhnya ke Phase 2** (dicatat di Lampiran A). **(2)** Radius MVP: job maks 50 km, slider tukang 0–50 km. **(3)** Pembatalan bertingkat + status `CANCELLED` dan `EXPIRED`. **(4)** Kuota dicek di titik kritis, dihitung dari `completed_at`. **(5)** Lokasi dasar tukang, privasi alamat, enum Nota, iOS background location. **(6)** Login via email OTP. **(7)** Bagian 18 dipisah jadi Log Keputusan dan Open Questions | — |
| 1.2.0 | 2026-10-18 | **(1)** Alur pembatalan oleh Tukang: *slide-to-cancel*, dialog konfirmasi, status **`CANCEL_PENDING`**, form pembatalan (semua detail untuk Admin, User hanya melihat alasan), persetujuan User, batas 3 pembatalan/bulan lalu suspend otomatis 2 hari. **(2)** Pin job boleh digeser maks 2 km dari GPS HP, tanpa label. **(3)** Backend Supabase saja. **(4)** Expiry 24 jam, lokasi basi 60 menit, bid tukang pembatal ditarik | — |
| 1.3.0 | 2026-10-18 | **(1)** `WORKING` **tidak dapat dibatalkan** oleh User maupun Tukang. **(2)** Status baru **`ARRIVED`**, lalu "Mulai Bekerja" manual; total 10 status. **(3)** Alur penyelesaian: foto hasil kerja, konfirmasi "User sudah membayar", bukti bayar untuk transfer/e-wallet (tunai tanpa unggahan). **(4)** Batas waktu respons chat 30 menit. **(5)** Zona waktu lokal (WIB/WITA/WIT) untuk batas minggu/bulan | — |
| **1.4.0** | **2026-10-18** | **(1) Aturan Lamaran (Bid) Maks 5 Job & Auto-Clear Saat Lock:** Tukang boleh melamar maks 5 job (`OPEN`); begitu di-lock oleh 1 User, seluruh lamaran di job lain otomatis ditarik/hilang. **(2) Revisi Nota Wajib Persetujuan User:** Nota awal yang sudah disetujui bersifat sah & terkunci; perubahan harga wajib lewat Revisi Nota dengan notifikasi jelas perbandingan harga lama vs baru di chat User & wajib di-Approve User; Tukang dapat menarik Revisi Nota yang belum dijawab. **(3) Timer 30 Menit Klik "Berangkat" setelah `NOTA_APPROVED`:** Jika Tukang tidak klik Berangkat dalam 30 menit, job otomatis dilepas kembali ke portal (`OPEN`) dan Tukang kena 1 Strike (lebih dari 3x = suspend 2 hari). **(4) Penyempurnaan Aturan Strike & Chat:** Saat `NEGOTIATING` (sebelum Nota disetujui), ketidakaktifan chat > 30 menit oleh User maupun Tukang melepas job kembali ke portal **tanpa Strike** bagi siapa pun. Sebaliknya, jika sudah `ON_THE_WAY` atau `ARRIVED` dan **User** tidak membalas chat > 30 menit, **User kena 1 Strike** (lebih dari 3x = suspend 2 hari). **(5) Investigasi & Suspend Langsung User Tidak Membayar:** Tombol khusus lapor masalah pembayaran di tahap `WORKING`; jika User terbukti tidak mau bayar/kurang dari Nota, Admin langsung men-suspend akun User **tanpa pemakluman 3x** (banding via email resmi). **(6) Aturan `ON_THE_WAY` > 3 Jam & `ARRIVED`:** User tidak bisa cancel saat `ON_THE_WAY` di bawah 3 jam maupun saat `ARRIVED`; jika `ON_THE_WAY` $\ge$ 3 jam belum sampai, muncul tombol Cancel bagi User (butuh persetujuan tukang, atau auto-cancel + 1 strike tukang jika tukang tidak merespons 30 menit). **(7) Kedatangan Otomatis $\le$ 50 m & Fallback Manual $\le$ 200 m.** **(8) Satu Email Satu Peran, Hapus Akun, Reverse Geocoding via OS HP, MFA Admin, Perbaikan Draft `CANCEL_PENDING`, dan Lampiran C (FAQ & Aturan Tertulis Lengkap).** | **mhmmddhimas** |

---

## 0. Cara Membaca & Menggunakan Dokumen Ini

Dokumen ini adalah **sumber kebenaran (source of truth)** untuk *apa* yang dibangun dan *kenapa*. Keputusan *bagaimana* (arsitektur, skema detail, struktur kode) ada di dokumen terkait.

### 0.1 Konvensi

- **Kata kunci kebutuhan** mengikuti RFC 2119: **HARUS** (wajib), **DILARANG** (tidak boleh), **SEBAIKNYA** (disarankan), **DAPAT** (opsional).
- **ID unik** agar bisa dilacak ke kode, test, dan tiket:
  `G-xx` Goal, `NG-xx` Non-goal, `BR-xx` Business Rule, `FR-xxx` Functional Requirement, `NFR-xx` Non-Functional Requirement, `EV-xx` Analytics Event, `RISK-xx` Risiko, `D-xx` Keputusan, `OQ-xx` Open Question.
- **ID bersifat stabil.** Requirement yang ditunda ke Phase 2 **tidak dihapus**, melainkan ditandai **`[DITUNDA]`** agar penomoran tidak bergeser.
- **Prioritas:** `P0` = wajib MVP, `P1` = penting tapi boleh menyusul, `P2` = Phase 2.
- Tanda **(v1.1)** / **(v1.2)** / **(v1.3)** / **(v1.4)** = ditambah atau diubah pada versi tersebut.

### 0.2 Aturan untuk AI Coding Agent

1. DILARANG menambah fitur, tabel, library, atau layar di luar dokumen ini. Fitur di Bagian 3.2 (Non-Goals) dan Lampiran A (Phase 2) DILARANG dikerjakan di MVP.
2. Kerjakan **satu milestone per sesi** (Bagian 15). Jangan lanjut sebelum *Definition of Done* (Bagian 16) terpenuhi.
3. Jika menemukan requirement ambigu atau bertabrakan, **berhenti dan tanyakan**. Jangan menebak.
4. Semua **Business Rule (BR)** HARUS ditegakkan di **server/database** (trigger, RLS, constraint, fungsi atomik), bukan hanya di UI.
5. Setiap FR yang selesai HARUS punya test yang merujuk ID-nya (contoh: nama test memuat `FR-031`).
6. Setiap perubahan perilaku HARUS memperbarui dokumen ini (naikkan versi dan isi riwayat revisi).
7. **Hook Phase 2** (kolom DB yang disiapkan untuk Gold/Boost) boleh dibuat di skema, tetapi DILARANG dipakai oleh UI atau logika MVP.

---

## 1. Ringkasan Eksekutif

**Beres** adalah platform marketplace jasa pertukangan *on-demand* di Indonesia. Pelanggan memposting masalah (listrik korslet, pipa bocor, motor mogok, dll.), tukang di sekitar lokasi menawar (*bid*), lalu pelanggan memilih satu tukang dan menyepakati harga lewat **Nota Digital** di ruang chat sebelum pekerjaan dimulai.

Pembeda utama:

1. **Zero In-App Wallet:** pelanggan membayar 100% langsung ke tukang (transfer, e-wallet, atau tunai). Platform tidak memegang dana sehingga bebas dari regulasi e-money/escrow dan tidak memotong komisi per order.
2. **Harga transparan & sah lewat Nota Digital:** harga wajib disepakati dan di-*approve* sebelum tukang berangkat. Tukang tidak dapat mengubah harga Nota yang sudah sah secara sepihak; setiap tambahan biaya di lapangan wajib diajukan lewat **Revisi Nota (Adendum)** yang memberi notifikasi jelas ke pelanggan dan wajib disetujui kembali oleh pelanggan.
3. **Keamanan dan pengawasan:** semua tukang lolos verifikasi KTP (KYC), lokasi tukang dilacak GPS real-time saat bertugas, serta wajib ada foto bukti hasil kerja dan bukti pembayaran (untuk non-tunai).
4. **Monetisasi (Phase 2):** rencana pendapatan dari Langganan Bulanan Tukang (Gold) dan Boost pekerjaan oleh user. **MVP belum memiliki fitur berbayar apa pun** (lihat Lampiran A).

Ekosistem terdiri dari tiga aplikasi yang tersinkron real-time: **Beres User** (Flutter), **Beres Mitra/Tukang** (Flutter), dan **Beres Web Admin** (Next.js).

---

## 2. Latar Belakang & Problem Statement

### 2.1 Masalah

| Pihak | Masalah | Dampak |
| :--- | :--- | :--- |
| **Pelanggan** | Sulit menemukan tukang terpercaya saat mendadak; harga disepakati lisan lalu berubah ("getok harga"); sulit menilai kualitas | Biaya tidak terduga, risiko keamanan, kualitas tidak konsisten |
| **Tukang** | Order tidak merata; aplikator besar memotong 20%–30% per order dan menahan dana; tidak bebas menentukan harga; risiko pelanggan tidak mau bayar setelah kerja selesai | Pendapatan bersih turun, kerugian tenaga & material |
| **Pengelola** | Model escrow/e-money mahal secara regulasi dan operasional | Hambatan masuk pasar, biaya tinggi |

### 2.2 Peluang

Kebutuhan jasa perbaikan di Indonesia tersebar, mendesak, dan didominasi pasar informal. Model "tanpa komisi, bayar langsung dengan bukti Nota sah, bisnis dari langganan" memosisikan Beres sebagai opsi yang lebih adil bagi tukang sekaligus lebih sederhana secara regulasi.

---

## 3. Tujuan & Non-Tujuan

### 3.1 Goals

| ID | Goal | Pihak |
| :--- | :--- | :--- |
| G-01 | Pelanggan dapat memposting pekerjaan dan menerima bid dari tukang terverifikasi di sekitar lokasinya | User |
| G-02 | Harga disepakati tertulis (Nota) sebelum pekerjaan dimulai, tanpa perubahan sepihak | User, Tukang |
| G-03 | Tukang menerima 100% uang jasa langsung tanpa komisi per order | Tukang |
| G-04 | Seluruh tukang aktif telah lolos verifikasi KYC oleh Admin | Platform |
| G-05 | Lokasi tukang terpantau real-time selama `ON_THE_WAY`, `ARRIVED`, dan `WORKING` | User, Admin |
| G-06 | Setiap pekerjaan selesai memiliki foto hasil kerja, konfirmasi pembayaran, dan bukti bayar untuk pembayaran non-tunai | Platform |
| G-07 | Platform tidak menyimpan atau memproses dana pelanggan/tukang di MVP | Platform |
| G-08 | Admin dapat mengelola kategori, KYC, akun, dan menangani pembatalan/laporan sengketa tanpa rilis ulang aplikasi | Admin |

### 3.2 Non-Goals (DILARANG dikerjakan di MVP)

| ID | Non-Goal |
| :--- | :--- |
| NG-01 | Dompet digital, escrow, saldo, withdraw, atau pemrosesan pembayaran order apa pun di dalam aplikasi |
| NG-02 | **(v1.1, D-02)** **Langganan Gold dalam bentuk apa pun**: pembayaran DOKU, toggle manual oleh Admin, Gold Badge, kuota unlimited, radius 100 km, pin teratas, *headstart* notifikasi |
| NG-03 | **(v1.1)** **Boost** pekerjaan (radius 100 km, pin teratas, iklan) |
| NG-04 | Komisi per order atau biaya layanan per transaksi |
| NG-05 | Pembuatan Nota oleh User (Nota HANYA dibuat oleh Tukang) |
| NG-06 | Panggilan suara/video di dalam aplikasi |
| NG-07 | Penjadwalan pekerjaan di masa depan (booking terjadwal). MVP hanya *on-demand* |
| NG-08 | Aplikasi web untuk User/Tukang |
| NG-09 | Mediasi finansial/pengembalian dana otomatis oleh sistem. MVP menyediakan fitur **Laporkan** (termasuk Laporan Masalah Pembayaran) + investigasi & tindakan tegas oleh Admin (FR-041, BR-67) |
| NG-10 | Multi-bahasa (MVP hanya Bahasa Indonesia) |
| NG-11 | **(v1.1)** Verifikasi nomor HP via SMS/WhatsApp OTP. Login MVP memakai email OTP (D-09) |
| NG-12 | **(Diperbarui)** ~~Satu email untuk dua peran~~. Kini 1 alamat email **DIPERBOLEHKAN** untuk 2 peran (`USER` dan `TUKANG`) dengan role `BOTH` sesuai BR-44 |

---

## 4. Success Metrics

### 4.1 Primary

| Metrik | Definisi | Target (90 hari pasca rilis) |
| :--- | :--- | :--- |
| Job Completion Rate | `COMPLETED` ÷ job yang mencapai `NOTA_APPROVED` | ≥ 85% |
| Time to First Bid | Median waktu dari `OPEN` ke bid pertama | ≤ 10 menit |
| Bid Coverage | % job `OPEN` yang menerima ≥ 1 bid dalam 30 menit | ≥ 70% |

### 4.2 Secondary

| Metrik | Target |
| :--- | :--- |
| Rata-rata rating tukang | ≥ 4.3 / 5 |
| Waktu verifikasi KYC (submit → keputusan) | Median ≤ 24 jam |
| Nota di-approve pada percobaan pertama | ≥ 50% |
| Job `EXPIRED` ÷ job dibuat | ≤ 20% |

### 4.3 Guardrail (tidak boleh memburuk)

| Metrik | Batas |
| :--- | :--- |
| Job `COMPLETED` tanpa foto bukti hasil kerja | **0** |
| Tukang non-KYC yang berhasil bid | **0** |
| Tukang dengan `COMPLETED` > 5 dalam satu minggu (MVP) | **0** |
| Tukang atau User dengan > 3 Strike dalam satu bulan kalender **tanpa** terkena suspend otomatis 2 hari **(v1.4)** | **0** |
| Job `COMPLETED` dengan metode bayar aktual non-tunai tanpa bukti bayar **(v1.4)** | **0** |
| Pembatalan setelah `NOTA_APPROVED` ÷ job `NOTA_APPROVED` | ≤ 10% |
| Waktu muat Live Map Admin | p95 ≤ 3 detik |
| Crash-free sessions aplikasi mobile | ≥ 99% |

---

## 5. Pengguna & Persona

### 5.1 Persona

| Persona | Deskripsi | Kebutuhan Utama | Pain Point |
| :--- | :--- | :--- | :--- |
| **Pelanggan (User)** | Pemilik/penyewa rumah, kos, kantor, atau pengendara yang butuh bantuan mendadak | Tukang cepat, terpercaya, harga jelas & tidak berubah sepihak | Takut ditipu, tidak tahu harga wajar, tukang tidak datang |
| **Mitra Tukang** | Tukang mandiri, kurang terbiasa dengan aplikasi kompleks. Di MVP semua tukang berstatus Standar (kuota 5 selesai/minggu, maksimal lamar 5 job bersamaan, radius maks 50 km) | Akses order di sekitar lokasi, uang diterima penuh 100%, kepastian dibayar | Potongan komisi aplikator lain, pelanggan kabur/tidak mau bayar |
| **Mitra Tukang Gold** | *(Phase 2, belum ada di MVP. Lihat Lampiran A)* | Order tanpa batas, jangkauan lebih luas | Persaingan |
| **Admin** | Tim operasional Beres | Verifikasi KTP cepat, pantau lapangan, investigasi laporan pembayaran & pembatalan | Kurang visibilitas, penipuan identitas |

### 5.2 User Stories (ringkas)

- Sebagai **User**, saya ingin memposting masalah beserta foto dan lokasi, supaya tukang di sekitar saya bisa menawar.
- Sebagai **User**, saya ingin melihat nama, foto profil, keahlian, hari aktif, dan rating tukang yang menawar, supaya saya memilih yang terpercaya.
- Sebagai **User**, saya ingin menyetujui harga di Nota sebelum tukang berangkat dan wajib dimintai persetujuan lagi jika ada Revisi Nota, supaya tidak ada perubahan harga sepihak.
- Sebagai **User**, saya ingin job saya otomatis dilepas kembali ke portal jika tukang tidak berangkat dalam 30 menit setelah Nota disetujui, supaya saya bisa mencari tukang lain tanpa mengetik ulang postingan.
- Sebagai **User**, saya ingin tombol Cancel muncul jika tukang sudah `ON_THE_WAY` selama 3 jam namun tak kunjung tiba, supaya saya tidak terjebak.
- Sebagai **User**, saya ingin menyetujui atau menolak permintaan pembatalan dari tukang dan hanya melihat alasannya, supaya saya yang menentukan nasib pekerjaan saya.
- Sebagai **User**, saya ingin alamat lengkap dan nama saya hanya dilihat tukang yang saya pilih (*lock*), supaya privasi terjaga.
- Sebagai **Tukang**, saya ingin melamar hingga 5 pekerjaan terbuka sekaligus, dan begitu saya di-*lock* di satu pekerjaan maka lamaran saya di pekerjaan lain otomatis ditarik, supaya saya fokus pada satu pelanggan.
- Sebagai **Tukang**, saya ingin menyusun Nota sendiri setelah diskusi, dan dapat menarik kembali Revisi Nota yang belum dijawab pelanggan, supaya pekerjaan tidak macet.
- Sebagai **Tukang**, saya ingin tombol khusus untuk melaporkan pelanggan yang tidak mau membayar atau membayar kurang saat pekerjaan selesai, supaya Admin dapat menindak tegas pelanggan tersebut.
- Sebagai **Admin**, saya ingin memverifikasi KTP, memantau peta live, mengaudit chat/nota/foto, serta menginvestigasi dan langsung men-suspend pelanggan yang terbukti tidak membayar.

---

## 6. Ruang Lingkup & Fase Rilis

### 6.1 MVP (Phase 1) — P0

- Auth (email OTP, **1 email = 1 peran**; Admin dilengkapi MFA) dan profil User & Tukang + fitur **Hapus Akun**
- KYC Tukang + verifikasi Admin
- Kategori dinamis (dikelola Admin)
- Posting job (jangkauan maks **50 km**), batas lamar maks **5 job aktif** per tukang, auto-clear lamaran lain saat tukang di-lock
- Lokasi dasar tukang untuk filter radius (BR-26) & Reverse Geocoding nama kecamatan via OS perangkat
- Chat real-time, Nota & Revisi Nota (dengan notifikasi perbandingan harga & fitur tarik revisi), timer chat 30 menit di `NEGOTIATING` (lepas ke portal tanpa strike)
- State machine 10 status:
  - Timer **30 menit wajib klik "Berangkat"** setelah `NOTA_APPROVED` (lewat 30 menit $\rightarrow$ lepas ke portal + 1 strike tukang)
  - Deteksi `ARRIVED` otomatis di **$\le$ 50 m** + fallback manual **$\le$ 200 m**
  - Batas **3 jam `ON_THE_WAY`** untuk memunculkan opsi Cancel bagi User
  - Timer **30 menit respons chat User** saat tukang sudah `ON_THE_WAY` / `ARRIVED` (lewat 30 menit $\rightarrow$ 1 strike User)
  - Pembatalan oleh Tukang lewat *slide-to-cancel* + persetujuan User (+ 1 strike tukang bila disetujui)
- Live GPS Tracking
- Penyelesaian: foto hasil kerja (wajib), pilihan metode bayar aktual, konfirmasi "User sudah membayar", bukti bayar untuk transfer/e-wallet, serta tombol khusus **"Laporkan Masalah Pembayaran"** jika User menolak bayar/kurang
- Rating & review
- Kuota mingguan 5 job `COMPLETED` per tukang
- FAQ & Aturan Tertulis di dalam aplikasi (Lampiran C)
- Push notification (FCM)
- Web Admin: Live Map, monitoring, audit, KYC, suspend/ban (termasuk suspend langsung tanpa 3x bagi User yang tidak bayar), pembatalan paksa, antrean permintaan pembatalan, antrean laporan, kategori, konfigurasi sistem, dashboard analitik

### 6.2 Phase 2 (DILARANG di MVP, ringkasan di Lampiran A)

- Langganan **Gold** (semua privilese & toggle manual Admin) dan pembayarannya via **DOKU**
- **Boost** pekerjaan (radius 100 km)
- Migrasi Map Provider dari OpenStreetMap ke Google Maps (via adapter)

---

## 7. Glosarium

| Istilah | Definisi |
| :--- | :--- |
| **Job / Pekerjaan** | Postingan masalah oleh User yang menjadi tiket kerja |
| **Bid / Lamaran** | Minat tukang untuk mengambil job (maksimal 5 bid aktif bersamaan per tukang; otomatis ditarik dari job lain begitu di-lock di 1 job) |
| **Lock** | Tindakan User memilih tepat 1 tukang dari daftar bid |
| **Nota Sah** | Kartu kesepakatan harga digital di chat yang dibuat oleh Tukang dan telah di-*Approve* oleh User. Bersifat terkunci (*immutable*) |
| **Revisi Nota (Adendum)** | Pengajuan perubahan harga oleh Tukang saat di lokasi (`ARRIVED`/`WORKING`). Menampilkan perbandingan harga lama vs baru dan **wajib** disetujui User sebelum menggantikan Nota Sah |
| **KYC** | Verifikasi identitas tukang: Foto KTP + Selfie memegang KTP |
| **Lokasi Dasar** | Posisi kasar terakhir tukang saat aplikasi dibuka dalam kondisi Online, dipakai untuk filter radius. Berbeda dari Live Tracking |
| **Live Tracking** | Pengiriman GPS akurat dan sering selama `ON_THE_WAY`, `ARRIVED`, dan `WORKING` |
| **ARRIVED** | **(v1.4)** Status "tukang sampai": otomatis saat tukang berada ≤ 50 m dari titik job (atau manual ≤ 200 m) |
| **Strike Tukang** | **(v1.4)** Poin pelanggaran tukang karena: (1) tidak klik "Berangkat" dalam 30 menit setelah `NOTA_APPROVED`, atau (2) membatalkan pekerjaan setelah `NOTA_APPROVED`/`ON_THE_WAY`/`ARRIVED`. Lebih dari 3x (> 3, yaitu ke-4) dalam 1 bulan = **suspend otomatis 2 hari penuh** |
| **Strike User** | **(v1.4)** Poin pelanggaran User karena tidak aktif / tidak membalas chat tukang selama > 30 menit saat tukang sudah berstatus `ON_THE_WAY` atau `ARRIVED`. Lebih dari 3x (> 3, yaitu ke-4) dalam 1 bulan = **suspend otomatis 2 hari penuh** |
| **Pelanggaran Pembayaran User** | **(v1.4)** Pelanggaran berat saat User tidak mau membayar atau membayar kurang dari Nota Sah setelah pekerjaan selesai. Ditindak langsung oleh Admin dengan **suspend permanen tanpa toleransi 3x** |
| **CANCEL_PENDING** | Status saat Permintaan Pembatalan sudah dikirim (`SUBMITTED`) dan menunggu persetujuan pihak lawan |
| **Kuota Mingguan** | Batas 5 job `COMPLETED` per minggu per tukang |
| **Zero In-App Wallet** | Prinsip platform tidak menyimpan/mengelola dana transaksi order |

---

## 8. Aturan Bisnis (Business Rules)

### 8.1 Pembayaran, Nota Sah, & Revisi Nota (v1.4)

| ID | Aturan | Penegakan |
| :--- | :--- | :--- |
| BR-01 | Platform DILARANG menyimpan, menerima, atau meneruskan dana order. Pembayaran terjadi 100% langsung User → Tukang di luar aplikasi | Desain sistem |
| BR-02 | Metode bayar pada Nota dan Form Penyelesaian HANYA: `BANK_TRANSFER`, `E_WALLET`, `CASH` | Enum DB |
| BR-03 | Tidak ada komisi atau biaya per order | Desain sistem |
| BR-04 | Hanya Tukang yang dapat membuat Nota dan Revisi Nota. User hanya dapat *Approve*, *Tolak / Nego Ulang*, atau *Batalkan* | RLS + validasi server |
| BR-05 | **(v1.4)** Begitu Nota awal disetujui User (`APPROVED`), terbentuk **Nota Sah yang terkunci (*immutable*)**. Tukang DILARANG mengedit langsung Nota yang sudah sah. Jika Tukang ingin menambah/mengubah biaya di lapangan (`ARRIVED`/`WORKING`), Tukang WAJIB mengirim **Revisi Nota** baru. Aplikasi User WAJIB menampilkan notifikasi di chat yang memperlihatkan jelas **Harga Nota Awal vs Harga Revisi Baru**, dan perubahan harga tersebut **TIDAK SAH sebelum User menekan tombol *Approve*** | Trigger DB + Server |
| BR-06 | Rekening bank/e-wallet tukang dicantumkan otomatis pada Nota dari profil tukang | Server |
| BR-07 | Status Nota HANYA salah satu dari: `SENT`, `APPROVED`, `REJECTED`, `SUPERSEDED`, `VOID` (lihat 9.6) | Enum DB |
| BR-08 | **(v1.4)** Tukang DAPAT **menarik kembali (membatalkan)** Revisi Nota yang masih berstatus `SENT` (belum dijawab User). Saat ditarik, status Revisi Nota menjadi `SUPERSEDED` dan **Nota Sah sebelumnya tetap berlaku**, sehingga tidak memblokir penyelesaian tugas | Fungsi server |

### 8.2 Bidding (Maks 5 Job), Lock Otomatis Tarik Bid Lain, & Privasi (v1.4)

| ID | Aturan | Penegakan |
| :--- | :--- | :--- |
| BR-10 | Hanya tukang `KYC = APPROVED`, tidak suspended, dan `Online` yang dapat melihat job dan melakukan bid | RLS |
| BR-11 | Job tersebar ke tukang yang kategorinya cocok DAN `jarak(lokasi_job, lokasi_dasar_tukang) ≤ radius_tukang` (maks 50 km di MVP) | Query PostGIS |
| BR-12 | Satu job di-*lock* ke tepat **1 tukang** pada satu waktu | Constraint DB |
| BR-13 | Daftar bid ke User diurutkan berdasarkan waktu bid (terlama di atas) | Query |
| BR-14 | Jika batal di `NEGOTIATING`, job kembali `OPEN` di Job Portal. Kuota selesai mingguan tukang tidak terpotong | Fungsi server |
| BR-15 | **(v1.4)** Satu tukang hanya boleh memiliki maksimal **5 bid aktif (`ACTIVE`)** pada job berstatus `OPEN` dalam satu waktu. Jika sudah melamar 5 job (misal Job A, B, C, D, E), tukang DILARANG melamar job ke-6 sebelum salah satu lamarannya ditarik atau selesai | Fungsi server atomik |
| BR-16 | **(v1.4)** **Privasi Sebelum Lock:** Sebelum di-lock, Tukang HANYA melihat detail pekerjaan (kategori, deskripsi, foto kerusakan, jarak perkiraan, dan nama Kelurahan/Kecamatan), **tanpa** melihat nama User, foto User, nomor HP, atau alamat lengkap. Sebaliknya, pada daftar bid, User HANYA melihat **foto profil tukang, nama tukang, keahlian, hari aktif, dan rating/ulasan tukang**. Alamat lengkap dan koordinat tepat User HANYA terbuka bagi 1 tukang yang sedang di-*lock*, dan dicabut kembali bila job kembali ke `OPEN` atau `CANCELLED` | RLS + view khusus |
| BR-17 | **(v1.4 — Menggantikan aturan lama)** **Auto-Clear Bid Saat Di-Lock:** Begitu seorang tukang di-*lock* oleh User pada satu job (misal Job C), maka **seluruh bid/lamaran aktif tukang tersebut pada job lain (Job A, B, D, E) OTOMATIS ditarik (`WITHDRAWN`) dan dihapus dari daftar lamaran aktif tukang tersebut**. Dengan aturan ini, 1 tukang dijamin hanya pernah menangani **tepat 1 job** sejak tahap `NEGOTIATING` hingga `COMPLETED`. Jika nantinya Job C batal, tukang harus mulai melamar (*apply/bid*) lagi dari awal di Job Portal | Transaksi atomik server (T2) |

### 8.3 Kuota, Radius, dan Lokasi

| ID | Aturan | Penegakan |
| :--- | :--- | :--- |
| BR-20 | Slider radius tukang: **0–50 km** untuk semua tukang di MVP | Validasi server |
| BR-21 | Kuota: maksimal **5 job `COMPLETED` per minggu** per tukang. Dihitung langsung dari job `COMPLETED` dengan `completed_at` dalam minggu berjalan (Senin 00:00 sampai Minggu 23:59 menurut **zona waktu lokal tukang**, BR-75). **DILARANG** memakai counter yang di-reset cron | Query/fungsi DB |
| BR-22 | Kuota terpotong **hanya** saat `COMPLETED`. Pembatalan di status apa pun tidak memotong kuota | Desain query BR-21 |
| BR-23 | **(v1.4)** Karena BR-17 menjamin tukang hanya memegang 1 job setelah di-lock, pengecekan kuota 5x/minggu menjadi sangat bersih: Tukang yang sudah memiliki `selesai_minggu_ini ≥ 5` DILARANG melakukan bid baru sampai minggu berikutnya | Fungsi server |
| BR-24 | **[DITUNDA — Phase 2]** Hak istimewa Gold (kuota unlimited, badge, pin, headstart, radius 100 km) | — |
| BR-25 | **[DITUNDA — Phase 2]** Toggle Gold manual oleh Admin (saklar pengaktifan Gold manual di Web Admin ditunda bersama seluruh fitur Gold ke Phase 2) | — |
| BR-26 | **Lokasi Dasar tukang**: diperbarui saat aplikasi dibuka di foreground dalam keadaan `Online`, dengan akurasi kasar. Terpisah dari Live Tracking dan tercakup persetujuan privasi | Aplikasi + server |
| BR-27 | Jika Lokasi Dasar tukang lebih tua dari **60 menit**, tukang diperlakukan sebagai `Offline` untuk keperluan notifikasi dan portal | Query |

### 8.4 Eksekusi, Kedatangan, Penyelesaian, & Sengketa Pembayaran (v1.4)

| ID | Aturan | Penegakan |
| :--- | :--- | :--- |
| BR-30 | Tombol **"Berangkat ke Lokasi"** terkunci sampai Nota `APPROVED` | Server + UI |
| BR-31 | **(v1.4)** **Timer 30 Menit Wajib Klik "Berangkat" setelah `NOTA_APPROVED`:** Setelah Nota disetujui kedua belah pihak (`NOTA_APPROVED`), Tukang wajib menekan tombol **"Berangkat ke Lokasi"** dalam waktu maksimal **30 menit**. Selama 30 menit ini User menunggu dan tidak dapat membatalkan sepihak. Jika dalam 30 menit Tukang TIDAK menekan tombol Berangkat: **(a)** Job otomatis dilepas kembali ke Job Portal (`OPEN`) agar aktif kembali untuk tukang lain, **(b)** User mendapat notifikasi *"Tukang tidak aktif dalam beberapa menit, silakan cari tukang yang lain"*, **(c)** Tukang mendapat notifikasi *"Job tidak dapat diselesaikan"*, dan **(d)** Tukang terkena **1 Strike Tukang** (lebih dari 3x strike = suspend otomatis 2 hari, BR-57) | Job terjadwal + Server |
| BR-32 | **(v1.4)** Tombol **"Selesaikan Tugas"** DILARANG aktif sebelum: **(a)** ≥ 1 foto hasil kerja terunggah, **(b)** tukang memilih **Metode Bayar Aktual** (`CASH`, `BANK_TRANSFER`, atau `E_WALLET`), **(c)** tukang menandai **"User sudah membayar"**, **(d)** bukti pembayaran (screenshot) terunggah bila Metode Bayar Aktual adalah `BANK_TRANSFER`/`E_WALLET` (bila aktual `CASH`, opsi unggah tidak tampil), dan **(e)** tidak ada Revisi Nota yang masih berstatus `SENT` | **Server menolak transisi**, bukan hanya UI |
| BR-33 | Rating & review hanya oleh User, sekali per job, hanya setelah `COMPLETED`. Job `CANCELLED`/`EXPIRED` tidak bisa dinilai | Constraint DB |
| BR-34 | Foto bukti, chat, Nota, dan riwayat status dapat diaudit Admin | RLS Admin + audit log |
| BR-60 | **(v1.4)** Saat `ON_THE_WAY`, status berubah **otomatis** menjadi `ARRIVED` ketika jarak tukang ke titik job **≤ 50 meter** (dengan akurasi GPS ping ≤ 30 m), dihitung di server (PostGIS). Live GPS aktif selama `ON_THE_WAY`, `ARRIVED`, dan `WORKING` | Server (PostGIS) |
| BR-61 | **(v1.4)** Fallback kedatangan: bila jarak tukang ke titik job **≤ 200 meter**, tombol **"Saya Sudah Tiba"** tersedia agar tukang tidak terjebak akibat sinyal GPS di dalam gedung/gang sempit. Kedatangan ditandai `MANUAL` untuk audit | Server |
| BR-62 | **"Mulai Bekerja"** HANYA dapat ditekan secara manual oleh Tukang dari status `ARRIVED` | Server |
| BR-65 | Job berstatus `WORKING` **tidak dapat dibatalkan** oleh User maupun Tukang; tukang tetap harus menyelesaikan pekerjaan. Hanya **Admin** yang dapat membatalkan paksa (T10) | Server |
| BR-67 | **(v1.4)** **Laporan Masalah Pembayaran & Suspend Langsung User:** Pada tahap `WORKING` (saat pekerjaan fisik sudah selesai namun User menolak membayar atau membayar kurang dari nominal Nota Sah), Tukang memiliki tombol khusus **"Laporkan Masalah Pembayaran"**. Saat dikirim: **(a)** Tiket masuk antrean prioritas tinggi di Web Admin beserta foto bukti hasil kerja, **(b)** Ikatan job aktif Tukang dilepas sementara agar Tukang tetap dapat mencari pekerjaan lain sambil menunggu investigasi Admin, **(c)** Admin memeriksa seluruh bukti (Chat, Nota Sah, Foto Hasil Kerja), dan **(d)** Jika User terbukti bersalah tidak mau membayar sesuai kesepakatan, **Admin langsung men-suspend permanen akun User tersebut TANPA toleransi/pemakluman 3x**. User yang terkena suspend ini hanya dapat mengajukan banding melalui **Email Resmi Admin/Perusahaan** | Fungsi server + Admin UI |

### 8.5 Akun, Peran Tunggal per Email, & Verifikasi (v1.4)

| ID | Aturan | Penegakan |
| :--- | :--- | :--- |
| BR-40 | Tukang baru `KYC = PENDING` dan DILARANG bid sampai Admin menyetujui | RLS |
| BR-41 | KYC membutuhkan Foto KTP dan Foto Selfie memegang KTP | Validasi |
| BR-42 | **(v1.4)** **Suspend Manual vs Suspend Otomatis:** **(a) Suspend Permanen/Manual oleh Admin** (misal karena penipuan KTP atau User tidak mau membayar): pengguna tidak dapat bertransaksi dan layar menampilkan alasan suspend serta alamat Email Resmi Perusahaan untuk banding. **(b) Suspend Otomatis 2 Hari (48 jam)** karena melewati batas 3x Strike: pengguna masih dapat membuka aplikasi untuk melihat halaman penjelasan suspend (penyebab, daftar pelanggaran, dan hitung mundur waktu berakhir), namun DILARANG melakukan transaksi baru (`Online`, `Bid`, atau `Posting Job`) | Server + UI |
| BR-43 | Kategori pekerjaan dikelola dinamis oleh Admin tanpa rilis aplikasi | Data-driven |
| BR-44 | **(Diperbarui)** **Satu Email = Dua Peran (USER & TUKANG):** Satu alamat email DIPERBOLEHKAN terdaftar sekaligus di aplikasi Beres User dan Beres Mitra (Tukang). Jika pengguna mendaftar di kedua aplikasi, perannya di database menjadi `BOTH`. Data pesanan pelanggan (`jobs.user_id`) dan data pekerjaan tukang (`job_bids.tukang_id` & `tukang_profiles`) terpisah secara alami di masing-masing aplikasi. Aturan mutlak: Akun dilarang melamar pekerjaannya sendiri (`jobs.user_id != auth.uid()`) | Constraint DB + RPC Sync |
| BR-45 | **(v1.4)** Pengguna (`USER` maupun `TUKANG`) dapat mengajukan **Hapus Akun** dari menu pengaturan profil selama tidak sedang memiliki pekerjaan berjalan atau sengketa pembayaran yang belum selesai | Fungsi server |

### 8.6 Pembatalan pada `ON_THE_WAY` dan `ARRIVED` (v1.4)

| ID | Aturan | Penegakan |
| :--- | :--- | :--- |
| BR-50 | **Pembatalan oleh Tukang (`NOTA_APPROVED`, `ON_THE_WAY`, `ARRIVED`):** Tukang dapat mengajukan Permintaan Pembatalan lewat urutan: **tombol geser** → dialog konfirmasi **Ya/Tidak** → halaman form pembatalan → klik **Kirim**. Dari `WORKING` DILARANG (BR-65) | Fungsi server |
| BR-51 | **(v1.4 — Perbaikan Draft):** Saat tukang memilih **Ya** dan sedang berada di halaman form pembatalan (`DRAFT`), **tampilan di aplikasi User TIDAK berubah** (tetap menampilkan status berjalan sebelumnya) agar User tidak bingung bila tukang menekan **Kembali**. Jika tukang menekan **Kembali** atau `DRAFT` lewat 10 menit tanpa dikirim, draft dibatalkan (`ABORTED`) tanpa notifikasi apa pun | Server |
| BR-53 | Saat tukang menekan **Kirim**: status job berubah menjadi `CANCEL_PENDING`, permintaan menjadi `SUBMITTED`, dan User diberi notifikasi. **Semua field** (termasuk catatan Admin, foto bukti, lokasi GPS) dikirim ke Admin, sedangkan **User HANYA menerima alasan pembatalan** (kategori + teks) | View/RLS terpisah + test negatif |
| BR-55 | **Jika User Menyetujui pembatalan Tukang:** Job kembali dibuka ke Job Portal (`OPEN`, timer 24 jam direset), dan **Tukang yang membatalkan terkena 1 Strike Tukang** (BR-57). **Jika User Menolak:** Job kembali ke `status_before_cancel` dan tukang tidak dapat mengajukan pembatalan lagi pada job tersebut (hanya jalur **Laporkan**). Jika User tidak merespons dalam **30 menit**, permintaan dieskalasi ke Admin | Fungsi server |
| BR-56 | **(v1.4)** **Aturan Pembatalan oleh User pada `ON_THE_WAY` dan `ARRIVED`:** **(a)** Saat tukang berstatus `ON_THE_WAY` di **bawah 3 jam**, tombol Cancel **TIDAK tersedia** bagi User. **(b)** Jika status `ON_THE_WAY` sudah berlangsung **≥ 3 jam** dan tukang belum sampai, barulah di aplikasi User muncul tombol **Cancel**. Saat User menekan Cancel dan mengisi alasan, permintaan pembatalan dikirim ke Tukang untuk meminta persetujuan Tukang. Jika Tukang menyetujui, job kembali ke `OPEN` (atau `CANCELLED` sesuai pilihan User). Jika Tukang **tidak merespons dalam 30 menit**, sistem melakukan **Auto-Cancel (otomatis disetujui)** dan **Tukang terkena 1 Strike Tukang**. **(c)** Saat tukang sudah berstatus `ARRIVED` (sudah sampai di lokasi), User **TIDAK dapat membatalkan sepihak** | Fungsi server + Job terjadwal |

### 8.7 Sistem Strike & Suspend Otomatis 2 Hari (Tukang & User — v1.4)

| ID | Aturan | Penegakan |
| :--- | :--- | :--- |
| BR-57 | **(v1.4)** **Aturan Strike Tukang (Maks 3x, Lebih dari 3x = Suspend 2 Hari):** Tukang mendapatkan **1 Strike** setiap kali melakukan salah satu dari: **(1)** Tidak menekan tombol "Berangkat" dalam 30 menit setelah `NOTA_APPROVED` (BR-31), **(2)** Melakukan pembatalan pada status `NOTA_APPROVED`/`ON_THE_WAY`/`ARRIVED` yang disetujui User/Admin (BR-55), atau **(3)** Tidak sampai ke lokasi > 3 jam saat `ON_THE_WAY` dan di-cancel User tanpa respons 30 menit (BR-56b). Batas toleransi adalah **maksimal 3x Strike** dalam 1 bulan kalender (zona waktu lokal). Pada **Strike ke-4 (lebih dari 3x)**, akun Tukang **otomatis ter-suspend selama 2 hari penuh (48 jam)** dan tidak dapat menerima atau mengerjakan job | Fungsi DB + Trigger |
| BR-70 | **(v1.4)** **Aturan Chat di Tahap `NEGOTIATING` (Tanpa Strike):** Setelah User melakukan *lock* pada 1 tukang dan ruang chat terbuka (`NEGOTIATING`, sebelum Nota disetujui): **(a)** Jika **User** memulai chat duluan namun **Tukang tidak membalas selama > 30 menit**, maka job otomatis dilepas/dibuka kembali ke Job Portal (`OPEN`) dan User juga memiliki tombol Cancel untuk melepas job ke portal. **Tukang TIDAK terkena Strike** (karena User bisa saja melakukan lock di malam hari saat tukang sudah tidur). **(b)** Jika **Tukang** memulai chat/mengirim Nota duluan namun **User tidak membalas selama > 30 menit**, maka job otomatis dilepas kembali ke Job Portal (`OPEN`, melanjutkan sisa waktu 24 jam) dan Tukang memiliki tombol Cancel untuk melepas job tersebut. **User TIDAK terkena Strike** | Job terjadwal + Fungsi server |
| BR-71 | **(v1.4)** **Aturan Strike User Saat Tukang Sudah `ON_THE_WAY` atau `ARRIVED` (Maks 3x, Lebih dari 3x = Suspend 2 Hari):** Apabila Nota sudah disetujui dan status pekerjaan sudah **`ON_THE_WAY`** atau **`ARRIVED`**, lalu Tukang mengirim pesan di chat namun **User tidak aktif / tidak membalas chat selama lebih dari 30 menit**, maka **User terkena 1 Strike User**! Batas toleransi adalah **maksimal 3x Strike** dalam 1 bulan kalender. Jika **lebih dari 3x (Strike ke-4)**, akun User **otomatis di-suspend selama 2 hari penuh (48 jam)** | Job terjadwal + Fungsi DB |
| BR-75 | Batas **minggu** (kuota 5x selesai, BR-21) dan **bulan** (perhitungan Strike Tukang & Strike User, BR-57, BR-71) dihitung menurut **zona waktu lokal pengguna** (`Asia/Jakarta` WIB, `Asia/Makassar` WITA, `Asia/Jayapura` WIT). Semua timestamp disimpan UTC | Server |

---

## 9. State Machine Pekerjaan (v1.4)

### 9.1 Status (10 Status)

`OPEN`, `NEGOTIATING`, `NOTA_APPROVED`, `ON_THE_WAY`, `ARRIVED`, `WORKING`, `COMPLETED`, `CANCELLED`, `EXPIRED`, `CANCEL_PENDING`

- Status akhir (terminal): `COMPLETED`, `CANCELLED`, `EXPIRED`.
- **`ARRIVED`** = "tukang sampai", otomatis saat jarak tukang ≤ 50 m dari titik job (atau manual ≤ 200 m).
- **`CANCEL_PENDING`** = status saat Permintaan Pembatalan sudah dikirim (`SUBMITTED`) dan menunggu persetujuan.

### 9.2 Tabel Transisi Lengkap (v1.4)

| # | Dari | Ke | Aktor | Syarat (Guard) | Efek Samping |
| :-: | :--- | :--- | :--- | :--- | :--- |
| T1 | — | `OPEN` | User | Kategori, deskripsi, dan lokasi terisi (pin ≤ 2 km dari GPS HP); foto opsional maks 5; maks 3 job `OPEN` aktif | Sebar ke tukang dalam radius 50 km; `expires_at = now + 24 jam`; simpan `area_label` (Kelurahan/Kecamatan) |
| T2 | `OPEN` | `NEGOTIATING` | User | ≥ 1 bid; User memilih 1 tukang | **Otomatis menarik (`WITHDRAWN`) seluruh bid aktif tukang tersebut di job lain (BR-17)**; buka ruang chat; buka alamat lengkap ke tukang terpilih (BR-16) |
| T3 | `NEGOTIATING` | `OPEN` | User / Tukang / Sistem | Nota belum `APPROVED`; pembatalan negosiasi atau **salah satu pihak tidak membalas chat > 30 menit (BR-70)** | Tutup chat; Nota `SENT` jadi `SUPERSEDED`; alamat kembali disembunyikan; **TIDAK ADA STRIKE** untuk User maupun Tukang; job kembali tampil di Job Portal |
| T4 | `NEGOTIATING` | `NOTA_APPROVED` | User | Ada Nota `SENT` terbaru; User menekan *Approve* | **Nota menjadi Nota Sah & terkunci (BR-05)**; buka tombol "Berangkat"; **mulai timer 30 menit wajib klik Berangkat (BR-31)** |
| **T4a** | `NOTA_APPROVED` | `OPEN` | **Sistem** | **Tukang tidak menekan tombol "Berangkat" dalam 30 menit sejak `NOTA_APPROVED` (BR-31)** | Job otomatis dilepas kembali ke Job Portal (`OPEN`); Nota `VOID`; User dapat notif *"Tukang tidak aktif, silakan cari tukang lain"*; Tukang dapat notif *"Job tidak dapat diselesaikan"*; **Tukang kena +1 Strike Tukang** (ke-4 = suspend 2 hari) |
| T5 | `NOTA_APPROVED` | `ON_THE_WAY` | Tukang | Menekan "Berangkat ke Lokasi" sebelum 30 menit habis | Timer 30 menit berhenti; mulai Live GPS; tampil di Live Map User & Admin; catat `on_the_way_at` (untuk hitung batas 3 jam) |
| **T6a** | `ON_THE_WAY` | `ARRIVED` | **Sistem** | Jarak ping terbaru ke titik job **≤ 50 m** (akurasi ≤ 30 m), dihitung server (BR-60) | Notifikasi "Tukang telah tiba" ke User; Live GPS tetap; `arrival_mode = AUTO`; Revisi Nota terbuka |
| **T6b** | `ON_THE_WAY` | `ARRIVED` | Tukang | Jarak **≤ 200 m**; menekan "Saya Sudah Tiba" (BR-61) | Sama seperti T6a; `arrival_mode = MANUAL` |
| T6 | `ARRIVED` | `WORKING` | Tukang | Menekan "Mulai Bekerja" (BR-62) | Live GPS tetap; Revisi Nota tersedia; pembatalan ditutup (BR-65) |
| T7 | `WORKING` | `COMPLETED` | Tukang | **BR-32:** foto hasil kerja + metode bayar aktual + "User sudah membayar" + bukti bayar (bila non-tunai) + tidak ada Revisi Nota `SENT` | Stop GPS; kuota selesai mingguan +1 (BR-21); buka form rating untuk User |
| T8 | `OPEN` | `CANCELLED` | **User** | Alasan wajib; hanya saat status masih `OPEN` | Job ditutup; bid yang ada diakhiri |
| **T9_Tukang** | `NOTA_APPROVED`, `ON_THE_WAY`, `ARRIVED` | `CANCEL_PENDING` | **Tukang** | Geser tombol batal → Ya → isi form → klik **Kirim** (BR-50, BR-51, BR-53) | Status job ditahan di `CANCEL_PENDING`; User menerima alasan pembatalan; Admin menerima seluruh field |
| **T9_User_3Jam** | `ON_THE_WAY` | `CANCEL_PENDING` | **User** | **Sudah ≥ 3 jam di `ON_THE_WAY` belum sampai (BR-56b)** → User klik Cancel & isi alasan | Mengirim permintaan batal ke Tukang. Jika Tukang setuju atau **tidak merespons 30 menit (Auto-Cancel)** → kembali ke `OPEN` (atau `CANCELLED`) & jika tanpa respons 30 menit **Tukang kena +1 Strike** |
| **T9d** | `CANCEL_PENDING` | `OPEN` | User / Tukang / Sistem | Permintaan pembatalan disetujui | Job dilepas kembali ke Job Portal (`OPEN`, timer 24 jam direset); Nota `VOID`; stop GPS; bila pembatal adalah Tukang maka **Tukang kena +1 Strike Tukang** (ke-4 = suspend 2 hari) |
| **T9e** | `CANCEL_PENDING` | `status_before_cancel` | User / Tukang / Admin | Permintaan pembatalan ditolak | Status pulih ke status sebelum batal; tidak ada Strike |
| T10 | Status non-terminal mana pun (termasuk `WORKING`) | `CANCELLED` | **Admin saja** | Investigasi laporan (termasuk Laporan Masalah Pembayaran BR-67) + alasan wajib | Stop GPS; Nota `VOID`; audit log; jika User terbukti tidak mau bayar → **Admin langsung suspend permanen akun User** |
| T11 | `OPEN` | `EXPIRED` | Sistem | `now > expires_at` (24 jam) dan belum di-lock | Notifikasi ke User; job hilang dari portal tukang |

### 9.3 Matriks Pembatalan Lengkap (v1.4)

| Status | Apakah User Bisa Batal? | Apakah Tukang Bisa Batal? | Aturan & Dampak Strike |
| :--- | :--- | :--- | :--- |
| `OPEN` | ✅ Bisa langsung (alasan wajib) | ✅ Bisa tarik lamaran (*Withdraw Bid*) | Tanpa strike untuk siapa pun |
| `NEGOTIATING` | ✅ Bisa lepas/cancel (atau diam > 30 mnt) | ✅ Bisa lepas/cancel (atau diam > 30 mnt) | Job kembali `OPEN` ke portal. **Tanpa strike untuk siapa pun** (BR-70) |
| `NOTA_APPROVED` | ❌ Menunggu timer 30 menit Tukang klik Berangkat | ✅ Lewat Permintaan Pembatalan (*slide-to-cancel* + form) | Jika Tukang tidak klik Berangkat 30 menit **ATAU** Tukang batal & disetujui User → Job kembali `OPEN` + **Tukang kena 1 Strike** |
| `ON_THE_WAY` (< 3 Jam) | ❌ Tidak ada tombol Cancel | ✅ Lewat Permintaan Pembatalan (butuh persetujuan User) | Jika Tukang batal & disetujui User → Job kembali `OPEN` + **Tukang kena 1 Strike** |
| `ON_THE_WAY` (≥ 3 Jam) | ✅ Muncul tombol Cancel (butuh persetujuan Tukang; auto-approve jika Tukang diam 30 mnt) | ✅ Lewat Permintaan Pembatalan | Jika Tukang diam 30 mnt atas cancel User atau Tukang yang batal → **Tukang kena 1 Strike** |
| `ARRIVED` | ❌ Tidak bisa cancel sepihak | ✅ Lewat Permintaan Pembatalan (butuh persetujuan User) | Jika Tukang batal & disetujui User → Job kembali `OPEN` + **Tukang kena 1 Strike** |
| `WORKING` | ❌ **DILARANG BATAL** | ❌ **DILARANG BATAL** | Pekerjaan wajib diselesaikan. Jika User tidak mau bayar / bayar kurang → Tukang klik **"Laporkan Masalah Pembayaran"** → Admin investigasi & **langsung suspend User tanpa toleransi 3x** |

---

## 10. Kebutuhan Fungsional (Functional Requirements)

Format acceptance criteria: **Given / When / Then**. Prioritas default `P0`.

### 10.1 Autentikasi, Peran Tunggal per Email, & Profil

#### FR-001: Registrasi, Login Email/Password/OTP/Google, & Aturan Satu Email Dua Peran
- **Metode:** Email + Password, Email OTP 6 digit, atau Google OAuth.
- **Acceptance Criteria:**
  - [ ] Given email belum pernah terdaftar di peran mana pun, When pengguna mendaftar di aplikasi User, Then akun dibuat dengan peran `USER`.
  - [ ] Given email sudah terdaftar sebagai `USER`, When email yang sama digunakan mendaftar/login di aplikasi Tukang (`TUKANG`), Then peran akun ditingkatkan menjadi `BOTH` dan profil mitra tukang dibuat (BR-44) — berlaku sebaliknya tanpa penolakan akun.
  - [ ] Given akun dengan peran `BOTH`, When tukang melihat daftar pekerjaan di Job Portal, Then pekerjaan yang diposting oleh dirinya sendiri disembunyikan/dilarang dilamar (`jobs.user_id != auth.uid()`).
  - [ ] Given akun terkena **Suspend Permanen (Manual Admin)**, When membuka aplikasi, Then transaksi diblokir dan tampil alasan suspend beserta alamat Email Resmi Perusahaan untuk pengajuan banding (BR-42a).
  - [ ] Given akun terkena **Suspend Otomatis 2 Hari (karena > 3x Strike)**, When membuka aplikasi, Then pengguna dapat melihat banner/halaman penjelasan penyebab suspend, rincian strike, dan waktu berakhirnya suspend, namun tidak dapat memposting job atau mengambil job (BR-42b).

#### FR-002: Registrasi, Edit Profil, & Rekening Tukang (v1.4)
- **Acceptance Criteria:**
  - [ ] Given tukang baru, When mengisi biodata, memilih ≥ 1 kategori keahlian, dan mengisi rekening bank/e-wallet, Then status `KYC = PENDING`.
  - [ ] Given tukang aktif, When mengedit nomor rekening/e-wallet atau menambah keahlian di menu Profil, Then perubahan berlaku untuk Nota baru berikutnya (Nota lama yang sudah dibuat tidak berubah).

#### FR-003: Verifikasi KYC (sisi Tukang)
- **Acceptance Criteria:**
  - [ ] Given `PENDING`, When mengunggah Foto KTP dan Selfie+KTP, Then tersimpan di bucket privat `kyc-private` dan masuk antrean Admin.
  - [ ] Given `REJECTED`, Then alasan tampil dan tukang dapat mengunggah ulang.
  - [ ] Given KYC belum `APPROVED`, Then job tidak tampil dan bid ditolak server.

#### FR-004: Hapus Akun (User & Tukang) — baru v1.4
- **Acceptance Criteria:**
  - [ ] Given pengguna tidak memiliki job berjalan (`NEGOTIATING` s/d `WORKING`) dan tidak memiliki laporan sengketa aktif, When mengajukan Hapus Akun dengan konfirmasi OTP, Then akun dinonaktifkan/dianonimkan sesuai UU PDP dan sesi dicabut (BR-45).
  - [ ] Given pengguna masih memiliki job berjalan atau laporan pembayaran aktif, When mencoba Hapus Akun, Then ditolak dengan penjelasan.

### 10.2 Beres User

#### FR-010: Memposting, Mengedit Pekerjaan `OPEN`, & Reverse Geocoding HP (v1.4)
- **Field wajib:** kategori (aktif), deskripsi (min. 10 karakter), lokasi (pin peta ≤ 2 km dari GPS HP). **Opsional:** foto kerusakan (maks 5).
- **Acceptance Criteria:**
  - [ ] Given User memilih titik pin di peta (≤ 2 km dari GPS HP), Then aplikasi mengambil nama Kelurahan/Kecamatan menggunakan geocoder bawaan OS perangkat dan mengirimkannya sebagai `area_label` bersama koordinat tepat.
  - [ ] Given form valid dan User memiliki < 3 job `OPEN` aktif, When disubmit, Then job berstatus `OPEN`, `broadcast_radius_km = 50`, `expires_at = now + 24 jam`.
  - [ ] Given job masih `OPEN` (belum di-lock), When User mengedit deskripsi atau menambah foto kerusakan, Then perubahan tersimpan.

#### FR-011: Melihat Daftar Bid & Privasi Profil Tukang (v1.4)
- **Acceptance Criteria:**
  - [ ] Given ada tukang yang melakukan bid, Then User hanya melihat **foto profil tukang, nama tukang, lencana keahlian, lama hari aktif sejak KYC disetujui, rata-rata rating, dan ulasan** (BR-16).

#### FR-012: Lock Tukang & Auto-Clear Bid Lain (v1.4)
- **Acceptance Criteria:**
  - [ ] Given job `OPEN` dengan bid, When User memilih 1 tukang (misal di Job C), Then dalam satu transaksi atomik: **(1)** Job C berubah menjadi `NEGOTIATING`, **(2)** **Seluruh bid aktif tukang tersebut di job lain (Job A, B, D, E) otomatis berubah menjadi `WITHDRAWN` dan hilang dari daftar lamaran aktif tukang tersebut (BR-17)**, dan **(3)** Ruang chat serta alamat lengkap Job C terbuka bagi tukang tersebut.

#### FR-013: Chat Real-Time, Timer 30 Menit `NEGOTIATING`, & Kewajiban Respons Saat `ON_THE_WAY`/`ARRIVED` (v1.4)
- **Acceptance Criteria:**
  - [ ] Given status `NEGOTIATING` (Nota belum disetujui):
    - Jika User mengirim chat duluan dan Tukang tidak membalas > 30 menit, Then job otomatis dilepas kembali ke Job Portal (`OPEN`), User juga dapat menekan tombol Cancel untuk melepas job ke portal, dan **Tukang TIDAK terkena Strike** (BR-70a).
    - Jika Tukang mengirim chat/Nota duluan dan User tidak membalas > 30 menit, Then job otomatis dilepas kembali ke Job Portal (`OPEN`, melanjutkan sisa waktu 24 jam), Tukang juga dapat menekan tombol Cancel untuk melepas job ke portal, dan **User TIDAK terkena Strike** (BR-70b).
  - [ ] Given status sudah **`ON_THE_WAY`** atau **`ARRIVED`**, When Tukang mengirim pesan di chat dan **User tidak aktif / tidak membalas selama > 30 menit**, Then **User terkena 1 Strike User** (BR-71). Jika lebih dari 3x (> 3, yaitu Strike ke-4) dalam 1 bulan kalender, akun User otomatis di-suspend selama 2 hari penuh.

#### FR-014: Menanggapi Nota Sah & Timer 30 Menit Tukang Berangkat (v1.4)
- **Acceptance Criteria:**
  - [ ] Given Nota `SENT`, When User menekan *Approve*, Then terbentuk **Nota Sah yang terkunci**, status job menjadi `NOTA_APPROVED`, dan **timer 30 menit wajib klik Berangkat** dimulai bagi Tukang (T4, BR-31).
  - [ ] Given status `NOTA_APPROVED` dan timer 30 menit sedang berjalan, Then User menunggu Tukang berangkat (tombol Cancel sepihak User tidak aktif).
  - [ ] Given Tukang tidak menekan tombol "Berangkat" dalam 30 menit sejak `NOTA_APPROVED`, Then sistem otomatis melepas job kembali ke Job Portal (`OPEN`), mengirim notifikasi ke User (*"Tukang tidak aktif dalam beberapa menit, silakan cari tukang yang lain"*), mengirim notifikasi ke Tukang (*"Job tidak dapat diselesaikan"*), dan memberi **+1 Strike Tukang** (T4a, BR-31).

#### FR-015: Menyetujui atau Menolak Revisi Nota (Anti Perubahan Harga Sepihak — v1.4)
- **Acceptance Criteria:**
  - [ ] Given Tukang mengirimkan Revisi Nota saat `ARRIVED` atau `WORKING` (misal dari Rp 100.000 menjadi Rp 150.000), Then User menerima **notifikasi khusus di ruang chat** yang menampilkan dengan jelas **Nominal Nota Sah Awal (Rp 100.000) vs Nominal Revisi Baru (Rp 150.000)** beserta rincian item tambahannya (BR-05).
  - [ ] Given Revisi Nota belum di-*Approve* oleh User, Then nominal yang sah tetap nominal Nota awal (Rp 100.000); Tukang tidak dapat mengubah harga sepihak tanpa klik *Approve* dari User.
  - [ ] Given User menekan *Approve* pada Revisi Nota, Then barulah Revisi Nota tersebut menjadi Nota Sah terbaru.
  - [ ] Given User menekan *Tolak*, Then Revisi Nota berstatus `REJECTED` dan Nota Sah awal tetap berlaku.

#### FR-016: Live Tracking & Riwayat Pekerjaan
- **Acceptance Criteria:**
  - [ ] Given `ON_THE_WAY`, `ARRIVED`, atau `WORKING`, Then posisi tukang tampil di peta dan ter-update ≤ 10 detik.
  - [ ] Given halaman Riwayat Pekerjaan, Then User dapat melihat daftar pekerjaan Aktif, Selesai, dan Batal.

#### FR-017: Bukti, Pembayaran Langsung, dan Rating
- **Acceptance Criteria:**
  - [ ] Given `COMPLETED`, Then User melihat foto hasil kerja, rincian Nota Sah terakhir, metode bayar aktual, dan bukti pembayaran (bila non-tunai).
  - [ ] Given `COMPLETED`, When memberi rating 1–5 + review opsional, Then tersimpan sekali per job.

#### FR-018: Pembatalan Pekerjaan oleh User (termasuk Aturan 3 Jam `ON_THE_WAY` — v1.4)
- **Acceptance Criteria:**
  - [ ] Given status `OPEN`, When User menekan "Batalkan Pekerjaan" dan mengisi alasan, Then job menjadi `CANCELLED` (T8).
  - [ ] Given status `NOTA_APPROVED` (< 30 menit), `ON_THE_WAY` (< 3 jam), `ARRIVED`, atau `WORKING`, Then tombol Cancel sepihak oleh User **TIDAK tersedia** (BR-31, BR-56, BR-65).
  - [ ] Given status `ON_THE_WAY` sudah berlangsung **≥ 3 jam** dan tukang belum tiba di lokasi, Then di aplikasi User **muncul tombol Cancel** (BR-56b).
  - [ ] Given User menekan tombol Cancel setelah ≥ 3 jam `ON_THE_WAY`, Then permintaan dikirim ke Tukang untuk persetujuan. Jika Tukang menyetujui, atau jika **Tukang tidak merespons dalam 30 menit (Auto-Cancel)**, job dilepas kembali ke `OPEN` (atau `CANCELLED` sesuai pilihan User), dan bila Tukang tidak merespons 30 menit maka **Tukang terkena +1 Strike Tukang**.

#### FR-028: Menanggapi Permintaan Pembatalan dari Tukang (v1.4)
- **Acceptance Criteria:**
  - [ ] Given Tukang masih berada di halaman form pembatalan (`DRAFT`, belum klik Kirim), Then tampilan di aplikasi User **tidak berubah** (BR-51).
  - [ ] Given Tukang sudah menekan **Kirim** (`SUBMITTED`), Then User menerima notifikasi dan melihat alasan pembatalan beserta tombol **Setujui Pembatalan** dan **Tolak Pembatalan** (tanpa melihat catatan internal Admin/foto/lokasi tukang, BR-53).
  - [ ] Given User menekan **Setujui Pembatalan**, Then job dilepas kembali ke Job Portal (`OPEN`, timer 24 jam direset) dan **Tukang terkena +1 Strike Tukang** (T9d, BR-55, BR-57).
  - [ ] Given User menekan **Tolak Pembatalan**, Then job kembali ke status sebelumnya (`status_before_cancel`) dan Tukang tidak dapat mengajukan batal lagi di job tersebut (T9e).

### 10.3 Beres Mitra / Tukang

#### FR-020: Online/Offline & Radius (0–50 km)
- **Acceptance Criteria:**
  - [ ] Given tukang, When mengatur slider radius, Then rentang **0–50 km** (default 20 km).
  - [ ] Given tukang terkena suspend (otomatis 2 hari maupun manual Admin), Then tidak dapat `Online` dan aplikasi menampilkan keterangan lengkap alasan suspend serta waktu berakhirnya.

#### FR-021: Kuota Mingguan (5 Job Selesai / Minggu)
- **Acceptance Criteria:**
  - [ ] Given tukang, Then sisa kuota = `5 − COMPLETED minggu ini` tampil jelas di aplikasi.
  - [ ] Given `selesai_minggu_ini ≥ 5`, When mencoba bid, Then ditolak dengan pesan kuota mingguan telah penuh (BR-23).

#### FR-022: Job Portal, Batas Lamar Maks 5 Job, & Auto-Clear Saat Di-Lock (v1.4)
- **Acceptance Criteria:**
  - [ ] Given daftar Job Portal, Then tukang HANYA melihat kategori, deskripsi, foto kerusakan, jarak perkiraan, dan nama Kelurahan/Kecamatan (`area_label`), **tanpa** nama/foto/alamat lengkap User (BR-16).
  - [ ] Given tukang belum mencapai 5 job `COMPLETED` minggu ini dan sedang tidak memiliki job berjalan (`NEGOTIATING` s/d `WORKING`), Then tukang dapat melamar (*bid*) hingga **maksimal 5 job `OPEN` sekaligus** (misal Job A, B, C, D, E) (BR-15).
  - [ ] Given tukang sudah memiliki 5 bid aktif, When mencoba bid job ke-6, Then ditolak dengan pesan *"Anda sudah melamar maksimal 5 pekerjaan. Tarik salah satu lamaran atau tunggu dipilih pelanggan"*.
  - [ ] Given tukang menarik sendiri lamarannya (*Withdraw Bid*) saat job masih `OPEN`, Then kuota lamaran aktifnya kembali tersedia tanpa sanksi.
  - [ ] Given tukang di-*lock* oleh User pada salah satu job (misal Job C), Then **seluruh lamaran tukang pada job lain (A, B, D, E) otomatis ditarik/dihapus dari histori lamaran aktif tukang** (BR-17). Jika nantinya Job C batal, tukang mulai melamar dari awal lagi di Job Portal.

#### FR-023: Chat, Pembuatan Nota, Revisi Nota, & Tarik Revisi Nota (v1.4)
- **Acceptance Criteria:**
  - [ ] Given status `NEGOTIATING`, When tukang mengirim Nota awal, Then muncul di chat User dengan status `SENT`.
  - [ ] Given Nota awal sudah `APPROVED` oleh User (menjadi **Nota Sah**), When tukang mencoba mengedit langsung Nota tersebut, Then server menolak (BR-05).
  - [ ] Given status `ARRIVED` atau `WORKING`, When terdapat tambahan biaya/pekerjaan, Then tukang hanya dapat mengajukan **Revisi Nota** yang mengirim notifikasi perubahan harga ke chat User dan wajib menunggu klik *Approve* dari User (BR-05).
  - [ ] Given Revisi Nota masih berstatus `SENT` (belum dijawab User), When tukang menekan tombol **"Tarik / Batalkan Revisi Nota"**, Then Revisi Nota menjadi `SUPERSEDED` dan Nota Sah sebelumnya tetap berlaku sehingga tukang dapat menyelesaikan pekerjaan (BR-08).

#### FR-024: Eksekusi Pekerjaan — Timer 30 Menit Berangkat & Deteksi Sampai 50m/200m (v1.4)
- **Acceptance Criteria:**
  - [ ] Given `NOTA_APPROVED`, Then tampil hitung mundur **30 menit** bagi tukang untuk menekan **"Berangkat ke Lokasi"** (BR-31).
  - [ ] Given tukang menekan "Berangkat ke Lokasi" sebelum 30 menit habis, Then status menjadi `ON_THE_WAY` dan Live GPS menyala.
  - [ ] Given tukang tidak menekan "Berangkat ke Lokasi" hingga 30 menit habis, Then job otomatis dilepas kembali ke Job Portal (`OPEN`), tukang menerima notifikasi *"Job tidak dapat diselesaikan"*, dan **tukang terkena +1 Strike Tukang** (BR-31).
  - [ ] Given `ON_THE_WAY` dan jarak ke titik job **≤ 50 m** (akurasi ≤ 30 m), Then status otomatis menjadi `ARRIVED` (`AUTO`, BR-60).
  - [ ] Given `ON_THE_WAY` dan jarak **≤ 200 m**, Then tombol **"Saya Sudah Tiba"** tersedia (`MANUAL`, BR-61).
  - [ ] Given `ARRIVED`, When tukang menekan **"Mulai Bekerja"**, Then status menjadi `WORKING` (BR-62).

#### FR-025: Penyelesaian Tugas & Tombol Khusus "Laporkan Masalah Pembayaran" (v1.4)
- **Form Penyelesaian (saat `WORKING`):**
  1. Unggah **Foto Bukti Hasil Kerja** (wajib ≥ 1 foto, maks 5).
  2. Pilih **Metode Bayar Aktual** (`CASH`, `BANK_TRANSFER`, atau `E_WALLET`).
  3. Centang konfirmasi **"User sudah membayar sesuai Nota Sah"**.
  4. Unggah **Screenshot Bukti Pembayaran** (wajib **HANYA** jika Metode Bayar Aktual adalah `BANK_TRANSFER` atau `E_WALLET`; jika `CASH`, opsi unggah tidak tampil).
- **Acceptance Criteria:**
  - [ ] Given semua syarat di atas terpenuhi dan tidak ada Revisi Nota `SENT` yang menggantung, When tukang menekan **"Selesaikan Tugas"**, Then status menjadi `COMPLETED`, GPS berhenti, dan kuota mingguan terhitung +1.
  - [ ] **Kasus User Tidak Mau Bayar / Bayar Kurang (BR-67):** Given pekerjaan fisik sudah selesai namun User menolak membayar atau membayar kurang dari kesepakatan Nota Sah, When tukang menekan tombol khusus **"Laporkan Masalah Pembayaran (User Tidak Membayar / Kurang)"** dan melampirkan foto hasil kerja + kronologi, Then:
    1. Laporan masuk ke **Antrean Investigasi Prioritas Tinggi** di Web Admin.
    2. Ikatan job aktif tukang dilepas sementara agar tukang tidak terjebak dan tetap bisa mencari job lain sambil menunggu keputusan Admin.
    3. Jika dari hasil investigasi bukti (Chat, Nota Sah, Foto Hasil Kerja) User terbukti bersalah, Admin **langsung men-suspend permanen akun User tersebut tanpa toleransi 3x** (BR-67).

#### FR-026: Membatalkan Pekerjaan oleh Tukang (`NOTA_APPROVED`, `ON_THE_WAY`, `ARRIVED` — v1.4)
- **Acceptance Criteria:**
  - [ ] Given status `NOTA_APPROVED`, `ON_THE_WAY`, atau `ARRIVED`, When tukang menggeser tombol Batal → klik **Ya** → mengisi form pembatalan → klik **Kirim**, Then job masuk `CANCEL_PENDING` dan User menerima alasan pembatalan.
  - [ ] Given User menyetujui pembatalan tersebut, Then job dilepas kembali ke Job Portal (`OPEN`) agar dapat dikerjakan tukang lain, dan **tukang yang membatalkan terkena +1 Strike Tukang** (BR-55, BR-57).
  - [ ] Given total Strike Tukang bulan ini mencapai **lebih dari 3x (Strike ke-4)**, Then akun tukang **otomatis di-suspend selama 2 hari penuh (48 jam)** (BR-57).
  - [ ] Given status sudah `WORKING`, Then tombol pembatalan **tidak tersedia** bagi tukang maupun User (BR-65).

#### FR-027: Pembaruan Lokasi Dasar Tukang
- **Acceptance Criteria:**
  - [ ] Given tukang `Online` dan aplikasi dibuka di foreground, Then lokasi dasar dikirim untuk filter radius 50 km. Jika lokasi dasar > 60 menit tidak diperbarui, tukang diperlakukan `Offline`.

### 10.4 Beres Web Admin

#### FR-030: Live Map Monitoring
- **Acceptance Criteria:**
  - [ ] Menampilkan marker real-time seluruh tukang yang sedang `ON_THE_WAY`, `ARRIVED`, dan `WORKING` (ter-update ≤ 10 detik) beserta garis ke titik lokasi User.

#### FR-031: Monitoring Status (10 Status) & Panel Audit Lengkap (v1.4)
- **Acceptance Criteria:**
  - [ ] Tabel & filter mendukung seluruh **10 status pekerjaan**.
  - [ ] Detail job menampilkan: riwayat transisi status (`job_status_history`), seluruh isi Chat, seluruh versi Nota & Revisi Nota, Foto Kerusakan Awal, Foto Hasil Kerja, serta Bukti Pembayaran.
  - [ ] Setiap akses Admin ke data sensitif tercatat di `audit_logs`.

#### FR-032: Verifikasi KYC
- **Acceptance Criteria:**
  - [ ] Admin memeriksa Foto KTP & Selfie (via signed URL privat) dan memilih *Approve* atau *Reject* (dengan alasan wajib).

#### FR-033: Suspend / Ban Akun & Investigasi User Tidak Membayar (v1.4)
- **Acceptance Criteria:**
  - [ ] Admin dapat melakukan **Suspend Permanen/Manual** pada akun User atau Tukang dengan alasan wajib.
  - [ ] **Tindak Lanjut Laporan Masalah Pembayaran (BR-67):** Pada antrean laporan pembayaran, Admin dapat memeriksa bukti Chat, Nota Sah, dan Foto Hasil Kerja. Jika User terbukti bersalah tidak membayar/kurang, Admin menekan **"Vonis Bersalah & Suspend User"** yang langsung men-suspend akun User tersebut **tanpa menunggu 3x pelanggaran**, serta menyelesaikan/menutup status job tukang agar tukang tidak dirugikan.
  - [ ] Layar akun yang di-suspend menampilkan alamat **Email Resmi Admin/Perusahaan** untuk pengajuan banding.

#### FR-034: Toggle Gold Badge Manual — **`[DITUNDA — Phase 2]`**
- Ditunda seluruhnya ke Phase 2 bersama fitur langganan Gold (D-02, NG-02).

#### FR-035: Manajemen Kategori Dinamis & Konfigurasi Parameter (`app_configs`)
- **Acceptance Criteria:**
  - [ ] Admin dapat menambah/mengedit/mengurutkan/menonaktifkan kategori pekerjaan tanpa update aplikasi.
  - [ ] Admin dapat mengatur parameter waktu/jarak di tabel `app_configs` (timer 30 menit chat, 30 menit berangkat, 3 jam on-the-way, jarak 50m/200m sampai).

#### FR-036: Dashboard Analitik
- **Acceptance Criteria:**
  - [ ] Menampilkan metrik harian/bulanan: job masuk, tingkat penyelesaian, tingkat pembatalan, kategori terpopuler, tukang aktif, serta antrean laporan pembayaran.

#### FR-037: Otorisasi Admin & MFA (Verifikasi 2 Langkah — v1.4)
- **Acceptance Criteria:**
  - [ ] Hanya peran `ADMIN` yang dapat mengakses Web Admin.
  - [ ] Login Web Admin **WAJIB menggunakan MFA (Email + Password + Kode OTP 6 digit / Authenticator)** demi melindungi data KTP seluruh tukang.

#### FR-038 & FR-039: Pembatalan Paksa Admin, Antrean Pembatalan, & Pantauan Strike User/Tukang (v1.4)
- **Acceptance Criteria:**
  - [ ] Admin dapat membatalkan paksa job di status mana pun (`T10`) dengan alasan wajib.
  - [ ] Admin dapat melihat jumlah **Strike Tukang** (maks 3x/bulan) dan **Strike User** (maks 3x/bulan), serta dapat mencabut suspend otomatis 2 hari bila terbukti terjadi kendala darurat yang sah.

### 10.5 Notifikasi (FCM) & Pelaporan

#### FR-040: Push Notification
- **Acceptance Criteria:**
  - [ ] Semua notifikasi memakai **satu bunyi standar yang seragam** dan mendukung *deep link* ke halaman terkait.
  - [ ] Mencakup: job baru/kembali ke portal, bid masuk, lock tukang, chat masuk, Nota baru, **notifikasi perubahan harga Revisi Nota**, pengingat 20 menit & pelepasan job 30 menit (chat maupun klik berangkat), tukang sampai (`ARRIVED`), permintaan pembatalan, peringatan Strike ke-1 s/d ke-3, serta notifikasi Suspend 2 hari / Suspend Admin.

#### FR-041: Tombol Laporkan & Laporan Khusus Masalah Pembayaran (v1.4)
- **Acceptance Criteria:**
  - [ ] Tersedia tombol **Laporkan** umum untuk kendala lapangan, dan tombol khusus **"Laporkan Masalah Pembayaran"** bagi Tukang pada tahap `WORKING` (BR-67).

---

## 11. Kebutuhan Non-Fungsional (Non-Functional Requirements)

| ID | Kategori | Kebutuhan |
| :--- | :--- | :--- |
| NFR-01 | Performa | Respons API p95 ≤ 500 ms untuk baca umum; pembuatan job ≤ 2 detik (tanpa upload foto) |
| NFR-02 | Real-time | Chat dan perubahan status ≤ 2 detik; update GPS tampil ≤ 10 detik |
| NFR-03 | Geospasial | Filter radius 50 km dieksekusi di database (PostGIS) dengan index spasial; Reverse Geocoding nama kecamatan dilakukan di perangkat klien (OS Geocoder) agar Rp 0 dan bebas rate-limit server |
| NFR-04 | Skalabilitas | MVP mendukung ≥ 1.000 pengguna aktif harian dan ≥ 200 tukang online bersamaan |
| NFR-05 | Lokasi & Baterai | **Live Tracking:** foreground service saat `ON_THE_WAY`/`ARRIVED`/`WORKING` (interval kirim ke Realtime 5–10 detik, penyimpanan riwayat ke tabel DB setiap ~30 detik atau saat jarak ≤ 200 m dari lokasi job untuk efisiensi storage). **Lokasi Dasar:** hanya diperbarui saat aplikasi di foreground dalam keadaan `Online` |
| NFR-06 | Ketersediaan | Uptime ≥ 99,5% |
| NFR-07 | Keamanan | Autentikasi berbasis token; **RLS** pada semua tabel; **MFA wajib untuk Admin**; HTTPS wajib |
| NFR-08 | Audit | Akses Admin ke data sensitif dan seluruh aksi suspend/ban/KYC/pembatalan dicatat di `audit_logs` yang tidak dapat diubah |
| NFR-09 | Upload | Foto dikompresi di klien; batas ≤ 5 MB/foto; JPEG/PNG/WebP |
| NFR-10 | Privasi | Bucket `kyc-private` dan `proof-photos` (bukti bayar) **wajib bersifat privat** dan diakses via signed URL berumur pendek; kepatuhan UU PDP No. 27/2022 |
| NFR-15 | Maintainability | Map Provider dibungkus Adapter (OSM → Google Maps cukup ganti 1 implementasi) |
| NFR-18 | Konkurensi | Operasi **Bid (cek maks 5 lamaran), Lock (auto-clear bid lain), Approve Nota, dan Pembatalan** HARUS atomik di dalam transaksi database |
| NFR-19 | OTP Email | Custom SMTP (Resend) dengan domain terverifikasi (SPF/DKIM) dan rate limit |
| NFR-20 | Pemisahan Data | Respons API ke User untuk permintaan pembatalan HANYA berisi kategori + teks alasan, waktu, dan status (diuji dengan test negatif) |
| NFR-21 | Job Terjadwal | Seluruh timer otomatis (30 menit chat `NEGOTIATING`, 30 menit wajib klik Berangkat saat `NOTA_APPROVED`, 30 menit respons chat User saat `ON_THE_WAY`/`ARRIVED`, 3 jam batas `ON_THE_WAY`, 24 jam expiry `OPEN`) berjalan lewat mekanisme terjadwal server (`pg_cron` / Edge Functions) dan membaca nilai durasi dari tabel `app_configs` |
| NFR-22 | Deteksi Kedatangan | Otomatis `ARRIVED` di ≤ 50 m (akurasi ≤ 30 m) dihitung di server (PostGIS), ditambah tombol manual "Saya Sudah Tiba" di ≤ 200 m |

---

## 12. Model Data & Antarmuka (Tingkat Konseptual — v1.4)

### 12.1 Entitas Utama

| Entitas | Deskripsi | Catatan v1.4 |
| :--- | :--- | :--- |
| `profiles` | Identitas dasar + peran tunggal (`USER`/`TUKANG`/`ADMIN`, **1 email = 1 peran**) | + `suspend_type` (`NONE`/`AUTO_2_DAYS`/`MANUAL_PERMANENT`), `suspended_until`, `suspend_reason`, `timezone` (WIB/WITA/WIT), `deleted_at` |
| `tukang_profiles` | KYC status, rekening/e-wallet, radius (0–50), online, lokasi dasar | + `last_known_location`, `location_updated_at`. **Hook Phase 2:** `tier`, `gold_until` |
| `tukang_categories` | Keahlian tukang | N–N |
| `categories` | Kategori dinamis | — |
| `jobs` | Tiket pekerjaan, status (**10 status**), lokasi tepat & `area_label` (Kelurahan/Kecamatan) | + `broadcast_radius_km` (50), `expires_at`, `nota_approved_at`, `on_the_way_at`, `arrived_at`, `arrival_mode` (`AUTO`/`MANUAL`), `work_started_at`, `completed_at`, `actual_payment_method`, `payment_confirmed_at`, `status_before_cancel`, `last_chat_at`, `last_chat_sender_role` |
| `job_status_history` | **(baru v1.4)** Riwayat waktu setiap perpindahan status job | Untuk timeline & audit Admin |
| `job_photos` | Foto kerusakan (`DAMAGE`), hasil kerja (`WORK_RESULT`), dan bukti bayar (`PAYMENT_PROOF`) | `PAYMENT_PROOF` disimpan di bucket privat |
| `bids` | Lamaran tukang pada job | unik (job, tukang); status `ACTIVE`/`WITHDRAWN`/`LOCKED`. Maks 5 `ACTIVE` per tukang; otomatis `WITHDRAWN` di job lain saat tukang di-lock (BR-17) |
| `chat_messages` | Pesan teks/foto/notifikasi sistem per job | — |
| `notas` | Nota awal & Revisi Nota | status: `SENT`, `APPROVED`, `REJECTED`, `SUPERSEDED`, `VOID`; menyimpan `previous_approved_total` untuk menampilkan selisih harga secara transparan ke User |
| `reviews` | Rating & ulasan | unik per job |
| `kyc_documents` | KTP & selfie, status, reviewer | Bucket privat `kyc-private` |
| `location_pings` | Titik GPS Live Tracking per job | — |
| `cancel_requests` | Permintaan Pembatalan (`DRAFT`/`SUBMITTED`/`APPROVED`/`REJECTED`/`ABORTED`), pengaju (`TUKANG`/`USER`), alasan, catatan Admin, foto, lokasi | Selama `DRAFT`, status job di sisi lawan bicara belum berubah (BR-51) |
| `strikes` | **(baru v1.4, menggantikan `chat_timeouts`)** Pencatatan seluruh Strike untuk **Tukang** maupun **User** | `user_id`, `role` (`TUKANG`/`USER`), `job_id`, `strike_type` (`NO_DEPART_30M`, `TUKANG_CANCEL_APPROVED`, `OTW_3H_UNRESPONSIVE`, `USER_UNRESPONSIVE_OTW_ARRIVED`), `created_at`. Lebih dari 3 strike dalam 1 bulan lokal memicu `AUTO_2_DAYS` suspend |
| `reports` | Laporan kendala & **Laporan Masalah Pembayaran** (`PAYMENT_DEFAULT`) | `is_priority = true` untuk masalah pembayaran (BR-67) |
| `app_configs` | **(baru v1.4)** Tabel parameter operasional | Menyimpan nilai durasi timer (30 menit, 3 jam, 24 jam) dan jarak (50 m, 200 m, 50 km) |
| `notifications` / `device_tokens` | Notifikasi & token FCM | — |
| `audit_logs` | Aksi Admin, akses sensitif, suspend, dan pembatalan | Immutable |

---

## 13. Keamanan, Privasi & Kepatuhan

| Area | Kebutuhan |
| :--- | :--- |
| Hak akses & Peran | RLS ketat di semua tabel; **1 email dapat untuk 2 peran (role BOTH)** (BR-44); **MFA wajib untuk login Web Admin** (FR-037) |
| Data sensitif | KTP, selfie, nomor rekening, bukti transfer, lokasi, alamat lengkap = **data pribadi**; wajib disimpan di bucket privat dengan signed URL |
| Privasi sebelum Lock | Tukang hanya melihat detail job & kecamatan (`area_label`); User hanya melihat nama, foto, keahlian, hari aktif, dan rating tukang (BR-16) |
| UU PDP & App Store | Persetujuan eksplisit saat registrasi; fitur **Hapus Akun** tersedia di dalam aplikasi (FR-004); teks izin background location jelas untuk review iOS/Android |

---

## 14. Analytics & Event Tracking

| ID | Event | Properti Utama |
| :--- | :--- | :--- |
| EV-01 | `job_created` | job_id, category_id, area_label, jumlah foto |
| EV-02 | `bid_submitted` / `bid_withdrawn` | job_id, tukang_id, active_bids_count |
| EV-03 | `tukang_locked` | job_id, tukang_id, auto_withdrawn_other_bids_count |
| EV-04 | `nota_sent` / `nota_approved` / `nota_rejected` | job_id, versi, total |
| EV-05 | `nota_revision_sent` / `revision_withdrawn` / `revision_approved` | job_id, old_total, new_total |
| EV-06 | `job_status_changed` | job_id, dari, ke, aktor |
| EV-07 | `depart_timeout_30m` | job_id, tukang_id (memicu +1 Strike Tukang & lepas ke portal) |
| EV-08 | `tukang_arrived` | job_id, mode (`AUTO`/`MANUAL`), jarak_m |
| EV-09 | `job_completed` | job_id, durasi_total, total_nota, actual_payment_method |
| EV-10 | `payment_dispute_reported` | job_id, tukang_id, user_id, agreed_amount |
| EV-11 | `strike_recorded` | target_user_id, role (`TUKANG`/`USER`), strike_type, monthly_strike_count |
| EV-12 | `account_suspended` | target_user_id, role, suspend_type (`AUTO_2_DAYS`/`MANUAL_PERMANENT`), reason |

---

## 15. Milestone & Urutan Pembangunan (Diselaraskan — v1.4)

| M | Nama | Isi | Selesai Jika |
| :-: | :--- | :--- | :--- |
| **M0** | Fondasi | Monorepo (`mobile/shared`, `mobile/user`, `mobile/tukang`, `web/admin`), `AGENTS.md`, Supabase lokal, migrasi awal v1.4, tabel `app_configs`, SMTP Resend | Semua proyek ter-build; migrasi dari nol berhasil; OTP email terkirim |
| **M1** | Auth, Peran Tunggal & Profil | FR-001 (1 email = 1 peran), FR-002, FR-004 (Hapus Akun), FR-037 (Admin + MFA); RLS dasar | Login 3 peran berjalan; uji tolak email ganda antar peran lolos; MFA Admin aktif |
| **M2** | Kategori Dinamis & KYC | FR-003, FR-032, FR-033, FR-035 | Tukang submit KYC; Admin approve/reject; kategori dinamis tampil di mobile |
| **M3** | Posting Job, Batas 5 Bid, Auto-Clear Lock & FCM Dasar | FR-010 (OS Reverse Geocoding), FR-011, FR-012, FR-020, FR-022, FR-027, FR-040; BR-11, BR-15 (maks 5 bid), BR-16 (privasi), BR-17 (auto-clear bid lain saat lock) | Tukang bisa lamar maks 5 job; saat di-lock di Job C maka lamaran di A,B,D,E otomatis ditarik; privasi sebelum lock terjaga |
| **M4** | Chat, Nota Sah, Revisi Nota & Timer 30 Menit | FR-013, FR-014, FR-015, FR-023; BR-05 (Nota Sah & notifikasi perbandingan harga revisi), BR-08 (tarik revisi), BR-31 (timer 30 mnt klik Berangkat), BR-70 (chat `NEGOTIATING` 30 mnt lepas ke portal tanpa strike) | Alur Nota Sah & Revisi Nota berjalan; tarik revisi berfungsi; timer 30 menit `NEGOTIATING` & timer 30 menit `NOTA_APPROVED` berjalan akurat |
| **M5** | Eksekusi, GPS, Kedatangan 50m/200m & Penyelesaian | FR-016, FR-017, FR-021, FR-024, FR-025, FR-030; BR-21/23 (kuota 5x/minggu), BR-32, BR-60/61 (`ARRIVED` ≤ 50m auto / ≤ 200m manual), BR-65 (`WORKING` tidak bisa batal), BR-67 (Laporan Masalah Pembayaran) | Alur `ON_THE_WAY → ARRIVED → WORKING → COMPLETED` berjalan; kuota 5x/minggu akurat; form penyelesaian (metode bayar aktual & bukti) dan tombol Laporkan Masalah Pembayaran berfungsi |
| **M6** | Pembatalan, Aturan 3 Jam OTW, Sistem Strike & Suspend | FR-018, FR-026, FR-028, FR-038, FR-039, FR-041; BR-50–57, BR-71 (Strike User saat `ON_THE_WAY`/`ARRIVED` diam > 30 mnt) | Geser-batal tukang (`DRAFT` tidak bocor ke User); tombol Cancel User muncul setelah 3 jam `ON_THE_WAY`; perhitungan Strike Tukang & Strike User (> 3x = suspend 2 hari) serta Suspend Permanen User tidak bayar berjalan akurat |
| **M7** | Admin Lengkap, Audit Log & FAQ In-App | FR-031, FR-036; halaman FAQ & Ketentuan Tertulis di aplikasi (Lampiran C) | Panel audit lengkap, dashboard analitik, dan halaman FAQ tampil di aplikasi |
| **M8** | Hardening & Persiapan Rilis | Seluruh NFR, uji E2E, uji konkurensi, persiapan review Play Store & App Store | Semua DoD terpenuhi; siap Beta/Soft Launch |

---

## 16. Definition of Done

Sebuah FR/milestone selesai jika **semua** terpenuhi:
- [ ] Seluruh acceptance criteria FR terkait lolos.
- [ ] Unit test dan integration test mereferensikan ID FR/BR.
- [ ] BR terkait ditegakkan di server/DB dan **dibuktikan dengan test negatif** (memanggil API langsung melewati UI).
- [ ] Ada **test konkurensi** untuk: batas 5 bid & auto-clear bid lain saat lock (BR-15, BR-17), persetujuan Nota & Revisi Nota (BR-05), serta pembatalan (BR-55, BR-56).
- [ ] Ada **test negatif** bahwa saat `DRAFT` pembatalan, tampilan User tidak berubah (BR-51) dan field internal tidak pernah bocor ke User (BR-53).
- [ ] Linter, formatter, analyzer bersih (`flutter analyze`, ESLint) tanpa peringatan baru.
- [ ] Migrasi database dapat dijalankan dari nol.

---

## 17. Risiko & Mitigasi

| ID | Risiko | Prob. | Dampak | Mitigasi |
| :--- | :--- | :-: | :-: | :--- |
| RISK-01 | **Cold start marketplace** | Tinggi | Tinggi | Mulai dari 1–2 area; rekrut tukang lebih dulu; tanpa potongan komisi sebagai daya tarik utama |
| RISK-02 | **Sengketa pembayaran di luar aplikasi (User menolak bayar / Tukang ubah harga)** | Tinggi | Tinggi | **(1)** Harga Nota Sah terkunci & Revisi Nota wajib di-Approve User dengan notifikasi perbandingan harga (BR-05). **(2)** Tombol khusus "Laporkan Masalah Pembayaran" bagi Tukang; User yang terbukti tidak membayar langsung di-suspend permanen oleh Admin tanpa toleransi 3x (BR-67). **(3)** FAQ & Aturan Tertulis yang tegas (Lampiran C) |
| RISK-04 | **Kebocoran data KYC / bukti transfer** | Rendah | Sangat Tinggi | Bucket privat `kyc-private` & `proof-photos`, signed URL, RLS, **MFA Admin**, audit log |
| RISK-05 | **GPS meleset di dalam gedung/gang sempit** | Tinggi | Sedang | Ambang otomatis `ARRIVED` ≤ 50 m + tombol fallback manual "Saya Sudah Tiba" ≤ 200 m (BR-60, BR-61) |
| RISK-13 | **Tukang atau User tidak responsif / membatalkan sepihak saat sudah jalan** | Sedang | Tinggi | Timer 30 menit klik Berangkat (+1 Strike Tukang), pembatalan tukang (+1 Strike Tukang), User diam > 30 menit saat tukang sudah `ON_THE_WAY`/`ARRIVED` (+1 Strike User); > 3x Strike = Suspend Otomatis 2 Hari |

---

## 18. Log Keputusan & Status Open Questions (v1.4)

### 18.1 Log Keputusan Lengkap (Decision Log)

| ID | Keputusan | Sumber | Dampak |
| :--- | :--- | :--- | :--- |
| **D-01** | **Radius:** job tersebar maks **50 km**; tukang mengatur slider **0–50 km** | **User** | BR-11, BR-20 |
| **D-02** | **Seluruh fitur Gold (termasuk Toggle Manual Admin), Boost, dan DOKU ditunda 100% ke Phase 2** | **User (Dikonfirmasi v1.4)** | NG-02, NG-03, BR-24/25, FR-034 |
| **D-04** | **Kuota Mingguan:** 5 job `COMPLETED` per minggu menurut zona waktu lokal tukang | **User** | BR-21–23, BR-75 |
| **D-09** | **Login Fleksibel** (Email+Password, Email OTP, Google OAuth); **1 Email = 2 Peran** (`USER` dan `TUKANG` diperbolehkan, role `BOTH`); **Web Admin wajib MFA** | **User (Diperbarui)** | FR-001, FR-037, BR-44 |
| **D-15** | **Backend:** Supabase saja (Auth, Realtime, Storage, Postgres + PostGIS + RPC/Edge Functions) | **User** | `docs/ARCHITECTURE.md` |
| **D-16** | **`WORKING` tidak dapat dibatalkan** oleh User maupun Tukang; tukang wajib menyelesaikan pekerjaan | **User** | BR-65, 9.3 |
| **D-17** | **Status `ARRIVED`:** otomatis pada jarak **≤ 50 m** (akurasi ≤ 30 m) + fallback manual **"Saya Sudah Tiba" pada ≤ 200 m** | **User (Dikonfirmasi v1.4)** | BR-60, BR-61, FR-024 |
| **D-18** | **Penyelesaian & Metode Bayar Aktual:** wajib foto hasil kerja + pilih metode bayar aktual + centang "User sudah membayar" + upload bukti transfer bila metode aktual non-tunai (tunai tanpa unggahan) | **User (v1.4)** | BR-32, FR-025 |
| **D-22** | **(Baru v1.4) Batas Lamar Maks 5 Job & Auto-Clear Saat Di-Lock:** Tukang boleh melamar maks 5 job `OPEN` (A, B, C, D, E). Begitu di-lock oleh User di 1 job (misal C), maka lamaran di job A, B, D, E otomatis ditarik/hilang dari histori apply tukang. Jika Job C batal, tukang melamar lagi dari awal | **User** | BR-15, BR-17, T2, FR-012, FR-022 |
| **D-23** | **(Baru v1.4) Keabsahan Nota & Revisi Nota Anti-Getok Harga:** Nota awal yang sudah disetujui User bersifat sah & terkunci. Jika ada tambahan biaya, Tukang wajib mengirim Revisi Nota yang memberi notifikasi jelas perbandingan harga lama vs baru di chat User, dan wajib di-Approve User. Tukang juga dapat menarik kembali Revisi Nota yang belum dijawab User | **User** | BR-05, BR-08, FR-015, FR-023 |
| **D-24** | **(Baru v1.4) Timer 30 Menit Wajib Klik "Berangkat" setelah `NOTA_APPROVED`:** Setelah Nota disetujui, Tukang wajib klik "Berangkat" dalam maks 30 menit (selama 30 menit itu User menunggu). Jika lewat 30 menit tidak klik Berangkat, job otomatis dilepas kembali ke Job Portal (`OPEN`) dan Tukang terkena 1 Strike (lebih dari 3x = suspend 2 hari) | **User** | BR-31, T4a, FR-014, FR-024 |
| **D-25** | **(Baru v1.4) Aturan Chat 30 Menit di `NEGOTIATING` (Tanpa Strike):** Saat baru di-lock (`NEGOTIATING`, Nota belum disetujui), jika User atau Tukang tidak membalas chat > 30 menit, job otomatis dilepas kembali ke Job Portal (`OPEN`) dan **TIDAK ADA STRIKE** untuk siapa pun (karena User bisa saja melakukan lock saat malam/jam tidur tukang) | **User** | BR-70, T3, FR-013 |
| **D-26** | **(Baru v1.4) Aturan Strike User & Suspend Langsung User Tidak Bayar:** **(1)** Jika Nota sudah disetujui dan Tukang sudah `ON_THE_WAY` atau `ARRIVED`, namun User tidak aktif/tidak membalas chat > 30 menit, **User terkena 1 Strike** (lebih dari 3x = suspend 2 hari). **(2)** Jika pekerjaan selesai (`WORKING`) dan User tidak mau membayar atau membayar kurang dari Nota Sah, Tukang melapor lewat tombol khusus ke Admin → Admin investigasi bukti → jika User terbukti bersalah, **Admin langsung men-suspend akun User tanpa pemakluman 3x** (banding via email resmi perusahaan) | **User** | BR-67, BR-71, FR-013, FR-025, FR-033 |
| **D-27** | **(Baru v1.4) Aturan Cancel Saat `ON_THE_WAY` (3 Jam) & `ARRIVED`:** **(1)** Di bawah 3 jam `ON_THE_WAY` dan saat `ARRIVED`, User tidak bisa cancel sepihak. **(2)** Jika `ON_THE_WAY` ≥ 3 jam tukang belum sampai, muncul tombol Cancel bagi User (butuh persetujuan tukang; otomatis disetujui + 1 Strike Tukang jika tukang tidak merespons dalam 30 menit). **(3)** Jika Tukang yang mengajukan cancel saat `NOTA_APPROVED`/`ON_THE_WAY`/`ARRIVED` dan disetujui User, job dilepas kembali ke portal (`OPEN`) dan Tukang terkena 1 Strike (lebih dari 3x = suspend 2 hari) | **User** | BR-55, BR-56, BR-57, FR-018, FR-026 |
| **D-28** | **(Baru v1.4) Privasi Sebelum Lock, Hapus Akun, & Reverse Geocoding HP:** Sebelum lock, Tukang hanya melihat detail job & nama kecamatan (dihasilkan dari geocoder bawaan HP User), sedangkan User hanya melihat foto profil, nama, keahlian, hari aktif, dan rating tukang. Fitur Hapus Akun tersedia di aplikasi | **User** | BR-16, BR-45, FR-004, FR-010, FR-011 |

### 18.2 Open Questions
> **Status:** Seluruh Open Questions kritis (🔴 `OQ-01` s/d `OQ-28`) **TELAH TERJAWAB DAN DIKUNCI** di dalam Log Keputusan di atas. Tidak ada lagi blocker untuk memulai penulisan dokumen teknis turunan (`AGENTS.md`, `DATABASE_SCHEMA.md`, `ARCHITECTURE.md`, `ROADMAP.md`) maupun implementasi kode.

---

## 19. Rencana Rilis

| Tahap | Deskripsi | Gerbang Masuk |
| :--- | :--- | :--- |
| **Alpha internal** | Tim sendiri + beberapa tukang kenalan, 1 area kecil | M0–M7 selesai |
| **Closed Beta** | Undangan terbatas (User & Tukang) | M8 selesai, S&K/PDP & FAQ in-app siap, build iOS lolos TestFlight |
| **Soft Launch** | 1 kota, pemantauan ketat metrik Bagian 4 | Guardrail terpenuhi selama beta |
| **Perluasan** | Tambah kota; mulai Phase 2 (Lampiran A) | Metrik primer tercapai |

---

## 20. Matriks Keterlacakan (Traceability)

| Goal | Requirement Terkait |
| :--- | :--- |
| G-01 | FR-001, FR-010, FR-011, FR-012, FR-020, FR-022, FR-027, BR-11, BR-15, BR-16, BR-17 |
| G-02 | FR-013, FR-014, FR-015, FR-023, BR-04, BR-05, BR-07, BR-08, BR-30, BR-31, BR-70 |
| G-03 | BR-01, BR-02, BR-03, BR-06 |
| G-04 | FR-002, FR-003, FR-032, FR-037, BR-10, BR-40, BR-41, BR-44 |
| G-05 | FR-016, FR-024, FR-030, BR-31, BR-60, BR-61 |
| G-06 | FR-017, FR-021, FR-025, BR-21–23, BR-32, BR-67 |
| G-07 | BR-01, NG-01 |
| G-08 | FR-004, FR-018, FR-026, FR-028, FR-031, FR-033, FR-035, FR-036, FR-038, FR-039, FR-040, FR-041, BR-42, BR-45, BR-50–57, BR-71 |

---

## Lampiran A. Catatan Phase 2 (Gold, Boost, Pembayaran DOKU)

> Bagian ini **hanya catatan perencanaan Phase 2**. DILARANG diimplementasikan di MVP (D-02).

- **Langganan Tukang Gold:** Slider radius 0–100 km, kuota pekerjaan selesai unlimited, Gold Badge, pin teratas pada daftar bid User, dan *headstart* notifikasi + visibilitas Job Portal 60 detik lebih awal. Pembayaran otomatis melalui **DOKU** (serta opsi toggle manual Admin).
- **Boost Pekerjaan oleh User:** Memperluas `broadcast_radius_km` dari 50 km menjadi 100 km dan mem-pin pekerjaan di urutan teratas Job Portal Tukang. Pembayaran otomatis melalui **DOKU**.
- **Migrasi Peta:** Mengganti adapter peta dari OpenStreetMap (`flutter_map`/MapLibre) ke **Google Maps Platform** penuh saat skala trafik sudah besar.

---

## Lampiran B. Rujukan & Tech Stack

| Lapisan | Teknologi |
| :--- | :--- |
| Mobile (`User`, `Tukang`) | Flutter (Dart), monorepo dengan paket bersama `mobile/shared` |
| Web Admin | Next.js (React) + Tailwind CSS + shadcn/ui |
| Backend, Auth, Realtime | Supabase (Postgres + PostGIS + Auth + Realtime + Storage + Edge Functions / `pg_cron`) |
| Email OTP | Custom SMTP (Resend) |
| Peta (MVP → Phase 2) | OpenStreetMap (`flutter_map`/MapLibre) via Map Provider Adapter → Google Maps Platform (Phase 2) |
| Reverse Geocoding Kecamatan | Geocoder bawaan OS perangkat (Android/iOS) saat pemilihan titik pin oleh User |
| Push Notification | Firebase Cloud Messaging (FCM) — satu bunyi notifikasi seragam |
| Payment Gateway SaaS (Phase 2) | DOKU |

---

## Lampiran C. FAQ & Aturan Tertulis Resmi (Wajib Tampil di Aplikasi User & Tukang)

> Bagian ini adalah **aturan tertulis resmi** yang wajib dapat diakses oleh Pelanggan (User) dan Mitra Tukang di dalam aplikasi (menu *Pusat Bantuan / Aturan & FAQ*) serta tercantum pada layar pembuatan/persetujuan Nota, agar kedua belah pihak memahami hak, kewajiban, kekuatan **Nota Digital**, dan sanksi tegas yang berlaku di ekosistem **Beres**.

### C.1 Aturan Pembayaran & Kekuatan Hukum "Nota Digital"
1. **Bagaimana cara pembayaran jasa tukang di aplikasi Beres?**
   * Aplikasi **Beres tidak menyimpan saldo/uang pelanggan** (*Zero In-App Wallet*) dan **tidak memotong komisi sepeser pun** dari penghasilan Tukang.
   * Seluruh pembayaran jasa dan material dilakukan **100% secara langsung** dari Pelanggan (User) kepada Mitra Tukang setelah pekerjaan selesai, sesuai metode pembayaran yang disepakati bersama di dalam **Nota Digital** (Transfer Bank ke rekening tukang, E-Wallet tukang, atau Uang Tunai/Cash).
2. **Apa fungsi dan kekuatan "Nota Digital" di dalam aplikasi?**
   * **Nota Digital adalah bukti kesepakatan harga resmi yang mengikat kedua belah pihak.**
   * Sebelum Tukang berangkat ke lokasi, Tukang wajib membuat Nota di ruang chat dan Pelanggan wajib menekan tombol **Setuju (Approve)**. Begitu disetujui, terbentuk **Nota Sah yang terkunci**.
   * **Larangan Getok Harga / Ubah Harga Sepihak:** Tukang **tidak bisa** mengedit atau menaikkan harga Nota yang sudah sah secara diam-diam.
3. **Bagaimana jika saat di lokasi ditemukan kerusakan tambahan atau butuh beli alat/material tambahan?**
   * Jika ada tambahan biaya di lapangan, Tukang wajib mengirimkan **Revisi Nota** di dalam aplikasi.
   * Aplikasi Pelanggan akan memberikan **notifikasi khusus di ruang chat** yang memperlihatkan perbandingan **Harga Nota Awal vs Harga Revisi Baru**.
   * Perubahan harga tersebut **hanya sah jika Pelanggan menekan tombol Setuju (Approve)** pada Revisi Nota tersebut. Jika Pelanggan menolak atau belum menyetujui, maka harga yang berlaku tetaplah harga **Nota Sah awal**.
4. **Apa sanksinya jika pekerjaan sudah selesai sesuai kesepakatan, tetapi Pelanggan (User) menolak membayar atau membayar kurang dari nominal Nota Sah?**
   * Tukang memiliki tombol khusus **"Laporkan Masalah Pembayaran"** pada halaman penyelesaian kerja.
   * Tim Admin Beres akan langsung melakukan investigasi mendalam dengan memeriksa seluruh bukti digital yang terekam di server: **riwayat Chat, Nota Sah yang telah disetujui Pelanggan, Foto Kerusakan Awal, dan Foto Bukti Hasil Pekerjaan Tukang**.
   * Apabila Pelanggan terbukti bersalah tidak mau membayar atau membayar kurang dari kesepakatan Nota Sah, **Admin Beres akan langsung memblokir (Suspend Permanen) akun Pelanggan tersebut SEKETIKA TANPA toleransi/pemakluman 3 kali!**
   * Pelanggan yang akunnya diblokir karena pelanggaran pembayaran hanya dapat mengajukan banding dengan mengirimkan bukti penyelesaian ke **Email Resmi Admin/Perusahaan Beres**.

### C.2 Aturan Melamar Pekerjaan (Bid), Lock Tukang, & Ruang Chat
5. **Berapa banyak pekerjaan yang bisa dilamar (Bid) oleh Tukang dalam satu waktu?**
   * Tukang dapat melamar maksimal hingga **5 pekerjaan terbuka (`OPEN`)** sekaligus (misalnya Pekerjaan A, B, C, D, dan E), selama kuota mingguan (5 pekerjaan selesai per minggu) masih tersedia.
   * **Aturan Otomatis Saat Dipilih (Lock):** Begitu salah satu Pelanggan (misal pemilik Pekerjaan C) memilih (*Lock*) Tukang tersebut, maka **lamaran Tukang di Pekerjaan A, B, D, dan E otomatis ditarik/dihapus oleh sistem**. Hal ini memastikan setiap Tukang fokus 100% melayani 1 Pelanggan sampai tuntas. Jika nantinya Pekerjaan C batal sebelum selesai, Tukang dapat kembali melamar pekerjaan baru di Job Portal.
6. **Bagaimana jika setelah Lock, salah satu pihak tidak membalas chat selama lebih dari 30 menit (sebelum Nota disetujui)?**
   * Jika Pelanggan memulai chat duluan namun Tukang tidak membalas > 30 menit, **ATAU** jika Tukang memulai chat/mengirim Nota duluan namun Pelanggan tidak membalas > 30 menit, maka pekerjaan tersebut **otomatis dilepas kembali ke Job Portal** agar dapat diambil oleh tukang lain (masing-masing pihak juga dapat menekan tombol Cancel untuk melepas pekerjaan ke portal).
   * Pada tahap obrolan awal ini (sebelum Nota disetujui), **TIDAK ADA pihak yang terkena poin pelanggaran (Strike)**, karena bisa saja Pelanggan memposting pekerjaan di siang hari namun baru memilih tukang di malam/tengah malam saat tukang sudah beristirahat.

### C.3 Aturan Keberangkatan, Pembatalan, dan Sanksi "Strike & Suspend 2 Hari"
7. **Kapan Tukang terkena poin pelanggaran (Strike) dan Suspend Otomatis 2 Hari?**
   Tukang akan mendapatkan **1 Poin Pelanggaran (Strike)** apabila melakukan salah satu dari hal berikut setelah **Nota Disetujui (`NOTA_APPROVED`)**:
   1. **Tidak menekan tombol "Berangkat" dalam waktu 30 menit** setelah Nota disetujui (pekerjaan akan otomatis dilepas kembali ke Job Portal agar Pelanggan bisa mencari tukang lain).
   2. **Membatalkan pekerjaan** pada saat status sudah `NOTA_APPROVED`, sedang di jalan (`ON_THE_WAY`), atau sudah tiba di lokasi (`ARRIVED`).
   3. **Tidak kunjung sampai di lokasi selama lebih dari 3 jam** sejak menekan tombol Berangkat (`ON_THE_WAY`), lalu dibatalkan oleh Pelanggan dan Tukang tidak merespons dalam 30 menit.
   * **Batas Toleransi Tukang:** Maksimal **3 kali Strike** dalam 1 bulan. Jika Tukang melakukan pelanggaran **lebih dari 3 kali (Strike ke-4)**, maka akun Tukang akan **otomatis di-suspend (dibekukan) selama 2 hari penuh (48 jam)** dan tidak dapat menerima ataupun mengerjakan pekerjaan apa pun.
8. **Kapan Pelanggan (User) terkena poin pelanggaran (Strike) dan Suspend Otomatis?**
   * **Menghilang Saat Tukang Sudah Berangkat / Sampai:** Apabila Nota sudah disetujui dan Tukang sudah dalam perjalanan (`ON_THE_WAY`) atau bahkan sudah tiba di lokasi (`ARRIVED`), namun Pelanggan **tidak aktif di aplikasi / tidak membalas chat Tukang selama lebih dari 30 menit**, maka **Pelanggan terkena 1 Strike**. Maksimal toleransi adalah **3 kali Strike** dalam 1 bulan; jika **lebih dari 3 kali (Strike ke-4)**, akun Pelanggan **otomatis di-suspend selama 2 hari penuh (48 jam)**.
   * **Tidak Membayar Jasa Tukang:** Langsung dikenakan **Suspend Permanen oleh Admin tanpa toleransi 3 kali** (lihat poin 4 di atas).
9. **Apakah pekerjaan bisa dibatalkan saat Tukang sedang di jalan (`ON_THE_WAY`), sudah sampai (`ARRIVED`), atau sedang bekerja (`WORKING`)?**
   * **Saat Tukang Sedang di Jalan (`ON_THE_WAY` di bawah 3 jam) & Saat Sudah Sampai (`ARRIVED`):** Pelanggan **tidak dapat** membatalkan sepihak karena Tukang sudah mengeluarkan waktu dan biaya perjalanan menuju lokasi. Hanya Tukang yang dapat mengajukan permohonan pembatalan (dengan mengisi form alasan dan meminta persetujuan Pelanggan, serta Tukang tetap terkena 1 Strike bila batal).
   * **Jika Tukang `ON_THE_WAY` Lebih dari 3 Jam Belum Sampai:** Di aplikasi Pelanggan akan muncul tombol **Cancel** untuk mengajukan pembatalan (otomatis disetujui dalam 30 menit bila Tukang tidak merespons).
   * **Saat Status Sedang Bekerja (`WORKING`):** Baik Pelanggan maupun Tukang **TIDAK DAPAT membatalkan pekerjaan**. Tukang wajib menyelesaikan pekerjaannya hingga tuntas, dan kendala darurat hanya dapat ditangani oleh Admin melalui menu **Laporkan**.
