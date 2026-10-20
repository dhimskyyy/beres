import 'package:flutter/material.dart';
import '../../services/cancellation_service.dart';
import '../../theme/app_colors.dart';

/// Kartu Keputusan Pembatalan (CANCEL_PENDING)
/// Ditampilkan saat ada pengajuan pembatalan aktif yang menunggu tanggapan (BR-53, BR-55, BR-56b)
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
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade300, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: AppColors.error, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isRequester
                      ? 'Menunggu Tanggapan Pembatalan'
                      : 'Permintaan Pembatalan Pekerjaan',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9F1239),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kategori: $reasonCategory',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13),
                ),
                if (reasonText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Alasan: "$reasonText"',
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ],
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),

          // Jika saya adalah pemohon (menunggu pihak lain)
          if (isRequester)
            const Text(
              'Pengajuan pembatalan telah dikirim. Menunggu konfirmasi dari pihak lawan (Maks 30 menit).',
              style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.black54),
              textAlign: TextAlign.center,
            )
          // Jika User yang menerima pembatalan dari Tukang (BR-55)
          else if (!widget.isTukang && requesterRole == 'TUKANG') ...[
            const Text(
              'Aturan: Jika disetujui, pekerjaan kembali ke Bursa & Tukang terkena 1 Strike. Jika ditolak, Tukang wajib melanjutkan pekerjaan (BR-55).',
              style:
                  TextStyle(fontSize: 11, color: Colors.black87, height: 1.3),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    onPressed:
                        _isActing ? null : () => _handleUserDecision(false),
                    child: const Text('Tolak Batal'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                    onPressed:
                        _isActing ? null : () => _handleUserDecision(true),
                    child: _isActing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Setujui Batal'),
                  ),
                ),
              ],
            ),
          ]
          // Jika Tukang yang menerima pembatalan 3 jam OTW dari User (BR-56b)
          else if (widget.isTukang && requesterRole == 'USER') ...[
            const Text(
              'Aturan BR-56b: Pelanggan mengajukan batal karena perjalanan >= 3 jam. Harap tanggapi dalam 30 menit (tanpa respons = auto-cancel & +1 Strike).',
              style:
                  TextStyle(fontSize: 11, color: Colors.black87, height: 1.3),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isActing ? null : () => _handleTukangDecision(false),
                    child: const Text('Tolak (Lanjut)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                    ),
                    onPressed:
                        _isActing ? null : () => _handleTukangDecision(true),
                    child: _isActing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
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
