import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:beres_shared/beres_shared.dart';

final jobServiceProvider = Provider((ref) => JobService());

class JobPortalScreen extends ConsumerStatefulWidget {
  const JobPortalScreen({super.key});

  @override
  ConsumerState<JobPortalScreen> createState() => _JobPortalScreenState();
}

class _JobPortalScreenState extends ConsumerState<JobPortalScreen> {
  List<TukangJobFeedItem> _jobs = [];
  bool _isLoading = true;
  bool _isActionInProgress = false;
  String? _errorMessage;

  // Status Tukang
  bool _isOnline = true;
  int _radiusKm = 20;
  String _kycStatus = 'PENDING';
  int _activeBidsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadTukangProfileAndJobs();
  }

  Future<void> _loadTukangProfileAndJobs() async {
    setState(() => _isLoading = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Ambil data tukang profile
      final profileRes = await Supabase.instance.client
          .from('tukang_profiles')
          .select('is_online, radius_km, kyc_status')
          .eq('user_id', user.id)
          .maybeSingle();

      if (profileRes != null) {
        _isOnline = profileRes['is_online'] as bool? ?? true;
        _radiusKm = profileRes['radius_km'] as int? ?? 20;
        _kycStatus = profileRes['kyc_status'] as String? ?? 'PENDING';
      }

      // 2. Hitung jumlah lamaran aktif tukang saat ini (BR-15)
      final bidsRes = await Supabase.instance.client
          .from('bids')
          .select('id, jobs!inner(status)')
          .eq('tukang_id', user.id)
          .eq('status', 'ACTIVE')
          .eq('jobs.status', 'OPEN');

      _activeBidsCount = (bidsRes as List<dynamic>).length;

      // 3. Ambil feed pekerjaan terbuka via RPC (BR-16)
      final jobService = ref.read(jobServiceProvider);
      final feed = await jobService.getOpenJobsForTukang();

      if (mounted) {
        setState(() {
          _jobs = feed;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat bursa pekerjaan: $e';
        });
      }
    }
  }

  Future<void> _handleToggleOnline(bool val) async {
    setState(() => _isOnline = val);
    try {
      await ref.read(jobServiceProvider).updateTukangStatusAndLocation(
            isOnline: val,
          );
      _loadTukangProfileAndJobs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengubah status: $e')),
        );
      }
    }
  }

  Future<void> _handleRadiusChanged(double val) async {
    final int newRadius = val.round();
    setState(() => _radiusKm = newRadius);
    try {
      await ref.read(jobServiceProvider).updateTukangStatusAndLocation(
            radiusKm: newRadius,
          );
      _loadTukangProfileAndJobs();
    } catch (_) {}
  }

  Future<void> _submitBid(TukangJobFeedItem job) async {
    if (_kycStatus != 'APPROVED') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'BR-10: Anda harus terverifikasi KYC terlebih dahulu sebelum dapat melamar pekerjaan.',
          ),
          backgroundColor: AppColors.warningAmber,
        ),
      );
      return;
    }

    if (_activeBidsCount >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'BR-15: Anda sudah mencapai batas maksimal 5 lamaran aktif. Tarik lamaran yang belum direspons atau tunggu pelanggan.',
          ),
          backgroundColor: AppColors.dangerCrimson,
        ),
      );
      return;
    }

    setState(() => _isActionInProgress = true);
    final jobService = ref.read(jobServiceProvider);

    try {
      await jobService.submitBid(job.jobId);
      if (mounted) {
        setState(() => _isActionInProgress = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lamaran berhasil diajukan! Menunggu keputusan User.'),
            backgroundColor: AppColors.successGreen,
          ),
        );
        _loadTukangProfileAndJobs();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionInProgress = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.dangerCrimson,
          ),
        );
      }
    }
  }

  Future<void> _withdrawBid(TukangJobFeedItem job) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tarik Lamaran?'),
        content: const Text(
          'Apakah Anda yakin ingin membatalkan/menarik lamaran pada pekerjaan ini? Kuota lamaran aktif Anda akan bertambah kembali.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Kembali'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerCrimson,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Tarik Lamaran'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionInProgress = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      // Cari bid ID
      final bidRes = await Supabase.instance.client
          .from('bids')
          .select('id')
          .eq('job_id', job.jobId)
          .eq('tukang_id', user.id)
          .single();

      final bidId = bidRes['id'] as String;
      await ref.read(jobServiceProvider).withdrawBid(bidId);

      if (mounted) {
        setState(() => _isActionInProgress = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lamaran berhasil ditarik.'),
            backgroundColor: AppColors.successGreen,
          ),
        );
        _loadTukangProfileAndJobs();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionInProgress = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menarik lamaran: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Bursa Pekerjaan (Job Portal)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan',
            onPressed: _loadTukangProfileAndJobs,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTukangProfileAndJobs,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Control Bar: Online/Offline & Radius Kerja (FR-020, FR-027)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _isOnline
                                      ? AppColors.successGreen
                                      : Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isOnline ? 'Status: ONLINE' : 'Status: OFFLINE',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
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
                      const Divider(),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Radius Kerja: $_radiusKm km',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const Text(
                            '(Maks 50 km)',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _radiusKm.toDouble(),
                        min: 0,
                        max: 50,
                        divisions: 50,
                        activeColor: AppColors.primaryNavy,
                        label: '$_radiusKm km',
                        onChanged: (val) {
                          setState(() => _radiusKm = val.round());
                        },
                        onChangeEnd: _handleRadiusChanged,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 2. Info Bar: Batas 5 Bid (BR-15) & KYC Status
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.userBadgeBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.trustCobalt.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.fact_check_outlined,
                            size: 18, color: AppColors.trustCobalt),
                        const SizedBox(width: 8),
                        Text(
                          'Lamaran Aktif: $_activeBidsCount / 5 (BR-15)',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryNavy,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    if (_activeBidsCount >= 5)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.dangerCrimson,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'KUOTA PENUH',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 3. Feed List
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.dangerCrimson.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_errorMessage!,
                      style: TextStyle(color: AppColors.dangerCrimson)),
                )
              else if (!_isOnline)
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(Icons.cloud_off,
                            size: 48, color: AppColors.textSecondary),
                        SizedBox(height: 12),
                        Text(
                          'Anda Sedang OFFLINE',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Aktifkan status ONLINE di atas untuk melihat bursa pekerjaan dan mulai melamar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_jobs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.work_outline,
                            size: 48, color: AppColors.textSecondary),
                        const SizedBox(height: 12),
                        const Text(
                          'Belum Ada Pekerjaan Terbuka',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Belum ada pekerjaan di radius $_radiusKm km yang cocok dengan keahlian Anda. Coba perbesar radius atau tunggu beberapa saat.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
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
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final job = _jobs[index];
                    return _buildJobFeedCard(job);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildJobFeedCard(TukangJobFeedItem job) {
    final hasActiveBid = job.hasBid && job.bidStatus == BidStatus.active;
    final isLockedOnThis = job.hasBid && job.bidStatus == BidStatus.locked;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isLockedOnThis
              ? AppColors.successGreen
              : hasActiveBid
                  ? AppColors.trustCobalt
                  : AppColors.borderLight,
          width: (isLockedOnThis || hasActiveBid) ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Kategori & Jarak
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.tukangBadgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    job.categoryName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryNavy,
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.near_me_outlined,
                        size: 14, color: AppColors.trustCobalt),
                    const SizedBox(width: 4),
                    Text(
                      '${job.distanceKm.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.trustCobalt,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Deskripsi Kerusakan
            Text(
              job.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            // Area Label (BR-16: Privasi sebelum lock)
            Row(
              children: [
                const Icon(Icons.location_city_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    job.areaLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
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

            if (job.damagePhotos.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 50,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: job.damagePhotos.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, idx) {
                    return Container(
                      width: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: AppColors.primaryNavy.withValues(alpha: 0.08),
                      ),
                      child: const Icon(
                        Icons.broken_image_outlined,
                        size: 24,
                        color: AppColors.trustCobalt,
                      ),
                    );
                  },
                ),
              ),
            ],

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Action: Lamar / Tarik Lamaran (BR-15, BR-17)
            if (isLockedOnThis)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.successGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'LOCKED (Anda Terpilih untuk Job Ini!)',
                    style: TextStyle(
                      color: AppColors.successGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            else if (hasActiveBid)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.trustCobalt.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'Lamaran Aktif (Menunggu User)',
                          style: TextStyle(
                            color: AppColors.trustCobalt,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed:
                        _isActionInProgress ? null : () => _withdrawBid(job),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Tarik'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.dangerCrimson,
                      side: const BorderSide(color: AppColors.dangerCrimson),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_isActionInProgress || _activeBidsCount >= 5)
                      ? null
                      : () => _submitBid(job),
                  icon: const Icon(Icons.send_outlined, size: 18),
                  label: Text(_activeBidsCount >= 5
                      ? 'Batas 5 Lamaran Penuh (BR-15)'
                      : 'Lamar Pekerjaan Ini'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryNavy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
