import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beres_shared/beres_shared.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class TukangLoginScreen extends ConsumerStatefulWidget {
  const TukangLoginScreen({super.key});

  @override
  ConsumerState<TukangLoginScreen> createState() => _TukangLoginScreenState();
}

class _TukangLoginScreenState extends ConsumerState<TukangLoginScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _fullNameController = TextEditingController();

  bool _isOtpSent = false;
  bool _isLoading = false;
  bool _isNewUser = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  String _cleanMessage(dynamic raw) {
    return BeresFormatters.formatAuthError(raw);
  }

  Future<void> _handleSendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Masukkan alamat email yang valid.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);

      final checkResult = await authService.checkEmailRole(
        email: email,
        targetRole: UserRole.tukang,
      );

      if (checkResult.isRoleMismatch) {
        setState(() {
          _isLoading = false;
          _errorMessage = checkResult.message != null
              ? _cleanMessage(checkResult.message!)
              : 'Email ini sudah terdaftar sebagai akun Pelanggan. Gunakan email lain untuk masuk sebagai Mitra Tukang.';
        });
        return;
      }

      if (checkResult.isDeleted) {
        setState(() {
          _isLoading = false;
          _errorMessage = checkResult.message != null
              ? _cleanMessage(checkResult.message!)
              : 'Akun dengan email ini telah dihapus atau dinonaktifkan.';
        });
        return;
      }

      if (checkResult.isSuspendedPermanent) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => SuspendScreen(
                isPermanent: true,
                reason:
                    checkResult.suspendReason ??
                    'Akun mitra dinonaktifkan permanen oleh tim operasional.',
                appealEmail: checkResult.appealEmail ?? 'support@beres.id',
                onSignOut: () => context.go('/login'),
              ),
            ),
          );
        }
        return;
      }

      if (checkResult.isSuspendedAuto2Days) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => SuspendScreen(
                isPermanent: false,
                reason:
                    checkResult.suspendReason ??
                    'Akun mitra ditangguhkan sementara selama 48 jam.',
                suspendedUntil: checkResult.suspendedUntil,
                onSignOut: () => context.go('/login'),
              ),
            ),
          );
        }
        return;
      }

      await authService.sendEmailOtp(email: email);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOtpSent = true;
          _isNewUser = (checkResult.status == 'ALLOWED_NEW_USER');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal mengirim kode verifikasi. Silakan coba lagi.';
        });
      }
    }
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length < 6 || otp.length > 8) {
      setState(() => _errorMessage = 'Masukkan kode OTP 6 hingga 8 digit.');
      return;
    }

    final fullName = _isNewUser
        ? (_fullNameController.text.trim().isNotEmpty
              ? _fullNameController.text.trim()
              : 'Mitra Tukang')
        : 'Mitra Tukang';

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.verifyOtpAndSyncProfile(
        email: _emailController.text.trim(),
        token: otp,
        targetRole: UserRole.tukang,
        fullName: fullName,
      );

      if (mounted) {
        if (_isNewUser) {
          context.go('/onboarding');
        } else {
          context.go('/home');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e is AuthException
              ? 'Kode OTP tidak sesuai atau sudah kedaluwarsa.'
              : _cleanMessage(e.toString());
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Masuk Mitra Tukang')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.tukangBadgeBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.handyman_outlined,
                        size: 26,
                        color: AppColors.safetyOrange,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Beres Mitra', style: AppTypography.headingLarge),
                  const SizedBox(height: 6),
                  const Text(
                    'Terima pesanan pekerjaan sesuai keahlian Anda dan terima pembayaran 100% langsung tanpa potongan komisi.',
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: 24),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.dangerCrimson.withValues(
                            alpha: 0.25,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: AppColors.dangerCrimson,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.dangerCrimson,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !_isOtpSent && !_isLoading,
                          decoration: const InputDecoration(
                            labelText: 'Alamat Email Mitra',
                            hintText: 'mitra@email.com',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                        ),

                        if (_isOtpSent) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.tukangBadgeBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Kode verifikasi telah dikirim ke ${_emailController.text.trim()}.',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.tukangBadgeText,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            maxLength: 8,
                            enabled: !_isLoading,
                            style: AppTypography.otpCode,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              labelText: 'Kode Verifikasi (OTP)',
                              hintText: '••••••',
                              counterText: '',
                              prefixIcon: Icon(Icons.lock_outline_rounded),
                            ),
                          ),
                          if (_isNewUser) ...[
                            const SizedBox(height: 14),
                            TextField(
                              controller: _fullNameController,
                              enabled: !_isLoading,
                              decoration: const InputDecoration(
                                labelText: 'Nama Lengkap Sesuai KTP',
                                hintText: 'Masukkan nama lengkap Anda',
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleVerifyOtp,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Verifikasi & Masuk'),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () => setState(() {
                                    _isOtpSent = false;
                                    _otpController.clear();
                                  }),
                            child: const Text('Ubah Alamat Email'),
                          ),
                        ] else ...[
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleSendOtp,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Kirim Kode Masuk'),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Ingin bergabung sebagai mitra?',
                        style: AppTypography.bodySmall,
                      ),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => context.push('/register'),
                        child: const Text('Daftar Mitra Baru'),
                      ),
                    ],
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
