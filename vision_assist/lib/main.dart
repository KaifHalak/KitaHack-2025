import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/camera_screen.dart';
import 'providers/accessibility_provider.dart';
import 'package:provider/provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(
    ChangeNotifierProvider(
      create: (context) => AccessibilityProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final accessibilityProvider = Provider.of<AccessibilityProvider>(context);
    
    return MaterialApp(
      title: 'Vision Assist',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: accessibilityProvider.highContrastMode
            ? const ColorScheme.dark(
                primary: Colors.yellow,
                secondary: Colors.white,
                surface: Colors.black,
                background: Colors.black,
                onPrimary: Colors.black,
                onSecondary: Colors.black,
                onSurface: Colors.yellow,
                onBackground: Colors.white,
              )
            : ColorScheme.fromSeed(seedColor: Colors.blue),
        textTheme: Theme.of(context).textTheme.apply(
          fontSizeFactor: accessibilityProvider.textScaleFactor,
          fontSizeDelta: accessibilityProvider.fontSizeDelta,
        ),
        iconTheme: IconThemeData(
          size: 24 * accessibilityProvider.iconScaleFactor,
          color: accessibilityProvider.highContrastMode 
              ? Colors.yellow 
              : Colors.blue,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.all(16 * accessibilityProvider.uiScaleFactor),
            textStyle: TextStyle(
              fontSize: 16 * accessibilityProvider.textScaleFactor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        useMaterial3: true,
      ),
      home: const CameraScreen(),
    );
  }
}
