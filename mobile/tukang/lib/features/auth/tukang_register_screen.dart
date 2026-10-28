import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beres_shared/beres_shared.dart';

import 'tukang_login_screen.dart';
import 'widgets/auth_hero_header.dart';
import 'widgets/auth_text_field.dart';

class TukangRegisterScreen extends ConsumerStatefulWidget {
  const TukangRegisterScreen({super.key});

  @override
  ConsumerState<TukangRegisterScreen> createState() =>
      _TukangRegisterScreenState();
}

class _TukangRegisterScreenState extends ConsumerState<TukangRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeTerms = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
  }

  void _onPasswordChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _passwordController.removeListener(_onPasswordChanged);
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _cleanMessage(dynamic raw) {
    return BeresFormatters.formatAuthError(raw);
  }

  Future<void> _handleRegister() async {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (fullName.isEmpty) {
      setState(() => _errorMessage = 'Nama lengkap wajib diisi.');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Masukkan alamat email yang valid.');
      return;
    }

    final passwordError =
        BeresPasswordValidation.check(password).errorMessage;
    if (passwordError != null) {
      setState(() => _errorMessage = passwordError);
      return;
    }

    if (password != confirmPassword) {
      setState(() => _errorMessage = 'Konfirmasi password tidak cocok.');
      return;
    }
    if (!_agreeTerms) {
      setState(() => _errorMessage =
          'Anda wajib menyetujui syarat kemitraan dan kebijakan privasi Beres.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);

      // 1. Cek status akun di rpc_check_email_role (BR-42, BR-44)
      final checkResult = await authService.checkEmailRole(
        email: email,
        targetRole: UserRole.tukang,
      );

      if (checkResult.isDeleted) {
        setState(() {
          _isLoading = false;
          _errorMessage = checkResult.message ??
              'Akun dengan email ini telah dinonaktifkan.';
        });
        return;
      }

      if (checkResult.isSuspendedPermanent || checkResult.isSuspendedAuto2Days) {
        setState(() {
          _isLoading = false;
          _errorMessage = checkResult.suspendReason ??
              'Akun dengan email ini sedang ditangguhkan.';
        });
        return;
      }

      if (checkResult.isExistingUser &&
          checkResult.hasRoleFor(UserRole.tukang)) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Email ini sudah terdaftar sebagai Mitra Tukang. Silakan masuk melalui halaman Login.';
        });
        return;
      }

      final isDualRoleActivation =
          checkResult.isExistingUser && checkResult.currentRole == UserRole.user;

      // 2. Mendaftar dengan Email & Password (atau aktivasi peran ganda BOTH pada BR-44)
      await authService.signUpWithPassword(
        email: email,
        password: password,
        fullName: fullName,
        role: UserRole.tukang,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isDualRoleActivation
                  ? 'Peran Mitra Tukang berhasil diaktifkan! Silakan lengkapi profil keahlian Anda.'
                  : 'Pendaftaran mitra berhasil! Selamat datang di Beres Mitra.',
            ),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
        // Lanjut ke alur onboarding pengaturan profil & keahlian mitra
        context.go('/onboarding');
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

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Syarat Kemitraan & Kode Etik Mitra'),
        content: const SingleChildScrollView(
          child: Text(
            '1. Pembayaran Langsung 100%: Pembayaran pekerjaan dilakukan langsung dari pelanggan ke rekening/tunai mitra tanpa potongan komisi (Zero Escrow / Zero In-App Wallet).\n\n'
            '2. Keabsahan Nota Digital: Nota awal yang telah disetujui pelanggan bersifat sah dan mengikat. Perubahan rincian wajib diajukan melalui Revisi Nota dan hanya sah bila disetujui pelanggan.\n\n'
            '3. Waktu Berangkat: Setelah Nota disetujui, mitra wajib menekan tombol "Berangkat ke Lokasi" maksimal dalam waktu 30 menit.\n\n'
            '4. Pelacakan GPS & Bukti Kerja: Mitra wajib menyalakan GPS selama perjalanan menuju lokasi dan mengunggah foto hasil kerja serta konfirmasi pembayaran sebelum menyelesaikan tugas.\n\n'
            '5. Sistem Sanksi (Strike): Keterlambatan berangkat atau pembatalan sepihak menimbulkan Strike. Maksimal toleransi 3x Strike per bulan, pelanggaran lebih lanjut menyebabkan penangguhan akun otomatis selama 2 hari.',
            style: TextStyle(fontSize: 13, height: 1.45),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup', style: TextStyle(color: AppColors.safetyOrange)),
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
        statusBarBrightness: Brightness.dark, // iOS: Light (white) text and icons
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
                subtitleBadge: 'PENDAFTARAN MITRA',
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
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Title & Subtitle
                          const Text(
                            'Daftar Sebagai Mitra',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Bergabung bersama ribuan mitra tukang profesional Beres',
                            textAlign: TextAlign.center,
                            style: TextStyle(
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

                          const SizedBox(height: 20),

                          // Field Nama
                          AuthTextField(
                            label: 'Nama Lengkap Sesuai KTP',
                            hintText: 'Contoh: Budi Santoso',
                            controller: _fullNameController,
                            prefixIcon: Icons.person_outline_rounded,
                            focusBorderColor: AppColors.safetyOrange,
                            enabled: !_isLoading,
                          ),

                          const SizedBox(height: 14),

                          // Field Email
                          AuthTextField(
                            label: 'Email Mitra',
                            hintText: 'mitra@email.com',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: Icons.mail_outline_rounded,
                            focusBorderColor: AppColors.safetyOrange,
                            enabled: !_isLoading,
                          ),

                          const SizedBox(height: 14),

                          // Field Password
                          AuthTextField(
                            label: 'Password',
                            hintText: 'Minimal 8 karakter (A-Z, a-z, 0-9, simbol)',
                            controller: _passwordController,
                            isPassword: true,
                            obscureText: _obscurePassword,
                            prefixIcon: Icons.lock_outline_rounded,
                            focusBorderColor: AppColors.safetyOrange,
                            enabled: !_isLoading,
                            onToggleObscure: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),

                          _buildPasswordCriteria(_passwordController.text),

                          const SizedBox(height: 14),

                          // Field Konfirmasi Password
                          AuthTextField(
                            label: 'Konfirmasi Password',
                            hintText: 'Ulangi password Anda',
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

                          const SizedBox(height: 16),

                          // Checkbox Syarat & Ketentuan Kemitraan
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _agreeTerms,
                                  activeColor: AppColors.safetyOrange,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  onChanged: _isLoading
                                      ? null
                                      : (val) => setState(
                                          () => _agreeTerms = val ?? false,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: GestureDetector(
                                  onTap: _showTermsDialog,
                                  child: RichText(
                                    text: const TextSpan(
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF475569),
                                        height: 1.4,
                                      ),
                                      children: [
                                        TextSpan(text: 'Saya menerima '),
                                        TextSpan(
                                          text: 'syarat kemitraan',
                                          style: TextStyle(
                                            color: AppColors.safetyOrange,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        TextSpan(
                                          text:
                                              ' serta kode etik mitra Beres.',
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Primary Button "DAFTAR"
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
                              onPressed: _isLoading ? null : _handleRegister,
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
                                      'DAFTAR',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Footer: Sudah punya akun mitra? Masuk
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'Sudah memiliki akun mitra? ',
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
            ),
          ],
        ),
      ),
    );
  }
}
