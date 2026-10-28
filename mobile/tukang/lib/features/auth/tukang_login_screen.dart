import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beres_shared/beres_shared.dart';

import 'widgets/auth_hero_header.dart';
import 'widgets/auth_text_field.dart';
import 'widgets/google_logo.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class TukangLoginScreen extends ConsumerStatefulWidget {
  const TukangLoginScreen({super.key});

  @override
  ConsumerState<TukangLoginScreen> createState() => _TukangLoginScreenState();
}

class _TukangLoginScreenState extends ConsumerState<TukangLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isOAuthFlow = false;
  String? _errorMessage;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    try {
      _authSubscription = SupabaseClientService
          .instance.client.auth.onAuthStateChange
          .listen((data) async {
        final session = data.session;
        final isGoogleProvider =
            (session?.user.appMetadata['provider'] as String?) == 'google';
        if (session != null && (_isOAuthFlow || isGoogleProvider) && mounted) {
          _isOAuthFlow = false;
          bool needsOnboarding = false;
          try {
            final authService = ref.read(authServiceProvider);
            final existingProfile = await authService.getCurrentProfile();
            if (existingProfile == null ||
                existingProfile.role == UserRole.user) {
              needsOnboarding = true;
            }
            await authService.syncOAuthProfile(
              session.user,
              role: UserRole.tukang,
            );
          } catch (_) {}
          if (mounted) {
            if (needsOnboarding) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Silakan lengkapi pendaftaran & profil keahlian Mitra Tukang Anda terlebih dahulu.',
                  ),
                  backgroundColor: AppColors.safetyOrange,
                ),
              );
              context.go('/onboarding');
            } else {
              context.go('/home');
            }
          }
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _cleanMessage(dynamic raw) {
    return BeresFormatters.formatAuthError(raw);
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Masukkan alamat email yang valid.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Password wajib diisi.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);

      // 1. Cek status suspend atau deleted sebelum login (BR-42, BR-44)
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

      if (checkResult.isSuspendedPermanent) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => SuspendScreen(
                isPermanent: true,
                reason: checkResult.suspendReason ??
                    'Akun mitra dinonaktifkan permanen oleh tim operasional.',
                appealEmail: checkResult.appealEmail ?? 'support@beres.id',
                onSignOut: () =>
                    Navigator.of(context).pushReplacementNamed('/login'),
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
                reason: checkResult.suspendReason ??
                    'Akun mitra ditangguhkan sementara selama 48 jam.',
                suspendedUntil: checkResult.suspendedUntil,
                onSignOut: () =>
                    Navigator.of(context).pushReplacementNamed('/login'),
              ),
            ),
          );
        }
        return;
      }

      // Proteksi BR-44: Jika email baru terdaftar sebagai USER (belum pernah daftar jadi Mitra Tukang),
      // tolak login dan arahkan untuk mendaftar sebagai mitra terlebih dahulu.
      if (checkResult.isExistingUser &&
          !checkResult.hasRoleFor(UserRole.tukang)) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Email ini terdaftar sebagai akun Pelanggan. Untuk masuk sebagai Mitra Tukang, silakan lakukan pendaftaran mitra terlebih dahulu melalui tombol Daftar Mitra.';
        });
        return;
      }

      // 2. Autentikasi Email + Password
      await authService.signInWithPassword(
        email: email,
        password: password,
        expectedRole: UserRole.tukang,
      );

      if (mounted) {
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

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _isOAuthFlow = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithGoogle();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isOAuthFlow = false;
          _errorMessage =
              'Gagal masuk menggunakan Google. Silakan coba kembali.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final heroHeight = (screenHeight * 0.32).clamp(230.0, 270.0);

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
            // 1. Hero Workshop & Logo Area
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AuthHeroHeader(
                height: heroHeight + 36,
                showBackButton: false,
                subtitleBadge: 'MITRA TUKANG',
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
                            'Selamat Datang Mitra',
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
                            'Silahkan Masuk ke Akun Mitra Tukang Anda',
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

                          const SizedBox(height: 22),

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

                          const SizedBox(height: 16),

                          // Field Password
                          AuthTextField(
                            label: 'Password',
                            hintText: '••••••••',
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

                          const SizedBox(height: 10),

                          // Lupa Password Button
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: _isLoading
                                  ? null
                                  : () => context.push('/forgot-password'),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  'Lupa Password?',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.safetyOrange,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Primary Button "MASUK"
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
                              onPressed: _isLoading ? null : _handleLogin,
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
                                      'MASUK',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Divider "Atau masuk dengan"
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  'Atau masuk dengan',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: const Color(0xFFE2E8F0),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // Button "Masuk menggunakan Google"
                          SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: const Color(0xFFF8FAFC),
                                side: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                elevation: 0,
                              ),
                              onPressed:
                                  _isLoading ? null : _handleGoogleSignIn,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  GoogleLogo(size: 18),
                                  SizedBox(width: 10),
                                  Text(
                                    'Masuk menggunakan Google',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Footer: Belum punya akun? Daftar Disini
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text(
                                'Ingin bergabung sebagai mitra? ',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              GestureDetector(
                                onTap: _isLoading
                                    ? null
                                    : () => context.push('/register'),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 4),
                                  child: Text(
                                    'Daftar Disini',
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
