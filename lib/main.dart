import 'package:flutter/material.dart';
import 'pages/login_page.dart';

void main() {
  runApp(const RaceTechApp());
}

class RaceTechApp extends StatelessWidget {
  const RaceTechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
    );
  }
}