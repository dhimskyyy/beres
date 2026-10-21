import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beres_shared/beres_shared.dart';

final jobDetailServiceProvider = Provider((ref) => JobService());

class JobDetailAndBidsScreen extends ConsumerStatefulWidget {
  final String jobId;

  const JobDetailAndBidsScreen({super.key, required this.jobId});

  @override
  ConsumerState<JobDetailAndBidsScreen> createState() =>
      _JobDetailAndBidsScreenState();
}

class _JobDetailAndBidsScreenState
    extends ConsumerState<JobDetailAndBidsScreen> {
  Job? _job;
  List<UserBidViewItem> _bids = [];
  bool _isLoading = true;
  bool _isActionInProgress = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadJobAndBids();
  }

  Future<void> _loadJobAndBids() async {
    setState(() => _isLoading = true);
    final jobService = ref.read(jobDetailServiceProvider);
    try {
      final job = await jobService.getJobById(widget.jobId);
      final bids = await jobService.getJobBidsForUser(widget.jobId);
      if (mounted) {
        setState(() {
          _job = job;
          _bids = bids;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat detail pesanan.';
        });
      }
    }
  }

  Future<void> _handleLockTukang(UserBidViewItem bid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Pilih Mitra Tukang Ini?',
          style: AppTypography.headingSmall,
        ),
        content: Text(
          'Anda akan memilih ${bid.tukangName} untuk menangani pekerjaan ini.\n\n'
          'Setelah dipilih, ruang diskusi chat akan terbuka untuk menyepakati rincian biaya melalui Nota Digital.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.trustCobalt,
              foregroundColor: Colors.white,
              minimumSize: const Size(120, 42),
            ),
            child: const Text('Ya, Pilih Mitra'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionInProgress = true);
    final jobService = ref.read(jobDetailServiceProvider);

    try {
      final res = await jobService.lockTukang(
        jobId: widget.jobId,
        bidId: bid.bidId,
      );

      if (mounted) {
        setState(() => _isActionInProgress = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res['message']?.toString() ??
                  'Mitra berhasil dipilih! Membuka ruang diskusi...',
            ),
            backgroundColor: AppColors.successGreen,
          ),
        );
        await _loadJobAndBids();
        if (mounted) {
          _openChatRoom();
        }
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

  Future<void> _handleCancelOpenJob() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Batalkan Pesanan?',
          style: AppTypography.headingSmall,
        ),
        content: const Text(
          'Pesanan ini masih berada di bursa terbuka dan belum memilih mitra tukang. Pembatalan tidak dikenakan penalti.',
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
              minimumSize: const Size(130, 42),
            ),
            child: const Text('Batalkan Pesanan'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionInProgress = true);
    try {
      await ref
          .read(jobDetailServiceProvider)
          .cancelOpenJobByUser(widget.jobId);
      if (mounted) {
        setState(() => _isActionInProgress = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pesanan telah dibatalkan.'),
            backgroundColor: AppColors.primaryNavy,
          ),
        );
        _loadJobAndBids();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isActionInProgress = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membatalkan pesanan: $e')),
        );
      }
    }
  }

  void _openChatRoom() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(builder: (_) => ChatScreen(jobId: widget.jobId)),
        )
        .then((_) => _loadJobAndBids());
  }

  void _openTrackingScreen() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => TrackingScreen(
              jobId: widget.jobId,
              isTukang: false,
              trackingService: TrackingService(),
              jobService: ref.read(jobDetailServiceProvider),
              reviewService: ReviewService(),
            ),
          ),
        )
        .then((_) => _loadJobAndBids());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Detail Pesanan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan',
            onPressed: _loadJobAndBids,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _job == null
          ? Center(child: Text(_errorMessage ?? 'Pesanan tidak ditemukan.'))
          : RefreshIndicator(
              onRefresh: _loadJobAndBids,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildJobSummaryCard(_job!),
                    const SizedBox(height: 16),

                    // Action Banner saat Mitra sudah dipilih
                    if (_job!.status == JobStatus.negotiating ||
                        _job!.status == JobStatus.notaApproved) ...[
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.trustCobalt.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.userBadgeBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.forum_outlined,
                                    color: AppColors.trustCobalt,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _job!.status == JobStatus.notaApproved
                                        ? 'Nota Digital Telah Disetujui'
                                        : 'Diskusi & Kesepakatan Biaya',
                                    style: AppTypography.headingSmall,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _job!.status == JobStatus.notaApproved
                                  ? 'Menunggu mitra tukang menekan tombol berangkat menuju lokasi Anda.'
                                  : 'Diskusikan rincian pekerjaan dan setujui Nota Digital yang diajukan mitra tukang di ruang chat.',
                              style: AppTypography.bodySmall,
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: _openChatRoom,
                              icon: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 18,
                              ),
                              label: const Text('Buka Ruang Diskusi & Nota'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (_job!.status == JobStatus.onTheWay ||
                        _job!.status == JobStatus.arrived ||
                        _job!.status == JobStatus.working ||
                        _job!.status == JobStatus.completed ||
                        _job!.status == JobStatus.cancelPending) ...[
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceWhite,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.successGreen.withValues(
                              alpha: 0.35,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.successLight,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.my_location_rounded,
                                    color: AppColors.successGreen,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: Text(
                                    'Pelacakan Lokasi & Progres Kerja',
                                    style: AppTypography.headingSmall,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Pantau posisi mitra tukang secara langsung di peta, cek rincian Nota Sah, atau berikan ulasan setelah selesai.',
                              style: AppTypography.bodySmall,
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: _openTrackingScreen,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.successGreen,
                              ),
                              icon: const Icon(Icons.map_outlined, size: 18),
                              label: const Text('Pantau Lokasi & Progres'),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _openChatRoom,
                              icon: const Icon(
                                Icons.receipt_long_outlined,
                                size: 18,
                              ),
                              label: const Text('Buka Chat & Nota Sah'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Daftar Pelamar saat OPEN
                    if (_job!.isOpen) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Mitra Tukang Melamar (${_bids.where((b) => b.isActive).length})',
                            style: AppTypography.headingSmall,
                          ),
                          TextButton.icon(
                            onPressed: _isActionInProgress
                                ? null
                                : _handleCancelOpenJob,
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: AppColors.dangerCrimson,
                            ),
                            label: const Text(
                              'Batalkan',
                              style: TextStyle(
                                color: AppColors.dangerCrimson,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Pilih 1 mitra tukang untuk mulai berdiskusi dan menyepakati biaya pengerjaan.',
                        style: AppTypography.bodySmall,
                      ),
                      const SizedBox(height: 12),

                      if (_bids.where((b) => b.isActive).isEmpty)
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
                                Icons.hourglass_empty_rounded,
                                size: 36,
                                color: AppColors.textMuted,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Menunggu Mitra Tukang Melamar',
                                style: AppTypography.headingSmall,
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Pesanan Anda sedang ditampilkan kepada mitra tukang terdekat yang sesuai keahlian. Tarik layar ke bawah untuk menyegarkan.',
                                textAlign: TextAlign.center,
                                style: AppTypography.bodySmall,
                              ),
                            ],
                          ),
                        )
                      else
                        ..._bids
                            .where((b) => b.isActive)
                            .map((bid) => _buildBidCard(bid)),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildJobSummaryCard(Job job) {
    return Container(
      padding: const EdgeInsets.all(18),
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
              _buildStatusPill(job.status),
              Text(
                Formatters.formatDateTime(job.createdAt),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            job.description,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          const Divider(height: 24),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 16,
                color: AppColors.trustCobalt,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  job.areaLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (job.agreedTotal != null) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Biaya Disepakati',
                  style: AppTypography.bodySmall,
                ),
                Text(
                  Formatters.formatCurrency(job.agreedTotal!),
                  style: AppTypography.rupiahMedium.copyWith(
                    color: AppColors.trustCobalt,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBidCard(UserBidViewItem bid) {
    final name = bid.tukangName;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'T';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.tukangBadgeBg,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.tukangBadgeText,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTypography.headingSmall),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: AppColors.warningAmber,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          bid.ratingAvg.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '• ${bid.completedJobsCount} pekerjaan selesai • ${bid.activeDays} hari aktif',
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (bid.distanceKm != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.userBadgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${bid.distanceKm!.toStringAsFixed(1)} km',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.trustCobalt,
                    ),
                  ),
                ),
            ],
          ),
          if (bid.skills.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: bid.skills
                  .map(
                    (s) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        s,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isActionInProgress
                  ? null
                  : () => _handleLockTukang(bid),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const Text('Pilih Mitra Ini'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPill(JobStatus status) {
    Color color;
    Color bg;
    switch (status) {
      case JobStatus.open:
        color = AppColors.trustCobalt;
        bg = AppColors.userBadgeBg;
        break;
      case JobStatus.negotiating:
      case JobStatus.notaApproved:
        color = AppColors.warningAmber;
        bg = AppColors.warningLight;
        break;
      case JobStatus.onTheWay:
      case JobStatus.arrived:
      case JobStatus.working:
      case JobStatus.completed:
        color = AppColors.successGreen;
        bg = AppColors.successLight;
        break;
      default:
        color = AppColors.dangerCrimson;
        bg = AppColors.dangerLight;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
