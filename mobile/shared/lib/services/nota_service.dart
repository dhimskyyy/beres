import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/nota.dart';

class NotaService {
  final SupabaseClient _client;

  NotaService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Mengambil daftar nota untuk sebuah pekerjaan
  Future<List<Nota>> getNotasForJob(String jobId) async {
    final data = await _client
        .from('notas')
        .select('*')
        .eq('job_id', jobId)
        .order('version', ascending: true);

    return (data as List<dynamic>)
        .map((item) => Nota.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  /// Streaming nota untuk suatu job
  Stream<List<Nota>> streamNotas(String jobId) {
    return _client
        .from('notas')
        .stream(primaryKey: ['id'])
        .eq('job_id', jobId)
        .order('version', ascending: true)
        .map((records) => records
            .map((item) => Nota.fromJson(Map<String, dynamic>.from(item)))
            .toList());
  }

  /// Membuat Nota Digital baru (Versi 1 saat NEGOTIATING, Versi 2+ saat ARRIVED/WORKING) (BR-04, BR-05)
  Future<Map<String, dynamic>> createNota({
    required String jobId,
    required List<NotaItem> items,
    required int totalAmount,
    required PaymentMethod paymentMethod,
    Map<String, dynamic>? paymentDestination,
    String? note,
  }) async {
    final response = await _client.rpc('rpc_create_nota', params: {
      'p_job_id': jobId,
      'p_items': items.map((e) => e.toJson()).toList(),
      'p_total_amount': totalAmount,
      'p_payment_method': paymentMethod.value,
      'p_payment_destination': paymentDestination,
      'p_note': note,
    });

    return Map<String, dynamic>.from(response as Map);
  }

  /// Menanggapi Nota (APPROVE atau REJECT oleh User) (FR-014, FR-015, BR-05)
  Future<Map<String, dynamic>> respondNota({
    required String notaId,
    required bool approve,
  }) async {
    final response = await _client.rpc('rpc_respond_nota', params: {
      'p_nota_id': notaId,
      'p_action': approve ? 'APPROVE' : 'REJECT',
    });

    return Map<String, dynamic>.from(response as Map);
  }

  /// Menarik kembali Revisi Nota yang masih SENT (Tukang) (BR-08)
  Future<Map<String, dynamic>> cancelRevision({
    required String notaId,
  }) async {
    final response = await _client.rpc('rpc_cancel_nota_revision', params: {
      'p_nota_id': notaId,
    });

    return Map<String, dynamic>.from(response as Map);
  }

  /// Tukang menekan Berangkat ke Lokasi dalam 30 menit (BR-31)
  Future<Map<String, dynamic>> departJob({
    required String jobId,
  }) async {
    final response = await _client.rpc('rpc_depart_job', params: {
      'p_job_id': jobId,
    });

    return Map<String, dynamic>.from(response as Map);
  }

  /// Mengecek apakah batas 30 menit berangkat telah berakhir (T4a, BR-31)
  Future<Map<String, dynamic>> checkDepartTimeout({
    required String jobId,
  }) async {
    final response = await _client.rpc('rpc_check_depart_timeout', params: {
      'p_job_id': jobId,
    });

    return Map<String, dynamic>.from(response as Map);
  }
}
