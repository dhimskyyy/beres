import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message.dart';

class ChatService {
  final SupabaseClient _client;

  ChatService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Mengambil konteks lengkap chat room (info lawan bicara, status, timer, nota)
  Future<JobChatContext> getChatContext(String jobId) async {
    final response = await _client.rpc('rpc_get_job_chat_context', params: {
      'p_job_id': jobId,
    });

    return JobChatContext.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Mengambil riwayat pesan obrolan
  Future<List<ChatMessage>> getMessages(String jobId, {int limit = 100}) async {
    final data = await _client
        .from('chat_messages')
        .select('*')
        .eq('job_id', jobId)
        .order('created_at', ascending: true)
        .limit(limit);

    return (data as List<dynamic>)
        .map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  /// Berlangganan streaming pesan chat secara real-time via Supabase Realtime
  Stream<List<ChatMessage>> streamMessages(String jobId) {
    return _client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('job_id', jobId)
        .order('created_at', ascending: true)
        .map((records) => records
            .map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)))
            .toList());
  }

  /// Mengirim pesan chat (Teks, Gambar, Nota Card)
  Future<ChatMessage> sendMessage({
    required String jobId,
    String? content,
    ChatMessageType messageType = ChatMessageType.text,
    String? imageUrl,
    String? notaId,
  }) async {
    final response = await _client.rpc('rpc_send_chat_message', params: {
      'p_job_id': jobId,
      'p_content': content,
      'p_message_type': messageType.value,
      'p_image_url': imageUrl,
      'p_nota_id': notaId,
    });

    return ChatMessage.fromJson(Map<String, dynamic>.from(response as Map));
  }

  /// Melepas pekerjaan kembali ke Job Portal saat NEGOTIATING tanpa Strike (BR-70)
  Future<Map<String, dynamic>> cancelNegotiationToPortal({
    required String jobId,
    String reason = 'Batas waktu 30 menit / pembatalan negosiasi',
  }) async {
    final response = await _client.rpc('rpc_cancel_negotiation_to_portal', params: {
      'p_job_id': jobId,
      'p_reason': reason,
    });

    return Map<String, dynamic>.from(response as Map);
  }
}
