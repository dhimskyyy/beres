import 'package:flutter/material.dart';
import '../../services/tracking_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Dialog Pelaporan Kendala Pembayaran oleh Mitra Tukang
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
        _errorMessage = 'Jelaskan kronologi kendala minimal 10 karakter.';
      });
      return;
    }

    if (_workPhotos.isEmpty) {
      setState(() {
        _errorMessage =
            'Lampirkan minimal 1 foto bukti bahwa pekerjaan telah diselesaikan.';
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
              backgroundColor: AppColors.primaryNavy,
              content: Text(
                'Laporan telah dikirim ke tim operasional. Anda kini dapat mengambil pekerjaan lain.',
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
      backgroundColor: AppColors.surfaceWhite,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.dangerCrimson,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Laporkan Kendala Pembayaran',
                          style: AppTypography.headingSmall,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const Divider(height: 22),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.dangerCrimson.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      'Gunakan formulir ini jika pelanggan menolak membayar atau membayar kurang dari Nota Sah. Laporan akan ditinjau langsung oleh tim operasional dan ikatan pekerjaan Anda dilepas sementara.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.dangerCrimson,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  Text(
                    'Kronologi Kejadian',
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _descController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText:
                          'Jelaskan kendala pembayaran yang terjadi di lapangan...',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Foto Bukti Pekerjaan Selesai',
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(
                          Icons.add_a_photo_outlined,
                          size: 16,
                        ),
                        label: const Text(
                          'Tambah Foto',
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed: _addMockWorkPhoto,
                      ),
                    ],
                  ),
                  if (_workPhotos.isEmpty)
                    const Text(
                      'Lampirkan minimal 1 foto hasil pekerjaan yang telah Anda selesaikan.',
                      style: AppTypography.bodySmall,
                    )
                  else
                    Wrap(
                      spacing: 8,
                      children: _workPhotos.map((url) {
                        return Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            image: DecorationImage(
                              image: NetworkImage(url),
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Bukti Tambahan (Opsional)',
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.attachment_rounded, size: 16),
                        label: const Text(
                          'Lampirkan',
                          style: TextStyle(fontSize: 12),
                        ),
                        onPressed: _addMockEvidencePhoto,
                      ),
                    ],
                  ),
                  if (_evidencePhotos.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: _evidencePhotos.map((url) {
                        return Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
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
                      backgroundColor: AppColors.dangerCrimson,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Kirim Laporan'),
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
