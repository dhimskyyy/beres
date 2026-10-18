## 📌 Ringkasan Perubahan (Pull Request)

- **Milestone Terkait:** `M_ (Contoh: M1 / M3 / M4)`
- **ID Requirement (`FR-xxx` / `BR-xx`):** `Contoh: FR-012, BR-15, BR-17`
- **Aplikasi yang Disentuh:**
  - [ ] `supabase/` (Database PostgreSQL + PostGIS / RPC / RLS)
  - [ ] `mobile/shared/` (`beres_shared`)
  - [ ] `mobile/user/` (`Beres User`)
  - [ ] `mobile/tukang/` (`Beres Mitra`)
  - [ ] `web/admin/` (`Beres Web Admin`)

---

## 📝 Deskripsi
<!-- Jelaskan secara singkat apa yang dikerjakan di PR ini dan bagaimana PR ini memenuhi Acceptance Criteria di docs/PRD.md v1.4.0 -->

---

## ✅ Checklist Definition of Done (Wajib Sesuai Bagian 16 `docs/PRD.md` v1.4.0)

- [ ] **Acceptance Criteria Lolos:** Seluruh poin *Given / When / Then* pada `FR-xxx` terkait sudah terpenuhi.
- [ ] **Penegakan di Server/DB:** Seluruh aturan bisnis (`BR-xx`) ditegakkan di sisi database/server (Trigger, RPC atomik, RLS), **bukan hanya di UI klien**.
- [ ] **Unit & Integration Test:** Memiliki test otomatis yang mencantumkan ID `FR-xxx` / `BR-xx` pada nama test-nya.
- [ ] **Test Negatif (`BR-xx`):** Dibuktikan dengan test negatif (pemanggilan API langsung melewati UI ditolak oleh server, dan data internal `BR-53` / `DRAFT` `BR-51` tidak bocor ke User).
- [ ] **Test Konkurensi (Jika Menyentuh Lock/Bid/Nota/Cancel):** Aman terhadap *race condition* (permintaan paralel).
- [ ] **Kualitas Kode Bersih:** `flutter analyze`, `dart format`, dan `eslint` lolos tanpa warning/error.
- [ ] **Disiplin MVP (Non-Goals & Phase 2):** Tidak mengimplementasikan fitur Phase 2 (Gold, Toggle Manual Gold, Boost 100 km, DOKU) atau In-App Wallet (`BR-01`).
- [ ] **Dokumentasi Sinkron:** Jika ada perubahan skema/perilaku, `docs/PRD.md`, `docs/DATABASE_SCHEMA.md`, dan `docs/ROADMAP.md` telah diperbarui.
