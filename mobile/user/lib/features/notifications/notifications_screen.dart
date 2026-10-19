import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beres_shared/beres_shared.dart';
import '../jobs/job_detail_and_bids_screen.dart';

final notificationServiceProvider = Provider((ref) => NotificationService());

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
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

    // Deep link handling (FR-040)
    if (notif.deepLink != null) {
      final uri = Uri.tryParse(notif.deepLink!);
      if (uri != null && uri.pathSegments.isNotEmpty) {
        // beres://job/<job_id>/bids
        if (uri.pathSegments.contains('job')) {
          final idx = uri.pathSegments.indexOf('job');
          if (idx + 1 < uri.pathSegments.length) {
            final jobId = uri.pathSegments[idx + 1];
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => JobDetailAndBidsScreen(jobId: jobId),
              ),
            );
            return;
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Notifikasi'),
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
                        'Pembaruan status pekerjaan dan penawaran tukang akan muncul di sini.',
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
                        color: n.isRead ? Colors.white : const Color(0xFFF0F7FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: n.isRead
                                ? AppColors.borderLight
                                : AppColors.trustCobalt.withValues(alpha: 0.3),
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
                                : AppColors.userBadgeBg,
                            child: Icon(
                              Icons.notifications_active,
                              color: n.isRead
                                  ? Colors.grey
                                  : AppColors.trustCobalt,
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
                                    color: AppColors.trustCobalt,
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
