import 'package:supabase_flutter/supabase_flutter.dart';

/// Layanan Alur Pembatalan & Sistem Strike (Milestone M6)
/// Mendukung BR-50 s/d BR-57, BR-71, FR-018, FR-026, FR-028
class CancellationService {
  final SupabaseClient _client;

  CancellationService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// 1. Tukang membuat draft pembatalan (BR-50, BR-51)
  /// Draft tidak mengubah status pekerjaan di database
  Future<Map<String, dynamic>> createTukangCancelDraft(String jobId) async {
    final response = await _client.rpc(
      'rpc_tukang_create_cancel_draft',
      params: {'p_job_id': jobId},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  /// 2. Tukang membatalkan draft jika menekan tombol Kembali (BR-51)
  Future<void> abortTukangCancelDraft(String cancelRequestId) async {
    await _client.rpc(
      'rpc_tukang_abort_cancel_draft',
      params: {'p_cancel_request_id': cancelRequestId},
    );
  }

  /// 3. Tukang mengirim form pembatalan resmi (BR-53)
  /// Status job berubah menjadi CANCEL_PENDING
  Future<Map<String, dynamic>> submitTukangCancelRequest({
    required String cancelRequestId,
    required String reasonCategory,
    required String reasonText,
    String? adminNotes,
    List<String> evidencePhotos = const [],
    double? latitude,
    double? longitude,
  }) async {
    final response = await _client.rpc(
      'rpc_tukang_submit_cancel_request',
      params: {
        'p_cancel_request_id': cancelRequestId,
        'p_reason_category': reasonCategory,
        'p_reason_text': reasonText,
        'p_admin_notes': adminNotes,
        'p_evidence_photos': evidencePhotos,
        'p_latitude': latitude,
        'p_longitude': longitude,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  /// 4. User merespons pembatalan dari Tukang (BR-55)
  /// Jika setuju: job -> OPEN, Tukang +1 Strike (BR-55, BR-57)
  /// Jika tolak: job kembali ke status_before_cancel
  Future<Map<String, dynamic>> userRespondToTukangCancel({
    required String jobId,
    required bool approved,
    String? decisionNotes,
  }) async {
    final response = await _client.rpc(
      'rpc_user_respond_to_tukang_cancel',
      params: {
        'p_job_id': jobId,
        'p_approved': approved,
        'p_decision_notes': decisionNotes,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  /// 5. User mengajukan pembatalan saat ON_THE_WAY >= 3 jam belum tiba (FR-018, BR-56b)
  Future<Map<String, dynamic>> userRequestCancelOtw3h({
    required String jobId,
    required String reasonCategory,
    required String reasonText,
    String actionAfterCancel = 'OPEN',
  }) async {
    final response = await _client.rpc(
      'rpc_user_request_cancel_otw_3h',
      params: {
        'p_job_id': jobId,
        'p_reason_category': reasonCategory,
        'p_reason_text': reasonText,
        'p_action_after_cancel': actionAfterCancel,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  /// 6. Tukang merespons pengajuan pembatalan 3 jam OTW dari User (BR-56b)
  Future<Map<String, dynamic>> tukangRespondToUserCancel({
    required String jobId,
    required bool approved,
  }) async {
    final response = await _client.rpc(
      'rpc_tukang_respond_to_user_cancel',
      params: {
        'p_job_id': jobId,
        'p_approved': approved,
      },
    );
    return Map<String, dynamic>.from(response as Map);
  }

  /// 7. Tukang melaporkan User tidak aktif / tidak balas chat > 30 menit (BR-71)
  /// User menerima +1 Strike, job dilepas kembali ke OPEN
  Future<Map<String, dynamic>> tukangReportUserUnresponsive(
      String jobId) async {
    final response = await _client.rpc(
      'rpc_tukang_report_user_unresponsive',
      params: {'p_job_id': jobId},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  /// 8. Ambil permintaan pembatalan aktif pada job tertentu
  Future<Map<String, dynamic>?> getActiveCancelRequest(String jobId) async {
    final res = await _client
        .from('cancel_requests')
        .select()
        .eq('job_id', jobId)
        .eq('status', 'SUBMITTED')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (res == null) return null;
    return Map<String, dynamic>.from(res);
  }

  /// 9. Ambil riwayat strike milik akun (FR-039)
  Future<List<Map<String, dynamic>>> getAccountStrikes(String userId) async {
    final response = await _client.rpc(
      'rpc_get_account_strikes',
      params: {'p_user_id': userId},
    );
    return List<Map<String, dynamic>>.from(response as List);
  }
}
