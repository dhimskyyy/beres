import 'package:flutter/material.dart';
import '../../services/cancellation_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Kartu Keputusan Pembatalan
class CancelDecisionCard extends StatefulWidget {
  final String jobId;
  final bool isTukang;
  final CancellationService cancellationService;
  final VoidCallback onDecisionResolved;

  const CancelDecisionCard({
    super.key,
    required this.jobId,
    required this.isTukang,
    required this.cancellationService,
    required this.onDecisionResolved,
  });

  @override
  State<CancelDecisionCard> createState() => _CancelDecisionCardState();
}

class _CancelDecisionCardState extends State<CancelDecisionCard> {
  Map<String, dynamic>? _cancelRequest;
  bool _isLoading = true;
  bool _isActing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCancelRequest();
  }

  Future<void> _loadCancelRequest() async {
    try {
      final req =
          await widget.cancellationService.getActiveCancelRequest(widget.jobId);
      if (mounted) {
        setState(() {
          _cancelRequest = req;
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

  Future<void> _handleUserDecision(bool approve) async {
    setState(() {
      _isActing = true;
      _errorMessage = null;
    });

    try {
      await widget.cancellationService.userRespondToTukangCancel(
        jobId: widget.jobId,
        approved: approve,
      );
      if (mounted) {
        widget.onDecisionResolved();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isActing = false;
        });
      }
    }
  }

  Future<void> _handleTukangDecision(bool approve) async {
    setState(() {
      _isActing = true;
      _errorMessage = null;
    });

    try {
      await widget.cancellationService.tukangRespondToUserCancel(
        jobId: widget.jobId,
        approved: approve,
      );
      if (mounted) {
        widget.onDecisionResolved();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isActing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_cancelRequest == null) {
      return const SizedBox.shrink();
    }

    final requesterRole = _cancelRequest!['requester_role'] as String? ?? '';
    final reasonCategory = _cancelRequest!['reason_category'] as String? ??
        'Alasan tidak spesifik';
    final reasonText = _cancelRequest!['reason_text'] as String? ?? '';
    final isRequester = (widget.isTukang && requesterRole == 'TUKANG') ||
        (!widget.isTukang && requesterRole == 'USER');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.dangerCrimson.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.dangerCrimson,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isRequester
                      ? 'Menunggu Konfirmasi Pembatalan'
                      : 'Permintaan Pembatalan Pesanan',
                  style: AppTypography.headingSmall.copyWith(
                    fontSize: 13.5,
                    color: AppColors.dangerCrimson,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reasonCategory,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (reasonText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    reasonText,
                    style: AppTypography.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(
                color: AppColors.dangerCrimson,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (isRequester)
            const Text(
              'Pengajuan pembatalan telah dikirim. Menunggu tanggapan dalam waktu maksimal 30 menit.',
              style: AppTypography.bodySmall,
              textAlign: TextAlign.center,
            )
          else if (!widget.isTukang && requesterRole == 'TUKANG') ...[
            const Text(
              'Jika disetujui, pesanan akan dibuka kembali di bursa agar Anda dapat memilih mitra lain.',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.dangerCrimson,
                      side: BorderSide(
                        color: AppColors.dangerCrimson.withValues(alpha: 0.4),
                      ),
                      minimumSize: const Size.fromHeight(42),
                    ),
                    onPressed:
                        _isActing ? null : () => _handleUserDecision(false),
                    child: const Text('Tolak'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(42),
                    ),
                    onPressed:
                        _isActing ? null : () => _handleUserDecision(true),
                    child: _isActing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Setujui Batal'),
                  ),
                ),
              ],
            ),
          ] else if (widget.isTukang && requesterRole == 'USER') ...[
            const Text(
              'Pelanggan mengajukan pembatalan karena waktu perjalanan melebihi 3 jam. Harap tanggapi dalam 30 menit.',
              style: AppTypography.bodySmall,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                    ),
                    onPressed:
                        _isActing ? null : () => _handleTukangDecision(false),
                    child: const Text('Lanjut Bertugas'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.dangerCrimson,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(42),
                    ),
                    onPressed:
                        _isActing ? null : () => _handleTukangDecision(true),
                    child: _isActing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Setujui Batal'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
