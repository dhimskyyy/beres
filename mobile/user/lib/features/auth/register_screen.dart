import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beres_shared/beres_shared.dart';

import 'login_screen.dart';
import 'widgets/auth_hero_header.dart';
import 'widgets/auth_text_field.dart';

class UserRegisterScreen extends ConsumerStatefulWidget {
  const UserRegisterScreen({super.key});

  @override
  ConsumerState<UserRegisterScreen> createState() =>
      _UserRegisterScreenState();
}

class _UserRegisterScreenState extends ConsumerState<UserRegisterScreen> {
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
  void dispose() {
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
    if (password.length < 6) {
      setState(() => _errorMessage = 'Password minimal terdiri dari 6 karakter.');
      return;
    }
    if (password != confirmPassword) {
      setState(() => _errorMessage = 'Konfirmasi password tidak cocok.');
      return;
    }
    if (!_agreeTerms) {
      setState(() => _errorMessage =
          'Anda wajib menyetujui syarat & ketentuan serta kebijakan privasi.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);

      // 1. Cek status akun
      final checkResult = await authService.checkEmailRole(
        email: email,
        targetRole: UserRole.user,
      );

      if (checkResult.isDeleted) {
        setState(() {
          _isLoading = false;
          _errorMessage = checkResult.message ??
              'Akun dengan email ini telah dinonaktifkan.';
        });
        return;
      }

      // 2. Mendaftar dengan Email & Password
      await authService.signUpWithPassword(
        email: email,
        password: password,
        fullName: fullName,
        role: UserRole.user,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pendaftaran berhasil! Selamat datang di Beres.'),
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

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Syarat & Ketentuan Layanan'),
        content: const SingleChildScrollView(
          child: Text(
            '1. Beres menghubungkan pelanggan dengan mitra tukang independen secara transparan.\n\n'
            '2. Pembayaran jasa dilakukan langsung kepada mitra tukang (Zero In-App Wallet).\n\n'
            '3. Nota Digital yang telah disetujui bersifat sah dan mengikat.\n\n'
            '4. Pembatalan sepihak dan keterlambatan respons chat saat tukang bertugas dapat dikenakan sanksi strike.\n\n'
            '5. Pelanggan wajib membayar biaya jasa sesuai Nota Sah begitu pekerjaan diselesaikan dengan baik.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tutup'),
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
                          'Silahkan Buat Akun Anda',
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
                          'Daftar untuk menggunakan layanan dengan mudah',
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
                          label: 'Nama',
                          hintText: 'Nama lengkap Anda',
                          controller: _fullNameController,
                          prefixIcon: Icons.person_outline_rounded,
                          enabled: !_isLoading,
                        ),

                        const SizedBox(height: 14),

                        // Field Email
                        AuthTextField(
                          label: 'Email',
                          hintText: 'nama@email.com',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: Icons.mail_outline_rounded,
                          enabled: !_isLoading,
                        ),

                        const SizedBox(height: 14),

                        // Field Password
                        AuthTextField(
                          label: 'Password',
                          hintText: '••••••••',
                          controller: _passwordController,
                          isPassword: true,
                          obscureText: _obscurePassword,
                          prefixIcon: Icons.lock_outline_rounded,
                          enabled: !_isLoading,
                          onToggleObscure: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                        ),

                        const SizedBox(height: 14),

                        // Field Konfirmasi Password
                        AuthTextField(
                          label: 'Konfirmasi Password',
                          hintText: '••••••••',
                          controller: _confirmPasswordController,
                          isPassword: true,
                          obscureText: _obscureConfirmPassword,
                          prefixIcon: Icons.lock_outline_rounded,
                          enabled: !_isLoading,
                          onToggleObscure: () => setState(() =>
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword),
                        ),

                        const SizedBox(height: 16),

                        // Checkbox Syarat & Ketentuan
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _agreeTerms,
                                activeColor: const Color(0xFF16397E),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                onChanged: _isLoading
                                    ? null
                                    : (val) => setState(
                                        () => _agreeTerms = val ?? false),
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
                                        text: 'syarat dan ketentuan',
                                        style: TextStyle(
                                          color: Color(0xFFD97706),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      TextSpan(
                                          text: ' serta kebijakan privasi aplikasi ini.'),
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
                              backgroundColor: const Color(0xFF16397E),
                              foregroundColor: Colors.white,
                              elevation: 3,
                              shadowColor:
                                  const Color(0xFF16397E).withValues(alpha: 0.35),
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

                        // Footer: Sudah punya akun? Masuk
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text(
                              'Sudah punya akun? ',
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
