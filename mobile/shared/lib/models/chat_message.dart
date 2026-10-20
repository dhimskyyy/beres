import 'nota.dart';

/// Jenis Tipe Pesan Chat
enum ChatMessageType {
  text('TEXT'),
  image('IMAGE'),
  notaCard('NOTA_CARD'),
  notaRevisionAlert('NOTA_REVISION_ALERT'),
  systemEvent('SYSTEM_EVENT');

  final String value;
  const ChatMessageType(this.value);

  static ChatMessageType fromString(String val) {
    return ChatMessageType.values.firstWhere(
      (e) => e.value == val,
      orElse: () => ChatMessageType.text,
    );
  }
}

/// Model Pesan Chat Real-Time Beres v1.4.0 (FR-013)
class ChatMessage {
  final String id;
  final String jobId;
  final String senderId;
  final ChatMessageType messageType;
  final String? content;
  final String? imageUrl;
  final String? notaId;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.jobId,
    required this.senderId,
    required this.messageType,
    this.content,
    this.imageUrl,
    this.notaId,
    required this.createdAt,
  });

  bool get isSystem => messageType == ChatMessageType.systemEvent;
  bool get isNotaCard => messageType == ChatMessageType.notaCard;
  bool get isNotaRevisionAlert => messageType == ChatMessageType.notaRevisionAlert;
  bool get isImage => messageType == ChatMessageType.image;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      jobId: json['job_id'] as String,
      senderId: json['sender_id'] as String,
      messageType: ChatMessageType.fromString(json['message_type'] as String? ?? 'TEXT'),
      content: json['content'] as String?,
      imageUrl: json['image_url'] as String?,
      notaId: json['nota_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'job_id': jobId,
      'sender_id': senderId,
      'message_type': messageType.value,
      'content': content,
      'image_url': imageUrl,
      'nota_id': notaId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Data Konteks Chat Ruang Diskusi & Negosiasi
class JobChatContext {
  final String jobId;
  final String status;
  final String description;
  final String areaLabel;
  final String addressFull;
  final String userId;
  final String? lockedTukangId;
  final DateTime? lockedAt;
  final DateTime? notaApprovedAt;
  final int? agreedTotal;
  final bool isUser;
  final bool isTukang;
  final Map<String, dynamic>? otherUser;
  final Nota? activeNota;
  final Nota? pendingNota;
  final int departTimerSeconds;
  final int negotiatingTimerSeconds;

  const JobChatContext({
    required this.jobId,
    required this.status,
    required this.description,
    required this.areaLabel,
    required this.addressFull,
    required this.userId,
    this.lockedTukangId,
    this.lockedAt,
    this.notaApprovedAt,
    this.agreedTotal,
    required this.isUser,
    required this.isTukang,
    this.otherUser,
    this.activeNota,
    this.pendingNota,
    required this.departTimerSeconds,
    required this.negotiatingTimerSeconds,
  });

  String get otherUserName => otherUser?['full_name'] as String? ?? 'Pengguna Beres';
  String? get otherUserAvatar => otherUser?['avatar_url'] as String?;
  String? get otherUserPhone => otherUser?['phone'] as String?;

  factory JobChatContext.fromJson(Map<String, dynamic> json) {
    return JobChatContext(
      jobId: json['job_id'] as String,
      status: json['status'] as String? ?? 'NEGOTIATING',
      description: json['description'] as String? ?? '',
      areaLabel: json['area_label'] as String? ?? '',
      addressFull: json['address_full'] as String? ?? '',
      userId: json['user_id'] as String,
      lockedTukangId: json['locked_tukang_id'] as String?,
      lockedAt: json['locked_at'] != null ? DateTime.parse(json['locked_at'] as String) : null,
      notaApprovedAt: json['nota_approved_at'] != null
          ? DateTime.parse(json['nota_approved_at'] as String)
          : null,
      agreedTotal: (json['agreed_total'] as num?)?.toInt(),
      isUser: json['is_user'] as bool? ?? false,
      isTukang: json['is_tukang'] as bool? ?? false,
      otherUser: json['other_user'] as Map<String, dynamic>?,
      activeNota: json['active_nota'] != null
          ? Nota.fromJson(json['active_nota'] as Map<String, dynamic>)
          : null,
      pendingNota: json['pending_nota'] != null
          ? Nota.fromJson(json['pending_nota'] as Map<String, dynamic>)
          : null,
      departTimerSeconds: (json['depart_timer_seconds'] as num?)?.toInt() ?? 0,
      negotiatingTimerSeconds: (json['negotiating_timer_seconds'] as num?)?.toInt() ?? 0,
    );
  }
}
