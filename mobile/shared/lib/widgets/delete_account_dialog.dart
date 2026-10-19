import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Dialog Konfirmasi Hapus Akun Beres v1.4.0 (FR-004, BR-45)
/// Menegakkan penolakan jika pengguna masih memiliki job aktif atau laporan sengketa berjalan
class DeleteAccountDialog extends StatefulWidget {
  final AuthService authService;
  final VoidCallback onAccountDeleted;

  const DeleteAccountDialog({
    super.key,
    required this.authService,
    required this.onAccountDeleted,
  });

  static Future<void> show(
    BuildContext context, {
    required AuthService authService,
    required VoidCallback onAccountDeleted,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DeleteAccountDialog(
        authService: authService,
        onAccountDeleted: onAccountDeleted,
      ),
    );
  }

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleDelete() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.authService.deleteAccount();
      if (mounted) {
        Navigator.of(context).pop();
        widget.onAccountDeleted();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Format pesan error dari server (BR-45)
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.dangerCrimson, size: 28),
          const SizedBox(width: 8),
          Text('Hapus Akun?', style: AppTypography.headingSmall),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tindakan ini permanen. Seluruh data pribadi Anda akan dianonimkan sesuai kepatuhan regulasi privasi (UU PDP).',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warningLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Perhatian: Penghapusan akun hanya diizinkan jika Anda tidak memiliki pekerjaan aktif yang sedang berjalan dan tidak sedang dalam investigasi sengketa (BR-45).',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.warningAmber),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.dangerCrimson, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.dangerCrimson),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleDelete,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.dangerCrimson,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Ya, Hapus Akun'),
        ),
      ],
    );
  }
}
