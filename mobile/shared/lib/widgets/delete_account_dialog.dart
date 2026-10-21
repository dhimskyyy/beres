import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Dialog Konfirmasi Hapus Akun Beres
/// Menegakkan penolakan jika pengguna masih memiliki pekerjaan aktif atau laporan kendala berjalan
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
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceWhite,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: AppColors.dangerCrimson,
            size: 24,
          ),
          SizedBox(width: 10),
          Text('Hapus Akun Permanen?', style: AppTypography.headingSmall),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tindakan ini tidak dapat dibatalkan. Data profil pribadi Anda akan dihapus secara permanen dari sistem.',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: const Text(
                'Pastikan Anda tidak memiliki pesanan yang sedang berjalan atau laporan kendala yang masih ditinjau.',
                style: AppTypography.bodySmall,
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.dangerCrimson,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.dangerCrimson,
                        ),
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
            minimumSize: const Size(120, 42),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Hapus Akun'),
        ),
      ],
    );
  }
}
