import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Halaman FAQ & Aturan Tertulis Resmi Beres v1.4.0 (Lampiran C PRD)
/// Wajib tampil di aplikasi User dan Tukang (menu Pusat Bantuan / Aturan & FAQ)
class FaqRulesScreen extends StatelessWidget {
  const FaqRulesScreen({super.key});

  static void show(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const FaqRulesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aturan Resmi & FAQ Beres'),
        backgroundColor: AppColors.trustCobalt,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner Pendahuluan
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.gavel, color: AppColors.trustCobalt, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Standar Operasional Resmi (v1.4.0)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.trustCobalt,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Seluruh aktivitas di platform Beres tunduk pada aturan tertulis resmi di bawah ini demi melindungi hak Pelanggan dan Mitra Tukang.',
                        style: AppTypography.bodySmall
                            .copyWith(color: Colors.blueGrey.shade800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // SEKSI C.1
          _buildSectionHeader(
            icon: Icons.receipt_long,
            title: 'C.1 Aturan Pembayaran & Kekuatan Nota Digital',
          ),
          _buildFaqItem(
            question: '1. Bagaimana cara pembayaran jasa tukang di Beres?',
            answer:
                '• Aplikasi Beres tidak menyimpan saldo/uang pengguna (Zero In-App Wallet) dan tidak memotong komisi sepeser pun (0% komisi).\n'
                '• Pembayaran jasa dan material 100% langsung dari Pelanggan ke Mitra Tukang setelah pekerjaan selesai.\n'
                '• Metode bayar disepakati di Nota: Transfer Bank ke rekening tukang, E-Wallet tukang, atau Tunai (Cash).',
          ),
          _buildFaqItem(
            question: '2. Apa fungsi dan kekuatan "Nota Digital"?',
            answer:
                '• Nota Digital adalah bukti kesepakatan harga resmi yang mengikat kedua belah pihak secara hukum.\n'
                '• Sebelum tukang berangkat, tukang wajib membuat Nota di ruang chat dan Pelanggan wajib menekan Setujui (Approve).\n'
                '• Begitu disetujui, terbentuk Nota Sah yang terkunci (Immutable). Tukang dilarang keras getok harga atau mengubah harga sepihak.',
          ),
          _buildFaqItem(
            question: '3. Bagaimana jika ada kerusakan tambahan di lokasi?',
            answer:
                '• Jika ada tambahan biaya di lapangan, Tukang wajib mengirimkan Revisi Nota di dalam aplikasi.\n'
                '• Aplikasi Pelanggan akan memunculkan notifikasi khusus di ruang chat yang memperbandingkan Harga Nota Awal vs Harga Revisi Baru.\n'
                '• Perubahan harga hanya sah jika Pelanggan menekan tombol Approve pada Revisi Nota tersebut.',
          ),
          _buildFaqItem(
            question:
                '4. Apa sanksinya jika pekerjaan selesai tetapi Pelanggan menolak bayar / bayar kurang?',
            answer:
                '• Tukang memiliki tombol khusus "Laporkan Masalah Pembayaran (BR-67)".\n'
                '• Admin Beres langsung menginvestigasi bukti chat, Nota Sah, dan foto hasil kerja.\n'
                '• Jika Pelanggan terbukti bersalah, Admin LANGSUNG memblokir (Suspend Permanen) akun Pelanggan tersebut SEKETIKA TANPA toleransi 3 kali!\n'
                '• Banding hanya dapat diajukan melalui email resmi perusahaan.',
            isWarning: true,
          ),
          const SizedBox(height: 20),

          // SEKSI C.2
          _buildSectionHeader(
            icon: Icons.work_history,
            title: 'C.2 Aturan Melamar, Lock Tukang, & Chat',
          ),
          _buildFaqItem(
            question: '5. Berapa banyak pekerjaan yang bisa dilamar Tukang?',
            answer:
                '• Tukang dapat melamar (bid) maksimal 5 pekerjaan terbuka (OPEN) sekaligus.\n'
                '• Aturan Auto-Clear (BR-17): Begitu salah satu Pelanggan menekan "Lock Tukang", seluruh lamaran tukang di pekerjaan lain OTOMATIS ditarik/dihapus oleh sistem agar tukang fokus 100% pada 1 pekerjaan.',
          ),
          _buildFaqItem(
            question:
                '6. Bagaimana jika chat tidak dibalas > 30 menit saat tahap Negosiasi?',
            answer:
                '• Jika salah satu pihak tidak membalas chat selama > 30 menit pada tahap NEGOTIATING (sebelum Nota disetujui), pekerjaan otomatis dilepas kembali ke Bursa Pekerjaan (OPEN).\n'
                '• Pada tahap ini TIDAK ADA pihak yang terkena poin Strike, karena kedua belah pihak masih tahap penjajakan.',
          ),
          const SizedBox(height: 20),

          // SEKSI C.3
          _buildSectionHeader(
            icon: Icons.shield_outlined,
            title: 'C.3 Keberangkatan, Pembatalan, & Strike/Suspend',
          ),
          _buildFaqItem(
            question: '7. Kapan Tukang terkena Strike & Suspend Otomatis 2 Hari?',
            answer:
                'Tukang menerima 1 Strike jika:\n'
                '1. Tidak klik "Berangkat" dalam 30 menit setelah Nota disetujui (job dilepas ke portal).\n'
                '2. Mengajukan pembatalan saat NOTA_APPROVED, ON_THE_WAY, atau ARRIVED yang disetujui User.\n'
                '3. Perjalanan ON_THE_WAY >= 3 jam belum tiba, dibatalkan User dan tukang tidak merespons dalam 30 menit.\n\n'
                'Sanksi: Maksimal 3 Strike per bulan kalender. Pada Strike ke-4 (> 3x), akun OTOMATIS DIBEKUKAN selama 2 hari penuh (48 jam).',
            isWarning: true,
          ),
          _buildFaqItem(
            question: '8. Kapan Pelanggan (User) terkena Strike & Suspend?',
            answer:
                '• Pelanggan menghilang / tidak membalas chat tukang > 30 menit saat tukang sudah ON_THE_WAY atau ARRIVED -> Pelanggan menerima 1 Strike (ke-4 otomatis suspend 2 hari).\n'
                '• Pelanggan menolak bayar / bayar kurang dari Nota Sah -> Langsung Suspend Permanen oleh Admin tanpa toleransi 3 kali.',
            isWarning: true,
          ),
          _buildFaqItem(
            question:
                '9. Apakah pekerjaan bisa dibatalkan saat perjalanan atau bekerja?',
            answer:
                '• ON_THE_WAY < 3 jam & ARRIVED: Pelanggan TIDAK BISA membatalkan sepihak. Hanya tukang yang bisa mengajukan batal (+1 Strike tukang).\n'
                '• ON_THE_WAY >= 3 jam belum tiba: Muncul tombol Cancel bagi Pelanggan (BR-56b).\n'
                '• WORKING: DILARANG BATAL oleh kedua belah pihak (BR-65). Tukang wajib menyelesaikan pekerjaan.',
          ),
          const SizedBox(height: 30),

          // Footer
          Center(
            child: Text(
              'Beres Platform v1.4.0 — Beres, Cepat, Tanpa Ribet',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.trustCobalt),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem({
    required String question,
    required String answer,
    bool isWarning = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isWarning ? Colors.red.shade50.withValues(alpha: 0.5) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isWarning ? Colors.red.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Theme(
        data: ThemeData(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: isWarning ? AppColors.error : AppColors.trustCobalt,
          collapsedIconColor: Colors.grey.shade600,
          title: Text(
            question,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isWarning ? const Color(0xFF9F1239) : Colors.black87,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                answer,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
