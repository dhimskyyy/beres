# Beres v1.4.0 — Master Design System (UI/UX Pro Max — Anti-AI-Slop Edition)

> **SOURCE OF TRUTH:** Dokumen ini adalah standar visual dan interaksi utama untuk 3 aplikasi **Beres v1.4.0** (`mobile/user`, `mobile/tukang`, dan `web/admin`), disusun menggunakan metodologi **`ui-ux-pro-max`** (`pro-rules.md` & `quick-reference.md`) dan dikunci penuh terhadap spesifikasi **[`docs/PRD.md`](../../docs/PRD.md) v1.4.0**.

---

## 1. Filosofi Desain: "Industrial Utility & High-Trust P2P Clarity" (Zero AI Slop)

Aplikasi marketplace pertukangan di Indonesia membutuhkan keseimbangan antara **kepercayaan institusional** (bagi Pelanggan yang mengundang orang asing ke rumah dan menyetujui Nota Digital) serta **keterbacaan ekstrem di lapangan** (bagi Mitra Tukang yang menggunakan layar HP di bawah terik matahari dengan tangan bekerja).

### Aturan Anti-AI-Slop (WAJIB DIPATUHI DI SELURUH LAYAR):
1. **DILARANG Menggunakan Gradien Neon / Ungu-Biru Generik:** Seluruh latar belakang, kartu, dan tombol wajib menggunakan warna solid yang tegas dan terkalibrasi.
2. **DILARANG Menggunakan Glassmorphism / Blur Berlebihan:** Hirarki visual dibangun melalui kontras bidang (`#F8FAFC` canvas vs `#FFFFFF` card), garis batas presisi `1px solid #E2E8F0`, dan bayangan fungsional tipis.
3. **DILARANG Menggunakan Emoji Sebagai Ikon UI:** Wajib menggunakan ikon vektor konsisten (Lucide Icons / Material Symbols Outlined dengan ketebalan stroke `1.75px`–`2px`).
4. **DILARANG Menggunakan Angka Proporsional untuk Uang & Timer:** Seluruh nominal Rupiah (`Rp 150.000`), nomor Nota (`#NTA-2026-0412`), timer mundur (`29:45`), jarak GPS (`42m • ±8m`), dan indikator Strike (`[2/3 STRIKE]`) **WAJIB** menggunakan font monospace **`JetBrains Mono`** (`tabular-nums`).
5. **DILARANG Menggunakan Teks Placeholder Bahasa Inggris / Lorem Ipsum:** Seluruh label, alamat (`Kel. Tebet Timur, Kec. Tebet`), nama kategori (`Kelistrikan`, `Pipa & Ledeng`), dan rincian Nota wajib menggunakan Bahasa Indonesia yang natural dan kontekstual.

---

## 2. Palet Warna Semantik (`Color Tokens`)

### A. Brand & Surface Tokens
| Token | Hex | Peruntukan Utama | Kontras (WCAG 2.2) |
| :--- | :--- | :--- | :--- |
| `--color-primary` | `#0F2942` | **Deep Industrial Navy** — Header utama, navigasi aktif, otoritas brand Beres | 14.2:1 vs Putih (AAA) |
| `--color-secondary` | `#1E40AF` | **Trust Cobalt Blue** — Badge informasi, tautan interaktif, pin lokasi User | 8.6:1 vs Putih (AAA) |
| `--color-accent` | `#EA580C` | **Safety Action Orange** — Tombol CTA utama (*Pilih Tukang*, *Berangkat ke Lokasi*, *Kirim Nota*) | 4.6:1 vs Putih (AA) |
| `--color-canvas` | `#F8FAFC` | **Cool Slate Alabaster** — Latar belakang dasar layar (mengurangi silau matahari) | — |
| `--color-surface` | `#FFFFFF` | **Pure Crisp White** — Kartu job, kartu Nota Digital, panel tabel Admin | — |
| `--color-surface-muted` | `#F1F5F9` | **Slate 100** — Header tabel, kotak perbandingan harga lama pada Revisi Nota | — |
| `--color-text-primary` | `#0F172A` | **Slate 900** — Judul, nominal harga, teks utama | 17.8:1 vs Putih (AAA) |
| `--color-text-secondary`| `#475569` | **Slate 600** — Deskripsi keluhan, label form, timestamp | 7.5:1 vs Putih (AAA) |
| `--color-border` | `#E2E8F0` | **Slate 200** — Garis pemisah struktural `1px solid` | — |

### B. Semantic Status Tokens (10 Status Pekerjaan & Sistem Sanksi)
Setiap status **wajib** memiliki kombinasi Ikon Vektor + Teks Label + Warna Semantik (tidak boleh hanya mengandalkan warna):

