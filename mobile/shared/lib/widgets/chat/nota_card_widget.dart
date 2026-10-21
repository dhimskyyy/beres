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
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isApproved
              ? AppColors.successGreen.withValues(alpha: 0.5)
              : isRevision
                  ? AppColors.warningAmber.withValues(alpha: 0.5)
                  : AppColors.borderLight,
          width: isApproved || isRevision ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: isApproved
                  ? AppColors.successLight
                  : isRevision
                      ? AppColors.warningLight
                      : AppColors.userBadgeBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isApproved
                      ? Icons.verified_outlined
                      : (isRevision
                          ? Icons.edit_note_rounded
                          : Icons.receipt_long_outlined),
                  size: 19,
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
                        ? 'Revisi Nota #${nota.version}'
                        : 'Nota Digital',
                    style: AppTypography.headingSmall.copyWith(
                      fontSize: 13.5,
                      color: isApproved
                          ? AppColors.successGreen
                          : (isRevision
                              ? AppColors.warningAmber
                              : AppColors.trustCobalt),
                    ),
                  ),
                ),
                _buildStatusBadge(nota.status),
              ],
            ),
          ),
          if (isRevision) ...[
            Container(
              color: AppColors.warningLight.withValues(alpha: 0.6),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Perbandingan Perubahan Biaya',
                    style: AppTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Biaya Sebelumnya',
                            style: AppTypography.bodySmall,
                          ),
                          Text(
                            Formatters.formatCurrency(
                              nota.previousApprovedTotal ?? 0,
                            ),
                            style: AppTypography.bodyMedium.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: AppColors.textMuted,
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Biaya Revisi Baru',
                            style: AppTypography.bodySmall,
                          ),
                          Text(
                            Formatters.formatCurrency(nota.totalAmount),
                            style: AppTypography.rupiahMedium.copyWith(
                              color: AppColors.trustCobalt,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (nota.previousApprovedTotal != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Selisih: ${Formatters.formatCurrency(nota.totalAmount - nota.previousApprovedTotal!)}',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.warningAmber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rincian Pekerjaan & Material',
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ...nota.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${item.name} (${item.qty}x)',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          Formatters.formatCurrency(item.totalPrice),
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
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
                    Text(
                      'Total Biaya',
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      Formatters.formatCurrency(nota.totalAmount),
                      style: AppTypography.rupiahMedium.copyWith(
                        color: AppColors.trustCobalt,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Metode Bayar: ${nota.paymentMethod.label}',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
                if (nota.note != null && nota.note!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.notes_rounded,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          nota.note!,
                          style: AppTypography.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (isApproved)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: const BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(14),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    size: 15,
                    color: AppColors.successGreen,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Nota Sah Terkunci — Harga telah disepakati bersama',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.successGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
                              side: BorderSide(
                                color: AppColors.dangerCrimson.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              minimumSize: const Size.fromHeight(42),
                            ),
                            child: Text(
                              isRevision ? 'Tolak Revisi' : 'Tolak',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => onApprove?.call(nota),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.successGreen,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(42),
                            ),
                            child: Text(
                              isRevision ? 'Setujui Revisi' : 'Setujui Nota',
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Menunggu persetujuan pelanggan',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.warningAmber,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isRevision)
                          TextButton.icon(
                            onPressed: () => onCancelRevision?.call(nota),
                            icon: const Icon(
                              Icons.undo_rounded,
                              size: 15,
                              color: AppColors.dangerCrimson,
                            ),
                            label: const Text(
                              'Tarik Revisi',
                              style: TextStyle(
                                color: AppColors.dangerCrimson,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
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
        bg = AppColors.successGreen.withValues(alpha: 0.14);
        text = AppColors.successGreen;
        label = 'Disetujui';
        break;
      case NotaStatus.sent:
        bg = AppColors.warningAmber.withValues(alpha: 0.14);
        text = AppColors.warningAmber;
        label = 'Menunggu';
        break;
      case NotaStatus.rejected:
        bg = AppColors.dangerCrimson.withValues(alpha: 0.14);
        text = AppColors.dangerCrimson;
        label = 'Ditolak';
        break;
      case NotaStatus.superseded:
        bg = AppColors.surfaceLight;
        text = AppColors.textSecondary;
        label = 'Digantikan';
        break;
      case NotaStatus.voidStatus:
        bg = AppColors.surfaceLight;
        text = AppColors.textSecondary;
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
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: text,
        ),
      ),
    );
  }
}
