import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beres_shared/beres_shared.dart';

import '../auth/login_screen.dart';

final userJobServiceProvider = Provider((ref) => JobService());

class UserHomeScreen extends ConsumerStatefulWidget {
  const UserHomeScreen({super.key});

  @override
  ConsumerState<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends ConsumerState<UserHomeScreen> {
  Profile? _profile;
  List<Job> _myJobs = [];
  final Map<String, int> _bidsCount = {};
  bool _isLoading = true;
  int _selectedTabIndex = 0;
  String _activityFilter = 'ALL'; // ALL, ACTIVE, HISTORY

  // 8 Kategori Beres v1.4.0 (Sesuai Desain Image 1)
  static const List<Map<String, dynamic>> _homeCategories = [
    {
      'name': 'Kelistrikan',
      'query': 'Kelistrikan',
      'desc': 'MCB, Lampu',
      'icon': Icons.bolt_rounded,
      'bgColor': Color(0xFFFEF3C7),
      'iconColor': Color(0xFFD97706),
      'isFilled': false,
    },
    {
      'name': 'Pipa Air',
      'query': 'Pipa Air',
      'desc': 'Bocor, Kran',
      'icon': Icons.water_drop_rounded,
      'bgColor': Color(0xFFE0F2FE),
      'iconColor': Color(0xFF0284C7),
      'isFilled': false,
    },
    {
      'name': 'AC Rumah',
      'query': 'AC Rumah',
      'desc': 'Cuci, Freon',
      'icon': Icons.air_rounded,
      'bgColor': Color(0xFFE0F7FA),
      'iconColor': Color(0xFF0097A7),
      'isFilled': false,
    },
    {
      'name': 'Atap...',
      'query': 'Atap',
      'desc': 'Bocor, Gypsum',
      'icon': Icons.roofing_rounded,
      'bgColor': Color(0xFFEDE9FE),
      'iconColor': Color(0xFF7C3AED),
      'isFilled': false,
    },
    {
      'name': 'Kunci...',
      'query': 'Kunci',
      'desc': 'Macet, Kusen',
      'icon': Icons.key_rounded,
      'bgColor': Color(0xFFF1F5F9),
      'iconColor': Color(0xFF475569),
      'isFilled': false,
    },
    {
      'name': 'Bangunan',
      'query': 'Bangunan',
      'desc': 'Cat, Keramik',
      'icon': Icons.format_paint_rounded,
      'bgColor': Color(0xFFFFEDD5),
      'iconColor': Color(0xFFEA580C),
      'isFilled': false,
    },
    {
      'name': 'Elektronik',
      'query': 'Elektronik',
      'desc': 'Mesin Cuci',
      'icon': Icons.local_laundry_service_rounded,
      'bgColor': Color(0xFFE0F2FE),
      'iconColor': Color(0xFF0284C7),
      'isFilled': false,
    },
    {
      'name': 'Lainnya',
      'query': '',
      'desc': 'Semua Jasa',
      'icon': Icons.grid_view_rounded,
      'bgColor': Color(0xFF16397E),
      'iconColor': Colors.white,
      'isFilled': true,
    },
  ];

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

      // Muat jumlah penawar (bids) untuk pekerjaan terbuka
      final openJobs = jobs.where((j) => j.status == JobStatus.open);
      for (final oj in openJobs) {
        try {
          final bids = await jobService.getJobBidsForUser(oj.id);
          _bidsCount[oj.id] = bids.length;
        } catch (_) {}
      }

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

  String get _displayName {
    final name = _profile?.fullName.trim();
    if (name != null &&
        name.isNotEmpty &&
        name != 'Pengguna Beres' &&
        name != 'Pelanggan Beres') {
      return name.split(' ').first;
    }
    // Periksa user metadata dari auth session
    final authUser = SupabaseClientService.instance.currentUser;
    final metaName = authUser?.userMetadata?['full_name'] as String?;
    if (metaName != null &&
        metaName.trim().isNotEmpty &&
        metaName.trim() != 'Pengguna Beres' &&
        metaName.trim() != 'Pelanggan Beres') {
      return metaName.trim().split(' ').first;
    }

    // Jika masih default, ambil nama depan dari prefix email
    final email = _profile?.email.trim() ?? authUser?.email?.trim();
    if (email != null && email.contains('@')) {
      final prefix = email.split('@').first.trim();
      if (prefix.isNotEmpty) {
        return prefix[0].toUpperCase() + prefix.substring(1);
      }
    }
    return 'Pelanggan';
  }

  String get _initial {
    final name = _displayName;
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }

  void _showEditProfileBottomSheet() {
    final currentName = _profile?.fullName.trim();
    final initialText = (currentName == 'Pengguna Beres' ||
            currentName == 'Pelanggan Beres')
        ? _displayName
        : (currentName ?? '');

    final nameController = TextEditingController(text: initialText);
    final phoneController = TextEditingController(text: _profile?.phone ?? '');
    bool isSaving = false;
    String? localError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Ubah Profil & Nama',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Nama ini akan ditampilkan pada sapaan beranda dan di ruang chat dengan mitra tukang.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              if (localError != null) ...[
                const SizedBox(height: 12),
                Text(
                  localError!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Nama Lengkap / Panggilan',
                  hintText: 'Contoh: Rizal, Budi Santoso',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Nomor WhatsApp / HP',
                  hintText: 'Contoh: 081234567890',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16397E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          final newName = nameController.text.trim();
                          if (newName.isEmpty) {
                            setModalState(() =>
                                localError = 'Nama tidak boleh kosong.');
                            return;
                          }
                          setModalState(() {
                            isSaving = true;
                            localError = null;
                          });
                          try {
                            final authService = ref.read(authServiceProvider);
                            await authService.updateProfile(
                              fullName: newName,
                              phone: phoneController.text.trim(),
                            );
                            if (ctx.mounted) {
                              Navigator.of(ctx).pop();
                            }
                            await _loadData();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profil berhasil disimpan!'),
                                  backgroundColor: Color(0xFF16A34A),
                                ),
                              );
                            }
                          } catch (e) {
                            setModalState(() {
                              isSaving = false;
                              localError = e.toString();
                            });
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Simpan Perubahan',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Job> get _activeJobs => _myJobs.where((j) => j.status.isActive).toList();

  List<Job> get _filteredActivityJobs {
    if (_activityFilter == 'ACTIVE') {
      return _myJobs.where((j) => j.status.isActive).toList();
    }
    if (_activityFilter == 'HISTORY') {
      return _myJobs.where((j) => j.status.isTerminal).toList();
    }
    return _myJobs;
  }

  List<Job> get _chatJobs =>
      _myJobs.where((j) => j.status != JobStatus.open).toList();

  void _handleActiveJobAction(Job job) {
    switch (job.status) {
      case JobStatus.open:
        context.push('/jobs/${job.id}').then((_) => _loadData());
        break;
      case JobStatus.negotiating:
      case JobStatus.notaApproved:
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (context) => ChatScreen(jobId: job.id),
              ),
            )
            .then((_) => _loadData());
        break;
      case JobStatus.onTheWay:
      case JobStatus.arrived:
      case JobStatus.working:
        Navigator.of(context)
            .push(
              MaterialPageRoute(
                builder: (context) => TrackingScreen(
                  jobId: job.id,
                  isTukang: false,
                  trackingService: TrackingService(),
                  jobService: ref.read(userJobServiceProvider),
                  cancellationService: CancellationService(),
                  reviewService: ReviewService(),
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),
            )
            .then((_) => _loadData());
        break;
      default:
        context.push('/jobs/${job.id}').then((_) => _loadData());
        break;
    }
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.light, // iOS: Dark icons
        statusBarIconBrightness: Brightness.dark, // Android: Dark icons
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: IndexedStack(
            index: _selectedTabIndex,
            children: [
              _buildDashboardTab(),
              _buildActivityTab(),
              _buildMessagesTab(),
              _buildProfileTab(),
            ],
          ),
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            boxShadow: [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 10,
                offset: Offset(0, -3),
              ),
            ],
          ),
          child: NavigationBar(
            selectedIndex: _selectedTabIndex,
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFFE0E7FF),
            elevation: 0,
            onDestinationSelected: (idx) {
              setState(() => _selectedTabIndex = idx);
              if (idx == 0 || idx == 1 || idx == 2) {
                _loadData();
              }
            },
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon:
                    Icon(Icons.home_rounded, color: Color(0xFF16397E)),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: _activeJobs.isNotEmpty,
                  label: Text('${_activeJobs.length}'),
                  backgroundColor: const Color(0xFF16397E),
                  child: const Icon(Icons.assignment_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: _activeJobs.isNotEmpty,
                  label: Text('${_activeJobs.length}'),
                  backgroundColor: const Color(0xFF16397E),
                  child: const Icon(
                    Icons.assignment_rounded,
                    color: Color(0xFF16397E),
                  ),
                ),
                label: 'Aktivitas',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: _chatJobs.isNotEmpty,
                  label: Text('${_chatJobs.length}'),
                  backgroundColor: const Color(0xFFF59E0B),
                  child: const Icon(Icons.chat_bubble_outline_rounded),
                ),
                selectedIcon: Badge(
                  isLabelVisible: _chatJobs.isNotEmpty,
                  label: Text('${_chatJobs.length}'),
                  backgroundColor: const Color(0xFFF59E0B),
                  child: const Icon(
                    Icons.chat_bubble_rounded,
                    color: Color(0xFF16397E),
                  ),
                ),
                label: 'Pesan',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon:
                    Icon(Icons.person_rounded, color: Color(0xFF16397E)),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 0: HOME / BERANDA (Kombinasi Gambar 1 & Gambar 2 Sesuai Arahan)
  // ===========================================================================
  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF16397E),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          // 1. Header Top Bar (Halo, Nama User + Avatar Profil tanpa logo Beres di tengah)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Greeting User
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Halo, $_displayName',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mau perbaiki apa hari ini?',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Profile Avatar (Tap to Tab Profil, Menampilkan Inisial Nama Depan User)
              GestureDetector(
                onTap: () => setState(() => _selectedTabIndex = 3),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFE0E7FF),
                    child: Text(
                      _initial,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF16397E),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // 2. Banner Hero Card (Warna Deep Navy #102A71)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0E2356),
                  Color(0xFF16397E),
                  Color(0xFF1C479B),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF16397E).withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge Pill: Cepat, Tepat, Hemat
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.22),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: Color(0xFF93C5FD),
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Cepat, Tepat, Hemat',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Ada yang Rusak di Rumah dan Butuh Bantuan Tenaga Ahli?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Serahkan pada kami. Cukup beritahu keluhan Anda, pilih mitra terbaik, dan sepakati harga!',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // 3. Tiga Kartu Nilai Unggulan (Mitra Terverifikasi, Harga Transparan, Pantau Progres)
          Row(
            children: [
              Expanded(
                child: _buildValueCard(
                  icon: Icons.verified_user_rounded,
                  iconColor: const Color(0xFF2563EB),
                  title: 'Mitra Terverifikasi',
                  subtitle: 'Mitra yang terdaftar telah tervalidasi',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildValueCard(
                  icon: Icons.receipt_long_rounded,
                  iconColor: const Color(0xFF0284C7),
                  title: 'Harga Transparan',
                  subtitle: 'Sepakati harga dengan mitra',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildValueCard(
                  icon: Icons.timeline_rounded,
                  iconColor: const Color(0xFF10B981),
                  title: 'Pantau Progres',
                  subtitle: 'Lacak status pekrejaan realtime',
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 4. Section: Permintaan Saya (Header)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Permintaan Saya',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              if (_myJobs.isNotEmpty)
                GestureDetector(
                  onTap: () => setState(() => _selectedTabIndex = 1),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      'Lihat Semua',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF16397E),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // 5. State Permintaan: Aktif vs Belum Ada Permintaan
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_activeJobs.isNotEmpty)
            _buildActiveJobSpotlightCard(_activeJobs.first)
          else
            _buildEmptyJobSpotlightCard(),

          const SizedBox(height: 24),

          // 6. Section: Kategori Jasa (Grid 4x2 Sesuai Gambar 1)
          const Text(
            'Kategori',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
          ),

          const SizedBox(height: 12),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _homeCategories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.76,
            ),
            itemBuilder: (context, index) {
              final cat = _homeCategories[index];
              final isFilled = cat['isFilled'] as bool? ?? false;

              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  final q = cat['query'] as String;
                  if (q.isNotEmpty) {
                    context
                        .push('/jobs/create?category=$q')
                        .then((_) => _loadData());
                  } else {
                    context.push('/jobs/create').then((_) => _loadData());
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    color: isFilled ? const Color(0xFF16397E) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isFilled
                          ? const Color(0xFF16397E)
                          : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x06000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: cat['bgColor'] as Color,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          cat['icon'] as IconData,
                          size: 22,
                          color: cat['iconColor'] as Color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cat['name'] as String,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: isFilled
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cat['desc'] as String,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          color: isFilled
                              ? Colors.white.withValues(alpha: 0.78)
                              : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // 7. Tombol CTA Utama: Buat Permintaan Sekarang
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () =>
                  context.push('/jobs/create').then((_) => _loadData()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16397E),
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: const Color(0xFF16397E).withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
              label: const Text(
                'Buat Permintaan Sekarang',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Value Card Widget (3 Kolom Ringkas)
  Widget _buildValueCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return GestureDetector(
      onTap: () => FaqRulesScreen.show(context),
      child: Container(
        height: 112,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: iconColor),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 9.5,
                  color: Color(0xFF64748B),
                  height: 1.3,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Card Status Permintaan Aktif (Desain Deep Dark Navy Gambar 1)
  Widget _buildActiveJobSpotlightCard(Job job) {
    final jobSuffix = job.id.length >= 4
        ? job.id.substring(job.id.length - 4).toUpperCase()
        : '8921';
    final count = _bidsCount[job.id] ?? 0;

    String statusText;
    IconData statusIcon = Icons.construction_rounded;
    String actionLabel = 'Lihat Penawaran';

    switch (job.status) {
      case JobStatus.open:
        statusText = count > 0
            ? '$count Tukang Sedang Menawar (Bid)'
            : 'Menunggu Penawaran Mitra Tukang';
        statusIcon = Icons.handyman_rounded;
        actionLabel = 'Lihat Penawaran';
        break;
      case JobStatus.negotiating:
        statusText = 'Diskusi & Kesepakatan Nota Digital';
        statusIcon = Icons.chat_rounded;
        actionLabel = 'Buka Chat & Nota';
        break;
      case JobStatus.notaApproved:
        statusText = 'Menunggu Tukang Berangkat (Maks 30 Menit)';
        statusIcon = Icons.schedule_rounded;
        actionLabel = 'Buka Chat & Nota';
        break;
      case JobStatus.onTheWay:
        statusText = 'Tukang Sedang Menuju Lokasi Anda';
        statusIcon = Icons.directions_car_rounded;
        actionLabel = 'Pantau Tukang';
        break;
      case JobStatus.arrived:
        statusText = 'Tukang Sudah Tiba di Lokasi';
        statusIcon = Icons.location_on_rounded;
        actionLabel = 'Pantau Tukang';
        break;
      case JobStatus.working:
        statusText = 'Sedang Dikerjakan (Dilarang Batal)';
        statusIcon = Icons.build_circle_rounded;
        actionLabel = 'Pantau Tukang';
        break;
      case JobStatus.cancelPending:
        statusText = 'Pengajuan Batal Menunggu Persetujuan';
        statusIcon = Icons.warning_amber_rounded;
        actionLabel = 'Cek Pengajuan';
        break;
      default:
        statusText = job.status.label;
        actionLabel = 'Lihat Detail';
        break;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _handleActiveJobAction(job),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D1E3A),
              Color(0xFF132A52),
              Color(0xFF19376D),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF254884)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0D1E3A).withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Badge PERMINTAAN AKTIF & Kode Job
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A162B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF59E0B),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'PERMINTAAN AKTIF',
                        style: TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E3A8A).withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '#BRS-$jobSuffix',
                    style: const TextStyle(
                      color: Color(0xFF93C5FD),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Row 2: Judul Pekerjaan
            Text(
              job.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 8),

            // Row 3: Status Pekerjaan
            Row(
              children: [
                Icon(statusIcon, size: 15, color: const Color(0xFFF59E0B)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Status: $statusText',
                    style: const TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Row 4: Stack Avatar Mitra + Tombol CTA Warna Emas
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Avatar Stack Mitra Bidding / Terpilih
                _buildAvatarStack(count),

                // Tombol Kuning Emas (Lihat Penawaran ➔)
                ElevatedButton(
                  onPressed: () => _handleActiveJobAction(job),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: const Color(0xFF0F172A),
                    elevation: 0,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        actionLabel,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(Icons.arrow_forward_rounded, size: 15),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Avatar Stack Widget (T., M., B., +X Sesuai Gambar 1)
  Widget _buildAvatarStack(int count) {
    final displayCount = count > 0 ? count : 3;
    final initials = ['T.', 'M.', 'B.'];
    final colors = [
      const Color(0xFF334155),
      const Color(0xFF2563EB),
      const Color(0xFFD97706),
    ];

    return SizedBox(
      height: 32,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < 3 && i < displayCount; i++)
            Align(
              widthFactor: 0.72,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: colors[i % colors.length],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF0D1E3A),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    initials[i % initials.length],
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          if (displayCount > 3)
            Align(
              widthFactor: 0.72,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF0D1E3A),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '+${displayCount - 3}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Card Status Kosong / Belum Ada Permintaan (Sesuai Desain Gambar 2)
  Widget _buildEmptyJobSpotlightCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFDBEAFE)),
            ),
            child: const Icon(
              Icons.construction_rounded,
              size: 26,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Belum Ada Permintaan Aktif',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Permintaan yang sedang berlangsung akan ditampilkan di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w400,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 1: AKTIVITAS (Daftar Semua Pekerjaan & Riwayat)
  // ===========================================================================
  Widget _buildActivityTab() {
    final jobs = _filteredActivityJobs;

    return Column(
      children: [
        // App Bar Aktivitas (Tengah, Tanpa Icon Reload)
        Container(
          color: Colors.white,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          alignment: Alignment.center,
          child: const Text(
            'Aktivitas Saya',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ),

        // Filter Chips (Semua, Berjalan, Selesai)
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: Row(
            children: [
              _buildActivityFilterChip('ALL', 'Semua (${_myJobs.length})'),
              const SizedBox(width: 8),
              _buildActivityFilterChip(
                'ACTIVE',
                'Berjalan (${_activeJobs.length})',
              ),
              const SizedBox(width: 8),
              _buildActivityFilterChip(
                'HISTORY',
                'Selesai (${_myJobs.length - _activeJobs.length})',
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: const Color(0xFF16397E),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : jobs.isEmpty
                    ? LayoutBuilder(
                        builder: (context, constraints) => SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: const Icon(
                                        Icons.assignment_outlined,
                                        size: 26,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    const Text(
                                      'Belum Ada Aktivitas',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Pekerjaan yang Anda posting akan tersimpan dan dapat dipantau di sini.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    ElevatedButton.icon(
                                      onPressed: () => context
                                          .push('/jobs/create')
                                          .then((_) => _loadData()),
                                      icon: const Icon(Icons.add_rounded,
                                          size: 18),
                                      label: const Text('Buat Permintaan Baru'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF16397E),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(18),
                        itemCount: jobs.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) =>
                            _buildJobCard(jobs[index]),
                      ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityFilterChip(String key, String label) {
    final selected = _activityFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: const Color(0xFFE0E7FF),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
        color: selected ? const Color(0xFF16397E) : const Color(0xFF64748B),
      ),
      side: BorderSide(
        color: selected ? const Color(0xFF16397E) : const Color(0xFFCBD5E1),
      ),
      onSelected: (_) => setState(() => _activityFilter = key),
    );
  }

  // ===========================================================================
  // TAB 2: PESAN (Ruang Chat & Nota Digital dengan Tukang)
  // ===========================================================================
  Widget _buildMessagesTab() {
    final chatJobs = _chatJobs;

    return Column(
      children: [
        // App Bar Pesan (Tengah, Tanpa Icon Reload)
        Container(
          color: Colors.white,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Pesan & Nota Digital',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Diskusi langsung dan persetujuan Nota Sah',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: const Color(0xFF16397E),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : chatJobs.isEmpty
                    ? LayoutBuilder(
                        builder: (context, constraints) => SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: const Icon(
                                        Icons.chat_bubble_outline_rounded,
                                        size: 26,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    const Text(
                                      'Belum Ada Percakapan Aktif',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Ruang chat dan Nota Digital akan otomatis aktif saat Anda mengunci (lock) 1 mitra tukang untuk berdiskusi.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: Color(0xFF64748B),
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(18),
                        itemCount: chatJobs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final job = chatJobs[index];
                          final jobSuffix = job.id.length >= 4
                              ? job.id.substring(job.id.length - 4).toUpperCase()
                              : 'JOB';

                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.of(context)
                                  .push(
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ChatScreen(jobId: job.id),
                                    ),
                                  )
                                  .then((_) => _loadData());
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x06000000),
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: const Color(0xFF16397E),
                                    child: const Icon(
                                      Icons.handyman_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              '#BRS-$jobSuffix',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFF16397E),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                job.status.label,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF475569),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          job.description,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          'Ketuk untuk membuka ruang chat & Nota Sah',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 3: PROFIL & PENGATURAN AKUN (Mengikuti Tema Navy Home)
  // ===========================================================================
  Widget _buildProfileTab() {
    final name = (_profile?.fullName != null &&
            _profile!.fullName.trim().isNotEmpty &&
            _profile!.fullName.trim() != 'Pengguna Beres' &&
            _profile!.fullName.trim() != 'Pelanggan Beres')
        ? _profile!.fullName.trim()
        : _displayName;
    final email = _profile?.email ?? '-';
    final phone = (_profile?.phone != null && _profile!.phone!.isNotEmpty)
        ? _profile!.phone!
        : 'Belum diatur';
    final initial = _initial;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF16397E),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(18),
        children: [
          // App Bar Title (Centered)
          const Center(
            child: Text(
              'Profil & Akun',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ),

        const SizedBox(height: 16),

        // Profile Summary Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFFE0E7FF),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF16397E),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E7FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Akun Pelanggan Aktif',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF16397E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: Color(0xFF16397E),
                ),
                tooltip: 'Ubah Profil',
                onPressed: _showEditProfileBottomSheet,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Stats Row (Permintaan, Aktif, Selesai)
        Row(
          children: [
            Expanded(
              child: _buildProfileStatCard(
                '${_myJobs.length}',
                'Total Dibuat',
                const Color(0xFF16397E),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildProfileStatCard(
                '${_activeJobs.length}',
                'Sedang Berjalan',
                const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildProfileStatCard(
                '${_myJobs.length - _activeJobs.length}',
                'Selesai',
                const Color(0xFF16A34A),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Informasi Kontak
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Informasi Kontak',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 12),
              _buildInfoRow(
                icon: Icons.mail_outline_rounded,
                label: 'Email Terdaftar',
                value: email,
              ),
              const Divider(height: 20, color: Color(0xFFF1F5F9)),
              _buildInfoRow(
                icon: Icons.phone_outlined,
                label: 'Nomor WhatsApp / HP',
                value: phone,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Menu Pengaturan & Bantuan
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.person_outline_rounded,
                  color: Color(0xFF16397E),
                  size: 22,
                ),
                title: const Text(
                  'Ubah Profil & Nama Lengkap',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                subtitle: const Text(
                  'Perbarui nama lengkap dan nomor telepon Anda',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: _showEditProfileBottomSheet,
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              ListTile(
                leading: const Icon(
                  Icons.help_outline_rounded,
                  color: Color(0xFF16397E),
                  size: 22,
                ),
                title: const Text(
                  'Panduan Layanan & Aturan Beres',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                subtitle: const Text(
                  'Cara kerja Nota Digital, timer 30 mnt, & sistem bayar',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => FaqRulesScreen.show(context),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFF0F172A),
                  size: 22,
                ),
                title: const Text(
                  'Keluar dari Akun',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: _handleSignOut,
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFFDC2626),
                  size: 22,
                ),
                title: const Text(
                  'Hapus Akun Saya',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
                subtitle: const Text(
                  'Hapus permanen data akun sesuai UU PDP',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
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

  Widget _buildProfileStatCard(String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
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
        Icon(icon, size: 18, color: const Color(0xFF64748B)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Job Card untuk Tab Aktivitas
  Widget _buildJobCard(Job job) {
    final Color statusColor;
    final Color statusBg;
    switch (job.status) {
      case JobStatus.open:
        statusColor = const Color(0xFF2563EB);
        statusBg = const Color(0xFFEFF6FF);
        break;
      case JobStatus.negotiating:
      case JobStatus.notaApproved:
        statusColor = const Color(0xFFD97706);
        statusBg = const Color(0xFFFEF3C7);
        break;
      case JobStatus.onTheWay:
      case JobStatus.arrived:
      case JobStatus.working:
        statusColor = const Color(0xFF16A34A);
        statusBg = const Color(0xFFDCFCE7);
        break;
      case JobStatus.completed:
        statusColor = const Color(0xFF16397E);
        statusBg = const Color(0xFFF1F5F9);
        break;
      default:
        statusColor = const Color(0xFFDC2626);
        statusBg = const Color(0xFFFEE2E2);
    }

    final jobSuffix = job.id.length >= 4
        ? job.id.substring(job.id.length - 4).toUpperCase()
        : 'JOB';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _handleActiveJobAction(job),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        job.status.label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '#BRS-$jobSuffix',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                Text(
                  Formatters.formatDateTime(job.createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
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
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 15,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    job.areaLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (job.agreedTotal != null)
                  Text(
                    Formatters.formatCurrency(job.agreedTotal!),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF16397E),
                    ),
                  ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
