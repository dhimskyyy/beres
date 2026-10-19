import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beres_shared/beres_shared.dart';
import '../auth/tukang_login_screen.dart';

class TukangHomeScreen extends ConsumerWidget {
  const TukangHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.read(authServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Beres Mitra'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () async {
              await authService.signOut();
              if (context.mounted) {
                context.go('/');
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card Profil
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.tukangBadgeBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.engineering,
                          size: 30,
                          color: AppColors.safetyOrange,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mitra Tukang Beres',
                              style: AppTypography.headingSmall,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.tukangBadgeBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Role: TUKANG',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.tukangBadgeText,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.warningLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'KYC: PENDING',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.warningAmber,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Kartu Info KYC & Bursa
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_user_outlined, color: AppColors.trustCobalt, size: 22),
                        const SizedBox(width: 8),
                        Text('Verifikasi KTP (KYC)', style: AppTypography.headingSmall),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Unggah Foto KTP & Selfie di Milestone M2 agar dapat melihat bursa pekerjaan dan mulai melamar (BR-10).',
                      style: AppTypography.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Alur unggah Foto KTP akan aktif di Milestone M2.')),
                        );
                      },
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Unggah Berkas KYC'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section: Pengaturan & Kepatuhan Privasi (FR-004, BR-45)
              Text('Pengaturan & Informasi Akun', style: AppTypography.headingSmall),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.shield_outlined, color: AppColors.safetyOrange),
                      title: const Text('Aturan 1 Email 1 Peran (BR-44)'),
                      subtitle: const Text('Email Anda terikat khusus untuk akun Mitra Tukang'),
                      trailing: const Icon(Icons.check_circle, color: AppColors.successGreen, size: 20),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.info_outline, color: AppColors.warningAmber),
                      title: const Text('Aturan Pelanggaran & Strike (BR-57)'),
                      subtitle: const Text('Batas 3x strike per bulan kalender. Strike ke-4 = suspend 48 jam.'),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.delete_forever_outlined, color: AppColors.dangerCrimson),
                      title: Text(
                        'Hapus Akun Mitra (FR-004)',
                        style: TextStyle(color: AppColors.dangerCrimson, fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text('Hapus data akun sesuai regulasi UU PDP (BR-45)'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        DeleteAccountDialog.show(
                          context,
                          authService: authService,
                          onAccountDeleted: () {
                            if (context.mounted) {
                              context.go('/');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Akun Mitra Anda berhasil dinonaktifkan/dihapus.')),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
