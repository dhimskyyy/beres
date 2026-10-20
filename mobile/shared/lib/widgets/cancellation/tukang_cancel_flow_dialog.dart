import 'package:flutter/material.dart';
import '../../services/cancellation_service.dart';
import '../../theme/app_colors.dart';

/// Alur Pembatalan oleh Tukang (BR-50, BR-51, BR-53, BR-55)
/// Geser tombol -> Dialog Ya/Tidak -> Form DRAFT -> Kirim (CANCEL_PENDING)
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
  int _step = 1; // 1: Slide to Cancel, 2: Form DRAFT
  double _sliderValue = 0.0;
  String? _draftId;

  // Form Fields
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
    // Dialog konfirmasi Ya / Tidak (BR-50)
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.error),
            SizedBox(width: 8),
            Text('Konfirmasi Batal'),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin membatalkan tugas ini?\n\n'
          'Sesuai aturan BR-55, jika pelanggan menyetujui, pekerjaan akan kembali dilepas ke bursa dan Anda akan menerima 1 Strike Tukang (Maks 3x/bulan, ke-4 dibekukan 2 hari).',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Lanjut Isi Form',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) {
      if (mounted) setState(() => _sliderValue = 0.0);
      return;
    }

    // Inisialisasi draft di server (BR-51: status job di DB tidak berubah)
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
      setState(() => _errorMessage = 'Alasan detail minimal 10 karakter.');
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
            backgroundColor: AppColors.primary,
            content: Text(
              'Permintaan pembatalan telah dikirim ke pelanggan (Status: CANCEL_PENDING).',
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
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            Icon(Icons.cancel_outlined, color: AppColors.error),
            SizedBox(width: 8),
            Text(
              'Batalkan Tugas Pekerjaan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0x1AE11D48),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0x33E11D48)),
          ),
          child: const Text(
            'Aturan Pembatalan Tukang (BR-50 & BR-55):\n'
            '• Pembatalan memerlukan persetujuan pelanggan.\n'
            '• Jika disetujui pelanggan, pekerjaan dilepas kembali ke portal dan Anda terkena +1 Strike Tukang.\n'
            '• Maksimal 3 Strike per bulan kalender. Strike ke-4 otomatis suspend 2 hari.',
            style:
                TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF9F1239)),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _errorMessage!,
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ],
        const SizedBox(height: 24),
        const Text(
          'Geser ke kanan untuk memulai pengajuan batal (BR-50):',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(27),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              activeTrackColor: AppColors.error,
              inactiveTrackColor: Colors.red.shade100,
              thumbColor: AppColors.error,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 20),
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
          child: const Text('Batal / Tetap Kerjakan'),
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
              'Form Alasan Pembatalan (BR-53)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _isLoading ? null : _handleAbortDraft,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade300),
          ),
          child: const Text(
            'Status saat ini: DRAFT (tampilan di aplikasi pelanggan belum berubah sampai Anda menekan Kirim — BR-51).',
            style: TextStyle(fontSize: 11, color: Colors.brown),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ],
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: _selectedCategory,
          decoration: const InputDecoration(
            labelText: 'Kategori Alasan Batal',
            border: OutlineInputBorder(),
          ),
          items: _categories
              .map((c) => DropdownMenuItem(
                  value: c,
                  child: Text(c, style: const TextStyle(fontSize: 13))))
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
            labelText: 'Alasan Detail (Diterima Pelanggan & Admin)',
            hintText: 'Jelaskan kronologi kendala Anda (min 10 karakter)...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _adminNotesController,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Catatan Khusus Admin (Opsional)',
            hintText: 'Hanya dibaca oleh Admin untuk audit investigasi...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isLoading ? null : _handleAbortDraft,
                child: const Text('Kembali (Batal)'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isLoading ? null : _handleSubmitRequest,
                child: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Kirim Batal'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
