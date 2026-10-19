import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category.dart';
import '../models/tukang_profile.dart';
import 'supabase_client_service.dart';

/// Service untuk Manajemen Profil Mitra Tukang, Keahlian, & Rekening (FR-002, BR-06)
class TukangService {
  final SupabaseClientService _supabaseService;

  TukangService({SupabaseClientService? supabaseService})
      : _supabaseService = supabaseService ?? SupabaseClientService.instance;

  SupabaseClient get _client => _supabaseService.client;

  /// Mengambil seluruh kategori jasa aktif dari database
  Future<List<JobCategory>> getActiveCategories() async {
    try {
      final data = await _client
          .from('categories')
          .select()
          .eq('is_active', true)
          .order('sort_order', ascending: true);
      return (data as List).map((e) => JobCategory.fromJson(e)).toList();
    } catch (e) {
      final fallbackDate = DateTime(2026, 1, 1);
      return [
        JobCategory(
            id: '1',
            slug: 'bangunan',
            name: 'Tukang Bangunan',
            iconName: 'construction',
            createdAt: fallbackDate),
        JobCategory(
            id: '2',
            slug: 'listrik',
            name: 'Tukang Listrik',
            iconName: 'electrical_services',
            createdAt: fallbackDate),
        JobCategory(
            id: '3',
            slug: 'pipa-plumbing',
            name: 'Tukang Pipa & Air',
            iconName: 'plumbing',
            createdAt: fallbackDate),
        JobCategory(
            id: '4',
            slug: 'cleaning-service',
            name: 'Cleaning Service & AC',
            iconName: 'cleaning_services',
            createdAt: fallbackDate),
        JobCategory(
            id: '5',
            slug: 'bengkel-motor',
            name: 'Bengkel Motor Panggilan',
            iconName: 'two_wheeler',
            createdAt: fallbackDate),
        JobCategory(
            id: '6',
            slug: 'bengkel-mobil',
            name: 'Bengkel Mobil Panggilan',
            iconName: 'directions_car',
            createdAt: fallbackDate),
        JobCategory(
            id: '7',
            slug: 'tukang-kayu',
            name: 'Tukang Kayu & Mebel',
            iconName: 'carpenter',
            createdAt: fallbackDate),
      ];
    }
  }

  /// Mengambil profil tukang beserta kategori keahlian
  Future<TukangProfile?> getTukangProfile(String userId) async {
    try {
      final data = await _client
          .from('tukang_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (data != null) {
        return TukangProfile.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  /// Memperbarui biodata, radius, rekening bank / e-wallet, dan kategori keahlian (FR-002, BR-06, BR-20)
  Future<void> updateTukangProfile({
    required String tukangId,
    required String bio,
    required int radiusKm,
    required List<Map<String, dynamic>> paymentAccounts,
    required List<String> categoryIds,
  }) async {
    await _client.rpc(
      'rpc_update_tukang_profile',
      params: {
        'p_tukang_id': tukangId,
        'p_bio': bio.trim(),
        'p_radius_km': radiusKm,
        'p_payment_accounts': paymentAccounts,
        'p_category_ids': categoryIds,
      },
    );
  }

  /// Mengambil data pengajuan KYC terakhir milik tukang (FR-003)
  Future<Map<String, dynamic>?> getLatestKycDocument(String tukangId) async {
    try {
      final data = await _client
          .from('kyc_documents')
          .select()
          .eq('tukang_id', tukangId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return data;
    } catch (_) {
      return null;
    }
  }

  /// Mengunggah file ke bucket privat kyc-private (FR-003)
  Future<String> uploadKycFile({
    required String tukangId,
    required String fileName,
    required List<int> fileBytes,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'kyc-documents/$tukangId/${timestamp}_$fileName';
    await _client.storage.from('kyc-private').uploadBinary(
          path,
          fileBytes as dynamic,
        );
    return path;
  }

  /// Submit dokumen KYC ke database (FR-003)
  Future<void> submitKycDocument({
    required String tukangId,
    required String ktpStoragePath,
    required String selfieStoragePath,
  }) async {
    await _client.rpc(
      'rpc_submit_kyc_document',
      params: {
        'p_tukang_id': tukangId,
        'p_ktp_storage_path': ktpStoragePath,
        'p_selfie_storage_path': selfieStoragePath,
      },
    );
  }
}
