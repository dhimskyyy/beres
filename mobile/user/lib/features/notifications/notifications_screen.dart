import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:beres_shared/beres_shared.dart';

final notificationServiceProvider = Provider((ref) => NotificationService());

class UserNotificationsScreen extends ConsumerStatefulWidget {
  final bool embedded;

  const UserNotificationsScreen({super.key, this.embedded = false});

  @override
  ConsumerState<UserNotificationsScreen> createState() =>
      _UserNotificationsScreenState();
}

class _UserNotificationsScreenState
    extends ConsumerState<UserNotificationsScreen> {
  List<InAppNotification> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final service = ref.read(notificationServiceProvider);
    try {
      final list = await service.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAllAsRead() async {
    final service = ref.read(notificationServiceProvider);
    await service.markAllAsRead();
    _loadNotifications();
  }

  void _handleNotificationTap(InAppNotification notif) {
    ref.read(notificationServiceProvider).markAsRead(notif.id);
    final deepLink = notif.deepLink;
    if (deepLink != null && deepLink.isNotEmpty) {
      context.push(deepLink).then((_) => _loadNotifications());
    } else {
      _loadNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _notifications.any((n) => !n.isRead);

    final content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _notifications.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceWhite,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderLight),
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      size: 28,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Belum Ada Notifikasi',
                    style: AppTypography.headingSmall,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pembaruan saat mitra tukang melamar pesanan atau memperbarui progres kerja akan muncul di sini.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: _loadNotifications,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _notifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final n = _notifications[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _handleNotificationTap(n),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: n.isRead
                          ? AppColors.surfaceWhite
                          : AppColors.userBadgeBg.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: n.isRead
                            ? AppColors.borderLight
                            : AppColors.trustCobalt.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: n.isRead
                                ? AppColors.surfaceLight
                                : AppColors.userBadgeBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.notifications_outlined,
                            color: n.isRead
                                ? AppColors.textSecondary
                                : AppColors.trustCobalt,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      n.title,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: n.isRead
                                            ? FontWeight.w600
                                            : FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (!n.isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppColors.trustCobalt,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(n.body, style: AppTypography.bodySmall),
                              const SizedBox(height: 6),
                              Text(
                                Formatters.formatDateTime(n.createdAt),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );

    if (widget.embedded) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Notifikasi'),
          actions: [
            if (hasUnread)
              TextButton(
                onPressed: _markAllAsRead,
                child: const Text('Tandai Dibaca'),
              ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Segarkan',
              onPressed: _loadNotifications,
            ),
          ],
        ),
        body: content,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          if (hasUnread)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Tandai Dibaca'),
            ),
        ],
      ),
      body: content,
    );
  }
}
