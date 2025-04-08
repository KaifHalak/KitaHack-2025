import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:js' as js;
import 'screens/camera_screen.dart';
import 'screens/api_key_screen.dart';
import 'providers/accessibility_provider.dart';
import 'providers/gemini_provider.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: '.env');

  // Inject Google Maps API key into JavaScript environment
  final mapsApiKey = dotenv.env['MAPS_API_KEY'] ?? '';
  if (mapsApiKey.isEmpty || mapsApiKey.contains('PLACEHOLDER')) {
    print('WARNING: MAPS_API_KEY is not set properly in .env file.');
    print('Please set a valid Google Maps API key in the .env file.');
  } else {
    print(
        'Maps API key loaded successfully from .env file: ${mapsApiKey.substring(0, 5)}...');
  }

  // Make API key available to JavaScript
  js.context.callMethod('eval', [
    '''
    window.MAPS_API_KEY = '$mapsApiKey';
    console.log('Maps API key set from Dart: ' + (window.MAPS_API_KEY ? 'Success' : 'Failed'));
  '''
  ]);

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Register the camera preview factory
  ui_web.platformViewRegistry.registerViewFactory(
    'camera-preview',
    (int viewId) {
      final videoElement = html.VideoElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..autoplay = true
        ..muted = true
        ..style.position = 'absolute'
        ..style.background = 'transparent';

      // Set playsInline attribute
      videoElement.setAttribute('playsinline', 'true');

      return videoElement;
    },
  );

  // Register the map container factory
  ui_web.platformViewRegistry.registerViewFactory(
    'map-container',
    (int viewId) {
      final mapDiv = html.DivElement()
        ..id = 'map'
        ..style.width = '100%'
        ..style.height = '100%';

      // Initialize Google Maps JavaScript functions
      if (js.context['initMap'] == null) {
        js.context['initMap'] = js.allowInterop(() {
          // This function will be called by the Google Maps API
          print("initMap callback from Google Maps API");
        });
      }

      return mapDiv;
    },
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AccessibilityProvider()),
        ChangeNotifierProvider(
            create: (context) => GeminiProvider(
                  apiKey: dotenv.env['GEMINI_API_KEY'] ?? '',
                )),
      ],
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
      routes: {
        '/api_key': (context) => const ApiKeyScreen(),
      },
    );
  }
}
