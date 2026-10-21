import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:beres_shared/beres_shared.dart';

final jobServiceProvider = Provider((ref) => JobService());

class JobPortalScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const JobPortalScreen({super.key, this.embedded = false});

  @override
  ConsumerState<JobPortalScreen> createState() => _JobPortalScreenState();
}

class _JobPortalScreenState extends ConsumerState<JobPortalScreen> {
  List<TukangJobFeedItem> _jobs = [];
  bool _isLoading = true;
  bool _isActionInProgress = false;
  String? _errorMessage;

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

      final bidsRes = await Supabase.instance.client
          .from('bids')
          .select('id, jobs!inner(status)')
          .eq('tukang_id', user.id)
          .eq('status', 'ACTIVE')
          .eq('jobs.status', 'OPEN');

      _activeBidsCount = (bidsRes as List<dynamic>).length;

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
          _errorMessage = 'Gagal memuat bursa pekerjaan.';
        });
      }
    }
  }

  Future<void> _handleToggleOnline(bool val) async {
    setState(() => _isOnline = val);
    try {
      double? lat;
      double? lng;
      if (val) {
        final loc = await DevicePermissionService().getCurrentLocation();
        lat = loc.latitude;
        lng = loc.longitude;
      }
      await ref
          .read(jobServiceProvider)
          .updateTukangStatusAndLocation(
            isOnline: val,
            latitude: lat,
            longitude: lng,
          );
      _loadTukangProfileAndJobs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal mengubah status: $e')));
      }
    }
  }

  Future<void> _handleRadiusChanged(double val) async {
    final int newRadius = val.round();
    setState(() => _radiusKm = newRadius);
    try {
      await ref
          .read(jobServiceProvider)
          .updateTukangStatusAndLocation(radiusKm: newRadius);
      _loadTukangProfileAndJobs();
    } catch (_) {}
  }

  Future<void> _submitBid(TukangJobFeedItem job) async {
    if (_kycStatus != 'APPROVED') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Selesaikan verifikasi identitas (KTP) terlebih dahulu untuk dapat melamar pekerjaan.',
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
            'Anda telah mencapai batas maksimal 5 lamaran aktif. Tarik lamaran lain atau tunggu respons pelanggan.',
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
            content: Text(
              'Lamaran berhasil diajukan! Menunggu konfirmasi pelanggan.',
            ),
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
        backgroundColor: AppColors.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Tarik Lamaran?', style: AppTypography.headingSmall),
        content: const Text(
          'Apakah Anda yakin ingin membatalkan lamaran pada pekerjaan ini? Kuota lamaran aktif Anda akan tersedia kembali.',
          style: AppTypography.bodyMedium,
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
              minimumSize: const Size(120, 42),
            ),
            child: const Text('Tarik Lamaran'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionInProgress = true);
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
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
            backgroundColor: AppColors.primaryNavy,
          ),
        );
        _loadTukangProfileAndJobs();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionInProgress = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal menarik lamaran: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: const Text('Bursa Pekerjaan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
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
              // 1. Control Panel: Online/Offline & Radius
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _isOnline
                                    ? AppColors.successGreen
                                    : AppColors.textMuted,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isOnline
                                      ? 'Siap Menerima Tugas'
                                      : 'Sedang Offline',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  _isOnline
                                      ? 'Tampil pada pencarian pelanggan'
                                      : 'Tidak menerima pesanan baru',
                                  style: AppTypography.bodySmall,
                                ),
                              ],
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
                    const Divider(height: 22),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Jangkauan Radius Kerja',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.tukangBadgeBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$_radiusKm km',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.safetyOrange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _radiusKm.toDouble(),
                      min: 0,
                      max: 50,
                      divisions: 50,
                      activeColor: AppColors.safetyOrange,
                      label: '$_radiusKm km',
                      onChanged: (val) {
                        setState(() => _radiusKm = val.round());
                      },
                      onChangeEnd: _handleRadiusChanged,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 2. Kuota Lamaran Aktif
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.fact_check_outlined,
                          size: 18,
                          color: AppColors.trustCobalt,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Lamaran Aktif: $_activeBidsCount dari 5 kuota',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _activeBidsCount >= 5
                            ? AppColors.dangerLight
                            : AppColors.successLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _activeBidsCount >= 5 ? 'Kuota Penuh' : 'Tersedia',
                        style: TextStyle(
                          color: _activeBidsCount >= 5
                              ? AppColors.dangerCrimson
                              : AppColors.successGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
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
                  padding: EdgeInsets.all(36.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.dangerCrimson),
                  ),
                )
              else if (!_isOnline)
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 40,
                        color: AppColors.textMuted,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Anda Sedang Offline',
                        style: AppTypography.headingSmall,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Aktifkan status Siap Menerima Tugas di atas untuk melihat daftar pekerjaan terbuka di sekitar Anda.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
                )
              else if (_jobs.isEmpty)
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.work_outline_rounded,
                        size: 40,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Belum Ada Pekerjaan Terbuka',
                        style: AppTypography.headingSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Belum ditemukan pekerjaan terbuka dalam radius $_radiusKm km yang sesuai dengan bidang keahlian Anda.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _jobs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _buildJobFeedCard(_jobs[index]),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLockedOnThis
              ? AppColors.successGreen
              : hasActiveBid
              ? AppColors.trustCobalt
              : AppColors.borderLight,
          width: (isLockedOnThis || hasActiveBid) ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.tukangBadgeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  job.categoryName,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tukangBadgeText,
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.near_me_outlined,
                    size: 14,
                    color: AppColors.trustCobalt,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${job.distanceKm.toStringAsFixed(1)} km',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.trustCobalt,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          Text(
            job.description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.4,
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
                child: Text(job.areaLabel, style: AppTypography.bodySmall),
              ),
              Text(
                Formatters.formatDateTime(job.createdAt),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),

          if (job.damagePhotos.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.photo_library_outlined,
                  size: 14,
                  color: AppColors.trustCobalt,
                ),
                const SizedBox(width: 6),
                Text(
                  '${job.damagePhotos.length} foto kondisi kerusakan terlampir',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.trustCobalt,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          if (isLockedOnThis)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text(
                  'Anda Terpilih untuk Pekerjaan Ini',
                  style: TextStyle(
                    color: AppColors.successGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else if (hasActiveBid)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.userBadgeBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text(
                        'Lamaran Terkirim • Menunggu Pelanggan',
                        style: TextStyle(
                          color: AppColors.trustCobalt,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _isActionInProgress
                      ? null
                      : () => _withdrawBid(job),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.dangerCrimson,
                    side: BorderSide(
                      color: AppColors.dangerCrimson.withValues(alpha: 0.4),
                    ),
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Text('Tarik'),
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
                icon: const Icon(Icons.send_rounded, size: 17),
                label: Text(
                  _activeBidsCount >= 5
                      ? 'Kuota 5 Lamaran Aktif Penuh'
                      : 'Lamar Pekerjaan Ini',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryNavy,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
