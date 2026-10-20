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
            content: Text('Status diubah ke ON_THE_WAY. Live GPS aktif.'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengubah status: $e'),
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
        title: const Text('Lepas ke Job Portal?'),
        content: const Text(
          'Pekerjaan akan dikembalikan ke status OPEN di portal agar dapat dilamar tukang lain. '
          'Sesuai aturan BR-70, TIDAK ADA STRIKE bagi pihak mana pun.',
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
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Lepas ke Portal (BR-70)'),
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
            content: Text(
                'Pekerjaan berhasil dilepas kembali ke portal tanpa sanksi strike.'),
            backgroundColor: AppColors.trustCobalt,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal melepas pekerjaan: $e'),
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
        color: AppColors.warningAmber.withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined,
                color: AppColors.warningAmber, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        'Timer Negosiasi (BR-70): ',
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.brown.shade800,
                        ),
                      ),
                      Text(
                        _formatTimer(_remainingSeconds),
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.dangerCrimson,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Jika tidak aktif > 30 mnt, job kembali ke portal tanpa Strike.',
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 11,
                      color: Colors.brown.shade700,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: _isActionLoading ? null : _handleCancelNegotiation,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.dangerCrimson,
                side: const BorderSide(color: AppColors.dangerCrimson),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Batal', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    if (status == 'NOTA_APPROVED') {
      return Container(
        color: AppColors.trustCobalt.withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.departure_board_outlined,
                    color: AppColors.trustCobalt, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Waktu Berangkat (BR-31): ',
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.trustCobalt,
                            ),
                          ),
                          Text(
                            _formatTimer(_remainingSeconds),
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.dangerCrimson,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isTukang
                            ? 'Wajib klik Berangkat dalam 30 mnt (+1 Strike jika lewat)'
                            : 'Menunggu mitra tukang menekan Berangkat ke Lokasi...',
                        style: AppTypography.bodySmall.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isTukang) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isActionLoading ? null : _handleDepartJob,
                  icon: const Icon(Icons.navigation_outlined, size: 18),
                  label: const Text('Berangkat ke Lokasi Sekarang (BR-31)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.trustCobalt,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
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
        color: AppColors.successGreen.withValues(alpha: 0.1),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline,
                color: AppColors.successGreen, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                status == 'ON_THE_WAY'
                    ? 'Tukang sedang dalam perjalanan ke lokasi.'
                    : status == 'ARRIVED'
                        ? 'Tukang telah sampai di lokasi pekerjaan.'
                        : 'Pekerjaan sedang berlangsung (Dilarang membatalkan BR-65).',
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
