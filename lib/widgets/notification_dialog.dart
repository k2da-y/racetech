import 'package:flutter/material.dart';
import '../profile/my_activity_page.dart';
import '../services/api_service.dart';

class NotificationDialog extends StatefulWidget {
  const NotificationDialog({super.key});

  @override
  State<NotificationDialog> createState() => _NotificationDialogState();
}

class _NotificationDialogState extends State<NotificationDialog> {
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;
  bool showUnreadOnly = false;

  int get unreadCount => notifications
      .where((notification) => notification["is_read"] != true)
      .length;

  List<Map<String, dynamic>> get visibleNotifications {
    if (!showUnreadOnly) {
      return notifications;
    }

    return notifications
        .where((notification) => notification["is_read"] != true)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    final data = await ApiService().getNotifications();

    if (!mounted) return;

    setState(() {
      notifications = data;
      isLoading = false;
    });
  }

  Future<void> markNotificationRead(Map<String, dynamic> notification) async {
    if (notification["is_read"] == true) {
      return;
    }

    final id = (notification["id"] ?? "").toString();
    if (id.isEmpty) {
      return;
    }

    final result = await ApiService().markNotificationRead(id);

    if (!mounted || !result.success) return;

    setState(() {
      notification["is_read"] = true;
      notification["read_at"] = DateTime.now().toIso8601String();
    });
  }

  Future<void> markAllRead() async {
    if (unreadCount == 0) {
      return;
    }

    final result = await ApiService().markAllNotificationsRead();

    if (!mounted || !result.success) return;

    setState(() {
      final now = DateTime.now().toIso8601String();
      for (final notification in notifications) {
        notification["is_read"] = true;
        notification["read_at"] = now;
      }
    });
  }

