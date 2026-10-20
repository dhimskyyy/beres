import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:beres_shared/beres_shared.dart';
import '../auth/tukang_login_screen.dart';
import '../job_portal/job_portal_screen.dart';
import '../notifications/notifications_screen.dart';

class TukangHomeScreen extends ConsumerStatefulWidget {
  const TukangHomeScreen({super.key});

  @override
  ConsumerState<TukangHomeScreen> createState() => _TukangHomeScreenState();
}

class _TukangHomeScreenState extends ConsumerState<TukangHomeScreen> {
  bool _isOnline = false;
  int _radiusKm = 20;
  String _kycStatus = 'PENDING';
  int _activeBidsCount = 0;
  int _unreadNotifsCount = 0;
  Map<String, dynamic>? _activeJob;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final profileRes = await Supabase.instance.client
          .from('tukang_profiles')
          .select('is_online, radius_km, kyc_status')
          .eq('user_id', user.id)
          .maybeSingle();

      if (profileRes != null) {
        _isOnline = profileRes['is_online'] as bool? ?? false;
        _radiusKm = profileRes['radius_km'] as int? ?? 20;
        _kycStatus = profileRes['kyc_status'] as String? ?? 'PENDING';
      }

      final bidsRes = await Supabase.instance.client
          .from('bids')
          .select('id, jobs!inner(status)')
          .eq('tukang_id', user.id)
          .eq('status', 'ACTIVE')
          .eq('jobs.status', 'OPEN');

      _activeBidsCount = (bidsRes as List<dynamic>).length;

      // Ambil pekerjaan aktif tukang yang sedang berjalan (M4: Chat, Nota, Timer)
      final activeJobRes = await Supabase.instance.client
          .from('jobs')
          .select('id, status, description, area_label, locked_at')
          .eq('locked_tukang_id', user.id)
          .inFilter('status', [
            'NEGOTIATING',
            'NOTA_APPROVED',
            'ON_THE_WAY',
            'ARRIVED',
            'WORKING',
          ])
          .order('locked_at', ascending: false)
          .limit(1)
          .maybeSingle();

      _activeJob = activeJobRes;

      final notifService = ref.read(notificationServiceProvider);
      final count = await notifService.getUnreadCount();

