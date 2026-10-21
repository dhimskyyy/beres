import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category.dart';
import '../models/job.dart';
import '../models/job_feed_item.dart';
import 'tukang_service.dart';

/// Service untuk Manajemen Pekerjaan, Penawaran (Bid), dan Atomic Lock Tukang
/// (Milestone M3: FR-010, FR-011, FR-012, FR-020, FR-022, FR-027, BR-15, BR-16, BR-17, BR-21)
class JobService {
  final SupabaseClient _client;

  JobService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Mengambil daftar kategori pekerjaan aktif
  Future<List<JobCategory>> getActiveCategories() {
    return TukangService().getActiveCategories();
  }

  /// Mengambil pekerjaan aktif yang sedang dikunci untuk Mitra Tukang
  Future<Job?> getActiveLockedJobForTukang({String? tukangId}) async {
    final effectiveTukangId = tukangId ?? _client.auth.currentUser?.id;
    if (effectiveTukangId == null) return null;

    final response = await _client
        .from('jobs')
        .select()
        .eq('locked_tukang_id', effectiveTukangId)
        .inFilter('status', [
          'NEGOTIATING',
          'NOTA_APPROVED',
          'ON_THE_WAY',
          'ARRIVED',
          'WORKING',
          'CANCEL_PENDING',
        ])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return Job.fromJson(response);
  }

  /// Membatalkan pekerjaan berstatus OPEN oleh Pelanggan
  Future<void> cancelOpenJobByUser(String jobId) async {
    await _client
        .from('jobs')
        .update({
          'status': 'CANCELLED',
          'cancelled_at': DateTime.now().toIso8601String(),
        })
        .eq('id', jobId)
        .eq('status', 'OPEN');
  }

  /// Memposting pekerjaan baru oleh User (FR-010, BR-16)
  /// Mendukung validasi pin lokasi maksimal 2 km dari GPS HP User
  Future<Map<String, dynamic>> createJob({
    required String categoryId,
    required String description,
    required double latitude,
    required double longitude,
    required String areaLabel,
    required String addressFull,
    List<String> photoUrls = const [],
    double? deviceLat,
    double? deviceLng,
  }) async {
    final response = await _client.rpc(
      'rpc_create_job',
      params: {
        'p_category_id': categoryId,
        'p_description': description,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_area_label': areaLabel,
        'p_address_full': addressFull,
        'p_photo_urls': photoUrls,
        'p_device_lat': deviceLat,
        'p_device_lng': deviceLng,
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }

  /// Mengedit pekerjaan yang masih berstatus OPEN oleh User (FR-010)
  Future<Map<String, dynamic>> updateJob({
    required String jobId,
    required String categoryId,
    required String description,
    required double latitude,
    required double longitude,
    required String areaLabel,
    required String addressFull,
    List<String>? photoUrls,
  }) async {
    final response = await _client.rpc(
      'rpc_update_job',
      params: {
        'p_job_id': jobId,
        'p_category_id': categoryId,
        'p_description': description,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_area_label': areaLabel,
        'p_address_full': addressFull,
        'p_photo_urls': photoUrls,
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }

  /// Mengambil daftar pekerjaan milik User tertentu
  Future<List<Job>> getUserJobs({String? userId}) async {
    final effectiveUserId = userId ?? _client.auth.currentUser?.id;
    if (effectiveUserId == null) return [];

    final response = await _client
        .from('jobs')
        .select()
        .eq('user_id', effectiveUserId)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((json) => Job.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Mengambil detail satu pekerjaan berdasarkan ID
  Future<Job?> getJobById(String jobId) async {
    final response =
        await _client.from('jobs').select().eq('id', jobId).maybeSingle();

    if (response == null) return null;
    return Job.fromJson(response);
  }

  /// Mengambil foto-foto kerusakan pada pekerjaan
  Future<List<String>> getJobDamagePhotos(String jobId) async {
    final response = await _client
        .from('job_photos')
        .select('storage_path')
        .eq('job_id', jobId)
        .eq('type', 'DAMAGE');

    return (response as List<dynamic>)
        .map((e) => (e as Map<String, dynamic>)['storage_path'].toString())
        .toList();
  }

  /// Mengunggah foto kerusakan ke bucket publik 'job-photos'
  Future<String> uploadJobPhoto(Uint8List bytes, String filename) async {
    final path = 'damage/${DateTime.now().millisecondsSinceEpoch}_$filename';
    await _client.storage.from('job-photos').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from('job-photos').getPublicUrl(path);
  }

  /// Memperbarui status online/offline, radius kerja (0-50 km), dan lokasi dasar tukang (FR-020, FR-027)
  Future<Map<String, dynamic>> updateTukangStatusAndLocation({
    bool? isOnline,
    int? radiusKm,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _client.rpc(
      'rpc_update_tukang_status_and_location',
      params: {
        'p_is_online': isOnline,
        'p_radius_km': radiusKm,
        'p_latitude': latitude,
        'p_longitude': longitude,
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }

  /// Mengambil daftar pekerjaan terbuka untuk feed Mitra Tukang (FR-022, BR-16)
  /// Menghormati privasi sebelum lock (tanpa data sensitif user)
  Future<List<TukangJobFeedItem>> getOpenJobsForTukang({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _client.rpc(
      'rpc_get_open_jobs_for_tukang',
      params: {
        'p_limit': limit,
        'p_offset': offset,
      },
    );

    return (response as List<dynamic>)
        .map((json) => TukangJobFeedItem.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Mengajukan penawaran/lamaran (bid) pada sebuah job oleh Tukang (BR-10, BR-15, BR-21)
  /// Menegakkan KYC Approved, batas maks 5 lamaran aktif, dan kuota mingguan
  Future<Map<String, dynamic>> submitBid(String jobId) async {
    final response = await _client.rpc(
      'rpc_submit_bid',
      params: {'p_job_id': jobId},
    );

    return Map<String, dynamic>.from(response as Map);
  }

  /// Menarik kembali lamaran aktif oleh Tukang (Withdraw Bid)
  Future<Map<String, dynamic>> withdrawBid(
    String bidId, {
    String reason = 'Ditarik oleh mitra',
  }) async {
    final response = await _client.rpc(
      'rpc_withdraw_bid',
      params: {
        'p_bid_id': bidId,
        'p_reason': reason,
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }

  /// Mengambil daftar pelamar pada job milik User (FR-011, BR-16)
  Future<List<UserBidViewItem>> getJobBidsForUser(String jobId) async {
    final response = await _client.rpc(
      'rpc_get_job_bids_for_user',
      params: {'p_job_id': jobId},
    );

    return (response as List<dynamic>)
        .map((json) => UserBidViewItem.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Mengunci 1 mitra tukang dan secara atomik menarik seluruh lamaran tukang tersebut di job lain (FR-012, BR-17)
  Future<Map<String, dynamic>> lockTukang({
    required String jobId,
    required String bidId,
  }) async {
    final response = await _client.rpc(
      'rpc_lock_tukang',
      params: {
        'p_job_id': jobId,
        'p_bid_id': bidId,
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }
}