  Future<void> openNotification(Map<String, dynamic> notification) async {
    await markNotificationRead(notification);

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (_) => NotificationDetailDialog(
        notification: notification,
        onOpenActivity: (notification["type"] ?? "").toString() == "payment"
            ? () {
                final navigator = Navigator.of(context);
                navigator.pop();
                navigator.pop();
                navigator.push(
                  MaterialPageRoute(builder: (_) => const MyActivityPage()),
                );
              }
            : null,
      ),
    );
  }

  IconData getIcon(String type) {
    switch (type) {
      case "comment":
      case "community_comment":
      case "post_comment":
        return Icons.comment_outlined;
      case "like":
      case "community_like":
      case "post_like":
        return Icons.favorite_border;
      case "event":
        return Icons.event_outlined;
      case "payment":
        return Icons.payments_outlined;
      case "announcement":
        return Icons.campaign_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  Color getColor(String type) {
    switch (type) {
      case "comment":
      case "community_comment":
      case "post_comment":
        return const Color(0xFF2563EB);
      case "like":
      case "community_like":
      case "post_like":
        return const Color(0xFFFF3B5C);
      case "event":
        return const Color(0xFFF59E0B);
      case "payment":
        return const Color(0xFF2563EB);
      case "announcement":
        return const Color(0xFF22C55E);
      default:
        return const Color(0xFF64748B);
    }
  }

  String notificationTime(Map<String, dynamic> notification) {
    final rawTime =
        (notification["sent_at"] ?? notification["created_at"] ?? "")
            .toString();

    if (rawTime.isEmpty) {
      return "";
    }

    final parsed = DateTime.tryParse(rawTime)?.toLocal();
    if (parsed == null) {
      return rawTime;
    }

    final difference = DateTime.now().difference(parsed);
    if (difference.inMinutes < 1) {
      return "Just now";
    }
    if (difference.inHours < 1) {
      return "${difference.inMinutes} min ago";
    }
    if (difference.inDays < 1) {
      return "${difference.inHours} hr ago";
    }
    if (difference.inDays < 7) {
      return "${difference.inDays} day${difference.inDays == 1 ? "" : "s"} ago";
    }

    return "${parsed.month}/${parsed.day}/${parsed.year}";
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final dialogHeight = screenHeight < 518 ? screenHeight - 48 : 470.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Container(
        height: dialogHeight,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF3F9),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DialogHeader(
              unreadCount: unreadCount,
              onClose: () => Navigator.pop(context),
              onMarkAllRead: unreadCount > 0 ? markAllRead : null,
            ),

            const SizedBox(height: 12),

            _NotificationTabs(
              showUnreadOnly: showUnreadOnly,
              unreadCount: unreadCount,
              onChanged: (value) {
                setState(() => showUnreadOnly = value);
              },
            ),

            const SizedBox(height: 14),

            Expanded(
              child: isLoading
                  ? _LoadingState()
                  : visibleNotifications.isEmpty
                  ? _EmptyNotificationState(
                      title: showUnreadOnly
                          ? "No unread notifications"
                          : "No notifications yet",
                      message: showUnreadOnly
                          ? "New unread updates will appear here."
                          : "Updates, comments, and event reminders will appear here.",
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        setState(() => isLoading = true);
                        await loadNotifications();
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        itemCount: visibleNotifications.length,
                        itemBuilder: (context, index) {
                          final notification = visibleNotifications[index];
                          final type = (notification["type"] ?? "").toString();
                          final title = (notification["title"] ?? "")
                              .toString();
                          final message = (notification["message"] ?? "")
                              .toString();
                          final time = notificationTime(notification);
                          final isUnread = notification["is_read"] != true;

                          return _NotificationCard(
                            title: title,
                            message: message,
                            time: time,
                            isUnread: isUnread,
                            type: type,
                            icon: getIcon(type),
                            color: getColor(type),
                            onTap: () => openNotification(notification),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTabs extends StatelessWidget {
  final bool showUnreadOnly;
  final int unreadCount;
  final ValueChanged<bool> onChanged;

  const _NotificationTabs({
    required this.showUnreadOnly,
    required this.unreadCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _NotificationTabButton(
            label: "All",
            selected: !showUnreadOnly,
            onTap: () => onChanged(false),
          ),
          _NotificationTabButton(
            label: unreadCount > 0 ? "Unread ($unreadCount)" : "Unread",
            selected: showUnreadOnly,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _NotificationTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NotificationTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF64748B),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onClose;
  final Future<void> Function()? onMarkAllRead;

  const _DialogHeader({
    required this.unreadCount,
    required this.onClose,
    required this.onMarkAllRead,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.notifications_none, color: Color(0xFF2563EB)),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Notifications",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                unreadCount == 0
                    ? "You're all caught up"
                    : "$unreadCount unread notification${unreadCount == 1 ? "" : "s"}",
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),

        if (onMarkAllRead != null)
          TextButton(
            onPressed: onMarkAllRead,
            child: const Text(
              "Read all",
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),

        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close),
          color: const Color(0xFF64748B),
        ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final String title;
  final String message;
  final String time;
  final bool isUnread;
  final String type;
  final IconData icon;
  final Color color;
  final Future<void> Function() onTap;

  const _NotificationCard({
    required this.title,
    required this.message,
    required this.time,
    required this.isUnread,
    required this.type,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: isUnread ? color.withValues(alpha: 0.35) : Colors.white,
        ),
      ),
      child: InkWell(
        onTap: () {
          onTap();
        },
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 25),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (type == "announcement") ...[
                      const _AnnouncementLabel(),
                      const SizedBox(height: 7),
                    ],

                    if (title.isNotEmpty)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isUnread
                                    ? FontWeight.w900
                                    : FontWeight.w800,
                                color: const Color(0xFF111827),
                              ),
                            ),
                          ),
                          if (isUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 9,
                              height: 9,
                              margin: const EdgeInsets.only(top: 5),
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),

                    if (title.isNotEmpty) const SizedBox(height: 5),

                    Text(
                      message,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: isUnread
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: const Color(0xFF475569),
                      ),
                    ),

                    if (time.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_outlined,
                            size: 14,
                            color: Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            time,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnouncementLabel extends StatelessWidget {
  const _AnnouncementLabel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFDCFCE7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF86EFAC)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_outlined, size: 14, color: Color(0xFF15803D)),
          SizedBox(width: 5),
          Text(
            "Admin Announcement",
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Color(0xFF15803D),
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationDetailDialog extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback? onOpenActivity;

  const NotificationDetailDialog({
    super.key,
    required this.notification,
    this.onOpenActivity,
  });

  String notificationTime() {
    final rawTime =
        (notification["sent_at"] ?? notification["created_at"] ?? "")
            .toString();

    if (rawTime.isEmpty) {
      return "";
    }

    final parsed = DateTime.tryParse(rawTime)?.toLocal();
    if (parsed == null) {
      return rawTime;
    }

    return "${parsed.month}/${parsed.day}/${parsed.year} ${parsed.hour.toString().padLeft(2, "0")}:${parsed.minute.toString().padLeft(2, "0")}";
  }

  IconData get icon {
    final type = (notification["type"] ?? "").toString();

    switch (type) {
      case "comment":
      case "community_comment":
      case "post_comment":
        return Icons.comment_outlined;
      case "like":
      case "community_like":
      case "post_like":
        return Icons.favorite_border;
      case "event":
        return Icons.event_outlined;
      case "payment":
        return Icons.payments_outlined;
      case "announcement":
        return Icons.campaign_outlined;
      default:
        return Icons.notifications_none;
    }
  }

  Color get color {
    final type = (notification["type"] ?? "").toString();

    switch (type) {
      case "comment":
      case "community_comment":
      case "post_comment":
        return const Color(0xFF2563EB);
      case "like":
      case "community_like":
      case "post_like":
        return const Color(0xFFFF3B5C);
      case "event":
        return const Color(0xFFF59E0B);
      case "payment":
        return const Color(0xFF2563EB);
      case "announcement":
        return const Color(0xFF22C55E);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = (notification["type"] ?? "").toString();
    final title = (notification["title"] ?? "").toString();
    final message = (notification["message"] ?? "").toString();
    final time = notificationTime();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: color, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (type == "announcement") ...[
                          const _AnnouncementLabel(),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          title.isEmpty ? "Notification" : title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF111827),
                          ),
                        ),
                        if (time.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            time,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                message.isEmpty ? "No message content." : message,
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Done"),
                  ),
                  if (onOpenActivity != null)
                    FilledButton.icon(
                      onPressed: onOpenActivity,
                      icon: const Icon(Icons.receipt_long_outlined, size: 18),
                      label: const Text("Open My Activity"),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Container(
          height: 88,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

class _EmptyNotificationState extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyNotificationState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.notifications_off_outlined,
              size: 52,
              color: Color(0xFF2563EB),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
