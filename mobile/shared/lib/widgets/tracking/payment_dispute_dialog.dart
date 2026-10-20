import 'package:flutter/material.dart';
import '../../services/tracking_service.dart';
import '../../theme/app_colors.dart';

/// Dialog Pelaporan Masalah Pembayaran oleh Tukang (BR-67, FR-025)
/// Untuk situasi di mana User menolak membayar atau membayar kurang saat status WORKING.
/// Melepas ikatan job aktif tukang sementara agar dapat menerima order lain.
class PaymentDisputeDialog extends StatefulWidget {
  final String jobId;
  final TrackingService trackingService;
  final VoidCallback onReportSubmitted;

  const PaymentDisputeDialog({
    super.key,
    required this.jobId,
    required this.trackingService,
    required this.onReportSubmitted,
  });

  @override
  State<PaymentDisputeDialog> createState() => _PaymentDisputeDialogState();
}

class _PaymentDisputeDialogState extends State<PaymentDisputeDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descController = TextEditingController();
  final List<String> _workPhotos = [];
  final List<String> _evidencePhotos = [];

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  void _addMockWorkPhoto() {
    setState(() {
      _workPhotos.add(
        'https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=600&q=80',
      );
    });
  }

  void _addMockEvidencePhoto() {
    setState(() {
      _evidencePhotos.add(
        'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?auto=format&fit=crop&w=600&q=80',
      );
    });
  }

  Future<void> _submit() async {
    final desc = _descController.text.trim();
    if (desc.length < 10) {
      setState(() {
        _errorMessage = 'Kronologi kendala pembayaran minimal 10 karakter.';
      });
      return;
    }

    if (_workPhotos.isEmpty) {
      setState(() {
        _errorMessage =
            'Wajib melampirkan minimal 1 Foto Bukti Hasil Kerja bahwa pekerjaan telah Anda selesaikan.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final res = await widget.trackingService.reportPaymentDispute(
        jobId: widget.jobId,
        description: desc,
        workPhotos: _workPhotos,
        evidencePhotos: _evidencePhotos,
      );

      if (mounted) {
        if (res['success'] == true) {
          Navigator.of(context).pop();
          widget.onReportSubmitted();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.primary,
              content: Text(
                'Laporan Prioritas telah dikirim ke Tim Admin. Ikatan job Anda telah dilepas sementara (BR-67).',
              ),
            ),
          );
        } else {
          setState(() {
            _errorMessage =
                res['error']?.toString() ?? 'Gagal mengirim laporan';
            _isSubmitting = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: AppColors.error, size: 28),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Laporkan Masalah Pembayaran (BR-67)',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Informasi Aturan BR-67
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: const Text(
                      'Perhatian (BR-67): Gunakan fitur ini jika Pelanggan menolak membayar atau membayar kurang dari Nota Sah. '
                      'Laporan ini akan langsung masuk ke Antrean Investigasi Prioritas Admin. '
                      'Ikatan job Anda akan dilepas sementara agar Anda bisa mengambil pekerjaan lain. '
                      'Jika terbukti wanprestasi, akun Pelanggan akan langsung di-suspend permanen.',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFF991B1B), height: 1.4),
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0x1AB91C1C),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.error),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: AppColors.error, fontSize: 12),
                      ),
                    ),

                  // 1. KRONOLOGI KENDALA
                  const Text(
                    'Kronologi Kejadian (Wajib >= 10 karakter)*',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _descController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText:
                          'Jelaskan alasan user menolak bayar, respon user, dll...',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. FOTO BUKTI PEKERJAAN TELAH SELESAI
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Bukti Hasil Kerja Selesai (Wajib >= 1)*',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add_a_photo, size: 16),
                        label:
                            const Text('Foto', style: TextStyle(fontSize: 12)),
                        onPressed: _addMockWorkPhoto,
                      ),
                    ],
                  ),
                  if (_workPhotos.isEmpty)
                    const Text(
                      'Wajib melampirkan foto fisik hasil kerja yang sudah Anda selesaikan.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      children: _workPhotos.map((url) {
                        return Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: NetworkImage(url),
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 16),

                  // 3. FOTO BUKTI PENDUKUNG (OPSIONAL)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Bukti Pendukung Tambahan (Opsional)',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.attachment, size: 16),
                        label: const Text('Lampirkan',
                            style: TextStyle(fontSize: 12)),
                        onPressed: _addMockEvidencePhoto,
                      ),
                    ],
                  ),
                  if (_evidencePhotos.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: _evidencePhotos.map((url) {
                        return Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(
                              image: NetworkImage(url),
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 20),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Kirim Laporan Prioritas ke Admin',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
