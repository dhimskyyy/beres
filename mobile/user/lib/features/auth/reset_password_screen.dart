import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beres_shared/beres_shared.dart';

import 'login_screen.dart';
import 'widgets/auth_hero_header.dart';
import 'widgets/auth_text_field.dart';

class UserResetPasswordScreen extends ConsumerStatefulWidget {
  const UserResetPasswordScreen({super.key});

  @override
  ConsumerState<UserResetPasswordScreen> createState() =>
      _UserResetPasswordScreenState();
}

class _UserResetPasswordScreenState
    extends ConsumerState<UserResetPasswordScreen> {
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
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _cleanMessage(dynamic raw) {
    return BeresFormatters.formatAuthError(raw);
  }

  // Step 1: Kirim Kode OTP 6 Digit ke Email
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
      await authService.sendPasswordResetOtp(email: email);

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

  // Step 2: Verifikasi OTP 6 Digit & Simpan Password Baru -> Masuk ke Home
  Future<void> _handleVerifyAndReset() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (otp.isEmpty || otp.length < 6) {
      setState(() => _errorMessage = 'Masukkan 6 digit kode OTP yang valid.');
      return;
    }
    if (newPassword.length < 6) {
      setState(() => _errorMessage = 'Password baru minimal terdiri dari 6 karakter.');
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
        expectedRole: UserRole.user,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Password berhasil diperbarui! Selamat datang kembali di Beres.',
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

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final heroHeight = (screenHeight * 0.28).clamp(210.0, 250.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarBrightness: Brightness.dark, // iOS: White icons/clock
        statusBarIconBrightness: Brightness.light, // Android: White icons
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
                          _isOtpSent
                              ? 'Atur Password Baru'
                              : 'Lupa Password?',
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
                              ? 'Masukkan kode 6 digit dari email Anda dan buat password baru.'
                              : 'Masukkan email terdaftar Anda untuk menerima kode OTP 6 digit.',
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

                        if (!_isOtpSent) ...[
                          // Step 1: Input Email
                          AuthTextField(
                            label: 'Email Terdaftar',
                            hintText: 'nama@email.com',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Icons.mail_outline_rounded,
                            enabled: !_isLoading,
                          ),

                          const SizedBox(height: 24),

                          // Tombol Kirim Kode OTP
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16397E),
                                foregroundColor: Colors.white,
                                elevation: 3,
                                shadowColor: const Color(0xFF16397E)
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

                          const SizedBox(height: 24),

                          // Footer: Ingat password Anda? Masuk
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'Ingat password Anda? ',
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
                                    'Masuk',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF16397E),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          // Step 2: Input OTP + Password Baru + Konfirmasi Password
                          AuthTextField(
                            label: 'Kode OTP 6 Digit',
                            hintText: 'Contoh: 123456',
                            controller: _otpController,
                            keyboardType: TextInputType.number,
                            prefixIcon: Icons.security_rounded,
                            enabled: !_isLoading,
                          ),

                          const SizedBox(height: 14),

                          AuthTextField(
                            label: 'Password Baru',
                            hintText: 'Minimal 6 karakter',
                            controller: _newPasswordController,
                            isPassword: true,
                            obscureText: _obscureNewPassword,
                            prefixIcon: Icons.lock_outline_rounded,
                            enabled: !_isLoading,
                            onToggleObscure: () => setState(() =>
                                _obscureNewPassword = !_obscureNewPassword),
                          ),

                          const SizedBox(height: 14),

                          AuthTextField(
                            label: 'Konfirmasi Password Baru',
                            hintText: 'Ulangi password baru',
                            controller: _confirmPasswordController,
                            isPassword: true,
                            obscureText: _obscureConfirmPassword,
                            prefixIcon: Icons.lock_outline_rounded,
                            enabled: !_isLoading,
                            onToggleObscure: () => setState(() =>
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword),
                          ),

                          const SizedBox(height: 24),

                          // Tombol Simpan & Masuk
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16397E),
                                foregroundColor: Colors.white,
                                elevation: 3,
                                shadowColor: const Color(0xFF16397E)
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
                                      'PERBARUI PASSWORD & MASUK',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Opsi Kirim Ulang & Ganti Email
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: _isLoading ? null : _handleSendOtp,
                                child: const Text(
                                  'Kirim Ulang Kode',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF16397E),
                                  ),
                                ),
                              ),
                              TextButton(
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
                                  'Ganti Email',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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
