import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/in_app_notification.dart';

/// Service Notifikasi Beres (FR-040 Dasar)
/// Mengelola device token (FCM), riwayat notifikasi in-app, dan stream real-time.
class NotificationService {
  final SupabaseClient _client;
  final StreamController<InAppNotification> _foregroundNotificationController =
      StreamController<InAppNotification>.broadcast();

  NotificationService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Stream notifikasi melayang yang diterima saat aplikasi aktif di foreground
  Stream<InAppNotification> get onForegroundNotification =>
      _foregroundNotificationController.stream;

  /// Mendaftarkan atau memperbarui token perangkat (FCM Token) ke Supabase (FR-040 Dasar)
  Future<void> registerDeviceToken({
    required String fcmToken,
    String? platform,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('device_tokens').upsert(
      {
        'user_id': userId,
        'fcm_token': fcmToken,
        'platform': platform,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,fcm_token',
    );
  }

  /// Mengambil riwayat notifikasi in-app milik user
  Future<List<InAppNotification>> getNotifications({
    String? userId,
    int limit = 30,
  }) async {
    final effectiveUserId = userId ?? _client.auth.currentUser?.id;
    if (effectiveUserId == null) return [];

    final response = await _client
        .from('notifications')
        .select()
        .eq('user_id', effectiveUserId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List<dynamic>)
        .map((json) =>
            InAppNotification.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Menandai notifikasi telah dibaca
  Future<void> markAsRead(String notificationId) async {
    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  /// Menandai seluruh notifikasi user telah dibaca
  Future<void> markAllAsRead({String? userId}) async {
    final effectiveUserId = userId ?? _client.auth.currentUser?.id;
    if (effectiveUserId == null) return;

    await _client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', effectiveUserId)
        .eq('is_read', false);
  }

  /// Menghitung jumlah notifikasi yang belum dibaca (badge counter)
  Future<int> getUnreadCount({String? userId}) async {
    final effectiveUserId = userId ?? _client.auth.currentUser?.id;
    if (effectiveUserId == null) return 0;

    final response = await _client
        .from('notifications')
        .select('id')
        .eq('user_id', effectiveUserId)
        .eq('is_read', false);

    return (response as List<dynamic>).length;
  }

  /// Memancarkan notifikasi lokal (in-app banner)
  void emitLocalNotification(InAppNotification notification) {
    if (!_foregroundNotificationController.isClosed) {
      _foregroundNotificationController.add(notification);
    }
  }

  void dispose() {
    _foregroundNotificationController.close();
  }
}
