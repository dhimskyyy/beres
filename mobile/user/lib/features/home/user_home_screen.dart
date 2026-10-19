import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beres_shared/beres_shared.dart';
import '../auth/login_screen.dart';

class UserHomeScreen extends ConsumerWidget {
  const UserHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.read(authServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Beres Customer'),
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
                          color: AppColors.userBadgeBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person,
                          size: 30,
                          color: AppColors.trustCobalt,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pelanggan Beres',
                              style: AppTypography.headingSmall,
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.userBadgeBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Role: USER (Pelanggan)',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.userBadgeText,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Action Banner: Panggil Tukang
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryNavy, AppColors.trustCobalt],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Butuh Bantuan Tukang?',
                      style: AppTypography.headingMedium.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Posting pekerjaan Anda, pilih tukang terpercaya, dan sepakati Nota digital.',
                      style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Fitur Posting Pekerjaan akan aktif di Milestone M3.')),
                        );
                      },
                      icon: const Icon(Icons.add_task),
                      label: const Text('Buat Pekerjaan Baru'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryNavy,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section: Pengaturan Akun & Kepatuhan Privasi (FR-004, BR-45)
              Text('Pengaturan & Privasi', style: AppTypography.headingSmall),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.shield_outlined, color: AppColors.trustCobalt),
                      title: const Text('Aturan 1 Email 1 Peran (BR-44)'),
                      subtitle: const Text('Email Anda hanya terikat ke akun Pelanggan'),
                      trailing: const Icon(Icons.check_circle, color: AppColors.successGreen, size: 20),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.delete_forever_outlined, color: AppColors.dangerCrimson),
                      title: Text(
                        'Hapus Akun Saya (FR-004)',
                        style: TextStyle(color: AppColors.dangerCrimson, fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text('Hapus data akun permanen sesuai UU PDP (BR-45)'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        DeleteAccountDialog.show(
                          context,
                          authService: authService,
                          onAccountDeleted: () {
                            if (context.mounted) {
                              context.go('/');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Akun Anda berhasil dinonaktifkan/dihapus.')),
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
