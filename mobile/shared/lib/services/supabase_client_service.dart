import 'package:supabase_flutter/supabase_flutter.dart';

/// Service Singleton Wrapper untuk Supabase Client Beres v1.4.0
class SupabaseClientService {
  static SupabaseClientService? _instance;
  static SupabaseClientService get instance => _instance ??= SupabaseClientService._();

  SupabaseClientService._();

  /// Inisialisasi Supabase
  static Future<void> initialize({
    required String supabaseUrl,
    required String supabaseAnonKey,
  }) async {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabaseAnonKey,
    );
  }

  /// Client getter
  SupabaseClient get client => Supabase.instance.client;

  /// Auth getter
  GoTrueClient get auth => client.auth;

  /// User getter saat ini
  User? get currentUser => client.auth.currentUser;

  /// ID User saat ini
  String? get currentUserId => client.auth.currentUser?.id;

  /// Cek apakah pengguna sudah login
  bool get isAuthenticated => currentUser != null;
}
