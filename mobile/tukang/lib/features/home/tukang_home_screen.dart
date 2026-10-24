import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beres_shared/beres_shared.dart';
import '../auth/tukang_login_screen.dart';
import '../profile/tukang_onboarding_screen.dart';
import '../job_portal/job_portal_screen.dart';
import '../notifications/notifications_screen.dart';

final tukangJobServiceProvider = Provider((ref) => JobService());

class TukangHomeScreen extends ConsumerStatefulWidget {
  const TukangHomeScreen({super.key});

  @override
  ConsumerState<TukangHomeScreen> createState() => _TukangHomeScreenState();
}

class _TukangHomeScreenState extends ConsumerState<TukangHomeScreen> {
  Profile? _profile;
  TukangProfile? _tukangProfile;
  Job? _activeLockedJob;
  bool _isLoading = true;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final authService = ref.read(authServiceProvider);
    final tukangService = ref.read(tukangServiceProvider);
    final jobService = ref.read(tukangJobServiceProvider);

    try {
      final profile = await authService.getCurrentProfile();
      TukangProfile? tProfile;
      Job? lockedJob;
      if (profile != null) {
        tProfile = await tukangService.getTukangProfile(profile.id);
        lockedJob = await jobService.getActiveLockedJobForTukang();
      }
      if (mounted) {
        setState(() {
          _profile = profile;
          _tukangProfile = tProfile;
          _activeLockedJob = lockedJob;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignOut() async {
    final authService = ref.read(authServiceProvider);
    await authService.signOut();
    if (mounted) {
      context.go('/login');
    }
  }

  void _openChatScreen(String jobId) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ChatScreen(jobId: jobId)))
        .then((_) => _loadData());
  }

  void _openTrackingScreen(String jobId) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => TrackingScreen(
              jobId: jobId,
              isTukang: true,
              trackingService: TrackingService(),
              jobService: ref.read(tukangJobServiceProvider),
            ),
          ),
        )
        .then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    if (_profile != null && _profile!.isSuspended) {
      return SuspendScreen(
        isPermanent: _profile!.suspendType == SuspendType.manualPermanent,
        reason: _profile!.suspendReason ?? 'Akun mitra sedang ditangguhkan.',
        suspendedUntil: _profile!.suspendedUntil,
        onRefresh: _loadData,
        onSignOut: _handleSignOut,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: IndexedStack(
        index: _selectedTabIndex,
        children: [
          _buildDashboardTab(),
          const JobPortalScreen(embedded: true),
          const TukangNotificationsScreen(embedded: true),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.borderLight)),
        ),
        child: NavigationBar(
          selectedIndex: _selectedTabIndex,
          onDestinationSelected: (idx) {
            setState(() => _selectedTabIndex = idx);
            if (idx == 0 || idx == 3) {
              _loadData();
            }
          },
          destinations: [
            NavigationDestination(
              icon: Badge(
                isLabelVisible: _activeLockedJob != null,
                backgroundColor: AppColors.safetyOrange,
                child: const Icon(Icons.dashboard_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: _activeLockedJob != null,
                backgroundColor: AppColors.safetyOrange,
                child: const Icon(Icons.dashboard_rounded),
              ),
              label: 'Beranda',
            ),
            const NavigationDestination(
              icon: Icon(Icons.work_outline_rounded),
              selectedIcon: Icon(Icons.work_rounded),
              label: 'Bursa Kerja',
            ),
            const NavigationDestination(
              icon: Icon(Icons.notifications_none_rounded),
              selectedIcon: Icon(Icons.notifications_rounded),
              label: 'Notifikasi',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 1: BERANDA MITRA (Active Job, Verification Status, Quick Portal Access)
  // ===========================================================================
  Widget _buildDashboardTab() {
    final kycStatus = _tukangProfile?.kycStatus ?? KycStatus.pending;
    final firstName = (_profile?.fullName ?? 'Mitra').split(' ').first.trim();

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Halo, $firstName',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              kycStatus == KycStatus.approved
                  ? 'Mitra Tukang Terverifikasi'
                  : 'Lengkapi verifikasi untuk mulai melamar',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Panduan Mitra',
            onPressed: () => FaqRulesScreen.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Banner Verifikasi KTP (Hanya tampil jika belum APPROVED)
                  if (kycStatus != KycStatus.approved) ...[
                    _buildKycAlertCard(kycStatus),
                    const SizedBox(height: 16),
                  ],

                  // Pekerjaan Aktif / Terkunci (Spotlight Utama)
                  const Text(
                    'Tugas Aktif Saat Ini',
                    style: AppTypography.headingSmall,
                  ),
                  const SizedBox(height: 8),

                  if (_activeLockedJob != null)
                    _buildActiveJobCard(_activeLockedJob!)
                  else
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.tukangBadgeBg,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.handyman_outlined,
                              color: AppColors.safetyOrange,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Belum Ada Tugas Berjalan',
                            style: AppTypography.headingSmall,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Buka Bursa Kerja untuk melihat dan melamar pekerjaan terbuka di sekitar lokasi Anda.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () =>
                                  setState(() => _selectedTabIndex = 1),
                              icon: const Icon(
                                Icons.work_outline_rounded,
                                size: 18,
                              ),
                              label: const Text('Cari Pekerjaan di Bursa'),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Ringkasan Pengaturan Operasional
                  const Text(
                    'Pengaturan Kerja Anda',
                    style: AppTypography.headingSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.radar_rounded,
                          label: 'Radius Jangkauan',
                          value: '${_tukangProfile?.radiusKm ?? 20} km',
                          onTap: () => context
                              .push('/onboarding')
                              .then((_) => _loadData()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.verified_user_outlined,
                          label: 'Status Identitas',
                          value: kycStatus == KycStatus.approved
                              ? 'Terverifikasi'
                              : kycStatus == KycStatus.rejected
                              ? 'Perlu Perbaikan'
                              : 'Ditinjau',
                          onTap: () =>
                              context.push('/kyc').then((_) => _loadData()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildKycAlertCard(KycStatus kycStatus) {
    final isRejected = kycStatus == KycStatus.rejected;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRejected ? AppColors.dangerLight : AppColors.warningLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isRejected ? AppColors.dangerCrimson : AppColors.warningAmber)
              .withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isRejected
                    ? Icons.error_outline_rounded
                    : Icons.verified_user_outlined,
                color: isRejected
                    ? AppColors.dangerCrimson
                    : AppColors.warningAmber,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isRejected
                      ? 'Verifikasi KTP Perlu Diperbaiki'
                      : 'Selesaikan Verifikasi Identitas (KTP)',
                  style: AppTypography.headingSmall.copyWith(
                    fontSize: 14,
                    color: isRejected
                        ? AppColors.dangerCrimson
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isRejected
                ? 'Dokumen Anda memerlukan perbaikan. Unggah ulang foto KTP dan selfie agar dapat mulai melamar pekerjaan.'
                : 'Unggah foto KTP dan selfie Anda agar akun terverifikasi dan dapat melamar pekerjaan di Bursa Kerja.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/kyc').then((_) => _loadData()),
              style: ElevatedButton.styleFrom(
                backgroundColor: isRejected
                    ? AppColors.dangerCrimson
                    : AppColors.primaryNavy,
                minimumSize: const Size.fromHeight(42),
              ),
              icon: const Icon(Icons.upload_file_rounded, size: 17),
              label: Text(
                isRejected ? 'Unggah Ulang Dokumen' : 'Verifikasi Sekarang',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveJobCard(Job job) {
    final canTrack =
        job.status == JobStatus.onTheWay ||
        job.status == JobStatus.arrived ||
        job.status == JobStatus.working ||
        job.status == JobStatus.completed ||
        job.status == JobStatus.cancelPending;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.safetyOrange.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.tukangBadgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  job.status.label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tukangBadgeText,
                  ),
                ),
              ),
              if (job.agreedTotal != null)
                Text(
                  Formatters.formatCurrency(job.agreedTotal!),
                  style: AppTypography.rupiahMedium.copyWith(
                    color: AppColors.trustCobalt,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            job.description,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 15,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(job.areaLabel, style: AppTypography.bodySmall),
              ),
            ],
          ),
          const Divider(height: 22),
          if (canTrack) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openTrackingScreen(job.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.successGreen,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.navigation_outlined, size: 18),
                label: const Text('Pelaksanaan & Peta Lokasi'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openChatScreen(job.id),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: const Text('Buka Chat & Nota Digital'),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openChatScreen(job.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.trustCobalt,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: const Text('Buka Diskusi & Buat Nota Digital'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 20, color: AppColors.safetyOrange),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(label, style: AppTypography.bodySmall),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 4: PROFIL & PENGATURAN MITRA
  // ===========================================================================
  Widget _buildProfileTab() {
    final name = _profile?.fullName ?? 'Mitra Tukang';
    final email = _profile?.email ?? '-';
    final phone = (_profile?.phone != null && _profile!.phone!.isNotEmpty)
        ? _profile!.phone!
        : 'Belum diatur';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'M';
    final kycStatus = _tukangProfile?.kycStatus ?? KycStatus.pending;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Profil Mitra'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.tukangBadgeBg,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.tukangBadgeText,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTypography.headingSmall),
                      const SizedBox(height: 2),
                      Text(email, style: AppTypography.bodySmall),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: kycStatus == KycStatus.approved
                              ? AppColors.successLight
                              : AppColors.warningLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          kycStatus == KycStatus.approved
                              ? 'Mitra Terverifikasi'
                              : 'Menunggu Verifikasi KTP',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: kycStatus == KycStatus.approved
                                ? AppColors.successGreen
                                : AppColors.warningAmber,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kontak & Operasional',
                  style: AppTypography.labelSmall,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nomor Telepon / WhatsApp',
                            style: AppTypography.bodySmall,
                          ),
                          Text(
                            phone,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Material(
            color: AppColors.surfaceWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.borderLight),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.build_circle_outlined,
                    color: AppColors.safetyOrange,
                    size: 22,
                  ),
                  title: const Text(
                    'Keahlian, Radius & Rekening',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    'Atur kategori keahlian dan rekening penerima pembayaran',
                    style: AppTypography.bodySmall,
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                  ),
                  onTap: () =>
                      context.push('/onboarding').then((_) => _loadData()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.badge_outlined,
                    color: AppColors.trustCobalt,
                    size: 22,
                  ),
                  title: const Text(
                    'Verifikasi Identitas (KTP)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    'Status dokumen KTP dan foto selfie verifikasi',
                    style: AppTypography.bodySmall,
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                  ),
                  onTap: () => context.push('/kyc').then((_) => _loadData()),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.help_outline_rounded,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                  title: const Text(
                    'Pusat Bantuan & Panduan Mitra',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    'Panduan Nota Digital, kuota kerja, dan ketentuan',
                    style: AppTypography.bodySmall,
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                  ),
                  onTap: () => FaqRulesScreen.show(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.textPrimary,
                    size: 22,
                  ),
                  title: const Text(
                    'Keluar dari Akun',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                  ),
                  onTap: _handleSignOut,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.dangerCrimson,
                    size: 22,
                  ),
                  title: const Text(
                    'Hapus Akun Saya',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.dangerCrimson,
                    ),
                  ),
                  subtitle: const Text(
                    'Hapus permanen data akun mitra dari sistem',
                    style: AppTypography.bodySmall,
                  ),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textMuted,
                  ),
                  onTap: () {
                    DeleteAccountDialog.show(
                      context,
                      authService: ref.read(authServiceProvider),
                      userEmail: _profile?.email,
                      onAccountDeleted: () => context.go('/login'),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
