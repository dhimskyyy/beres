import 'package:flutter/material.dart';
import '../../models/nota.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/formatters.dart';
import '../faq_rules_screen.dart';

class CreateNotaDialog extends StatefulWidget {
  final String jobId;
  final bool isRevision;
  final int? currentApprovedTotal;
  final Future<void> Function({
    required List<NotaItem> items,
    required int totalAmount,
    required PaymentMethod paymentMethod,
    String? note,
  }) onSubmit;

  const CreateNotaDialog({
    super.key,
    required this.jobId,
    required this.isRevision,
    this.currentApprovedTotal,
    required this.onSubmit,
  });

  @override
  State<CreateNotaDialog> createState() => _CreateNotaDialogState();
}

class _ItemEntry {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController qtyController = TextEditingController(text: '1');
  final TextEditingController priceController = TextEditingController();

  int get qty => int.tryParse(qtyController.text) ?? 1;
  int get unitPrice =>
      int.tryParse(priceController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  int get totalPrice => qty * unitPrice;

  void dispose() {
    nameController.dispose();
    qtyController.dispose();
    priceController.dispose();
  }
}

class _CreateNotaDialogState extends State<CreateNotaDialog> {
  final List<_ItemEntry> _items = [];
  final TextEditingController _noteController = TextEditingController();
  PaymentMethod _paymentMethod = PaymentMethod.bankTransfer;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _addItem();
  }

  void _addItem() {
    final item = _ItemEntry();
    item.qtyController.addListener(() => setState(() {}));
    item.priceController.addListener(() => setState(() {}));
    setState(() => _items.add(item));
  }

  void _removeItem(int index) {
    if (_items.length <= 1) return;
    final item = _items.removeAt(index);
    item.dispose();
    setState(() {});
  }

  int get _calculatedTotal {
    int total = 0;
    for (final item in _items) {
      total += item.totalPrice;
    }
    return total;
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final validItems = <NotaItem>[];
    for (final item in _items) {
      final name = item.nameController.text.trim();
      final qty = item.qty;
      final price = item.unitPrice;

      if (name.isNotEmpty && price > 0) {
        validItems.add(NotaItem(name: name, qty: qty, unitPrice: price));
      }
    }

    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Tambahkan minimal 1 item pekerjaan dengan harga valid'),
          backgroundColor: AppColors.dangerCrimson,
        ),
      );
      return;
    }

    final total = _calculatedTotal;
    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Total nota harus lebih dari Rp 0'),
          backgroundColor: AppColors.dangerCrimson,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.onSubmit(
        items: validItems,
        totalAmount: total,
        paymentMethod: _paymentMethod,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuat nota: $e'),
            backgroundColor: AppColors.dangerCrimson,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceWhite,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  widget.isRevision
                      ? Icons.edit_note_rounded
                      : Icons.receipt_long_outlined,
                  color: widget.isRevision
                      ? AppColors.warningAmber
                      : AppColors.trustCobalt,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.isRevision
                        ? 'Ajukan Revisi Nota'
                        : 'Buat Nota Digital',
                    style: AppTypography.headingSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (widget.isRevision && widget.currentApprovedTotal != null) ...[
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
                  'Nota Sah saat ini: ${Formatters.formatCurrency(widget.currentApprovedTotal!)}. Masukkan rincian keseluruhan biaya yang baru.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            const Divider(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Rincian Pekerjaan & Material',
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addItem,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text(
                            'Tambah Item',
                            style: TextStyle(fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ..._items.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: item.nameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Nama Jasa / Material',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                  ),
                                ),
                                if (_items.length > 1) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: AppColors.dangerCrimson,
                                      size: 20,
                                    ),
                                    onPressed: () => _removeItem(idx),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: TextField(
                                    controller: item.qtyController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Jumlah',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 10,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: item.priceController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Harga Satuan (Rp)',
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 10,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    Formatters.formatCurrency(item.totalPrice),
                                    style: AppTypography.bodySmall.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 14),
                    Text(
                      'Metode Pembayaran',
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text(
                              'Transfer Bank',
                              style: TextStyle(fontSize: 11.5),
                            ),
                            selected:
                                _paymentMethod == PaymentMethod.bankTransfer,
                            onSelected: (_) => setState(
                              () => _paymentMethod = PaymentMethod.bankTransfer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text(
                              'E-Wallet',
                              style: TextStyle(fontSize: 11.5),
                            ),
                            selected: _paymentMethod == PaymentMethod.eWallet,
                            onSelected: (_) => setState(
                              () => _paymentMethod = PaymentMethod.eWallet,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text(
                              'Tunai',
                              style: TextStyle(fontSize: 11.5),
                            ),
                            selected: _paymentMethod == PaymentMethod.cash,
                            onSelected: (_) => setState(
                              () => _paymentMethod = PaymentMethod.cash,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _noteController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Catatan atau Garansi (Opsional)',
                        hintText: 'Contoh: Garansi pengerjaan 7 hari',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => FaqRulesScreen.show(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.userBadgeBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 15,
                              color: AppColors.trustCobalt,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Nota yang telah disetujui bersifat mengikat. Pelajari selengkapnya',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.trustCobalt,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: AppColors.trustCobalt,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total Biaya', style: AppTypography.bodySmall),
                    Text(
                      Formatters.formatCurrency(_calculatedTotal),
                      style: AppTypography.rupiahMedium.copyWith(
                        color: AppColors.trustCobalt,
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.isRevision
                        ? AppColors.warningAmber
                        : AppColors.trustCobalt,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(150, 46),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          widget.isRevision ? 'Kirim Revisi' : 'Kirim Nota',
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
