import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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
  StreamSubscription<AuthState>? _authSubscription;
  bool _isUploadingAvatar = false;

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
    _authSubscription =
        SupabaseClientService.instance.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      if (data.event == AuthChangeEvent.signedOut) {
        // Jangan panggil _loadData() saat signedOut agar profil tidak ter-reset
        context.go('/login');
        return;
      }
      _loadData();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Jika tidak ada user (misal sedang logout), batalkan loading agar tidak menimpa profil
    final currentUser = SupabaseClientService.instance.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Keluar dari Akun',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun Beres?',
          style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Batal',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Ya, Keluar',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    // Batalkan listener auth agar tidak memicu _loadData() saat logout
    await _authSubscription?.cancel();
    _authSubscription = null;

    final authService = ref.read(authServiceProvider);

    // Langsung alihkan tampilan ke login secara mulus tanpa jeda
    if (mounted) {
      context.go('/login');
    }

    // Jalankan proses sign out di background
    try {
      await authService.signOut();
    } catch (_) {}
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

  bool get _isEmailVerified {
    if (_profile?.isEmailVerified == true) return true;
    final authUser = SupabaseClientService.instance.currentUser;
    if (authUser?.emailConfirmedAt != null) return true;
    final provider = authUser?.appMetadata['provider'] as String?;
    if (provider == 'google') return true;
    return false;
  }

  void _showAvatarOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
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
              'Foto Profil',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pilih sumber foto profil Anda atau hapus foto profil saat ini.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 18),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Color(0xFF16397E),
                  size: 22,
                ),
              ),
              title: const Text(
                'Ambil Foto dari Kamera',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickAndUploadAvatar(ImageSource.camera);
              },
            ),
            const SizedBox(height: 4),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.photo_library_rounded,
                  color: Color(0xFF16A34A),
                  size: 22,
                ),
              ),
              title: const Text(
                'Pilih dari Galeri',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickAndUploadAvatar(ImageSource.gallery);
              },
            ),
            if (_profile?.avatarUrl != null &&
                _profile!.avatarUrl!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFDC2626),
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Hapus Foto Profil',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _deleteAvatar();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _isUploadingAvatar = true);
      final authService = ref.read(authServiceProvider);
      final newUrl = await authService.uploadAvatar(picked);

      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
          _profile = _profile?.copyWith(avatarUrl: newUrl);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto profil berhasil diperbarui!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal mengunggah foto: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _deleteAvatar() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Hapus Foto Profil?'),
        content: const Text(
          'Foto profil Anda akan dihapus dan kembali menggunakan inisial nama Anda.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dCtx).pop(false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dCtx).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isUploadingAvatar = true);
      final authService = ref.read(authServiceProvider);
      await authService.deleteAvatar();

      if (mounted) {
        setState(() {
          _isUploadingAvatar = false;
          _profile = _profile?.copyWith(avatarUrl: '');
        });
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto profil berhasil dihapus.'),
              backgroundColor: Color(0xFF16A34A),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal menghapus foto: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _showEditProfileBottomSheet() {
    final currentName = _profile?.fullName.trim();
    final initialName = (currentName == null ||
            currentName.isEmpty ||
            currentName == 'Pengguna Beres' ||
            currentName == 'Pelanggan Beres')
        ? (_displayName != 'Pelanggan' ? _displayName : '')
        : currentName;

    final nameController = TextEditingController(text: initialName);
    final birthPlaceController =
        TextEditingController(text: _profile?.birthPlace ?? '');
    DateTime? selectedBirthDate = _profile?.birthDate;
    final phoneController = TextEditingController(text: _profile?.phone ?? '');
    final email = _profile?.email.isNotEmpty == true
        ? _profile!.email
        : (SupabaseClientService.instance.currentUser?.email ?? '');
    final isEmailVerified = _isEmailVerified;

    bool isSaving = false;
    String? localError;

    String formatBirthDate(DateTime date) {
      const months = [
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(modalCtx).size.height * 0.90,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle Bar & Header (Tetap di atas)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 16, 12),
                child: Column(
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
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Edit Profil Anda',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Scrollable Form Content
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 16,
                    bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 28,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Perbarui data pribadi dan kontak Anda agar mitra tukang dapat mengenali dan menghubungi Anda dengan mudah.',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                      if (localError != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  size: 16, color: Color(0xFFDC2626)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  localError!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFDC2626),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),

                      // FIELD 1: Nama Lengkap
                      const Text(
                        'Nama Lengkap',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person_outline_rounded,
                              size: 20, color: Color(0xFF16397E)),
                          hintText: 'Contoh: Budi Santoso',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: Color(0xFF16397E), width: 1.5),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // FIELD 2: Tempat Lahir
                      const Text(
                        'Tempat Lahir',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: birthPlaceController,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.location_city_outlined,
                              size: 20, color: Color(0xFF16397E)),
                          hintText: 'Contoh: Jakarta',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: Color(0xFF16397E), width: 1.5),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // FIELD 3: Tanggal Lahir (Interactive Date Picker)
                      const Text(
                        'Tanggal Lahir',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: modalCtx,
                            initialDate:
                                selectedBirthDate ?? DateTime(2000, 1, 1),
                            firstDate: DateTime(1920),
                            lastDate: DateTime.now(),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: Color(0xFF16397E),
                                    onPrimary: Colors.white,
                                    onSurface: Color(0xFF0F172A),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setModalState(() {
                              selectedBirthDate = picked;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border:
                                Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today_rounded,
                                  size: 19, color: Color(0xFF16397E)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  selectedBirthDate != null
                                      ? formatBirthDate(selectedBirthDate!)
                                      : 'Pilih Tanggal Lahir',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: selectedBirthDate != null
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFF94A3B8),
                                    fontWeight: selectedBirthDate != null
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (selectedBirthDate != null)
                                GestureDetector(
                                  onTap: () {
                                    setModalState(() {
                                      selectedBirthDate = null;
                                    });
                                  },
                                  child: const Icon(Icons.cancel_rounded,
                                      size: 18, color: Color(0xFF94A3B8)),
                                )
                              else
                                const Icon(Icons.keyboard_arrow_down_rounded,
                                    size: 20, color: Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // FIELD 4: Email Terdaftar
                      const Text(
                        'Email Terdaftar',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.mail_outline_rounded,
                                size: 20, color: Color(0xFF64748B)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    email.isNotEmpty ? email : '-',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF334155),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),                                                                    
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isEmailVerified) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFF86EFAC)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified_rounded,
                                        size: 13, color: Color(0xFF16A34A)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Terverifikasi',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF16A34A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              InkWell(
                                onTap: () {
                                  Navigator.of(ctx).pop();
                                  _showEmailVerificationModal();
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFFFDE68A)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.warning_amber_rounded,
                                          size: 12, color: Color(0xFFD97706)),
                                      SizedBox(width: 4),
                                      Text(
                                        'Verifikasi',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFD97706),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // FIELD 5: Nomor Telepon / WhatsApp
                      const Text(
                        'Nomor Telepon / WhatsApp',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.phone_outlined,
                              size: 20, color: Color(0xFF16397E)),
                          hintText: 'Contoh: 081234567890',
                          helperText:
                              'Tukang dapat menghubungi nomor ini saat menuju lokasi pesanan.',
                          helperStyle: const TextStyle(
                              fontSize: 11, color: Color(0xFF94A3B8)),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                                color: Color(0xFF16397E), width: 1.5),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ACTION: Simpan Perubahan
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16397E),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final newName = nameController.text.trim();
                                  if (newName.isEmpty) {
                                    setModalState(() => localError =
                                        'Nama lengkap tidak boleh kosong.');
                                    return;
                                  }
                                  if (newName.length < 2) {
                                    setModalState(() => localError =
                                        'Nama lengkap minimal 2 karakter.');
                                    return;
                                  }
                                  setModalState(() {
                                    isSaving = true;
                                    localError = null;
                                  });
                                  try {
                                    final authService =
                                        ref.read(authServiceProvider);
                                    final updated =
                                        await authService.updateProfile(
                                      fullName: newName,
                                      phone: phoneController.text.trim().isEmpty
                                          ? null
                                          : phoneController.text.trim(),
                                      birthPlace: birthPlaceController.text
                                              .trim()
                                              .isEmpty
                                          ? null
                                          : birthPlaceController.text.trim(),
                                      birthDate: selectedBirthDate,
                                    );
                                    if (ctx.mounted) {
                                      Navigator.of(ctx).pop();
                                    }
                                    if (mounted) {
                                      setState(() {
                                        _profile = updated;
                                      });
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content:
                                              Text('Profil berhasil disimpan!'),
                                          backgroundColor: Color(0xFF16A34A),
                                        ),
                                      );
                                    }
                                    await _loadData();
                                  } catch (e) {
                                    setModalState(() {
                                      isSaving = false;
                                      localError = e
                                          .toString()
                                          .replaceFirst('Exception: ', '');
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
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),

                      // DANGER ZONE: Hapus Akun Saya (BR-45 & UU PDP)
                      Container(
                        margin: const EdgeInsets.only(top: 28),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    size: 18, color: Color(0xFFDC2626)),
                                SizedBox(width: 8),
                                Text(
                                  'Zona Bahaya Akun',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Menghapus akun akan menghapus profil Anda secara permanen sesuai kepatuhan UU PDP. Pesanan aktif harus diselesaikan terlebih dahulu.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF991B1B),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 42,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFDC2626),
                                  side: const BorderSide(
                                      color: Color(0xFFDC2626), width: 1.2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  backgroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.delete_forever_rounded,
                                    size: 18, color: Color(0xFFDC2626)),
                                label: const Text(
                                  'Hapus Akun Saya',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(ctx).pop();
                                  DeleteAccountDialog.show(
                                    context,
                                    authService:
                                        ref.read(authServiceProvider),
                                    userEmail: email,
                                    onAccountDeleted: () =>
                                        context.go('/login'),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEmailVerificationModal() {
    final email = _profile?.email ??
        SupabaseClientService.instance.currentUser?.email ??
        '';
    bool isSending = false;
    bool isSent = false;
    bool isVerifying = false;
    String? statusMessage;
    String? errorMessage;
    final otpController = TextEditingController();

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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.mark_email_read_outlined,
                      color: Color(0xFF16397E),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verifikasi Email Akun',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Validasi kepemilikan email Anda',
                          style: TextStyle(
                              fontSize: 12.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.email_outlined,
                        size: 20, color: Color(0xFF64748B)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        email,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 16, color: Color(0xFFDC2626)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (statusMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          size: 16, color: Color(0xFF16A34A)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          statusMessage!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF16A34A),
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (!isSent) ...[
                const Text(
                  'Kami akan mengirimkan tautan konfirmasi langsung ke kotak masuk email Anda. Anda cukup membuka email tersebut dan mengeklik tautan untuk memverifikasi akun secara instan.',
                  style: TextStyle(
                      fontSize: 13, color: Color(0xFF475569), height: 1.4),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16397E),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: isSending
                        ? const SizedBox.shrink()
                        : const Icon(Icons.send_rounded, size: 18),
                    label: isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Kirim Tautan Verifikasi',
                            style: TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.w700),
                          ),
                    onPressed: isSending
                        ? null
                        : () async {
                            setModalState(() {
                              isSending = true;
                              errorMessage = null;
                            });
                            try {
                              final authService = ref.read(authServiceProvider);
                              await authService.sendEmailVerificationLink(
                                  email: email);
                              setModalState(() {
                                isSending = false;
                                isSent = true;
                                statusMessage =
                                    'Tautan verifikasi telah dikirim ke $email!';
                              });
                            } catch (e) {
                              setModalState(() {
                                isSending = false;
                                errorMessage = e
                                    .toString()
                                    .replaceFirst('Exception: ', '');
                              });
                            }
                          },
                  ),
                ),
              ] else ...[
                const Text(
                  'Silakan periksa kotak masuk atau folder spam email Anda, lalu klik tautan verifikasi.\n\nJika tautan tidak terbuka otomatis, Anda juga dapat memasukkan 6 digit kode yang tertera di email:',
                  style: TextStyle(
                      fontSize: 12.5, color: Color(0xFF475569), height: 1.4),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '123456',
                    hintStyle: const TextStyle(
                        fontSize: 20,
                        letterSpacing: 6,
                        color: Color(0xFFCBD5E1)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: isVerifying
                        ? null
                        : () async {
                            final code = otpController.text.trim();
                            if (code.length != 6) {
                              setModalState(() => errorMessage =
                                  'Masukkan 6 digit kode dari email.');
                              return;
                            }
                            setModalState(() {
                              isVerifying = true;
                              errorMessage = null;
                            });
                            try {
                              final authService = ref.read(authServiceProvider);
                              await authService.verifyEmailOtp(
                                  email: email, token: code);
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              if (mounted) {
                                setState(() {
                                  _profile = _profile?.copyWith(
                                      isEmailVerified: true);
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                        'Selamat! Email Anda telah berhasil diverifikasi.'),
                                    backgroundColor: Color(0xFF16A34A),
                                  ),
                                );
                              }
                              await _loadData();
                            } catch (e) {
                              setModalState(() {
                                isVerifying = false;
                                errorMessage = e
                                    .toString()
                                    .replaceFirst('Exception: ', '');
                              });
                            }
                          },
                    child: isVerifying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Verifikasi Kode Sekarang',
                            style: TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: isSending
                        ? null
                        : () async {
                            setModalState(() {
                              isSending = true;
                              errorMessage = null;
                            });
                            try {
                              final authService = ref.read(authServiceProvider);
                              await authService.sendEmailVerificationLink(
                                  email: email);
                              setModalState(() {
                                isSending = false;
                                statusMessage =
                                    'Tautan baru telah dikirim kembali!';
                              });
                            } catch (e) {
                              setModalState(() {
                                isSending = false;
                                errorMessage = e
                                    .toString()
                                    .replaceFirst('Exception: ', '');
                              });
                            }
                          },
                    child: Text(
                      isSending ? 'Mengirim ulang...' : 'Kirim Ulang Email',
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF16397E),
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
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
        backgroundColor: _selectedTabIndex == 0
            ? const Color(0xFFF8FAFC)
            : Colors.white,
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
          // 1. Header Top Bar (Halo, Nama User + Avatar Profil - Scrollable, Tidak Stack)
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
                    backgroundImage: (_profile?.avatarUrl != null &&
                            _profile!.avatarUrl!.trim().isNotEmpty)
                        ? NetworkImage(_profile!.avatarUrl!)
                        : null,
                    child: (_profile?.avatarUrl == null ||
                            _profile!.avatarUrl!.trim().isEmpty)
                        ? Text(
                            _initial,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF16397E),
                            ),
                          )
                        : null,
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
          child: Container(
            color: const Color(0xFFF8FAFC),
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
          alignment: Alignment.center,
          child: const Text(
            'Pesan',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ),

        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        Expanded(
          child: Container(
            color: const Color(0xFFF8FAFC),
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
    final email = _profile?.email ??
        SupabaseClientService.instance.currentUser?.email ??
        '-';
    final initial = _initial;
    final isEmailVerified = _isEmailVerified;

    return Column(
      children: [
        // App Bar Profil (Seragam Putih + Divider seperti Aktivitas & Pesan)
        Container(
          color: Colors.white,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          alignment: Alignment.center,
          child: const Text(
            'Profil',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
        ),

        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        Expanded(
          child: Container(
            color: const Color(0xFFF8FAFC),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
              children: [
              // 1. PROFIL HERO CARD (Deep Midnight Navy Gradient Sesuai Gambar 2 - Mewah & Mencolok)
              Container(
                padding: const EdgeInsets.all(20),
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
                    // Badge Header: AKUN PELANGGAN
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A162B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF38BDF8)
                              .withValues(alpha: 0.35),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 12,
                            color: Color(0xFF38BDF8),
                          ),
                          SizedBox(width: 5),
                          Text(
                            'AKUN PELANGGAN',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF38BDF8),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Avatar + Nama + Email
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Avatar dengan Badge Kamera
                        GestureDetector(
                          onTap: _showAvatarOptionsSheet,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2.5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.35),
                                    width: 2,
                                  ),
                                ),
                                child: CircleAvatar(
                                  radius: 34,
                                  backgroundColor: const Color(0xFF1E3A8A),
                                  backgroundImage: (_profile?.avatarUrl != null &&
                                          _profile!.avatarUrl!.trim().isNotEmpty)
                                      ? NetworkImage(_profile!.avatarUrl!)
                                      : null,
                                  child: _isUploadingAvatar
                                      ? const CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        )
                                      : ((_profile?.avatarUrl == null ||
                                              _profile!.avatarUrl!.trim().isEmpty)
                                          ? Text(
                                              initial,
                                              style: const TextStyle(
                                                fontSize: 26,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                              ),
                                            )
                                          : null),
                                ),
                              ),
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFFCBD5E1),
                                      width: 1.2,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x28000000),
                                        blurRadius: 5,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_outlined,
                                    size: 14,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 16),

                        // Nama & Email
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      email,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        color: Color(0xFFCBD5E1),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isEmailVerified) ...[
                                    const SizedBox(width: 5),
                                    const Icon(
                                      Icons.verified_rounded,
                                      size: 16,
                                      color: Color(0xFF22C55E),
                                    ),
                                  ] else ...[
                                    const SizedBox(width: 6),
                                    InkWell(
                                      onTap: _showEmailVerificationModal,
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF451A03),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          border: Border.all(
                                            color: const Color(0xFFF59E0B)
                                                .withValues(alpha: 0.5),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.warning_amber_rounded,
                                              size: 11,
                                              color: Color(0xFFFBBF24),
                                            ),
                                            SizedBox(width: 3),
                                            Text(
                                              'Verifikasi',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFFFBBF24),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Tombol Ubah Profil & Nama (Kontras Tinggi, Elegan di Atas Navy)
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0D1E3A),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(23),
                          ),
                        ),
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 17,
                          color: Color(0xFF0D1E3A),
                        ),
                        label: const Text(
                          'Ubah Profil & Nama',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0D1E3A),
                            letterSpacing: -0.2,
                          ),
                        ),
                        onPressed: _showEditProfileBottomSheet,
                      ),
                    ),
                  ],
                ),
              ),

        const SizedBox(height: 16),

        // 3. STATS CARD TERSAMBUNG (Total Dibuat, Sedang Berjalan, Selesai Sesuai Gambar)
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _buildSegmentStat(
                    count: '${_myJobs.length}',
                    label: 'Total Dibuat',
                    color: const Color(0xFF16397E),
                  ),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Color(0xFFF1F5F9),
                ),
                Expanded(
                  child: _buildSegmentStat(
                    count: '${_activeJobs.length}',
                    label: 'Sedang Berjalan',
                    color: const Color(0xFFD97706),
                  ),
                ),
                const VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Color(0xFFF1F5F9),
                ),
                Expanded(
                  child: _buildSegmentStat(
                    count: '${_myJobs.length - _activeJobs.length}',
                    label: 'Selesai',
                    color: const Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 18),

        // 4. MENU PANDUAN & KELUAR DARI AKUN
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.help_outline_rounded,
                    color: Color(0xFF16397E),
                    size: 20,
                  ),
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
                  'Cara kerja Nota Digital, timer 30 mnt, & sistem bayar langsung',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                onTap: () => FaqRulesScreen.show(context),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFF0F172A),
                    size: 20,
                  ),
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
            ],
          ),
        ),
      ],
    ),
  ),
),
],
);
}

  Widget _buildSegmentStat({
    required String count,
    required String label,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
