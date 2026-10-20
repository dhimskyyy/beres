import 'package:flutter/material.dart';
import '../../services/cancellation_service.dart';
import '../../theme/app_colors.dart';

/// Dialog Pembatalan oleh Pelanggan saat ON_THE_WAY >= 3 Jam (FR-018, BR-56b)
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
  String _actionAfterCancel = 'OPEN'; // 'OPEN' atau 'CANCELLED'
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
      setState(() => _errorMessage = 'Alasan pembatalan wajib diisi.');
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
            backgroundColor: AppColors.primary,
            content: Text(
              'Permintaan pembatalan dikirim ke tukang. Menunggu konfirmasi tukang (Maks 30 menit).',
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
      child: Column(
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
              Icon(Icons.hourglass_bottom_rounded, color: AppColors.warning),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Batalkan Pekerjaan (>= 3 Jam OTW)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: const Text(
              'Sesuai aturan BR-56b:\n'
              'Karena tukang sudah berstatus ON_THE_WAY selama >= 3 jam dan belum tiba di lokasi, Anda berhak mengajukan pembatalan.\n'
              'Tukang diberi waktu 30 menit untuk merespons. Jika tidak merespons, pembatalan otomatis disetujui (Auto-Cancel) & Tukang menerima 1 Strike.',
              style: TextStyle(fontSize: 12, color: Colors.brown, height: 1.4),
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
              labelText: 'Kategori Alasan',
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
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Keterangan Tambahan',
              hintText: 'Tuliskan catatan untuk tukang...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Setelah pembatalan selesai, apa yang ingin Anda lakukan?',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          RadioListTile<String>(
            dense: true,
            title: const Text('Buka kembali ke Bursa untuk tukang lain (OPEN)',
                style: TextStyle(fontSize: 13)),
            value: 'OPEN',
            groupValue: _actionAfterCancel,
            onChanged: (v) => setState(() => _actionAfterCancel = v!),
          ),
          RadioListTile<String>(
            dense: true,
            title: const Text('Tutup dan batalkan pekerjaan sepenuhnya (CANCELLED)',
                style: TextStyle(fontSize: 13)),
            value: 'CANCELLED',
            groupValue: _actionAfterCancel,
            onChanged: (v) => setState(() => _actionAfterCancel = v!),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isLoading ? null : _handleSubmit,
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
      ),
    );
  }
}
