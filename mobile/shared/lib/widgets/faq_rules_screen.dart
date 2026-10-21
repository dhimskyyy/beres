import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Halaman Pusat Bantuan & Ketentuan Layanan Beres
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
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Pusat Bantuan & Panduan'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.userBadgeBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.trustCobalt.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  color: AppColors.trustCobalt,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transparan & Aman bagi Semua',
                        style: AppTypography.headingSmall.copyWith(
                          color: AppColors.trustCobalt,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Panduan ini menjelaskan cara kerja Nota Digital, pembayaran langsung, serta perlindungan bagi Pelanggan dan Mitra Tukang.',
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionHeader(
            icon: Icons.receipt_long_outlined,
            title: 'Pembayaran & Nota Digital',
          ),
          _buildFaqItem(
            question: 'Bagaimana cara pembayaran jasa tukang di Beres?',
            answer:
                '• Pembayaran dilakukan 100% langsung dari Pelanggan ke Mitra Tukang setelah pekerjaan selesai tanpa potongan komisi.\n'
                '• Anda dapat membayar melalui Transfer Bank, E-Wallet, atau Tunai sesuai kesepakatan pada Nota Digital.',
          ),
          _buildFaqItem(
            question: 'Apa fungsi Nota Digital?',
            answer:
                '• Nota Digital adalah bukti rincian biaya resmi yang disepakati sebelum tukang berangkat ke lokasi.\n'
                '• Setelah disetujui Pelanggan, harga pada Nota Sah terkunci sehingga bebas dari biaya tersembunyi.',
          ),
          _buildFaqItem(
            question: 'Bagaimana jika ada tambahan pekerjaan di lokasi?',
            answer:
                '• Jika terdapat kerusakan tambahan yang memerlukan biaya ekstra, Tukang akan mengirimkan Revisi Nota di ruang chat.\n'
                '• Aplikasi menampilkan perbandingan harga lama dan harga baru secara transparan, serta hanya berlaku jika disetujui Pelanggan.',
          ),
          _buildFaqItem(
            question:
                'Apa yang terjadi jika Pelanggan menolak membayar sesuai Nota Sah?',
            answer:
                '• Mitra Tukang dapat mengirim laporan kendala pembayaran beserta bukti foto hasil kerja.\n'
                '• Tim operasional akan meninjau bukti chat dan Nota Sah. Akun yang terbukti melanggar kesepakatan pembayaran akan dinonaktifkan secara permanen.',
            isWarning: true,
          ),
          const SizedBox(height: 18),
          _buildSectionHeader(
            icon: Icons.handshake_outlined,
            title: 'Pemesanan & Diskusi Chat',
          ),
          _buildFaqItem(
            question:
                'Berapa banyak pekerjaan yang dapat dilamar Mitra Tukang?',
            answer:
                '• Mitra Tukang dapat melamar hingga 5 pekerjaan terbuka sekaligus.\n'
                '• Saat seorang Pelanggan memilih dan mengunci satu Mitra Tukang, lamaran mitra tersebut di pekerjaan lain otomatis ditarik agar mitra fokus penuh pada satu pesanan.',
          ),
          _buildFaqItem(
            question: 'Berapa lama batas waktu respons chat saat negosiasi?',
            answer:
                '• Sebelum Nota disetujui, masing-masing pihak memiliki waktu 30 menit untuk membalas pesan.\n'
                '• Jika tidak ada respons lebih dari 30 menit, pesanan otomatis dikembalikan ke bursa terbuka tanpa penalti.',
          ),
          const SizedBox(height: 18),
          _buildSectionHeader(
            icon: Icons.shield_outlined,
            title: 'Keberangkatan, Pembatalan & Kedisiplinan',
          ),
          _buildFaqItem(
            question: 'Kapan Mitra Tukang menerima poin pelanggaran (Strike)?',
            answer: 'Mitra Tukang menerima 1 poin pelanggaran apabila:\n'
                '1. Tidak berangkat dalam 30 menit setelah Nota disetujui.\n'
                '2. Mengajukan pembatalan setelah Nota disetujui atau saat dalam perjalanan.\n'
                '3. Belum tiba di lokasi lebih dari 3 jam sejak berangkat dan tidak merespons pembatalan.\n\n'
                'Akun yang mengumpulkan lebih dari 3 pelanggaran dalam satu bulan akan ditangguhkan otomatis selama 48 jam.',
            isWarning: true,
          ),
          _buildFaqItem(
            question: 'Kapan Pelanggan menerima poin pelanggaran (Strike)?',
            answer:
                '• Pelanggan menerima 1 poin pelanggaran apabila tidak dapat dihubungi atau tidak membalas chat lebih dari 30 menit saat Mitra Tukang sudah dalam perjalanan atau tiba di lokasi.',
            isWarning: true,
          ),
          _buildFaqItem(
            question:
                'Apakah pesanan dapat dibatalkan saat pekerjaan sedang berlangsung?',
            answer:
                '• Saat pekerjaan sudah dimulai, pembatalan sepihak dikunci untuk melindungi kedua belah pihak hingga pekerjaan selesai.',
          ),
          const SizedBox(height: 24),
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
          Icon(icon, size: 18, color: AppColors.textPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: AppTypography.headingSmall.copyWith(fontSize: 14),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isWarning
                ? AppColors.dangerCrimson.withValues(alpha: 0.25)
                : AppColors.borderLight,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: ThemeData(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            iconColor:
                isWarning ? AppColors.dangerCrimson : AppColors.trustCobalt,
            collapsedIconColor: AppColors.textMuted,
            title: Text(
              question,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color:
                    isWarning ? AppColors.dangerCrimson : AppColors.textPrimary,
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Text(
                  answer,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
