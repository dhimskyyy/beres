import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beres_shared/beres_shared.dart';

final notificationServiceProvider = Provider((ref) => NotificationService());

class TukangNotificationsScreen extends ConsumerStatefulWidget {
  const TukangNotificationsScreen({super.key});

  @override
  ConsumerState<TukangNotificationsScreen> createState() =>
      _TukangNotificationsScreenState();
}

class _TukangNotificationsScreenState
    extends ConsumerState<TukangNotificationsScreen> {
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
    _loadNotifications();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Notifikasi: ${notif.title}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Notifikasi Mitra'),
        actions: [
          if (_notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Tandai Dibaca'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.notifications_none_outlined,
                        size: 56,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 12),
                      Text('Belum ada notifikasi',
                          style: AppTypography.headingSmall),
                      const SizedBox(height: 4),
                      Text(
                        'Pemberitahuan saat pelanggan memilih Anda atau ada pekerjaan baru akan muncul di sini.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadNotifications,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final n = _notifications[index];
                      return Card(
                        color: n.isRead ? Colors.white : const Color(0xFFFFF7ED),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: n.isRead
                                ? AppColors.borderLight
                                : AppColors.warningAmber.withValues(alpha: 0.3),
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: n.isRead
                                ? Colors.grey.shade200
                                : AppColors.tukangBadgeBg,
                            child: Icon(
                              Icons.notifications_active,
                              color: n.isRead
                                  ? Colors.grey
                                  : AppColors.safetyOrange,
                              size: 20,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  n.title,
                                  style: TextStyle(
                                    fontWeight: n.isRead
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (!n.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.safetyOrange,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(n.body, style: AppTypography.bodySmall),
                              const SizedBox(height: 6),
                              Text(
                                Formatters.formatDateTime(n.createdAt),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _handleNotificationTap(n),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
