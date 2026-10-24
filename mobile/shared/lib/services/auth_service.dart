import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_role.dart';
import '../models/profile.dart';
import '../utils/formatters.dart';
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
  bool get isNewUser => status == 'ALLOWED_NEW_USER';
  bool get isExistingUser => status == 'ALLOWED_EXISTING_USER';
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

  /// Masuk dengan Email dan Password tradisional
  Future<Profile> signInWithPassword({
    required String email,
    required String password,
    required UserRole expectedRole,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    final user = response.user;
    if (user == null) {
      throw Exception('Login gagal. Periksa kembali email dan password Anda.');
    }

    try {
      final rpcRes = await _client.rpc(
        'rpc_sync_profile_after_auth',
        params: {
          'p_user_id': user.id,
          'p_email': user.email ?? email.trim().toLowerCase(),
          'p_role': expectedRole.value,
          'p_full_name':
              (user.userMetadata?['full_name'] as String?) ?? 'Pengguna Beres',
        },
      );

      if (rpcRes is Map && rpcRes['profile'] != null) {
        final profileMap = Map<String, dynamic>.from(rpcRes['profile'] as Map);
        if (profileMap['created_at'] == null) {
          profileMap['created_at'] = DateTime.now().toIso8601String();
        }
        return Profile.fromJson(profileMap);
      }
    } catch (_) {}

    final current = await getCurrentProfile();
    if (current != null) return current;

    return Profile(
      id: user.id,
      email: user.email ?? email.trim().toLowerCase(),
      role: expectedRole,
      fullName:
          (user.userMetadata?['full_name'] as String?) ?? 'Pengguna Beres',
      createdAt: DateTime.now(),
    );
  }

  /// Mendaftar dengan Email dan Password tradisional
  Future<Profile> signUpWithPassword({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    required UserRole role,
  }) async {
    final validationError =
        BeresPasswordValidation.check(password).errorMessage;
    if (validationError != null) {
      throw Exception(validationError);
    }

    final response = await _client.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        'role': role.value,
      },
    );

    var user = response.user;
    if (user == null) {
      throw Exception('Pendaftaran gagal. Silakan coba kembali.');
    }

    // Pastikan session aktif di client (bila Supabase belum membuat session saat signUp)
    if (response.session == null) {
      try {
        final loginRes = await _client.auth.signInWithPassword(
          email: email.trim().toLowerCase(),
          password: password,
        );
        user = loginRes.user ?? user;
      } catch (_) {}
    }

    final activeUser = user!;

    try {
      final rpcRes = await _client.rpc(
        'rpc_sync_profile_after_auth',
        params: {
          'p_user_id': activeUser.id,
          'p_email': email.trim().toLowerCase(),
          'p_role': role.value,
          'p_full_name': fullName.trim(),
          'p_phone': phone?.trim(),
        },
      );

      if (rpcRes is Map && rpcRes['profile'] != null) {
        final profileMap = Map<String, dynamic>.from(rpcRes['profile'] as Map);
        if (profileMap['created_at'] == null) {
          profileMap['created_at'] = DateTime.now().toIso8601String();
        }
        return Profile.fromJson(profileMap);
      }
    } catch (_) {}

    return Profile(
      id: activeUser.id,
      email: email.trim().toLowerCase(),
      role: role,
      fullName: fullName.trim(),
      phone: phone?.trim(),
      createdAt: DateTime.now(),
    );
  }

  /// Mengirim kode OTP untuk reset password
  Future<void> sendPasswordResetOtp({required String email}) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Cek status akun di rpc_check_email_role
    final check = await checkEmailRole(
      email: cleanEmail,
      targetRole: UserRole.user,
    );

    if (check.isNewUser) {
      throw Exception(
        'Akun dengan email ini tidak ditemukan. Silakan lakukan pendaftaran terlebih dahulu.',
      );
    }
    if (check.isDeleted) {
      throw Exception('Akun dengan email ini telah dinonaktifkan.');
    }
    if (check.isSuspendedPermanent) {
      throw Exception('Akun telah dinonaktifkan permanen oleh operasional.');
    }
    if (check.isSuspendedAuto2Days) {
      throw Exception(
        check.suspendReason ??
            'Akun sedang ditangguhkan sementara selama 48 jam.',
      );
    }

    // 2. Proteksi lapis ganda: Pastikan profil memang ada di tabel profiles
    final profile = await _client
        .from('profiles')
        .select('id')
        .eq('email', cleanEmail)
        .maybeSingle();

    if (profile == null) {
      throw Exception(
        'Akun dengan email ini tidak ditemukan. Silakan lakukan pendaftaran terlebih dahulu.',
      );
    }

    // 3. Kirim OTP Supabase
    await _client.auth.signInWithOtp(
      email: cleanEmail,
      shouldCreateUser: false,
    );
  }

  /// Verifikasi kode OTP 6 digit dan perbarui password, lalu kembalikan Profil
  Future<Profile> verifyOtpAndResetPassword({
    required String email,
    required String otp,
    required String newPassword,
    required UserRole expectedRole,
  }) async {
    final validationError =
        BeresPasswordValidation.check(newPassword).errorMessage;
    if (validationError != null) {
      throw Exception(validationError);
    }

    // 1. Verifikasi OTP
    final response = await _client.auth.verifyOTP(
      email: email.trim().toLowerCase(),
      token: otp.trim(),
      type: OtpType.email,
    );

    final user = response.user;
    if (user == null) {
      throw Exception('Kode OTP tidak valid atau telah kedaluwarsa.');
    }

    // 2. Perbarui Password Baru
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );

    // 3. Sinkronisasi Profil
    try {
      final rpcRes = await _client.rpc(
        'rpc_sync_profile_after_auth',
        params: {
          'p_user_id': user.id,
          'p_email': user.email ?? email.trim().toLowerCase(),
          'p_role': expectedRole.value,
          'p_full_name':
              (user.userMetadata?['full_name'] as String?) ?? 'Pelanggan Beres',
        },
      );

      if (rpcRes is Map && rpcRes['profile'] != null) {
        final profileMap = Map<String, dynamic>.from(rpcRes['profile'] as Map);
        if (profileMap['created_at'] == null) {
          profileMap['created_at'] = DateTime.now().toIso8601String();
        }
        return Profile.fromJson(profileMap);
      }
    } catch (_) {}

    final current = await getCurrentProfile();
    if (current != null) return current;

    return Profile(
      id: user.id,
      email: user.email ?? email.trim().toLowerCase(),
      role: expectedRole,
      fullName:
          (user.userMetadata?['full_name'] as String?) ?? 'Pelanggan Beres',
      createdAt: DateTime.now(),
    );
  }

  /// Mengirim email tautan atur ulang password (Lupa Password)
  Future<void> resetPasswordForEmail({required String email}) async {
    await _client.auth.resetPasswordForEmail(email.trim().toLowerCase());
  }

  /// Masuk dengan Google OAuth
  Future<bool> signInWithGoogle({String? redirectTo}) async {
    return await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo ?? 'beres://auth-callback',
    );
  }

  /// Sinkronisasi profil otomatis setelah login OAuth (Google)
  Future<Profile?> syncOAuthProfile(User user,
      {UserRole role = UserRole.user}) async {
    final meta = user.userMetadata ?? {};
    final fullName = (meta['full_name'] as String?) ??
        (meta['name'] as String?) ??
        (user.email != null ? user.email!.split('@').first : 'Pelanggan');

    try {
      final res = await _client.rpc(
        'rpc_sync_profile_after_auth',
        params: {
          'p_user_id': user.id,
          'p_email': user.email ?? '',
          'p_role': role.value,
          'p_full_name': fullName,
          'p_phone': user.phone,
        },
      );
      if (res is Map && res['profile'] != null) {
        final profileMap = Map<String, dynamic>.from(res['profile'] as Map);
        if (profileMap['created_at'] == null) {
          profileMap['created_at'] = DateTime.now().toIso8601String();
        }
        return Profile.fromJson(profileMap);
      }
    } catch (_) {}
    return await getCurrentProfile();
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
      type: OtpType.email,
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
    final user = _supabaseService.currentUser ?? _client.auth.currentUser;
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

  /// Mengunggah foto profil pengguna ke Supabase Storage (bucket avatars)
  Future<String> uploadAvatar(XFile file) async {
    final user = _supabaseService.currentUser;
    if (user == null) {
      throw Exception('Pengguna belum login.');
    }

    final bytes = await file.readAsBytes();
    final ext = file.name.split('.').last.toLowerCase();
    final mimeType = ext == 'png'
        ? 'image/png'
        : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
    final filePath =
        '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _client.storage.from('avatars').uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: mimeType,
          ),
        );

    final publicUrl = _client.storage.from('avatars').getPublicUrl(filePath);

    await _client.from('profiles').update({
      'avatar_url': publicUrl,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', user.id);

    return publicUrl;
  }

  /// Menghapus foto profil pengguna (set avatar_url menjadi null)
  Future<void> deleteAvatar() async {
    final user = _supabaseService.currentUser;
    if (user == null) {
      throw Exception('Pengguna belum login.');
    }

    await _client.from('profiles').update({
      'avatar_url': null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', user.id);
  }

  /// Memperbarui nama lengkap, nomor telepon, foto profil, tempat & tanggal lahir pengguna
  Future<Profile> updateProfile({
    required String fullName,
    String? phone,
    String? avatarUrl,
    String? birthPlace,
    DateTime? birthDate,
  }) async {
    final user = _supabaseService.currentUser;
    if (user == null) {
      throw Exception('Pengguna belum login.');
    }

    final updateData = <String, dynamic>{
      'full_name': fullName.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (phone != null) {
      updateData['phone'] = phone.trim().isEmpty ? null : phone.trim();
    }
    if (avatarUrl != null) {
      updateData['avatar_url'] = avatarUrl;
    }
    if (birthPlace != null) {
      updateData['birth_place'] =
          birthPlace.trim().isEmpty ? null : birthPlace.trim();
    }
    if (birthDate != null) {
      updateData['birth_date'] =
          birthDate.toIso8601String().split('T').first;
    }

    final res = await _client
        .from('profiles')
        .update(updateData)
        .eq('id', user.id)
        .select()
        .single();

    try {
      await _client.auth.updateUser(
        UserAttributes(
          data: {'full_name': fullName.trim()},
        ),
      );
    } catch (_) {}

    return Profile.fromJson(res);
  }

  /// Mengirim tautan / kode verifikasi email dari Profile
  Future<void> sendEmailVerificationLink({required String email}) async {
    final cleanEmail = email.trim().toLowerCase();
    try {
      await _client.auth.resend(
        type: OtpType.signup,
        email: cleanEmail,
        emailRedirectTo: 'beres://auth-callback',
      );
    } catch (_) {
      await _client.auth.signInWithOtp(
        email: cleanEmail,
        emailRedirectTo: 'beres://auth-callback',
        shouldCreateUser: false,
      );
    }
  }

  /// Verifikasi kode OTP email dan tandai profil terverifikasi
  Future<bool> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    try {
      try {
        await _client.auth.verifyOTP(
          email: email.trim().toLowerCase(),
          token: token.trim(),
          type: OtpType.email,
        );
      } catch (_) {
        await _client.auth.verifyOTP(
          email: email.trim().toLowerCase(),
          token: token.trim(),
          type: OtpType.signup,
        );
      }

      await markEmailAsVerified();
      return true;
    } catch (e) {
      throw Exception(BeresFormatters.formatAuthError(e));
    }
  }

  /// Menandai email profil saat ini sebagai terverifikasi di database
  Future<void> markEmailAsVerified() async {
    await _client.rpc('rpc_verify_profile_email');
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
