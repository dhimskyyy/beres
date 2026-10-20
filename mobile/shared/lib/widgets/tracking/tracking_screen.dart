import 'dart:async';
import 'package:flutter/material.dart';
import '../../adapters/map_adapter.dart';
import '../../models/job.dart';
import '../../models/job_status.dart';
import '../../models/location_ping.dart';
import '../../services/job_service.dart';
import '../../services/tracking_service.dart';
import '../../services/review_service.dart';
import '../../theme/app_colors.dart';
import 'job_completion_dialog.dart';
import 'payment_dispute_dialog.dart';
import 'review_dialog.dart';

/// Layar Pelacakan GPS Real-time & Eksekusi Pekerjaan (M5)
/// Mendukung alur: ON_THE_WAY -> Kedatangan 50m/200m (ARRIVED) -> WORKING -> COMPLETED
class TrackingScreen extends StatefulWidget {
  final String jobId;
  final bool isTukang;
  final TrackingService trackingService;
  final JobService jobService;
  final ReviewService? reviewService;
  final VoidCallback? onBack;

  const TrackingScreen({
    super.key,
    required this.jobId,
    required this.isTukang,
    required this.trackingService,
    required this.jobService,
    this.reviewService,
    this.onBack,
  });

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  Job? _job;
  LocationPing? _latestPing;
  StreamSubscription<List<LocationPing>>? _pingSubscription;
  bool _isLoading = true;
  String? _errorMessage;

  // Koordinat tukang
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
            // Default awal tukang jika belum ada ping: geser 300m dari job
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
        // Refresh status job jika ada perubahan otomatis dari server
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

  /// Kirim Ping Lokasi Tukang (Simulasi atau GPS HP)
  Future<void> _sendPing(double lat, double lng,
      {double accuracy = 10.0}) async {
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
        if (res['auto_arrived'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.success,
              content: Text(
                  'Jarak <= 50 meter! Status otomatis menjadi ARRIVED (BR-60).'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              backgroundColor: AppColors.error, content: Text('Error: $e')),
        );
      }
    }
  }

  /// Konfirmasi Kedatangan Manual saat <= 200 meter (BR-61)
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.success,
              content: Text(
                  'Kedatangan berhasil dikonfirmasi secara manual (BR-61).'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('$e')),
        );
      }
    }
  }

  /// Mulai Bekerja (ARRIVED -> WORKING) (BR-62)
  Future<void> _startWork() async {
    try {
      final res = await widget.trackingService.startWork(jobId: widget.jobId);
      if (mounted) {
        if (res['success'] == true) {
          await _refreshJobStatus();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.primary,
              content: Text(
                  'Pekerjaan dimulai. Sesuai BR-65 pekerjaan dilarang dibatalkan.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.error, content: Text('$e')),
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
        appBar: AppBar(title: const Text('Live Tracking')),
        body: Center(child: Text(_errorMessage ?? 'Pekerjaan tidak ditemukan')),
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
      appBar: AppBar(
        title:
            Text(widget.isTukang ? 'Pelaksanaan Tugas' : 'Pantau Mitra Tukang'),
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back), onPressed: widget.onBack)
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshJobStatus,
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. PETA LIVE TRACKING
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

                // BADGE STATUS OPERASIONAL
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _getStatusColor(job.status),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Status: ${job.status.label}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        Text(
                          'Jarak: ${_distanceMeters.toStringAsFixed(0)} m',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. KONTROL DAN AKSI STATE MACHINE (BR-60, BR-61, BR-62, BR-65, BR-32, BR-67)
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // A. DETAIL JOB SINGKAT & PING INFO
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            job.areaLabel,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (_latestPing != null)
                          Text(
                            'GPS Aktif',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600),
                          ),
                      ],
                    ),
                    Text(
                      job.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const Divider(height: 20),

                    // B. TAMPILAN KHUSUS STATUS WORKING (BR-65: DILARANG BATAL)
                    if (job.isWorking)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock, size: 18, color: Colors.amber),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pekerjaan sedang berlangsung. Sesuai aturan BR-65, pekerjaan dilarang dibatalkan oleh siapa pun.',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // C. KONTROL KHUSUS MITRA TUKANG
                    if (widget.isTukang) ...[
                      // 1. TAHAP ON_THE_WAY
                      if (job.isOnTheWay) ...[
                        const Text(
                          'Deteksi Kedatangan Tukang (BR-60 / BR-61):',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            // Simulasi Tombol Sampai <= 50m (Auto ARRIVED)
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  _sendPing(
                                    job.latitude + 0.0001,
                                    job.longitude + 0.0001,
                                    accuracy: 5.0,
                                  );
                                },
                                child: const Text('Simulasi Jarak 15m (Auto)',
                                    style: TextStyle(fontSize: 11)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Tombol Manual Kedatangan <= 200m (BR-61)
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _distanceMeters <= 200
                                      ? AppColors.primary
                                      : Colors.grey.shade400,
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: _distanceMeters <= 200
                                    ? _confirmManualArrival
                                    : () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Tombol aktif saat jarak <= 200 meter (BR-61)'),
                                          ),
                                        );
                                      },
                                child: const Text('Saya Sudah Tiba',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // 2. TAHAP ARRIVED
                      if (job.isArrived) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Mulai Bekerja (BR-62)',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          onPressed: _startWork,
                        ),
                      ],

                      // 3. TAHAP WORKING
                      if (job.isWorking) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Selesaikan Tugas (BR-32)',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14)),
                          onPressed: _openCompletionDialog,
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon:
                              const Icon(Icons.warning_amber_rounded, size: 18),
                          label: const Text(
                              'Laporkan Masalah Pembayaran (BR-67)',
                              style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: _openPaymentDisputeDialog,
                        ),
                      ],

                      // 4. TAHAP COMPLETED
                      if (job.isCompleted) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0x1A15803D),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.success),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.verified, color: AppColors.success),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Pekerjaan telah selesai. Pembayaran telah diterima langsung.',
                                  style: TextStyle(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ] else ...[
                      // D. TAMPILAN KHUSUS PELANGGAN (USER)
                      if (job.isOnTheWay)
                        const Text(
                          'Tukang sedang menuju lokasi Anda. Lokasi diperbarui secara real-time.',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      if (job.isArrived)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0x1A2563EB),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Tukang telah tiba di lokasi Anda dan bersiap memulai pekerjaan.',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary),
                          ),
                        ),
                      if (job.isWorking)
                        const Text(
                          'Tukang sedang melakukan pengerjaan. Harap menunggu hingga selesai.',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      if (job.isCompleted) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.amber.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.star),
                          label: const Text('Beri Ulasan & Bintang (FR-021)',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13)),
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
        return Colors.orange;
      case JobStatus.arrived:
        return Colors.blue;
      case JobStatus.working:
        return AppColors.primary;
      case JobStatus.completed:
        return AppColors.success;
      default:
        return Colors.grey;
    }
  }
}
