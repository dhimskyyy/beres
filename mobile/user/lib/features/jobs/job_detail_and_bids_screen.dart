import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beres_shared/beres_shared.dart';
import 'job_create_screen.dart';

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
  List<String> _photos = [];
  bool _isLoading = true;
  bool _isLocking = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadJobAndBids();
  }

  Future<void> _loadJobAndBids() async {
    setState(() => _isLoading = true);
    final jobService = ref.read(jobServiceProvider);

    try {
      final job = await jobService.getJobById(widget.jobId);
      final bids = await jobService.getJobBidsForUser(widget.jobId);
      final photos = await jobService.getJobDamagePhotos(widget.jobId);

      if (mounted) {
        setState(() {
          _job = job;
          _bids = bids;
          _photos = photos;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat data pekerjaan: $e';
        });
      }
    }
  }

  Future<void> _handleLockTukang(UserBidViewItem bid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kunci Mitra Tukang?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Anda akan memilih ${bid.tukangName} untuk menangani pekerjaan ini.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.userBadgeBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Aturan Beres (BR-17): Seluruh lamaran aktif mitra ini pada pekerjaan lain akan otomatis ditarik (WITHDRAWN) agar mitra fokus menangani pekerjaan Anda.',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.userBadgeText,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Status pekerjaan akan berubah menjadi NEGOSIASI (NEGOTIATING) untuk mendiskusikan rincian Nota Digital di ruang Chat.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.successGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Kunci Mitra'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLocking = true);
    final jobService = ref.read(jobServiceProvider);

    try {
      final result = await jobService.lockTukang(
        jobId: widget.jobId,
        bidId: bid.bidId,
      );

      if (mounted) {
        setState(() => _isLocking = false);
        final clearedCount = result['other_bids_cleared_count'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Berhasil mengunci ${bid.tukangName}! ($clearedCount lamaran lain otomatis ditarik BR-17)',
            ),
            backgroundColor: AppColors.successGreen,
          ),
        );
        _loadJobAndBids();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLocking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunci tukang: $e'),
            backgroundColor: AppColors.dangerCrimson,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Pekerjaan')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_job == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Pekerjaan')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage ?? 'Pekerjaan tidak ditemukan'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadJobAndBids,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final isJobOpen = _job!.isOpen;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Detail & Penawaran'),
        actions: [
          if (isJobOpen)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Pekerjaan (FR-010)',
              onPressed: () async {
                final updated = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => JobCreateScreen(existingJob: _job),
                  ),
                );
                if (updated == true) {
                  _loadJobAndBids();
                }
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan',
            onPressed: _loadJobAndBids,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadJobAndBids,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header Card Pekerjaan
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
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
                              color: _getStatusBgColor(_job!.status),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _job!.status.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _getStatusTextColor(_job!.status),
                              ),
                            ),
                          ),
                          Text(
                            Formatters.formatDateTime(_job!.createdAt),
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _job!.description,
                        style: AppTypography.headingSmall,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 16, color: AppColors.trustCobalt),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _job!.areaLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryNavy,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _job!.addressFull,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (_photos.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text(
                          'Foto Kerusakan (${_photos.length}):',
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 70,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _photos.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, idx) {
                              return Container(
                                width: 70,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: AppColors.primaryNavy
                                      .withValues(alpha: 0.1),
                                ),
                                child: const Icon(
                                  Icons.image,
                                  color: AppColors.trustCobalt,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 2. Section: Pelamar / Bids
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Mitra Tukang yang Melamar (${_bids.length})',
                    style: AppTypography.headingSmall,
                  ),
                  if (isJobOpen)
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
                        'Pilih 1 Tukang (BR-17)',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.userBadgeText,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (_bids.isEmpty)
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.radar_outlined,
                          size: 48,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Belum Ada Penawaran Masuk',
                          style: AppTypography.headingSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Pekerjaan Anda sedang disiarkan ke mitra tukang terverifikasi di sekitar ${_job!.areaLabel}. Notifikasi akan muncul begitu ada yang melamar.',
                          textAlign: TextAlign.center,
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
                  itemCount: _bids.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final bid = _bids[index];
                    return _buildBidCard(bid, isJobOpen);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBidCard(UserBidViewItem bid, bool isJobOpen) {
    return Card(
      elevation: bid.isLocked ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: bid.isLocked ? AppColors.successGreen : AppColors.borderLight,
          width: bid.isLocked ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.tukangBadgeBg,
                  child: const Icon(
                    Icons.person,
                    color: AppColors.warningAmber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bid.tukangName,
                        style: AppTypography.headingSmall,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            '${bid.ratingAvg.toStringAsFixed(1)} (${bid.ratingCount} ulasan)',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '•  ${bid.completedJobsCount} job selesai',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildBidBadge(bid.bidStatus),
              ],
            ),
            const SizedBox(height: 12),

            // Info Jarak & Hari Aktif
            Row(
              children: [
                if (bid.distanceKm != null) ...[
                  const Icon(Icons.near_me_outlined,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    '${bid.distanceKm!.toStringAsFixed(1)} km dari lokasi',
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(width: 12),
                ],
                const Icon(Icons.calendar_today_outlined,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Aktif ${bid.activeDays} hari',
                  style: AppTypography.bodySmall,
                ),
              ],
            ),

            if (bid.skills.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: bid.skills.map((s) {
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Text(s, style: const TextStyle(fontSize: 11)),
                  );
                }).toList(),
              ),
            ],

            // Action Button: Lock Tukang (FR-012, BR-17)
            if (isJobOpen && bid.isActive) ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLocking ? null : () => _handleLockTukang(bid),
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: const Text('Pilih & Kunci Mitra Ini (BR-17)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.successGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBidBadge(BidStatus status) {
    Color bg;
    Color text;
    String label;

    switch (status) {
      case BidStatus.locked:
        bg = AppColors.successGreen.withValues(alpha: 0.15);
        text = AppColors.successGreen;
        label = 'LOCKED (Terpilih)';
        break;
      case BidStatus.active:
        bg = AppColors.trustCobalt.withValues(alpha: 0.15);
        text = AppColors.trustCobalt;
        label = 'Melamar';
        break;
      case BidStatus.rejected:
        bg = Colors.grey.shade200;
        text = Colors.grey.shade700;
        label = 'Ditolak';
        break;
      case BidStatus.withdrawn:
        bg = Colors.grey.shade200;
        text = Colors.grey.shade700;
        label = 'Auto-Clear';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: text,
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
