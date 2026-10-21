import 'package:flutter/material.dart';
import '../../services/cancellation_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Dialog Pembatalan oleh Pelanggan saat perjalanan melebihi 3 Jam
class UserCancelOtwDialog extends StatefulWidget {
  final String jobId;
  final CancellationService cancellationService;
  final VoidCallback onSuccess;

  const UserCancelOtwDialog({
    super.key,
    required this.jobId,
    required this.cancellationService,
    required this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required String jobId,
    required CancellationService cancellationService,
    required VoidCallback onSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UserCancelOtwDialog(
        jobId: jobId,
        cancellationService: cancellationService,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<UserCancelOtwDialog> createState() => _UserCancelOtwDialogState();
}

class _UserCancelOtwDialogState extends State<UserCancelOtwDialog> {
  final _reasonTextController = TextEditingController();
  String _selectedCategory = 'Tukang Belum Tiba Setelah >= 3 Jam';
  String _actionAfterCancel = 'OPEN';
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _categories = [
    'Tukang Belum Tiba Setelah >= 3 Jam',
    'Tukang Tidak Dapat Dihubungi / Chat Tidak Dibalas',
    'Kebutuhan Darurat / Jadwal Berubah',
    'Lainnya',
  ];

  @override
  void dispose() {
    _reasonTextController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final text = _reasonTextController.text.trim();
    if (text.length < 5) {
      setState(() => _errorMessage = 'Tuliskan alasan pembatalan.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.cancellationService.userRequestCancelOtw3h(
        jobId: widget.jobId,
        reasonCategory: _selectedCategory,
        reasonText: text,
        actionAfterCancel: _actionAfterCancel,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.primaryNavy,
            content: Text(
              'Permintaan pembatalan telah dikirim kepada mitra tukang.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 16,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Row(
            children: [
              Icon(
                Icons.hourglass_bottom_rounded,
                color: AppColors.warningAmber,
                size: 22,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ajukan Pembatalan Pesanan',
                  style: AppTypography.headingSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warningLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.warningAmber.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              'Karena mitra tukang belum tiba di lokasi setelah lebih dari 3 jam perjalanan, Anda dapat mengajukan pembatalan. Jika mitra tidak merespons dalam 30 menit, pembatalan disetujui secara otomatis.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary,
              ),
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
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _selectedCategory,
            decoration: const InputDecoration(
              labelText: 'Kategori Alasan',
            ),
            items: _categories
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text(c, style: const TextStyle(fontSize: 13.5)),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedCategory = v);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonTextController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Keterangan Tambahan',
              hintText: 'Tuliskan catatan singkat...',
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Tindakan Setelah Pembatalan',
            style: AppTypography.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'OPEN',
                label: Text('Cari Mitra Lain', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.search_rounded, size: 16),
              ),
              ButtonSegment(
                value: 'CANCELLED',
                label: Text('Tutup Pesanan', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.close_rounded, size: 16),
              ),
            ],
            selected: {_actionAfterCancel},
            onSelectionChanged: (s) =>
                setState(() => _actionAfterCancel = s.first),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Kembali'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dangerCrimson,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isLoading ? null : _handleSubmit,
                  child: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Ajukan Batal'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
