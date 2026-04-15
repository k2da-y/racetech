import 'package:flutter/material.dart';
import '../data/notification_data.dart';

class NotificationDialog extends StatelessWidget {
  const NotificationDialog({super.key});

  IconData getIcon(String type) {
    switch (type) {
      case "comment":
        return Icons.comment;
      case "event":
        return Icons.event;
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
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {

    final notifications = NotificationData.notifications;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(15),
        height: 400, // fixed height para scrollable
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              "Notifications 🔔",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: notifications.isEmpty
                  ? const Center(child: Text("No notifications yet"))
                  : ListView.builder(
                itemCount: notifications.length,
                itemBuilder: (context, index) {

                  final notif = notifications[index];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),

                    child: Row(
                      children: [

                        // ICON
                        Container(
                          height: 40,
                          width: 40,
                          decoration: BoxDecoration(
                            color: getColor(notif["type"]).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            getIcon(notif["type"]),
                            color: getColor(notif["type"]),
                          ),
                        ),

                        const SizedBox(width: 10),

                        // TEXT
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(notif["message"]),
                              const SizedBox(height: 3),
                              Text(
                                notif["time"],
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),

                      ],
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