import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beres_shared/beres_shared.dart';
import '../auth/login_screen.dart';
import '../jobs/job_create_screen.dart';
import '../jobs/job_detail_and_bids_screen.dart';
import '../notifications/notifications_screen.dart';

class UserHomeScreen extends ConsumerStatefulWidget {
  const UserHomeScreen({super.key});

  @override
  ConsumerState<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends ConsumerState<UserHomeScreen> {
  List<Job> _jobs = [];
  int _unreadNotifsCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final jobService = ref.read(jobServiceProvider);
    final notifService = ref.read(notificationServiceProvider);

    try {
      final jobs = await jobService.getUserJobs();
      final count = await notifService.getUnreadCount();
      if (mounted) {
        setState(() {
          _jobs = jobs;
          _unreadNotifsCount = count;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.read(authServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Beres Customer'),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'Notifikasi',
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsScreen(),
                    ),
                  );
                  _loadData();
                },
              ),
              if (_unreadNotifsCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.dangerCrimson,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      _unreadNotifsCount > 9 ? '9+' : '$_unreadNotifsCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                          decoration: const BoxDecoration(
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
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
                        style: AppTypography.headingMedium.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Posting pekerjaan Anda, pilih tukang terpercaya, dan sepakati Nota digital.',
                        style: AppTypography.bodyMedium.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final created = await Navigator.push<bool>(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const JobCreateScreen(),
                            ),
                          );
                          if (created == true) {
                            _loadData();
                          }
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

                // Section: Riwayat Pekerjaan Aktif
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Pekerjaan Saya (${_jobs.length})',
                      style: AppTypography.headingSmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: _loadData,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_jobs.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.assignment_outlined,
                            size: 40,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Belum ada pekerjaan aktif',
                            style: AppTypography.headingSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Klik tombol "Buat Pekerjaan Baru" di atas untuk mencari tukang.',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _jobs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final job = _jobs[index];
                      return _buildJobCard(job);
                    },
                  ),

                const SizedBox(height: 28),

                // Section: Pengaturan Akun & Kepatuhan Privasi (FR-004, BR-45)
                Text('Pengaturan & Privasi', style: AppTypography.headingSmall),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      const ListTile(
                        leading: Icon(
                          Icons.shield_outlined,
                          color: AppColors.trustCobalt,
                        ),
                        title: Text('Aturan 1 Email 1 Peran (BR-44)'),
                        subtitle: Text(
                          'Email Anda hanya terikat ke akun Pelanggan',
                        ),
                        trailing: Icon(
                          Icons.check_circle,
                          color: AppColors.successGreen,
                          size: 20,
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.menu_book_outlined,
                          color: AppColors.trustCobalt,
                        ),
                        title: const Text('Aturan & FAQ Resmi Beres (Lampiran C)'),
                        subtitle: const Text(
                          'Kekuatan Nota Sah, pembayaran langsung, & sanksi',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => FaqRulesScreen.show(context),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.delete_forever_outlined,
                          color: AppColors.dangerCrimson,
                        ),
                        title: Text(
                          'Hapus Akun Saya (FR-004)',
                          style: TextStyle(
                            color: AppColors.dangerCrimson,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: const Text(
                          'Hapus data akun permanen sesuai UU PDP (BR-45)',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          DeleteAccountDialog.show(
                            context,
                            authService: authService,
                            onAccountDeleted: () {
                              if (context.mounted) {
                                context.go('/');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Akun Anda berhasil dinonaktifkan/dihapus.',
                                    ),
                                  ),
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
      ),
    );
  }

  Widget _buildJobCard(Job job) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JobDetailAndBidsScreen(jobId: job.id),
            ),
          );
          _loadData();
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusBgColor(job.status),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      job.status.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _getStatusTextColor(job.status),
                      ),
                    ),
                  ),
                  Text(
                    Formatters.formatDateTime(job.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                job.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: AppColors.trustCobalt,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      job.areaLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              if (job.status != JobStatus.open &&
                  job.status != JobStatus.cancelled &&
                  job.status != JobStatus.expired &&
                  job.status != JobStatus.completed) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Buka Ruang Chat & Nota',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.trustCobalt,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward,
                      size: 14,
                      color: AppColors.trustCobalt,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusBgColor(JobStatus status) {
    switch (status) {
      case JobStatus.open:
        return AppColors.trustCobalt.withValues(alpha: 0.15);
      case JobStatus.negotiating:
        return AppColors.warningAmber.withValues(alpha: 0.15);
      case JobStatus.completed:
        return AppColors.successGreen.withValues(alpha: 0.15);
      case JobStatus.cancelled:
      case JobStatus.expired:
        return AppColors.dangerCrimson.withValues(alpha: 0.15);
      default:
        return AppColors.primaryNavy.withValues(alpha: 0.15);
    }
  }

  Color _getStatusTextColor(JobStatus status) {
    switch (status) {
      case JobStatus.open:
        return AppColors.trustCobalt;
      case JobStatus.negotiating:
        return AppColors.warningAmber;
      case JobStatus.completed:
        return AppColors.successGreen;
      case JobStatus.cancelled:
      case JobStatus.expired:
        return AppColors.dangerCrimson;
      default:
        return AppColors.primaryNavy;
    }
  }
}
