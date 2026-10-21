import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beres_shared/beres_shared.dart';
import '../auth/login_screen.dart';
import '../notifications/notifications_screen.dart';

final userJobServiceProvider = Provider((ref) => JobService());

class UserHomeScreen extends ConsumerStatefulWidget {
  const UserHomeScreen({super.key});

  @override
  ConsumerState<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends ConsumerState<UserHomeScreen> {
  Profile? _profile;
  List<Job> _myJobs = [];
  bool _isLoading = true;
  int _selectedTabIndex = 0;
  String _jobFilter = 'ALL'; // ALL, ACTIVE, HISTORY

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final authService = ref.read(authServiceProvider);
    final jobService = ref.read(userJobServiceProvider);

    try {
      final profile = await authService.getCurrentProfile();
      final jobs = await jobService.getUserJobs();
      if (mounted) {
        setState(() {
          _profile = profile;
          _myJobs = jobs;
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

  List<Job> get _activeJobs => _myJobs.where((j) => j.status.isActive).toList();

  List<Job> get _filteredJobs {
    if (_jobFilter == 'ACTIVE') {
      return _myJobs.where((j) => j.status.isActive).toList();
    }
    if (_jobFilter == 'HISTORY') {
      return _myJobs.where((j) => j.status.isTerminal).toList();
    }
    return _myJobs;
  }

  @override
  Widget build(BuildContext context) {
    if (_profile != null && _profile!.isSuspended) {
      return SuspendScreen(
        isPermanent: _profile!.suspendType == SuspendType.manualPermanent,
        reason: _profile!.suspendReason ?? 'Akun sedang ditangguhkan.',
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
          _buildOrdersTab(),
          const UserNotificationsScreen(embedded: true),
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
            if (idx == 0 || idx == 1 || idx == 3) {
              _loadData();
            }
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Beranda',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: _activeJobs.isNotEmpty,
                label: Text('${_activeJobs.length}'),
                backgroundColor: AppColors.trustCobalt,
                child: const Icon(Icons.receipt_long_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: _activeJobs.isNotEmpty,
                label: Text('${_activeJobs.length}'),
                backgroundColor: AppColors.trustCobalt,
                child: const Icon(Icons.receipt_long_rounded),
              ),
              label: 'Pesanan',
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
  // TAB 1: BERANDA (Clean Dashboard, Quick Order CTA, Active Jobs Spotlight)
  // ===========================================================================
  Widget _buildDashboardTab() {
    final firstName = (_profile?.fullName ?? 'Pelanggan')
        .split(' ')
        .first
        .trim();

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
            const Text(
              'Butuh bantuan perbaikan apa hari ini?',
              style: TextStyle(
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
            tooltip: 'Panduan Layanan',
            onPressed: () => FaqRulesScreen.show(context),
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
                  // Hero CTA Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primaryNavy,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '0% Komisi • Nota Digital Sah',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Panggil Mitra Tukang Terdekat',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Posting keluhan Anda, pilih mitra terbaik, dan sepakati biaya lewat Nota Digital sebelum tukang berangkat.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => context
                                .push('/jobs/create')
                                .then((_) => _loadData()),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.trustCobalt,
                              foregroundColor: Colors.white,
                            ),
                            icon: const Icon(
                              Icons.add_circle_outline_rounded,
                              size: 18,
                            ),
                            label: const Text('Buat Pesanan Pekerjaan'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Keunggulan Ringkas (3 Kolom Minimalis)
                  Row(
                    children: [
                      Expanded(
                        child: _buildHighlightTile(
                          icon: Icons.verified_user_outlined,
                          title: 'Mitra Terverifikasi',
                          subtitle: 'Identitas KTP tervalidasi',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildHighlightTile(
                          icon: Icons.receipt_long_outlined,
                          title: 'Anti Getok Harga',
                          subtitle: 'Biaya terkunci di Nota',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildHighlightTile(
                          icon: Icons.payments_outlined,
                          title: 'Bayar Langsung',
                          subtitle: '100% langsung ke mitra',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Pesanan Berjalan (Active Jobs Spotlight)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Pesanan Berjalan',
                        style: AppTypography.headingSmall,
                      ),
                      if (_myJobs.isNotEmpty)
                        TextButton(
                          onPressed: () =>
                              setState(() => _selectedTabIndex = 1),
                          child: const Text('Lihat Semua'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_activeJobs.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.handyman_outlined,
                            size: 36,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Belum Ada Pesanan Aktif',
                            style: AppTypography.headingSmall,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Pesanan yang sedang berlangsung akan ditampilkan di sini untuk memudahkan pemantauan.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ),
                    )
                  else
                    ..._activeJobs
                        .take(3)
                        .map(
                          (job) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildJobCard(job),
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildHighlightTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.trustCobalt),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: PESANAN (Daftar Pekerjaan & Filter Status)
  // ===========================================================================
  Widget _buildOrdersTab() {
    final jobs = _filteredJobs;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Pesanan Saya'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Buat Pesanan',
            onPressed: () =>
                context.push('/jobs/create').then((_) => _loadData()),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan',
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surfaceWhite,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(
              children: [
                _buildFilterChip('ALL', 'Semua (${_myJobs.length})'),
                const SizedBox(width: 8),
                _buildFilterChip('ACTIVE', 'Berjalan (${_activeJobs.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'HISTORY',
                  'Selesai (${_myJobs.length - _activeJobs.length})',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : jobs.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceWhite,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.borderLight),
                            ),
                            child: const Icon(
                              Icons.assignment_outlined,
                              size: 26,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Belum Ada Data Pesanan',
                            style: AppTypography.headingSmall,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Buat pesanan baru untuk memanggil mitra tukang ke lokasi Anda.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => context
                                .push('/jobs/create')
                                .then((_) => _loadData()),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Buat Pesanan Baru'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(180, 44),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: jobs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) =>
                          _buildJobCard(jobs[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final selected = _jobFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.userBadgeBg,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        color: selected ? AppColors.trustCobalt : AppColors.textSecondary,
      ),
      side: BorderSide(
        color: selected
            ? AppColors.trustCobalt.withValues(alpha: 0.35)
            : AppColors.borderLight,
      ),
      onSelected: (_) => setState(() => _jobFilter = key),
    );
  }

  // ===========================================================================
  // TAB 4: PROFIL & PENGATURAN AKUN
  // ===========================================================================
  Widget _buildProfileTab() {
    final name = _profile?.fullName ?? 'Pelanggan Beres';
    final email = _profile?.email ?? '-';
    final phone = (_profile?.phone != null && _profile!.phone!.isNotEmpty)
        ? _profile!.phone!
        : 'Belum diatur';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Profil & Akun'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Summary Card
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
                  backgroundColor: AppColors.userBadgeBg,
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.trustCobalt,
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
                          color: AppColors.userBadgeBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Akun Pelanggan Aktif',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.trustCobalt,
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

          // Informasi Kontak
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
                const Text('Informasi Kontak', style: AppTypography.labelSmall),
                const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.mail_outline_rounded,
                  label: 'Email Terdaftar',
                  value: email,
                ),
                const Divider(height: 20),
                _buildInfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Nomor Telepon / WhatsApp',
                  value: phone,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Menu Bantuan & Pengaturan Akun
          Material(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppColors.borderLight),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.help_outline_rounded,
                    color: AppColors.trustCobalt,
                    size: 21,
                  ),
                  title: const Text(
                    'Pusat Bantuan & Panduan Layanan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: const Text(
                    'Cara kerja Nota Digital, pembayaran, dan ketentuan',
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
                    size: 21,
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
                    size: 21,
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
                    'Hapus permanen data akun dari aplikasi',
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

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTypography.bodySmall),
              const SizedBox(height: 2),
              Text(
                value,
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
    );
  }

  Widget _buildJobCard(Job job) {
    final Color statusColor;
    final Color statusBg;
    switch (job.status) {
      case JobStatus.open:
        statusColor = AppColors.trustCobalt;
        statusBg = AppColors.userBadgeBg;
        break;
      case JobStatus.negotiating:
      case JobStatus.notaApproved:
        statusColor = AppColors.warningAmber;
        statusBg = AppColors.warningLight;
        break;
      case JobStatus.onTheWay:
      case JobStatus.arrived:
      case JobStatus.working:
        statusColor = AppColors.successGreen;
        statusBg = AppColors.successLight;
        break;
      case JobStatus.completed:
        statusColor = AppColors.primaryNavy;
        statusBg = AppColors.surfaceLight;
        break;
      default:
        statusColor = AppColors.dangerCrimson;
        statusBg = AppColors.dangerLight;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.push('/jobs/${job.id}').then((_) => _loadData()),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    job.status.label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                Text(
                  Formatters.formatDateTime(job.createdAt),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
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
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 15,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    job.areaLabel,
                    style: AppTypography.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (job.agreedTotal != null)
                  Text(
                    Formatters.formatCurrency(job.agreedTotal!),
                    style: AppTypography.rupiahMedium.copyWith(
                      fontSize: 14,
                      color: AppColors.trustCobalt,
                    ),
                  ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
