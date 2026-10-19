/// Model Notifikasi Aplikasi Beres (FR-040 Dasar)
class InAppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String? deepLink;
  final bool isRead;
  final DateTime createdAt;

  const InAppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.deepLink,
    this.isRead = false,
    required this.createdAt,
  });

  factory InAppNotification.fromJson(Map<String, dynamic> json) {
    return InAppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? 'Pemberitahuan',
      body: json['body'] as String? ?? '',
      deepLink: json['deep_link'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'body': body,
      'deep_link': deepLink,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
