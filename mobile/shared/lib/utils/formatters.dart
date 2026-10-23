import 'package:intl/intl.dart';

/// Formatter Utilitas Ekosistem Beres v1.4.0
typedef Formatters = BeresFormatters;

class BeresFormatters {
  /// Format Rupiah integer tanpa desimal (BR-01, BR-05)
  /// Contoh: 150000 -> "Rp 150.000"
  static String formatRupiah(int amount) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    return currencyFormatter.format(amount);
  }

  /// Alias untuk formatRupiah
  static String formatCurrency(int amount) => formatRupiah(amount);

  /// Format durasi detik ke format MM:SS untuk countdown timer (BR-31, BR-70)
  /// Contoh: 1800 detik -> "30:00"
  static String formatCountdown(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00';
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Format tanggal lokal Indonesia
  static String formatDateTime(DateTime dateTime) {
    final formatter = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    return formatter.format(dateTime);
  }

  /// Format jam lokal (HH:mm)
  static String formatTime(DateTime dateTime) {
    final formatter = DateFormat('HH:mm', 'id_ID');
    return formatter.format(dateTime);
  }

  /// Format jarak dalam kilometer
  /// Contoh: 2.35 -> "2.4 km"
  static String formatDistance(double km) {
    return '${km.toStringAsFixed(1)} km';
  }

  /// Format pesan error autentikasi & sistem ke bahasa Indonesia yang ramah pengguna
  static String formatAuthError(dynamic error) {
    if (error == null) return '';

    final raw = error.toString();
    final lower = raw.toLowerCase();

    // 1. Password salah / Invalid login credentials
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_credentials') ||
        lower.contains('invalid username or password')) {
      return 'Email atau password yang Anda masukkan salah. Silakan periksa kembali.';
    }

    // 2. Akun tidak ditemukan
    if (lower.contains('user not found') ||
        lower.contains('user_not_found')) {
      return 'Akun dengan email ini tidak ditemukan.';
    }

    // 3. Email belum konfirmasi
    if (lower.contains('email not confirmed')) {
      return 'Email belum dikonfirmasi. Silakan periksa kotak masuk atau spam email Anda.';
    }

    // 4. Rate limit / Terlalu banyak percobaan
    if (lower.contains('rate limit') ||
        lower.contains('over_email_send_rate_limit') ||
        lower.contains('too many requests')) {
      return 'Terlalu banyak permintaan dalam waktu singkat. Silakan tunggu beberapa saat.';
    }

    // 5. OTP kadaluwarsa / salah
    if (lower.contains('token has expired') ||
        lower.contains('token is invalid') ||
        lower.contains('otp_expired') ||
        lower.contains('invalid token')) {
      return 'Kode OTP tidak valid atau telah kedaluwarsa. Silakan minta kode baru.';
    }

    // 6. Email sudah terdaftar
    if (lower.contains('already registered') ||
        lower.contains('user already exists') ||
        lower.contains('user_already_exists')) {
      return 'Email ini sudah terdaftar. Silakan masuk menggunakan akun Anda.';
    }

    // 7. Password lemah
    if (lower.contains('weak password') ||
        lower.contains('password should be at least')) {
      return 'Password terlalu lemah. Gunakan minimal 6 karakter.';
    }

    // 8. Password baru sama dengan lama
    if (lower.contains('same_password') ||
        lower.contains('should be different from the old password')) {
      return 'Password baru tidak boleh sama dengan password sebelumnya.';
    }

    // 9. Jaringan / Koneksi Internet
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('networkrequestfailed') ||
        lower.contains('clientexception')) {
      return 'Koneksi internet bermasalah. Periksa jaringan Anda dan coba lagi.';
    }

    // 10. Jika ada AuthApiException(message: ...) ambil message-nya
    final apiMatch = RegExp(r'message:\s*([^,\)]+)').firstMatch(raw);
    if (apiMatch != null) {
      final msg = apiMatch.group(1)?.trim();
      if (msg != null && msg.isNotEmpty) {
        return msg;
      }
    }

    // 11. Bersihkan prefix teknis umum
    return raw
        .replaceAll(RegExp(r'\s*\((BR|FR)-[0-9a-zA-Z]+\)'), '')
        .replaceAll(RegExp(r'AuthApiException\([^)]*\)'), '')
        .replaceFirst('AuthApiException: ', '')
        .replaceFirst('AuthException: ', '')
        .replaceFirst('Exception: ', '')
        .trim();
  }
}

/// Validasi Password Kuat Standar Profesional Beres
class BeresPasswordValidation {
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasDigit;
  final bool hasSymbol;

  const BeresPasswordValidation({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasDigit,
    required this.hasSymbol,
  });

  bool get isValid =>
      hasMinLength && hasUppercase && hasLowercase && hasDigit && hasSymbol;

  static BeresPasswordValidation check(String password) {
    return BeresPasswordValidation(
      hasMinLength: password.length >= 8,
      hasUppercase: RegExp(r'[A-Z]').hasMatch(password),
      hasLowercase: RegExp(r'[a-z]').hasMatch(password),
      hasDigit: RegExp(r'[0-9]').hasMatch(password),
      hasSymbol:
          RegExp(r'[!@#$%^&*()_+\-=\[\]{};\x27:"\\|,.<>/?`~]').hasMatch(password),
    );
  }

  String? get errorMessage {
    if (!hasMinLength) {
      return 'Password minimal terdiri dari 8 karakter.';
    }
    if (!hasUppercase) {
      return 'Password harus mengandung minimal 1 huruf besar (A-Z).';
    }
    if (!hasLowercase) {
      return 'Password harus mengandung minimal 1 huruf kecil (a-z).';
    }
    if (!hasDigit) {
      return 'Password harus mengandung minimal 1 angka (0-9).';
    }
    if (!hasSymbol) {
      return 'Password harus mengandung minimal 1 simbol (!, @, #, dll).';
    }
    return null;
  }
}
