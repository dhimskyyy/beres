import 'package:flutter/material.dart';
import '../../models/nota.dart';
import '../../services/tracking_service.dart';
import '../../theme/app_colors.dart';

/// Dialog Form Penyelesaian Tugas oleh Mitra Tukang (FR-025, BR-32)
/// Menegakkan:
/// 1. Unggah >= 1 Foto Hasil Kerja (maks 5)
/// 2. Pemilihan Metode Bayar Aktual (CASH, BANK_TRANSFER, E_WALLET)
/// 3. Wajib centang "User sudah membayar sesuai Nota Sah"
/// 4. Wajib unggah Bukti Bayar jika metode non-tunai (Transfer / E-Wallet)
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

  void _addMockWorkPhoto() {
    if (_workPhotoUrls.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maksimal 5 foto hasil kerja')),
      );
      return;
    }
    setState(() {
      _workPhotoUrls.add(
        'https://images.unsplash.com/photo-1581092160607-ee22621dd758?auto=format&fit=crop&w=600&q=80',
      );
    });
  }

  void _addMockProofPhoto() {
    setState(() {
      _paymentProofPhotoUrl =
          'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?auto=format&fit=crop&w=600&q=80';
    });
  }

  Future<void> _submit() async {
    if (_workPhotoUrls.isEmpty) {
      setState(() {
        _errorMessage = 'Wajib mengunggah minimal 1 Foto Hasil Kerja (BR-32)';
      });
      return;
    }

    if (!_userPaidConfirmed) {
      setState(() {
        _errorMessage =
            'Anda wajib mencentang konfirmasi pembayaran pelanggan (BR-32)';
      });
      return;
    }

    if (_selectedPaymentMethod != PaymentMethod.cash &&
        (_paymentProofPhotoUrl == null || _paymentProofPhotoUrl!.isEmpty)) {
      setState(() {
        _errorMessage =
            'Wajib melampirkan Screenshot Bukti Bayar untuk metode non-tunai (BR-32)';
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
              backgroundColor: AppColors.success,
              content: Text('Selamat! Pekerjaan berhasil diselesaikan.'),
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
                      const Icon(Icons.check_circle,
                          color: AppColors.success, size: 28),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Selesaikan Pekerjaan (BR-32)',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  if (_errorMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0x1AB91C1C),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.error),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ),

                  // 1. FOTO HASIL KERJA (>= 1, MAKS 5)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '1. Foto Hasil Kerja (Wajib >= 1)*',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add_a_photo, size: 18),
                        label: const Text('Tambah Foto',
                            style: TextStyle(fontSize: 12)),
                        onPressed: _addMockWorkPhoto,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (_workPhotoUrls.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Center(
                        child: Text(
                          'Belum ada foto. Klik "Tambah Foto" di atas.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
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
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image: NetworkImage(url),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _workPhotoUrls.remove(url);
                                  });
                                },
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: const Icon(Icons.close,
                                      size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 16),

                  // 2. METODE PEMBAYARAN AKTUAL
                  const Text(
                    '2. Metode Bayar Aktual*',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<PaymentMethod>(
                    initialValue: _selectedPaymentMethod,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
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

                  // 3. UPLOAD BUKTI BAYAR JIKA NON-TUNAI
                  if (isNonCash) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Bukti Transfer / Screenshot*',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.upload_file, size: 16),
                          label: const Text('Unggah Bukti',
                              style: TextStyle(fontSize: 12)),
                          onPressed: _addMockProofPhoto,
                        ),
                      ],
                    ),
                    if (_paymentProofPhotoUrl != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0x142563EB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle,
                                size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text('Screenshot bukti bayar terlampir',
                                  style: TextStyle(fontSize: 12)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
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
                        'Wajib melampirkan foto screenshot transfer bank / mutasi e-wallet.',
                        style: TextStyle(fontSize: 11, color: Colors.orange),
                      ),
                  ],

                  const SizedBox(height: 16),

                  // 4. CHECKBOX KONFIRMASI PEMBAYARAN
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade400),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _userPaidConfirmed,
                      title: const Text(
                        'Saya menyatakan Pelanggan telah membayar lunas sesuai Nota Sah (BR-32)*',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87),
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

                  // 5. CATATAN PENYELESAIAN (OPSIONAL)
                  TextFormField(
                    controller: _noteController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Catatan Penyelesaian (Opsional)',
                      hintText:
                          'Contoh: Pipa bocor telah ditambal dan dites 15 menit lancar.',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),

                  const SizedBox(height: 20),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
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
                            'Selesaikan Tugas & Terima Pembayaran',
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