      if (mounted) {
        setState(() {
          _unreadNotifsCount = count;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleToggleOnline(bool val) async {
    setState(() => _isOnline = val);
    try {
      await ref
          .read(jobServiceProvider)
          .updateTukangStatusAndLocation(isOnline: val);
      _loadData();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final authService = ref.read(authServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Beres Mitra'),
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
                      builder: (context) => const TukangNotificationsScreen(),
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Header Card Profil & Status
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: const BoxDecoration(
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Mitra Tukang Beres',
                                          style: AppTypography.headingSmall,
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.tukangBadgeBg,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                'Role: TUKANG',
                                                style: AppTypography.bodySmall
                                                    .copyWith(
                                                      color: AppColors
                                                          .tukangBadgeText,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                              ),
                                            ),
                                            _buildKycBadge(_kycStatus),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),

                              // Switch Online/Offline Cepat (FR-020)
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: _isOnline
                                              ? AppColors.successGreen
                                              : Colors.grey,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _isOnline
                                            ? 'ONLINE (Siap Kerja)'
                                            : 'OFFLINE',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Switch(
                                    value: _isOnline,
                                    activeThumbColor: AppColors.successGreen,
                                    onChanged: _handleToggleOnline,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. Pekerjaan Aktif yang Sedang Berjalan (M4: FR-013, FR-014, BR-31)
                      if (_activeJob != null) ...[
                        Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(
                              color: AppColors.trustCobalt,
                              width: 1.5,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.handyman,
                                          color: AppColors.trustCobalt,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Pekerjaan Aktif Anda',
                                          style: AppTypography.headingSmall
                                              .copyWith(fontSize: 15),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.trustCobalt.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _activeJob!['status'] as String? ?? '',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.trustCobalt,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _activeJob!['description'] as String? ?? '',
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.location_on_outlined,
                                      size: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _activeJob!['area_label'] as String? ??
                                          '',
                                      style: AppTypography.bodySmall,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChatScreen(
                                            jobId: _activeJob!['id'] as String,
                                          ),
                                        ),
                                      );
                                      _loadData();
                                    },
                                    icon: const Icon(
                                      Icons.chat_outlined,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Buka Ruang Chat & Nota Digital',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.trustCobalt,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                      ),
                                    ),
                                  ),
                                ),
                                if ([
                                  'ON_THE_WAY',
                                  'ARRIVED',
                                  'WORKING',
                                  'COMPLETED',
                                ].contains(_activeJob!['status'])) ...[
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                TrackingScreen(
                                                  jobId:
                                                      _activeJob!['id']
                                                          as String,
                                                  isTukang: true,
                                                  trackingService:
                                                      TrackingService(),
                                                  jobService: ref.read(
                                                    jobServiceProvider,
                                                  ),
                                                ),
                                          ),
                                        );
                                        _loadData();
                                      },
                                      icon: const Icon(
                                        Icons.location_on,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        'Pelaksanaan & Live GPS Tracking (M5)',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.safetyOrange,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 3. Action Banner: Bursa Pekerjaan (Job Portal)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              AppColors.primaryNavy,
                              AppColors.trustCobalt,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Bursa Pekerjaan',
                                  style: AppTypography.headingMedium.copyWith(
                                    color: Colors.white,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Lamaran: $_activeBidsCount/5',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Cari pekerjaan di sekitar radius $_radiusKm km, ajukan penawaran, dan dapatkan pekerjaan hari ini.',
                              style: AppTypography.bodyMedium.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const JobPortalScreen(),
                                  ),
                                );
                                _loadData();
                              },
                              icon: const Icon(Icons.travel_explore),
                              label: const Text('Buka Bursa Pekerjaan'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.primaryNavy,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 3. Verifikasi KYC (FR-003, BR-10)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.verified_user_outlined,
                                    color: AppColors.trustCobalt,
                                    size: 22,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Verifikasi KTP (KYC)',
                                    style: AppTypography.headingSmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _kycStatus == 'APPROVED'
                                    ? 'Akun Anda sudah terverifikasi resmi oleh Admin. Anda dapat melamar semua pekerjaan yang tersedia.'
                                    : 'Unggah Foto KTP & Selfie agar dapat mulai melamar pekerjaan di bursa (BR-10).',
                                style: AppTypography.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await context.push('/kyc');
                                  _loadData();
                                },
                                icon: const Icon(Icons.upload_file),
                                label: Text(
                                  _kycStatus == 'APPROVED'
                                      ? 'Lihat Berkas KYC'
                                      : 'Kelola / Unggah Berkas KYC',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 4. Section: Pengaturan & Kepatuhan Privasi (FR-004, BR-45)
                      Text(
                        'Pengaturan & Informasi Akun',
                        style: AppTypography.headingSmall,
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Column(
                          children: [
                            const ListTile(
                              leading: Icon(
                                Icons.shield_outlined,
                                color: AppColors.safetyOrange,
                              ),
                              title: Text('Aturan 1 Email 1 Peran (BR-44)'),
                              subtitle: Text(
                                'Email Anda terikat khusus untuk akun Mitra Tukang',
                              ),
                              trailing: Icon(
                                Icons.check_circle,
                                color: AppColors.successGreen,
                                size: 20,
                              ),
                            ),
                            const Divider(height: 1),
                            const ListTile(
                              leading: Icon(
                                Icons.info_outline,
                                color: AppColors.warningAmber,
                              ),
                              title: Text(
                                'Aturan Pelanggaran & Strike (BR-57)',
                              ),
                              subtitle: Text(
                                'Batas 3x strike per bulan kalender. Strike ke-4 = suspend 48 jam.',
                              ),
                              trailing: Icon(Icons.chevron_right),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(
                                Icons.delete_forever_outlined,
                                color: AppColors.dangerCrimson,
                              ),
                              title: Text(
                                'Hapus Akun Mitra (FR-004)',
                                style: TextStyle(
                                  color: AppColors.dangerCrimson,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: const Text(
                                'Hapus data akun sesuai regulasi UU PDP (BR-45)',
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                DeleteAccountDialog.show(
                                  context,
                                  authService: authService,
                                  onAccountDeleted: () {
                                    if (context.mounted) {
                                      context.go('/');
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Akun Mitra Anda berhasil dinonaktifkan/dihapus.',
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

  Widget _buildKycBadge(String status) {
    Color bg;
    Color text;
    String label;

    switch (status) {
      case 'APPROVED':
        bg = AppColors.successGreen.withValues(alpha: 0.15);
        text = AppColors.successGreen;
        label = 'KYC: TERVERIFIKASI';
        break;
      case 'REJECTED':
        bg = AppColors.dangerCrimson.withValues(alpha: 0.15);
        text = AppColors.dangerCrimson;
        label = 'KYC: DITOLAK';
        break;
      default:
        bg = AppColors.warningAmber.withValues(alpha: 0.15);
        text = AppColors.warningAmber;
        label = 'KYC: PENDING';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          color: text,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
