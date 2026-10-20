import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/location_ping.dart';
import '../models/nota.dart';

/// Service untuk Live GPS Tracking, Kedatangan 50m/200m, Eksekusi Kerja,
/// Penyelesaian Tugas (BR-32), dan Laporan Sengketa Pembayaran (BR-67).
class TrackingService {
  final SupabaseClient _client;

  TrackingService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Mengirimkan ping lokasi tukang secara real-time (FR-016, FR-024, BR-60)
  /// Otomatis mentransisikan job ke ARRIVED jika jarak <= 50 meter dan akurasi <= 30m.
  Future<Map<String, dynamic>> recordLocationPing({
    required String jobId,
    required double latitude,
    required double longitude,
    double? accuracyM,
    double? heading,
    double? speed,
  }) async {
    final response = await _client.rpc(
      'rpc_record_location_ping',
      params: {
        'p_job_id': jobId,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_accuracy_m': accuracyM,
        'p_heading': heading,
        'p_speed': speed,
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }

  /// Konfirmasi kedatangan manual oleh Tukang jika jarak <= 200 meter (BR-61)
  Future<Map<String, dynamic>> confirmArrivalManual({
    required String jobId,
    required double latitude,
    required double longitude,
  }) async {
    final response = await _client.rpc(
      'rpc_confirm_arrival_manual',
      params: {
        'p_job_id': jobId,
        'p_latitude': latitude,
        'p_longitude': longitude,
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }

  /// Tukang menekan tombol manual Mulai Bekerja (BR-62)
  /// Mentransisikan status dari ARRIVED ke WORKING.
  Future<Map<String, dynamic>> startWork({
    required String jobId,
  }) async {
    final response = await _client.rpc(
      'rpc_start_work',
      params: {
        'p_job_id': jobId,
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }

  /// Menyelesaikan tugas pekerjaan oleh Tukang dengan penegakan BR-32
  /// Syarat: >= 1 Foto Hasil Kerja, metode bayar aktual, centang pembayaran,
  /// screenshot bukti transfer jika non-tunai, dan tidak ada Revisi Nota berstatus SENT.
  Future<Map<String, dynamic>> completeJob({
    required String jobId,
    required PaymentMethod actualPaymentMethod,
    required bool userPaidConfirmed,
    required List<String> workPhotos,
    String? paymentProofPhoto,
    String? completionNote,
  }) async {
    final response = await _client.rpc(
      'rpc_complete_job',
      params: {
        'p_job_id': jobId,
        'p_actual_payment_method': actualPaymentMethod.value,
        'p_user_paid_confirmed': userPaidConfirmed,
        'p_work_photos': workPhotos,
        'p_payment_proof_photo': paymentProofPhoto,
        'p_completion_note': completionNote,
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }

  /// Tukang melaporkan masalah pembayaran (User tidak bayar / bayar kurang) (BR-67)
  /// Melepas ikatan job aktif tukang sementara dan masuk antrean prioritas Admin.
  Future<Map<String, dynamic>> reportPaymentDispute({
    required String jobId,
    required String description,
    required List<String> workPhotos,
    List<String> evidencePhotos = const [],
  }) async {
    final response = await _client.rpc(
      'rpc_report_payment_dispute',
      params: {
        'p_job_id': jobId,
        'p_description': description,
        'p_work_photos': workPhotos,
        'p_evidence_photos': evidencePhotos,
      },
    );

    return Map<String, dynamic>.from(response as Map);
  }

  /// Mengunggah Foto Hasil Kerja ke storage Supabase
  Future<String> uploadWorkResultPhoto(Uint8List bytes, String filename) async {
    final path = 'work/${DateTime.now().millisecondsSinceEpoch}_$filename';
    await _client.storage.from('job-photos').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from('job-photos').getPublicUrl(path);
  }

  /// Mengunggah Foto Bukti Bayar Non-Tunai ke storage Supabase
  Future<String> uploadPaymentProofPhoto(
      Uint8List bytes, String filename) async {
    final path = 'payment/${DateTime.now().millisecondsSinceEpoch}_$filename';
    await _client.storage.from('job-photos').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from('job-photos').getPublicUrl(path);
  }

  /// Stream ping lokasi tukang secara real-time untuk job tertentu
  Stream<List<LocationPing>> streamLocationPings(String jobId) {
    return _client
        .from('location_pings')
        .stream(primaryKey: ['id'])
        .eq('job_id', jobId)
        .order('recorded_at', ascending: false)
        .limit(1)
        .map((records) => records
            .map((item) =>
                LocationPing.fromJson(Map<String, dynamic>.from(item)))
            .toList());
  }

  /// Mengambil ping lokasi terakhir untuk job tertentu
  Future<LocationPing?> getLatestLocationPing(String jobId) async {
    final response = await _client
        .from('location_pings')
        .select()
        .eq('job_id', jobId)
        .order('recorded_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return LocationPing.fromJson(Map<String, dynamic>.from(response));
  }
}
