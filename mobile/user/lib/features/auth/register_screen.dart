import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beres_shared/beres_shared.dart';
import 'login_screen.dart';

class UserRegisterScreen extends ConsumerStatefulWidget {
  const UserRegisterScreen({super.key});

  @override
  ConsumerState<UserRegisterScreen> createState() => _UserRegisterScreenState();
}

class _UserRegisterScreenState extends ConsumerState<UserRegisterScreen> {
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isOtpSent = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  String _cleanMessage(String raw) {
    return raw
        .replaceAll(RegExp(r'\s*\((BR|FR)-[0-9a-zA-Z]+\)'), '')
        .replaceFirst('Exception: ', '');
  }

  Future<void> _handleSendOtp() async {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();

    if (fullName.isEmpty) {
      setState(() => _errorMessage = 'Nama lengkap wajib diisi.');
      return;
    }
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
        targetRole: UserRole.user,
      );

      if (checkResult.isRoleMismatch) {
        setState(() {
          _isLoading = false;
          _errorMessage = checkResult.message != null
              ? _cleanMessage(checkResult.message!)
              : 'Email ini sudah terdaftar sebagai akun Mitra Tukang. Satu email hanya dapat digunakan untuk satu jenis akun.';
        });
        return;
      }

      if (checkResult.isDeleted) {
        setState(() {
          _isLoading = false;
          _errorMessage = checkResult.message != null
              ? _cleanMessage(checkResult.message!)
              : 'Akun dengan email ini telah dinonaktifkan.';
        });
        return;
      }

      await authService.sendEmailOtp(email: email);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOtpSent = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal mengirim kode OTP. Silakan coba lagi.';
        });
      }
    }
  }

  Future<void> _handleVerifyAndRegister() async {
    final otp = _otpController.text.trim();
    final fullName = _fullNameController.text.trim();

    if (otp.length < 6 || otp.length > 8) {
      setState(() => _errorMessage = 'Masukkan kode OTP 6 hingga 8 digit.');
      return;
    }
    if (fullName.isEmpty) {
      setState(() => _errorMessage = 'Nama lengkap wajib diisi.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.verifyOtpAndSyncProfile(
        email: _emailController.text.trim(),
        token: otp,
        targetRole: UserRole.user,
        fullName: fullName,
        phone: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
      );

      if (mounted) {
        context.go('/home');
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
      appBar: AppBar(title: const Text('Daftar Akun Pelanggan')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Buat Akun Baru',
                    style: AppTypography.headingLarge,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Lengkapi profil singkat Anda untuk mulai mencari dan memesan jasa tukang profesional.',
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
                          controller: _fullNameController,
                          enabled: !_isOtpSent && !_isLoading,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nama Lengkap',
                            hintText: 'Contoh: Budi Santoso',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          enabled: !_isOtpSent && !_isLoading,
                          decoration: const InputDecoration(
                            labelText: 'Nomor WhatsApp / Telepon (Opsional)',
                            hintText: '0812xxxxxxxx',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !_isOtpSent && !_isLoading,
                          decoration: const InputDecoration(
                            labelText: 'Alamat Email',
                            hintText: 'nama@email.com',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                        ),

                        if (_isOtpSent) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.userBadgeBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              'Masukkan kode verifikasi yang dikirim ke ${_emailController.text.trim()}.',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.trustCobalt,
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
                          const SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : _handleVerifyAndRegister,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Selesaikan Pendaftaran'),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () => setState(() {
                                    _isOtpSent = false;
                                    _otpController.clear();
                                  }),
                            child: const Text('Ubah Data Pendaftaran'),
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
                                : const Text('Kirim Kode Verifikasi'),
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
                        'Sudah memiliki akun?',
                        style: AppTypography.bodySmall,
                      ),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => context.go('/login'),
                        child: const Text('Masuk di Sini'),
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
