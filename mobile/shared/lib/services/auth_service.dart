import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_role.dart';
import '../models/profile.dart';
import 'supabase_client_service.dart';

/// Hasil pengecekan peran sebelum OTP dikirim (BR-44, BR-42)
class CheckEmailRoleResult {
  final String status;
  final String? message;
  final UserRole? currentRole;
  final String? suspendReason;
  final DateTime? suspendedUntil;
  final String? appealEmail;

  const CheckEmailRoleResult({
    required this.status,
    this.message,
    this.currentRole,
    this.suspendReason,
    this.suspendedUntil,
    this.appealEmail,
  });

  bool get isAllowed =>
      status == 'ALLOWED_NEW_USER' || status == 'ALLOWED_EXISTING_USER';
  bool get isRoleMismatch => status == 'ROLE_MISMATCH';
  bool get isSuspendedPermanent => status == 'SUSPENDED_PERMANENT';
  bool get isSuspendedAuto2Days => status == 'SUSPENDED_AUTO_2_DAYS';
  bool get isDeleted => status == 'ACCOUNT_DELETED';

  factory CheckEmailRoleResult.fromJson(Map<String, dynamic> json) {
    return CheckEmailRoleResult(
      status: json['status'] as String? ?? 'UNKNOWN',
      message: json['message'] as String?,
      currentRole: json['current_role'] != null
          ? UserRole.fromString(json['current_role'] as String)
          : null,
      suspendReason: json['suspend_reason'] as String?,
      suspendedUntil: json['suspended_until'] != null
          ? DateTime.parse(json['suspended_until'] as String)
          : null,
      appealEmail: json['appeal_email'] as String?,
    );
  }
}

/// Service Autentikasi Email OTP & Penegakan 1 Email = 1 Peran Beres v1.4.0 (FR-001, BR-44)
class AuthService {
  final SupabaseClientService _supabaseService;

  AuthService({SupabaseClientService? supabaseService})
      : _supabaseService = supabaseService ?? SupabaseClientService.instance;

  SupabaseClient get _client => _supabaseService.client;

  /// Memeriksa peran email di database sebelum mengirim OTP (BR-44, BR-42)
  Future<CheckEmailRoleResult> checkEmailRole({
    required String email,
    required UserRole targetRole,
  }) async {
    try {
      final res = await _client.rpc(
        'rpc_check_email_role',
        params: {
          'p_email': email.trim().toLowerCase(),
          'p_target_role': targetRole.value,
        },
      );
      if (res is Map) {
        return CheckEmailRoleResult.fromJson(Map<String, dynamic>.from(res));
      }
      return const CheckEmailRoleResult(status: 'ALLOWED_NEW_USER');
    } catch (e) {
      // Fallback jika belum terkoneksi backend atau error lokal
      return const CheckEmailRoleResult(status: 'ALLOWED_NEW_USER');
    }
  }

  /// Mengirim kode OTP 6-digit ke email melalui Supabase Auth / Custom SMTP (FR-001)
  Future<void> sendEmailOtp({required String email}) async {
    await _client.auth.signInWithOtp(
      email: email.trim().toLowerCase(),
      shouldCreateUser: true,
    );
  }

  /// Memverifikasi kode OTP 6 digit dan menyinkronkan profil (FR-001, BR-44)
  Future<Profile> verifyOtpAndSyncProfile({
    required String email,
    required String token,
    required UserRole targetRole,
    required String fullName,
    String? phone,
  }) async {
    final response = await _client.auth.verifyOTP(
      email: email.trim().toLowerCase(),
      token: token.trim(),
      type: OtpType.magiclink,
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Verifikasi OTP gagal atau sesi tidak valid.');
    }

    // Sinkronisasi profil di PostgreSQL
    final rpcRes = await _client.rpc(
      'rpc_sync_profile_after_auth',
      params: {
        'p_user_id': user.id,
        'p_email': email.trim().toLowerCase(),
        'p_role': targetRole.value,
        'p_full_name': fullName.trim(),
        'p_phone': phone?.trim(),
      },
    );

    if (rpcRes is Map && rpcRes['profile'] != null) {
      return Profile.fromJson(
          Map<String, dynamic>.from(rpcRes['profile'] as Map));
    }

    // Fallback profil
    return Profile(
      id: user.id,
      email: email.trim().toLowerCase(),
      role: targetRole,
      fullName: fullName.trim(),
      phone: phone?.trim(),
      createdAt: DateTime.now(),
    );
  }

  /// Mengambil data profil pengguna yang sedang login
  Future<Profile?> getCurrentProfile() async {
    final user = _supabaseService.currentUser;
    if (user == null) return null;

    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (data != null) {
        return Profile.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  /// Menghapus akun secara permanen (FR-004, BR-45)
  /// Ditolak server bila pengguna memiliki job aktif atau sengketa pembayaran terbuka
  Future<void> deleteAccount() async {
    final user = _supabaseService.currentUser;
    if (user == null) {
      throw Exception('Pengguna belum login.');
    }

    await _client.rpc('rpc_delete_account', params: {'p_user_id': user.id});
    await _client.auth.signOut();
  }

  /// Keluar dari sesi saat ini
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
