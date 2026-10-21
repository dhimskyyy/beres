import 'package:flutter/material.dart';
import '../../services/cancellation_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Alur Pengajuan Pembatalan oleh Mitra Tukang
class TukangCancelFlowDialog extends StatefulWidget {
  final String jobId;
  final CancellationService cancellationService;
  final double? currentLatitude;
  final double? currentLongitude;
  final VoidCallback onSuccess;

  const TukangCancelFlowDialog({
    super.key,
    required this.jobId,
    required this.cancellationService,
    this.currentLatitude,
    this.currentLongitude,
    required this.onSuccess,
  });

  static Future<void> show(
    BuildContext context, {
    required String jobId,
    required CancellationService cancellationService,
    double? currentLatitude,
    double? currentLongitude,
    required VoidCallback onSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TukangCancelFlowDialog(
        jobId: jobId,
        cancellationService: cancellationService,
        currentLatitude: currentLatitude,
        currentLongitude: currentLongitude,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<TukangCancelFlowDialog> createState() => _TukangCancelFlowDialogState();
}

class _TukangCancelFlowDialogState extends State<TukangCancelFlowDialog> {
  int _step = 1;
  double _sliderValue = 0.0;
  String? _draftId;

  final _reasonTextController = TextEditingController();
  final _adminNotesController = TextEditingController();
  String _selectedCategory = 'Kendaraan Mogok / Ban Bocor';
  bool _isLoading = false;
  String? _errorMessage;

  final List<String> _categories = [
    'Kendaraan Mogok / Ban Bocor',
    'Kondisi Cuaca Buruk / Banjir',
    'Alat Kerja Rusak / Hilang',
    'Keperluan Darurat Keluarga',
    'Kondisi Fisik / Sakit Mendadak',
    'Lainnya',
  ];

  @override
  void dispose() {
    _reasonTextController.dispose();
    _adminNotesController.dispose();
    super.dispose();
  }

  Future<void> _handleSlideComplete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppColors.dangerCrimson,
              size: 22,
            ),
            SizedBox(width: 8),
            Text('Konfirmasi Pembatalan', style: AppTypography.headingSmall),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin mengajukan pembatalan tugas ini?\n\nJika disetujui pelanggan, pesanan akan dikembalikan ke bursa terbuka dan tercatat sebagai 1 poin pelanggaran operasional.',
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
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      if (mounted) setState(() => _sliderValue = 0.0);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final res = await widget.cancellationService
          .createTukangCancelDraft(widget.jobId);
      if (mounted) {
        setState(() {
          _draftId = res['draft_id'] as String?;
          _step = 2;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
          _sliderValue = 0.0;
        });
      }
    }
  }

  Future<void> _handleAbortDraft() async {
    if (_draftId != null) {
      try {
        await widget.cancellationService.abortTukangCancelDraft(_draftId!);
      } catch (_) {}
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _handleSubmitRequest() async {
    final text = _reasonTextController.text.trim();
    if (text.length < 10) {
      setState(() => _errorMessage = 'Jelaskan alasan minimal 10 karakter.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.cancellationService.submitTukangCancelRequest(
        cancelRequestId: _draftId!,
        reasonCategory: _selectedCategory,
        reasonText: text,
        adminNotes: _adminNotesController.text.trim().isNotEmpty
            ? _adminNotesController.text.trim()
            : null,
        latitude: widget.currentLatitude,
        longitude: widget.currentLongitude,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.primaryNavy,
            content: Text(
              'Permintaan pembatalan telah dikirim kepada pelanggan.',
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
      child: _step == 1 ? _buildStep1Slide() : _buildStep2Form(),
    );
  }

  Widget _buildStep1Slide() {
    return Column(
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
              Icons.cancel_outlined,
              color: AppColors.dangerCrimson,
              size: 22,
            ),
            SizedBox(width: 8),
            Text(
              'Ajukan Pembatalan Tugas',
              style: AppTypography.headingSmall,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.dangerLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.dangerCrimson.withValues(alpha: 0.25),
            ),
          ),
          child: Text(
            '• Pembatalan memerlukan persetujuan dari pelanggan.\n'
            '• Jika disetujui, pekerjaan dikembalikan ke bursa terbuka dan akun Anda menerima 1 poin pelanggaran.\n'
            '• Akumulasi lebih dari 3 pelanggaran dalam sebulan menyebabkan penangguhan otomatis selama 48 jam.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: const TextStyle(
              color: AppColors.dangerCrimson,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'Geser penuh ke kanan untuk melanjutkan',
          style: AppTypography.bodySmall.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: AppColors.dangerLight,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: AppColors.dangerCrimson.withValues(alpha: 0.3),
            ),
          ),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: AppColors.dangerCrimson,
              inactiveTrackColor: AppColors.dangerCrimson.withValues(
                alpha: 0.15,
              ),
              thumbColor: AppColors.dangerCrimson,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 18),
            ),
            child: Slider(
              value: _sliderValue,
              onChanged: _isLoading
                  ? null
                  : (v) {
                      setState(() => _sliderValue = v);
                      if (v >= 0.95) {
                        _handleSlideComplete();
                      }
                    },
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Kembali & Tetap Kerjakan'),
        ),
      ],
    );
  }

  Widget _buildStep2Form() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Formulir Alasan Pembatalan',
              style: AppTypography.headingSmall,
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: _isLoading ? null : _handleAbortDraft,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: const Text(
            'Pesanan belum dibatalkan hingga Anda menekan tombol Kirim Pengajuan di bawah.',
            style: AppTypography.bodySmall,
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
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Alasan Lengkap untuk Pelanggan',
            hintText: 'Jelaskan kendala yang Anda alami...',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _adminNotesController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Catatan Tambahan untuk Tim Operasional (Opsional)',
            hintText: 'Keterangan pendukung (hanya dilihat oleh Admin)...',
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : _handleAbortDraft,
                child: const Text('Batal'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dangerCrimson,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isLoading ? null : _handleSubmitRequest,
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Kirim Pengajuan'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
