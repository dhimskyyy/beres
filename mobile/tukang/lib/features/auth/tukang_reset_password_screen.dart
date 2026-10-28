import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beres_shared/beres_shared.dart';

import 'tukang_login_screen.dart';
import 'widgets/auth_hero_header.dart';
import 'widgets/auth_text_field.dart';

class TukangResetPasswordScreen extends ConsumerStatefulWidget {
  const TukangResetPasswordScreen({super.key});

  @override
  ConsumerState<TukangResetPasswordScreen> createState() =>
      _TukangResetPasswordScreenState();
}

class _TukangResetPasswordScreenState
    extends ConsumerState<TukangResetPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isOtpSent = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_onPasswordChanged);
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _cleanMessage(dynamic raw) {
    return BeresFormatters.formatAuthError(raw);
  }

  // Step 1: Kirim Kode OTP 6 Digit ke Email Mitra
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
      await authService.sendPasswordResetOtp(
        email: email,
        targetRole: UserRole.tukang,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOtpSent = true;
          _errorMessage = null;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Kode OTP 6 digit telah dikirim ke $email. Silakan periksa kotak masuk atau spam.',
            ),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _cleanMessage(e.toString());
        });
      }
    }
  }

  // Step 2: Verifikasi OTP & Simpan Password Baru -> Masuk ke Home
  Future<void> _handleVerifyAndReset() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim().replaceAll(' ', '');
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (otp.isEmpty || otp.length < 6) {
      setState(() => _errorMessage = 'Masukkan kode OTP yang valid.');
      return;
    }

    final passwordError =
        BeresPasswordValidation.check(newPassword).errorMessage;
    if (passwordError != null) {
      setState(() => _errorMessage = passwordError);
      return;
    }

    if (newPassword != confirmPassword) {
      setState(() => _errorMessage = 'Konfirmasi password tidak cocok.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.verifyOtpAndResetPassword(
        email: email,
        otp: otp,
        newPassword: newPassword,
        expectedRole: UserRole.tukang,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Password berhasil diperbarui! Selamat datang kembali di Beres Mitra.',
            ),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _cleanMessage(e.toString());
        });
      }
    }
  }

  Widget _buildPasswordCriteria(String password) {
    final check = BeresPasswordValidation.check(password);
    final isStarted = password.isNotEmpty;

    Widget item(bool valid, String text) {
      final color = !isStarted
          ? const Color(0xFF94A3B8)
          : (valid ? const Color(0xFF16A34A) : const Color(0xFFDC2626));
      final icon = !isStarted
          ? Icons.circle_outlined
          : (valid ? Icons.check_circle_rounded : Icons.cancel_outlined);

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight:
                  valid && isStarted ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: !isStarted
              ? const Color(0xFFE2E8F0)
              : (check.isValid
                  ? const Color(0xFF86EFAC)
                  : const Color(0xFFCBD5E1)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Syarat Keamanan Password:',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              item(check.hasMinLength, '8+ Karakter'),
              item(check.hasUppercase, 'Huruf Besar (A-Z)'),
              item(check.hasLowercase, 'Huruf Kecil (a-z)'),
              item(check.hasDigit, 'Angka (0-9)'),
              item(check.hasSymbol, 'Simbol (!#@\$)'),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final heroHeight = (screenHeight * 0.28).clamp(210.0, 250.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Stack(
          children: [
            // 1. Hero Workshop & Logo Area with Back Button
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AuthHeroHeader(
                height: heroHeight + 36,
                showBackButton: true,
                onBack: () => context.go('/login'),
                subtitleBadge: 'LUPA PASSWORD',
              ),
            ),

            // 2. Solid White Sheet Container
            Positioned.fill(
              top: heroHeight,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x25000000),
                      blurRadius: 18,
                      offset: Offset(0, -6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(36)),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 36),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Title & Subtitle
                        Text(
                          _isOtpSent ? 'Atur Password Baru' : 'Lupa Password Mitra',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isOtpSent
                              ? 'Masukkan kode verifikasi 6 digit yang dikirim ke email mitra Anda'
                              : 'Masukkan alamat email yang terdaftar untuk menerima instruksi reset password',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFCA5A5),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  size: 18,
                                  color: Color(0xFFDC2626),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFFDC2626),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 22),

                        // STEP 1: Email Input
                        AuthTextField(
                          label: 'Email Mitra',
                          hintText: 'mitra@email.com',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.mail_outline_rounded,
                          focusBorderColor: AppColors.safetyOrange,
                          enabled: !_isOtpSent && !_isLoading,
                        ),

                        // STEP 2: Tampil setelah OTP terkirim
                        if (_isOtpSent) ...[
                          const SizedBox(height: 16),

                          // Field OTP 6 Digit
                          AuthTextField(
                            label: 'Kode OTP (6 Digit)',
                            hintText: '123456',
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            prefixIcon: Icons.pin_outlined,
                            focusBorderColor: AppColors.safetyOrange,
                            enabled: !_isLoading,
                          ),

                          const SizedBox(height: 14),

                          // Field Password Baru
                          AuthTextField(
                            label: 'Password Baru',
                            hintText: 'Minimal 8 karakter (A-Z, a-z, 0-9, simbol)',
                            controller: _newPasswordController,
                            isPassword: true,
                            obscureText: _obscureNewPassword,
                            prefixIcon: Icons.lock_outline_rounded,
                            focusBorderColor: AppColors.safetyOrange,
                            enabled: !_isLoading,
                            onToggleObscure: () => setState(
                              () => _obscureNewPassword = !_obscureNewPassword,
                            ),
                          ),

                          _buildPasswordCriteria(_newPasswordController.text),

                          const SizedBox(height: 14),

                          // Field Konfirmasi Password Baru
                          AuthTextField(
                            label: 'Konfirmasi Password Baru',
                            hintText: 'Ulangi password baru Anda',
                            controller: _confirmPasswordController,
                            isPassword: true,
                            obscureText: _obscureConfirmPassword,
                            prefixIcon: Icons.lock_outline_rounded,
                            focusBorderColor: AppColors.safetyOrange,
                            enabled: !_isLoading,
                            onToggleObscure: () => setState(
                              () => _obscureConfirmPassword =
                                  !_obscureConfirmPassword,
                            ),
                          ),

                          const SizedBox(height: 22),

                          // Button "SIMPAN PASSWORD BARU"
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.safetyOrange,
                                foregroundColor: Colors.white,
                                elevation: 3,
                                shadowColor: AppColors.safetyOrange
                                    .withValues(alpha: 0.35),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              onPressed:
                                  _isLoading ? null : _handleVerifyAndReset,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'SIMPAN PASSWORD BARU',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Button Kirim Ulang OTP / Ubah Email
                          Center(
                            child: TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => setState(() {
                                        _isOtpSent = false;
                                        _otpController.clear();
                                        _newPasswordController.clear();
                                        _confirmPasswordController.clear();
                                        _errorMessage = null;
                                      }),
                              child: const Text(
                                'Ubah Email atau Kirim Ulang OTP',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.safetyOrange,
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 24),

                          // Button "KIRIM KODE OTP"
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.safetyOrange,
                                foregroundColor: Colors.white,
                                elevation: 3,
                                shadowColor: AppColors.safetyOrange
                                    .withValues(alpha: 0.35),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              onPressed: _isLoading ? null : _handleSendOtp,
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'KIRIM KODE OTP',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Back to login footer
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'Sudah ingat password Anda? ',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            GestureDetector(
                              onTap: _isLoading
                                  ? null
                                  : () => context.go('/login'),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  'Masuk Disini',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.safetyOrange,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
