import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import '../widgets/notification_dialog.dart';

class AppNotificationService {
  static final navigatorKey = GlobalKey<NavigatorState>();
  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  static final refreshListenable = ValueNotifier<int>(0);

  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static StreamSubscription<RemoteMessage>? _openedSubscription;
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _handleOpenedMessage,
    );

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _notifyChanged();
      _openNotificationCenterWhenReady();
    }
  }

  static void dispose() {
    _foregroundSubscription?.cancel();
    _openedSubscription?.cancel();
    _foregroundSubscription = null;
    _openedSubscription = null;
    _initialized = false;
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    _notifyChanged();

    final text = _messageText(message);
    if (text.isEmpty) return;

    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(text),
        action: SnackBarAction(
          label: "View",
          onPressed: openNotificationCenter,
        ),
      ),
    );
  }

  static void _handleOpenedMessage(RemoteMessage message) {
    _notifyChanged();
    _openNotificationCenterWhenReady();
  }

  static void _notifyChanged() {
    refreshListenable.value++;
  }

  static String _messageText(RemoteMessage message) {
    final title = message.notification?.title ?? message.data["title"];
    final body = message.notification?.body ?? message.data["body"];

    return [title, body]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .join("\n");
  }

  static void _openNotificationCenterWhenReady() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (navigatorKey.currentContext == null) {
        Timer(
          const Duration(milliseconds: 300),
          _openNotificationCenterWhenReady,
        );
        return;
      }

      openNotificationCenter();
    });
  }

  static Future<void> openNotificationCenter() async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    await showDialog<void>(
      context: context,
      builder: (_) => const NotificationDialog(),
    );
    _notifyChanged();
  }
}
