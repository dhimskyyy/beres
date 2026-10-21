import 'dart:async';
import 'package:flutter/material.dart';
import '../../adapters/map_adapter.dart';
import '../../models/job.dart';
import '../../models/job_status.dart';
import '../../models/location_ping.dart';
import '../../services/job_service.dart';
import '../../services/tracking_service.dart';
import '../../services/review_service.dart';
import '../../services/cancellation_service.dart';
import '../../services/device_permission_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../cancellation/tukang_cancel_flow_dialog.dart';
import '../cancellation/user_cancel_otw_dialog.dart';
import '../cancellation/cancel_decision_card.dart';
import 'job_completion_dialog.dart';
import 'payment_dispute_dialog.dart';
import 'review_dialog.dart';

/// Layar Pelacakan GPS Real-time & Pelaksanaan Pekerjaan
class TrackingScreen extends StatefulWidget {
  final String jobId;
  final bool isTukang;
  final TrackingService trackingService;
  final JobService jobService;
  final ReviewService? reviewService;
  final CancellationService cancellationService;
  final VoidCallback? onBack;

  TrackingScreen({
    super.key,
    required this.jobId,
    required this.isTukang,
    required this.trackingService,
    required this.jobService,
    this.reviewService,
    CancellationService? cancellationService,
    this.onBack,
  }) : cancellationService = cancellationService ?? CancellationService();

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  Job? _job;
  LocationPing? _latestPing;
  StreamSubscription<List<LocationPing>>? _pingSubscription;
  bool _isLoading = true;
  String? _errorMessage;

  double? _tukangLat;
  double? _tukangLng;
  double _distanceMeters = 9999.0;

  @override
  void initState() {
    super.initState();
    _loadJob();
    _subscribeToPings();
  }

