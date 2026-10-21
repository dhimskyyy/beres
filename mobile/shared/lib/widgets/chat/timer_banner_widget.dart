import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../services/chat_service.dart';
import '../../services/nota_service.dart';

class TimerBannerWidget extends StatefulWidget {
  final JobChatContext chatContext;
  final VoidCallback onRefreshNeeded;

  const TimerBannerWidget({
    super.key,
    required this.chatContext,
    required this.onRefreshNeeded,
  });

  @override
  State<TimerBannerWidget> createState() => _TimerBannerWidgetState();
}

class _TimerBannerWidgetState extends State<TimerBannerWidget> {
  Timer? _timer;
  late int _remainingSeconds;
  bool _isActionLoading = false;
  final ChatService _chatService = ChatService();
  final NotaService _notaService = NotaService();

  @override
  void initState() {
    super.initState();
    _initTimerSeconds();
    _startTicking();
  }

  @override
  void didUpdateWidget(covariant TimerBannerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatContext.status != widget.chatContext.status ||
        oldWidget.chatContext.departTimerSeconds !=
            widget.chatContext.departTimerSeconds ||
        oldWidget.chatContext.negotiatingTimerSeconds !=
            widget.chatContext.negotiatingTimerSeconds) {
      _timer?.cancel();
      _initTimerSeconds();
      _startTicking();
    }
  }

  void _initTimerSeconds() {
    final status = widget.chatContext.status;
    if (status == 'NOTA_APPROVED') {
      _remainingSeconds = widget.chatContext.departTimerSeconds;
    } else if (status == 'NEGOTIATING') {
      _remainingSeconds = widget.chatContext.negotiatingTimerSeconds;
    } else {
      _remainingSeconds = 0;
    }
  }

  void _startTicking() {
    if (_remainingSeconds <= 0) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          timer.cancel();
          _handleTimerExpired();
        }
      });
    });
  }

  Future<void> _handleTimerExpired() async {
    final status = widget.chatContext.status;
    if (status == 'NOTA_APPROVED') {
      try {
        await _notaService.checkDepartTimeout(jobId: widget.chatContext.jobId);
      } catch (_) {}
      widget.onRefreshNeeded();
    } else if (status == 'NEGOTIATING') {
      widget.onRefreshNeeded();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTimer(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _handleDepartJob() async {
    setState(() => _isActionLoading = true);
    try {
      await _notaService.departJob(jobId: widget.chatContext.jobId);
      widget.onRefreshNeeded();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status diperbarui menjadi Menuju Lokasi.'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui status: $e'),
            backgroundColor: AppColors.dangerCrimson,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleCancelNegotiation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Akhiri Diskusi & Lepas Pesanan?',
          style: AppTypography.headingSmall,
        ),
        content: const Text(
          'Pesanan akan dikembalikan ke bursa terbuka agar dapat dilamar oleh mitra tukang lain tanpa penalti.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Kembali'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerCrimson,
              foregroundColor: Colors.white,
              minimumSize: const Size(120, 42),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lepas Pesanan'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isActionLoading = true);
    try {
      await _chatService.cancelNegotiationToPortal(
        jobId: widget.chatContext.jobId,
        reason: 'Pengguna memilih melepas negosiasi ke portal',
      );
      widget.onRefreshNeeded();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pesanan telah dikembalikan ke bursa terbuka.'),
            backgroundColor: AppColors.primaryNavy,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal melepas pesanan: $e'),
            backgroundColor: AppColors.dangerCrimson,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.chatContext.status;
    final isTukang = widget.chatContext.isTukang;

    if (status == 'NEGOTIATING') {
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.warningLight,
          border: Border(
            bottom: BorderSide(color: AppColors.borderLight),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.schedule_rounded,
              color: AppColors.warningAmber,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'Batas Waktu Diskusi: ',
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        _formatTimer(_remainingSeconds),
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.dangerCrimson,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Otomatis dilepas ke bursa jika tidak ada balasan 30 menit.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _isActionLoading ? null : _handleCancelNegotiation,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.dangerCrimson,
                side: BorderSide(
                  color: AppColors.dangerCrimson.withValues(alpha: 0.4),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                minimumSize: const Size(0, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Ganti Mitra',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    if (status == 'NOTA_APPROVED') {
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.userBadgeBg,
          border: Border(
            bottom: BorderSide(color: AppColors.borderLight),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(
                  Icons.directions_run_rounded,
                  color: AppColors.trustCobalt,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Batas Waktu Berangkat: ',
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            _formatTimer(_remainingSeconds),
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.dangerCrimson,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        isTukang
                            ? 'Segera tekan tombol berangkat sebelum batas waktu habis.'
                            : 'Menunggu mitra tukang berangkat menuju lokasi Anda.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isTukang) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isActionLoading ? null : _handleDepartJob,
                  icon: const Icon(Icons.navigation_outlined, size: 18),
                  label: const Text('Berangkat ke Lokasi Sekarang'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.trustCobalt,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(42),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (status == 'ON_THE_WAY' || status == 'ARRIVED' || status == 'WORKING') {
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.successLight,
          border: Border(
            bottom: BorderSide(color: AppColors.borderLight),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.successGreen,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                status == 'ON_THE_WAY'
                    ? 'Mitra tukang sedang menuju lokasi Anda.'
                    : status == 'ARRIVED'
                        ? 'Mitra tukang telah tiba di lokasi.'
                        : 'Pekerjaan sedang berlangsung.',
                style: AppTypography.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.successGreen,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
