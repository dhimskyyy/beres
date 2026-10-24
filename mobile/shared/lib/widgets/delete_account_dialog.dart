import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/supabase_client_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Dialog Konfirmasi Hapus Akun Beres (BR-45 & UU PDP)
/// Mencegah ghost touch atau ketidaksengajaan dengan pola "Type to Confirm":
/// Pengguna wajib mengetik kalimat persis "HAPUS akun user@email.com".
/// Tombol Hapus Akun terkunci (abu-abu) hingga kalimat tersebut benar diketik.
class DeleteAccountDialog extends StatefulWidget {
  final AuthService authService;
  final VoidCallback onAccountDeleted;
  final String? userEmail;

  const DeleteAccountDialog({
    super.key,
    required this.authService,
    required this.onAccountDeleted,
    this.userEmail,
  });

  static Future<void> show(
    BuildContext context, {
    required AuthService authService,
    required VoidCallback onAccountDeleted,
    String? userEmail,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => DeleteAccountDialog(
        authService: authService,
        onAccountDeleted: onAccountDeleted,
        userEmail: userEmail,
      ),
    );
  }

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final _confirmationController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  String get _targetEmail {
    if (widget.userEmail != null && widget.userEmail!.trim().isNotEmpty) {
      return widget.userEmail!.trim();
    }
    return SupabaseClientService.instance.currentUser?.email ?? '';
  }

  /// Kalimat wajib: "HAPUS akun <email>"
  /// HAPUS harus huruf kapital, kata akun huruf kecil, diikuti email pengguna.
  String get _expectedText => 'HAPUS akun $_targetEmail';

  /// Cek kecocokan kalimat secara persis
  bool get _isMatch =>
      _confirmationController.text.trim() == _expectedText.trim();

  Future<void> _handleDelete() async {
    if (!_isMatch) return;

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: AppColors.dangerCrimson,
            size: 24,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Hapus Akun Permanen?',
              style: AppTypography.headingSmall,
            ),
          ),
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
            const SizedBox(height: 16),
            const Text(
              'Ketik kalimat konfirmasi di bawah ini secara persis untuk membuka tombol hapus:',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: SelectableText(
                _expectedText,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmationController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Ketik di sini...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF94A3B8),
                ),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: _isMatch
                        ? const Color(0xFF16A34A)
                        : const Color(0xFFE2E8F0),
                    width: _isMatch ? 1.5 : 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: _isMatch
                        ? const Color(0xFF16A34A)
                        : const Color(0xFF16397E),
                    width: 1.5,
                  ),
                ),
                suffixIcon: _isMatch
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF16A34A),
                        size: 20,
                      )
                    : null,
              ),
            ),
            if (_confirmationController.text.isNotEmpty && !_isMatch) ...[
              const SizedBox(height: 6),
              const Text(
                'Teks belum sesuai (perhatikan huruf kapital HAPUS dan spasi)',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
          onPressed: (_isMatch && !_isLoading) ? _handleDelete : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.dangerCrimson,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFE2E8F0),
            disabledForegroundColor: const Color(0xFF94A3B8),
            elevation: _isMatch ? 1 : 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
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
              : const Text(
                  'Hapus Akun',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
        ),
      ],
    );
  }
}