  @override
  void dispose() {
    _pingSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadJob() async {
    try {
      final job = await widget.jobService.getJobById(widget.jobId);
      final ping =
          await widget.trackingService.getLatestLocationPing(widget.jobId);

      if (mounted) {
        setState(() {
          _job = job;
          _latestPing = ping;
          if (ping != null) {
            _tukangLat = ping.latitude;
            _tukangLng = ping.longitude;
          } else if (job != null && widget.isTukang) {
            _tukangLat = job.latitude + 0.0025;
            _tukangLng = job.longitude + 0.0025;
          }
          _calculateDistance();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _subscribeToPings() {
    _pingSubscription = widget.trackingService
        .streamLocationPings(widget.jobId)
        .listen((pings) {
      if (pings.isNotEmpty && mounted) {
        final ping = pings.first;
        setState(() {
          _latestPing = ping;
          _tukangLat = ping.latitude;
          _tukangLng = ping.longitude;
          _calculateDistance();
        });
        _refreshJobStatus();
      }
    });
  }

  Future<void> _refreshJobStatus() async {
    final updated = await widget.jobService.getJobById(widget.jobId);
    if (updated != null && mounted) {
      setState(() {
        _job = updated;
      });
    }
  }

  void _calculateDistance() {
    if (_job == null || _tukangLat == null || _tukangLng == null) return;
    final dist = ((_job!.latitude - _tukangLat!).abs() * 111000) +
        ((_job!.longitude - _tukangLng!).abs() * 111000);
    _distanceMeters = dist;
  }

  Future<void> _sendPing(
    double lat,
    double lng, {
    double accuracy = 10.0,
  }) async {
    try {
      final res = await widget.trackingService.recordLocationPing(
        jobId: widget.jobId,
        latitude: lat,
        longitude: lng,
        accuracyM: accuracy,
      );
      if (mounted) {
        setState(() {
          _tukangLat = lat;
          _tukangLng = lng;
          _calculateDistance();
        });
        await _refreshJobStatus();
        if (!mounted) return;
        if (res['auto_arrived'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.successGreen,
              content: Text(
                'Anda telah berada di lokasi. Status otomatis diperbarui.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.dangerCrimson,
            content: Text('Gagal mengirim lokasi: $e'),
          ),
        );
      }
    }
  }

  Future<void> _confirmManualArrival() async {
    if (_tukangLat == null || _tukangLng == null) return;
    try {
      final res = await widget.trackingService.confirmArrivalManual(
        jobId: widget.jobId,
        latitude: _tukangLat!,
        longitude: _tukangLng!,
      );
      if (mounted) {
        if (res['success'] == true) {
          await _refreshJobStatus();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.successGreen,
              content: Text('Kedatangan berhasil dikonfirmasi.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.dangerCrimson,
            content: Text('$e'),
          ),
        );
      }
    }
  }

  Future<void> _startWork() async {
    try {
      final res = await widget.trackingService.startWork(jobId: widget.jobId);
      if (mounted) {
        if (res['success'] == true) {
          await _refreshJobStatus();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.trustCobalt,
              content: Text('Pekerjaan dimulai. Selamat bertugas!'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.dangerCrimson,
            content: Text('$e'),
          ),
        );
      }
    }
  }

  void _openCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => JobCompletionDialog(
        jobId: widget.jobId,
        trackingService: widget.trackingService,
        onCompleted: _refreshJobStatus,
      ),
    );
  }

  void _openPaymentDisputeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PaymentDisputeDialog(
        jobId: widget.jobId,
        trackingService: widget.trackingService,
        onReportSubmitted: _refreshJobStatus,
      ),
    );
  }

  void _openTukangCancelDialog() {
    TukangCancelFlowDialog.show(
      context,
      jobId: widget.jobId,
      cancellationService: widget.cancellationService,
      currentLatitude: _tukangLat,
      currentLongitude: _tukangLng,
      onSuccess: _refreshJobStatus,
    );
  }

  void _openUserCancelOtwDialog() {
    UserCancelOtwDialog.show(
      context,
      jobId: widget.jobId,
      cancellationService: widget.cancellationService,
      onSuccess: _refreshJobStatus,
    );
  }

  Future<void> _handleReportUserUnresponsive() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(
              Icons.report_problem_outlined,
              color: AppColors.dangerCrimson,
              size: 22,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Laporkan Pelanggan Tidak Aktif?',
                style: AppTypography.headingSmall,
              ),
            ),
          ],
        ),
        content: const Text(
          'Jika Anda telah mengirim pesan dan pelanggan tidak merespons lebih dari 30 menit saat Anda dalam perjalanan atau tiba di lokasi, pesanan akan dilepas kembali ke bursa.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerCrimson,
              foregroundColor: Colors.white,
              minimumSize: const Size(120, 42),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kirim Laporan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await widget.cancellationService
          .tukangReportUserUnresponsive(widget.jobId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.primaryNavy,
            content: Text(
              'Laporan diterima. Pesanan telah dilepas kembali ke bursa terbuka.',
            ),
          ),
        );
        widget.onBack?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.dangerCrimson,
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    }
  }

  void _openReviewDialog() {
    if (widget.reviewService == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ReviewDialog(
        jobId: widget.jobId,
        reviewService: widget.reviewService!,
        onReviewSubmitted: _refreshJobStatus,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_job == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pelacakan Lokasi')),
        body: Center(
          child: Text(_errorMessage ?? 'Data pekerjaan tidak ditemukan'),
        ),
      );
    }

    final job = _job!;
    final jobCenter = MapLatLng(job.latitude, job.longitude);
    final markers = <BeresMapMarker>[
      BeresMapMarker(
        id: 'job_location',
        position: jobCenter,
        type: MapMarkerType.jobLocation,
        title: 'Lokasi Pekerjaan: ${job.areaLabel}',
      ),
    ];

    if (_tukangLat != null && _tukangLng != null) {
      markers.add(
        BeresMapMarker(
          id: 'tukang_location',
          position: MapLatLng(_tukangLat!, _tukangLng!),
          type: MapMarkerType.tukangCurrentLocation,
          title: 'Posisi Mitra Tukang',
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          widget.isTukang ? 'Pelaksanaan Pekerjaan' : 'Pantau Lokasi Mitra',
        ),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onBack,
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan',
            onPressed: _refreshJobStatus,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                BeresMapView(
                  initialCenter: _tukangLat != null
                      ? MapLatLng(_tukangLat!, _tukangLng!)
                      : jobCenter,
                  initialZoom: 15.5,
                  markers: markers,
                ),
                Positioned(
                  top: 12,
                  left: 14,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getStatusColor(job.status),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            job.status.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.userBadgeBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${_distanceMeters.toStringAsFixed(0)} m',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.trustCobalt,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: AppColors.surfaceWhite,
                border: Border(
                  top: BorderSide(color: AppColors.borderLight),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            job.areaLabel,
                            style: AppTypography.headingSmall,
                          ),
                        ),
                        if (_latestPing != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.successLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'GPS Aktif',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.successGreen,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall,
                    ),
                    const Divider(height: 22),
                    if (job.isCancelPending) ...[
                      CancelDecisionCard(
                        jobId: widget.jobId,
                        isTukang: widget.isTukang,
                        cancellationService: widget.cancellationService,
                        onDecisionResolved: _refreshJobStatus,
                      ),
                      const Divider(height: 22),
                    ],
                    if (job.isWorking)
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pekerjaan sedang berlangsung. Pembatalan sepihak dikunci hingga pekerjaan selesai.',
                                style: AppTypography.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (widget.isTukang) ...[
                      if (job.isOnTheWay) ...[
                        Text(
                          'Konfirmasi Kedatangan di Lokasi',
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () async {
                                  final loc = await DevicePermissionService()
                                      .getCurrentLocation();
                                  _sendPing(
                                    loc.latitude,
                                    loc.longitude,
                                    accuracy: 5.0,
                                  );
                                },
                                child: const Text(
                                  'Perbarui GPS',
                                  style: TextStyle(fontSize: 12.5),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _distanceMeters <= 200
                                      ? AppColors.trustCobalt
                                      : AppColors.textMuted,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _distanceMeters <= 200
                                    ? _confirmManualArrival
                                    : () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Tombol aktif saat jarak Anda maksimal 200 meter dari titik lokasi.',
                                            ),
                                          ),
                                        );
                                      },
                                child: const Text(
                                  'Saya Sudah Tiba',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (job.isArrived) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.trustCobalt,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Mulai Kerjakan Tugas'),
                          onPressed: _startWork,
                        ),
                      ],
                      if (job.isOnTheWay || job.isArrived) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.dangerCrimson,
                                  side: BorderSide(
                                    color: AppColors.dangerCrimson.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                  minimumSize: const Size.fromHeight(42),
                                ),
                                icon: const Icon(
                                  Icons.cancel_outlined,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Batalkan Tugas',
                                  style: TextStyle(fontSize: 12),
                                ),
                                onPressed: _openTukangCancelDialog,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.textSecondary,
                                  minimumSize: const Size.fromHeight(42),
                                ),
                                icon: const Icon(
                                  Icons.timer_off_outlined,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Pelanggan Tidak Aktif',
                                  style: TextStyle(fontSize: 11.5),
                                ),
                                onPressed: _handleReportUserUnresponsive,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (job.isWorking) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.successGreen,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          label: const Text('Selesaikan Pekerjaan'),
                          onPressed: _openCompletionDialog,
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.dangerCrimson,
                            side: BorderSide(
                              color: AppColors.dangerCrimson.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                          icon: const Icon(
                            Icons.warning_amber_rounded,
                            size: 18,
                          ),
                          label: const Text('Laporkan Kendala Pembayaran'),
                          onPressed: _openPaymentDisputeDialog,
                        ),
                      ],
                      if (job.isCompleted) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.successLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.successGreen.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                color: AppColors.successGreen,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Pekerjaan telah selesai dan pembayaran langsung telah dikonfirmasi.',
                                  style: TextStyle(
                                    color: AppColors.successGreen,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ] else ...[
                      if (job.isOnTheWay) ...[
                        const Text(
                          'Mitra tukang sedang menuju lokasi Anda. Posisi diperbarui secara otomatis.',
                          style: AppTypography.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        Builder(
                          builder: (context) {
                            final otwStartTime =
                                job.onTheWayAt ?? job.createdAt;
                            final elapsedMinutes = DateTime.now()
                                .difference(otwStartTime)
                                .inMinutes;
                            final isEligibleToCancel = elapsedMinutes >= 180;

                            if (isEligibleToCancel) {
                              return ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.dangerCrimson,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(
                                  Icons.cancel_schedule_send_outlined,
                                  size: 18,
                                ),
                                label: const Text('Ajukan Pembatalan Pesanan'),
                                onPressed: _openUserCancelOtwDialog,
                              );
                            } else {
                              final remainingMinutes = 180 - elapsedMinutes;
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.userBadgeBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.info_outline_rounded,
                                      size: 16,
                                      color: AppColors.trustCobalt,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Waktu perjalanan: $elapsedMinutes menit. Opsi pembatalan terbuka jika mitra belum tiba setelah 3 jam ($remainingMinutes menit lagi).',
                                        style: AppTypography.bodySmall.copyWith(
                                          fontSize: 11.5,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                        ),
                      ],
                      if (job.isArrived)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.userBadgeBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Mitra tukang telah tiba di lokasi Anda dan siap memulai pengerjaan.',
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.trustCobalt,
                            ),
                          ),
                        ),
                      if (job.isWorking)
                        const Text(
                          'Mitra tukang sedang melakukan pengerjaan. Silakan tunggu hingga pekerjaan selesai.',
                          style: AppTypography.bodySmall,
                        ),
                      if (job.isCompleted) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.warningAmber,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.star_rounded),
                          label: const Text('Beri Penilaian & Ulasan'),
                          onPressed: _openReviewDialog,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(JobStatus status) {
    switch (status) {
      case JobStatus.onTheWay:
        return AppColors.warningAmber;
      case JobStatus.arrived:
        return AppColors.trustCobalt;
      case JobStatus.working:
        return AppColors.primary;
      case JobStatus.completed:
        return AppColors.successGreen;
      default:
        return AppColors.textMuted;
    }
  }
}
