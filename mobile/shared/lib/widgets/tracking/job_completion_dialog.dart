import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/nota.dart';
import '../../services/device_permission_service.dart';
import '../../services/tracking_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Dialog Form Penyelesaian Pekerjaan oleh Mitra Tukang
class JobCompletionDialog extends StatefulWidget {
  final String jobId;
  final TrackingService trackingService;
  final VoidCallback onCompleted;

  const JobCompletionDialog({
    super.key,
    required this.jobId,
    required this.trackingService,
    required this.onCompleted,
  });

  @override
  State<JobCompletionDialog> createState() => _JobCompletionDialogState();
}

class _JobCompletionDialogState extends State<JobCompletionDialog> {
  final _formKey = GlobalKey<FormState>();
  PaymentMethod _selectedPaymentMethod = PaymentMethod.cash;
  bool _userPaidConfirmed = false;
  final List<String> _workPhotoUrls = [];
  String? _paymentProofPhotoUrl;
  final TextEditingController _noteController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickWorkPhoto() async {
    if (_workPhotoUrls.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maksimal 5 foto hasil kerja')),
      );
      return;
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.safetyOrange,
                ),
                title: const Text(
                  'Ambil Foto dengan Kamera',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.safetyOrange,
                ),
                title: const Text(
                  'Pilih dari Galeri',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final permissionService = DevicePermissionService();
    final file = source == ImageSource.camera
        ? await permissionService.pickImageFromCamera()
        : await permissionService.pickImageFromGallery();

    if (file != null && mounted) {
      setState(() {
        _workPhotoUrls.add(
          'https://storage.beres.id/jobs-media/work_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      });
    }
  }

  Future<void> _pickProofPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_outlined,
                  color: AppColors.safetyOrange,
                ),
                title: const Text(
                  'Ambil Foto Kamera',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.safetyOrange,
                ),
                title: const Text(
                  'Pilih dari Galeri / Screenshot',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final permissionService = DevicePermissionService();
    final file = source == ImageSource.camera
        ? await permissionService.pickImageFromCamera()
        : await permissionService.pickImageFromGallery();

    if (file != null && mounted) {
      setState(() {
        _paymentProofPhotoUrl =
            'https://storage.beres.id/jobs-media/proof_${DateTime.now().millisecondsSinceEpoch}.jpg';
      });
    }
  }

  Future<void> _submit() async {
    if (_workPhotoUrls.isEmpty) {
      setState(() {
        _errorMessage = 'Unggah minimal 1 foto hasil pekerjaan.';
      });
      return;
    }

    if (!_userPaidConfirmed) {
      setState(() {
        _errorMessage =
            'Centang konfirmasi bahwa pelanggan telah melakukan pembayaran.';
      });
      return;
    }

    if (_selectedPaymentMethod != PaymentMethod.cash &&
        (_paymentProofPhotoUrl == null || _paymentProofPhotoUrl!.isEmpty)) {
      setState(() {
        _errorMessage =
            'Lampirkan bukti pembayaran untuk metode transfer atau e-wallet.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final res = await widget.trackingService.completeJob(
        jobId: widget.jobId,
        actualPaymentMethod: _selectedPaymentMethod,
        userPaidConfirmed: _userPaidConfirmed,
        workPhotos: _workPhotoUrls,
        paymentProofPhoto: _paymentProofPhotoUrl,
        completionNote: _noteController.text.trim().isNotEmpty
            ? _noteController.text.trim()
            : null,
      );

      if (mounted) {
        if (res['success'] == true) {
          Navigator.of(context).pop();
          widget.onCompleted();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.successGreen,
              content: Text('Pekerjaan berhasil diselesaikan.'),
            ),
          );
        } else {
          setState(() {
            _errorMessage =
                res['error']?.toString() ?? 'Gagal menyelesaikan pekerjaan';
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
    final isNonCash = _selectedPaymentMethod != PaymentMethod.cash;

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
                        Icons.check_circle_outline_rounded,
                        color: AppColors.successGreen,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Selesaikan Pekerjaan',
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
                  const Divider(height: 24),
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Foto Hasil Pekerjaan',
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
                        onPressed: _pickWorkPhoto,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_workPhotoUrls.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: const Center(
                        child: Text(
                          'Unggah minimal 1 foto hasil pekerjaan yang telah selesai.',
                          style: AppTypography.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _workPhotoUrls.map((url) {
                        return Stack(
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                image: DecorationImage(
                                  image: NetworkImage(url),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _workPhotoUrls.remove(url);
                                  });
                                },
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: AppColors.dangerCrimson,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(3),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    size: 13,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Metode Pembayaran Aktual',
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<PaymentMethod>(
                    initialValue: _selectedPaymentMethod,
                    items: const [
                      DropdownMenuItem(
                        value: PaymentMethod.cash,
                        child: Text('Tunai (Cash Langsung)'),
                      ),
                      DropdownMenuItem(
                        value: PaymentMethod.bankTransfer,
                        child: Text('Transfer Bank'),
                      ),
                      DropdownMenuItem(
                        value: PaymentMethod.eWallet,
                        child: Text('E-Wallet (QRIS / OVO / GoPay / DANA)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedPaymentMethod = val;
                        });
                      }
                    },
                  ),
                  if (isNonCash) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Bukti Pembayaran Non-Tunai',
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.trustCobalt,
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.upload_file_rounded, size: 16),
                          label: const Text(
                            'Unggah Bukti',
                            style: TextStyle(fontSize: 12),
                          ),
                          onPressed: _pickProofPhoto,
                        ),
                      ],
                    ),
                    if (_paymentProofPhotoUrl != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.userBadgeBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.trustCobalt.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: AppColors.trustCobalt,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Bukti pembayaran terlampir',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16),
                              onPressed: () {
                                setState(() {
                                  _paymentProofPhotoUrl = null;
                                });
                              },
                            ),
                          ],
                        ),
                      )
                    else
                      const Text(
                        'Lampirkan tangkapan layar bukti transfer atau pembayaran e-wallet.',
                        style: AppTypography.bodySmall,
                      ),
                  ],
                  const SizedBox(height: 16),
                  Material(
                    color: AppColors.backgroundLight,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: AppColors.borderLight),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: CheckboxListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      value: _userPaidConfirmed,
                      title: const Text(
                        'Pelanggan telah membayar lunas sesuai Nota Sah',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _userPaidConfirmed = val ?? false;
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Catatan Penyelesaian (Opsional)',
                      hintText:
                          'Contoh: Perbaikan telah diuji coba dan berjalan normal.',
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.successGreen,
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
                        : const Text('Konfirmasi Selesai'),
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
