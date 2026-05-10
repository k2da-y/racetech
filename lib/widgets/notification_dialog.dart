import 'package:flutter/material.dart';
import '../services/api_service.dart';

class NotificationDialog extends StatefulWidget {
  const NotificationDialog({super.key});

  @override
  State<NotificationDialog> createState() => _NotificationDialogState();
}

class _NotificationDialogState extends State<NotificationDialog> {
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;

  int get unreadCount => notifications
      .where((notification) => notification["is_read"] != true)
      .length;

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

  IconData getIcon(String type) {
    switch (type) {
      case "comment":
        return Icons.comment;
      case "event":
        return Icons.event;
      case "announcement":
        return Icons.campaign;
      default:
        return Icons.notifications;
    }
  }

  Color getColor(String type) {
    switch (type) {
      case "comment":
        return Colors.blue;
      case "event":
        return Colors.orange;
      case "announcement":
        return Colors.green;
      default:
        return Colors.grey;
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(15),
        height: 400,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    unreadCount == 0
                        ? "Notifications"
                        : "Notifications ($unreadCount)",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (unreadCount > 0)
                  TextButton(
                    onPressed: markAllRead,
                    child: const Text("Mark all read"),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : notifications.isEmpty
                  ? const Center(child: Text("No notifications yet"))
                  : ListView.builder(
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final notification = notifications[index];
                        final type = (notification["type"] ?? "").toString();
                        final title = (notification["title"] ?? "").toString();
                        final message = (notification["message"] ?? "")
                            .toString();
                        final time = notificationTime(notification);
                        final isUnread = notification["is_read"] != true;

                        return InkWell(
                          onTap: () => markNotificationRead(notification),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isUnread
                                  ? getColor(type).withValues(alpha: 0.08)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isUnread
                                    ? getColor(type).withValues(alpha: 0.35)
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 40,
                                  width: 40,
                                  decoration: BoxDecoration(
                                    color: getColor(
                                      type,
                                    ).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    getIcon(type),
                                    color: getColor(type),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (title.isNotEmpty)
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                title,
                                                style: TextStyle(
                                                  fontWeight: isUnread
                                                      ? FontWeight.w800
                                                      : FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            if (isUnread)
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: getColor(type),
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                          ],
                                        ),
                                      Text(
                                        message,
                                        style: TextStyle(
                                          fontWeight: isUnread
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                        ),
                                      ),
                                      if (time.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          time,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