| Status / Kondisi | Background Tint | Border (`1px`) | Text & Icon | Kegunaan di PRD v1.4.0 |
| :--- | :--- | :--- | :--- | :--- |
| **Open / Negotiating** | `#EFF6FF` | `#BFDBFE` | `#1E40AF` | Status `OPEN`, `NEGOTIATING`, Timer Chat 30 Menit |
| **Verified / Nota Sah / Completed** | `#F0FDF4` | `#BBF7D0` | `#15803D` | Status `NOTA_APPROVED`, `COMPLETED`, Badge **NOTA SAH (IMMUTABLE)**, KYC `APPROVED` |
| **Active Field / Revisi Nota** | `#FFFBEB` | `#FDE68A` | `#B45309` | Status `ON_THE_WAY`, `ARRIVED`, `WORKING`, Alert **Revisi Nota (`SENT`)**, Timer Klik Berangkat 30 Menit |
| **Critical / Strike / Dispute** | `#FEF2F2` | `#FECACA` | `#B91C1C` | Status `CANCEL_PENDING`, `CANCELLED`, Badge **Strike `[1-3/3]`**, Suspend 48 Jam, & Tombol **Laporkan Masalah Pembayaran** |
| **Neutral / Superseded / Expired** | `#F1F5F9` | `#CBD5E1` | `#475569` | Status `EXPIRED`, Lamaran `WITHDRAWN` (Auto-Clear), Revisi Nota `SUPERSEDED` |

---

## 3. Sistem Tipografi (`Typography Scale`)

* **Headline & UI Body Font:** **`Plus Jakarta Sans`** (Weights: `400` Regular, `500` Medium, `600` SemiBold, `700` Bold) — Dirancang khusus dengan proporsi x-height tinggi yang sangat nyaman untuk kosakata Bahasa Indonesia.
* **Financial, Timer & Telemetry Font:** **`JetBrains Mono`** (Weights: `500` Medium, `600` SemiBold, `700` Bold) — Wajib untuk seluruh angka uang, jarak meter, countdown timer, dan ID transaksi.

| Level | Font Family | Ukuran (Mobile / Desktop) | Weight | Line Height | Penggunaan |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `display-price` | `JetBrains Mono` | `24px` / `28px` | `700` | `1.2` | Total Nominal Nota Digital & Perbandingan Revisi |
| `headline-lg` | `Plus Jakarta Sans` | `22px` / `26px` | `700` | `1.25` | Judul Halaman Utama & Status Operasional Besar |
| `headline-md` | `Plus Jakarta Sans` | `18px` / `20px` | `600` | `1.3` | Judul Kartu Job, Nama Tukang, Header Modal |
| `body-md` | `Plus Jakarta Sans` | `15px` / `14px` | `400` | `1.5` | Deskripsi Pekerjaan, Isi Chat, Form Input |
| `label-strong` | `Plus Jakarta Sans` | `13px` / `13px` | `600` | `1.35` | Teks Tombol, Tab Navigasi, Label Input |
| `code-telemetry`| `JetBrains Mono` | `12px` / `12px` | `600` | `1.2` | Countdown (`29:14`), GPS (`38m • ±6m`), Badge Strike |

---

## 4. Aturan Komponen Krusial Beres v1.4.0

1. **Kartu Nota Digital & Alert Komparasi Revisi Nota (Di Ruang Chat):**
   * **Nota Sah:** Berbingkai hijau tegas (`2px solid #16A34A`) dengan segel vektor `"NOTA SAH • TERKUNCI"` dan rincian Biaya Jasa + Material + Metode Bayar Rencana.
   * **Kartu Revisi Nota (`BR-05`, `BR-08`):** Wajib menampilkan kotak komparasi berdampingan:
     * Kolom Kiri (Muted): `Harga Nota Awal: Rp 100.000` (dicoret halus)
     * Kolom Kanan (Highlight Amber): `Harga Revisi Baru: Rp 150.000 (+Rp 50.000)`
     * Di aplikasi User: Tombol **Setujui Revisi (`#16A34A`)** & **Tolak Revisi (`#DC2626`)**.
     * Di aplikasi Tukang (selama status `SENT`): Tombol **Tarik / Batalkan Revisi Nota (`SUPERSEDED`)** agar tidak memblokir tombol Selesaikan Tugas.
2. **Komponen Operasional Lapangan Tukang (Touch Target Minimum `48x48dp`):**
   * **Banner Timer 30 Menit Klik Berangkat (`BR-31`):** Pita peringatan kuning-oranye di atas layar dengan angka mundur `JetBrains Mono` berukuran besar dan tombol penuh **"BERANGKAT KE LOKASI SEKARANG"**.
   * **Slide-to-Cancel (`BR-50`):** Track geser berbentuk pil dengan knob panah yang harus digeser penuh ke kanan untuk mencegah kepencet tidak sengaja di kantong celana tukang.
   * **Checklist Selesaikan Tugas (`BR-32`) vs Laporkan Masalah Pembayaran (`BR-67`):** Tombol **"Selesaikan Tugas"** menggunakan state *disabled* yang jelas jika 5 syarat belum lengkap, sedangkan di bawahnya terdapat kotak khusus berbingkai merah untuk **"Laporkan Masalah Pembayaran (User Tidak Bayar / Kurang)"**.
3. **Navigasi & Keterhubungan Layar (Screen-to-Screen Flow):**
   * **App User & App Tukang:** Menggunakan *Bottom Navigation Bar* (maksimal 4 tab dengan ikon vektor + label teks tegas) dan *Top App Bar* yang selalu menampilkan tombol *Back* konsisten, badge status job, serta indikator kuota/strike.
   * **Web Admin:** Menggunakan *Persistent Left Sidebar* (`240px`) dengan badge angka antrean real-time (misal: `KYC Pending [4]`, `Sengketa Bayar [2]`) + *Top Breadcrumb & Admin MFA Status Bar*.
