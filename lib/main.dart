import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'pages/auth_gate_page.dart';
import 'services/app_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const RacetechApp());
  await AppNotificationService.initialize();
}

class RacetechApp extends StatelessWidget {
  const RacetechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: AppNotificationService.navigatorKey,
      scaffoldMessengerKey: AppNotificationService.scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      home: const AuthGatePage(),
    );
  }
}
