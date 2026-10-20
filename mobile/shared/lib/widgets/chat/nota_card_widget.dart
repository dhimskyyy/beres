import 'package:flutter/material.dart';
import '../../models/nota.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/formatters.dart';

class NotaCardWidget extends StatelessWidget {
  final Nota nota;
  final bool isUser;
  final Function(Nota nota)? onApprove;
  final Function(Nota nota)? onReject;
  final Function(Nota nota)? onCancelRevision;

  const NotaCardWidget({
    super.key,
    required this.nota,
    required this.isUser,
    this.onApprove,
    this.onReject,
    this.onCancelRevision,
  });

  @override
  Widget build(BuildContext context) {
    final isRevision = nota.version > 1;
    final isSent = nota.status == NotaStatus.sent;
    final isApproved = nota.status == NotaStatus.approved;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRevision
              ? (isApproved ? AppColors.successGreen : AppColors.warningAmber)
              : (isApproved ? AppColors.successGreen : AppColors.trustCobalt),
          width: isApproved || isRevision ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isRevision
                  ? (isApproved
                      ? AppColors.successGreen.withValues(alpha: 0.12)
                      : AppColors.warningAmber.withValues(alpha: 0.15))
                  : (isApproved
                      ? AppColors.successGreen.withValues(alpha: 0.12)
                      : AppColors.trustCobalt.withValues(alpha: 0.1)),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(
                  isApproved
                      ? Icons.lock_outline
                      : (isRevision
                          ? Icons.warning_amber_rounded
                          : Icons.receipt_long_outlined),
                  size: 20,
                  color: isApproved
                      ? AppColors.successGreen
                      : (isRevision
                          ? AppColors.warningAmber
                          : AppColors.trustCobalt),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isRevision
                        ? 'REVISI NOTA (Versi ${nota.version})'
                        : 'NOTA DIGITAL (Versi 1)',
                    style: AppTypography.headingSmall.copyWith(
                      fontSize: 14,
                      color: isApproved
                          ? AppColors.successGreen
                          : (isRevision
                              ? Colors.brown.shade800
                              : AppColors.trustCobalt),
                    ),
                  ),
                ),
                _buildStatusBadge(nota.status),
              ],
            ),
          ),

          // 2. Alert Perbandingan Harga Revisi (FR-015, BR-05)
          if (isRevision) ...[
            Container(
              color: Colors.amber.shade50,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 16, color: Colors.orange),
                      const SizedBox(width: 6),
                      Text(
                        'Perbandingan Harga Revisi (BR-05):',
                        style: AppTypography.bodySmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.brown.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nota Sah Sebelumnya',
                              style: AppTypography.bodySmall),
                          Text(
                            Formatters.formatCurrency(
                                nota.previousApprovedTotal ?? 0),
                            style: AppTypography.bodyMedium.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const Icon(Icons.arrow_forward,
                          size: 18, color: Colors.grey),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Pengajuan Revisi Baru',
                              style: AppTypography.bodySmall),
                          Text(
                            Formatters.formatCurrency(nota.totalAmount),
                            style: AppTypography.headingSmall.copyWith(
                              color: AppColors.trustCobalt,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (nota.previousApprovedTotal != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Selisih Penambahan: ${Formatters.formatCurrency(nota.totalAmount - nota.previousApprovedTotal!)}',
                      style: AppTypography.bodySmall.copyWith(
                        color: Colors.brown.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
          ],

          // 3. Rincian Item Pekerjaan / Material
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rincian Pekerjaan & Material:',
                  style: AppTypography.bodySmall
                      .copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...nota.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.name} (${item.qty}x)',
                              style: AppTypography.bodyMedium,
                            ),
                          ),
                          Text(
                            Formatters.formatCurrency(item.totalPrice),
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )),
                const Divider(height: 16),

                // Total Nominal
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total Nominal:',
                      style: AppTypography.bodyMedium
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      Formatters.formatCurrency(nota.totalAmount),
                      style: AppTypography.headingSmall.copyWith(
                        color: AppColors.trustCobalt,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Metode Pembayaran Rencana
                Row(
                  children: [
                    const Icon(Icons.payment_outlined,
                        size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Rencana Pembayaran: ${nota.paymentMethod.label}',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),

                if (nota.note != null && nota.note!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.notes_outlined,
                          size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Catatan: ${nota.note}',
                          style: AppTypography.bodySmall
                              .copyWith(fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // 4. Approved Lock Banner
          if (isApproved)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.successGreen.withValues(alpha: 0.1),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified,
                      size: 16, color: AppColors.successGreen),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Nota Sah Terkunci — Harga & Item Mengikat (BR-05)',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.successGreen,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 5. Action Buttons (User Approve/Reject OR Tukang Tarik Revisi)
          if (isSent) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: isUser
                  ? Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => onReject?.call(nota),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.dangerCrimson,
                              side: const BorderSide(
                                  color: AppColors.dangerCrimson),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: Text(
                                isRevision ? 'Tolak Revisi' : 'Tolak Nota'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => onApprove?.call(nota),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.successGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            child: Text(isRevision
                                ? 'Setujui Revisi'
                                : 'Setujui (Nota Sah)'),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Menunggu Persetujuan Pelanggan',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.warningAmber,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isRevision)
                          TextButton.icon(
                            onPressed: () => onCancelRevision?.call(nota),
                            icon: const Icon(Icons.undo,
                                size: 16, color: AppColors.dangerCrimson),
                            label: const Text(
                              'Tarik Revisi (BR-08)',
                              style: TextStyle(
                                  color: AppColors.dangerCrimson, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(NotaStatus status) {
    Color bg;
    Color text;
    String label = status.label;

    switch (status) {
      case NotaStatus.approved:
        bg = AppColors.successGreen.withValues(alpha: 0.15);
        text = AppColors.successGreen;
        label = 'Nota Sah (Terkunci)';
        break;
      case NotaStatus.sent:
        bg = AppColors.warningAmber.withValues(alpha: 0.15);
        text = Colors.brown.shade800;
        label = 'Menunggu Persetujuan';
        break;
      case NotaStatus.rejected:
        bg = AppColors.dangerCrimson.withValues(alpha: 0.15);
        text = AppColors.dangerCrimson;
        break;
      case NotaStatus.superseded:
        bg = Colors.grey.shade200;
        text = Colors.grey.shade700;
        label = 'Digantikan / Ditarik';
        break;
      case NotaStatus.voidStatus:
        bg = Colors.grey.shade200;
        text = Colors.grey.shade700;
        label = 'Dibatalkan';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: text),
      ),
    );
  }
}
