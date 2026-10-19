import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beres_shared/beres_shared.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

class UserLoginScreen extends ConsumerStatefulWidget {
  const UserLoginScreen({super.key});

  @override
  ConsumerState<UserLoginScreen> createState() => _UserLoginScreenState();
}

class _UserLoginScreenState extends ConsumerState<UserLoginScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isOtpSent = false;
  bool _isLoading = false;
  bool _isNewUser = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
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

      // 1. Penegakan Mutlak BR-44: 1 Email = 1 Peran
      final checkResult = await authService.checkEmailRole(
        email: email,
        targetRole: UserRole.user,
      );

      if (checkResult.isRoleMismatch) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              checkResult.message ??
              'Email ini sudah terdaftar sebagai Mitra Tukang. Sesuai aturan Beres (BR-44), 1 email hanya boleh memiliki 1 peran.';
        });
        return;
      }

      if (checkResult.isDeleted) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              checkResult.message ??
              'Akun telah dinonaktifkan/dihapus (BR-45).';
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
                    'Akun dinonaktifkan permanen oleh Admin.',
                appealEmail: checkResult.appealEmail ?? 'support@beres.id',
                onSignOut: () =>
                    Navigator.of(context).pushReplacementNamed('/'),
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
                    'Akun ditangguhkan otomatis 2 hari karena akumulasi strike.',
                suspendedUntil: checkResult.suspendedUntil,
                onSignOut: () =>
                    Navigator.of(context).pushReplacementNamed('/'),
              ),
            ),
          );
        }
        return;
      }

      // 2. Kirim OTP via Email
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
          _errorMessage = 'Gagal mengirim OTP: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _handleVerifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      setState(() => _errorMessage = 'Masukkan 6 digit kode OTP.');
      return;
    }

    final fullName = _isNewUser
        ? _fullNameController.text.trim()
        : 'Pelanggan Beres';
    if (_isNewUser && fullName.isEmpty) {
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
          _errorMessage = 'Kode OTP salah atau kedaluwarsa. Silakan coba lagi.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(title: const Text('Masuk sebagai Pelanggan')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.userBadgeBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.person_pin_circle_outlined,
                    size: 36,
                    color: AppColors.trustCobalt,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Selamat Datang di Beres',
                style: AppTypography.headingLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Masuk dengan email untuk mulai memanggil tukang transparan tanpa biaya perantara.',
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.dangerCrimson.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: AppColors.dangerCrimson,
                        size: 22,
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
                const SizedBox(height: 20),
              ],

              // Tahap 1: Input Email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !_isOtpSent && !_isLoading,
                decoration: const InputDecoration(
                  labelText: 'Alamat Email',
                  hintText: 'nama@domain.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Tahap 2: Input OTP & Biodata (jika OTP sudah dikirim)
              if (_isOtpSent) ...[
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  enabled: !_isLoading,
                  style: AppTypography.otpCode,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    labelText: 'Kode OTP 6 Digit',
                    hintText: '123456',
                    counterText: '',
                    prefixIcon: Icon(Icons.lock_clock_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                if (_isNewUser) ...[
                  TextField(
                    controller: _fullNameController,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap',
                      hintText: 'Budi Santoso',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    enabled: !_isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Nomor WhatsApp / HP (Opsional)',
                      hintText: '081234567890',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

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
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => setState(() {
                          _isOtpSent = false;
                          _otpController.clear();
                        }),
                  child: const Text('Ganti Alamat Email'),
                ),
              ] else ...[
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
                      : const Text('Kirim Kode OTP'),
                ),
              ],

              const SizedBox(height: 24),
              // Footer info BR-44
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.shield_outlined,
                      color: AppColors.trustCobalt,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Aturan Beres (BR-44): 1 email hanya untuk 1 peran (Pelanggan atau Mitra Tukang).',
                        style: AppTypography.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
