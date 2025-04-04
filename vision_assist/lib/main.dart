import 'package:flutter/material.dart';
import 'screens/camera_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vision Assist',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      home: const CameraScreen(),
    );
  }
}
