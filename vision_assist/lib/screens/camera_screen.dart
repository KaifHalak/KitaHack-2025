import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/detection.dart';
import '../models/tracked_object.dart';
import '../models/point.dart';
import '../models/bounding_box.dart';
import '../widgets/detection_highlight.dart';
import '../widgets/detection_label.dart';
import '../providers/accessibility_provider.dart';
import '../providers/gemini_provider.dart';
import 'accessibility_settings_screen.dart';
import 'dart:convert';
import '../services/object_detection_service.dart';
import 'package:flutter/foundation.dart';
import '../web/camera_preview.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  bool _isDetectorInitialized = false;
  bool _isProcessingFrame = false;
  String? _errorMessage;
  String _statusMessage = '';
  List<TrackedObject> _trackedObjects = [];
  Timer? _detectionTimer;
  html.VideoElement? _cameraStream;
  html.CanvasElement? _canvas;
  html.CanvasRenderingContext2D? _ctx;
  bool _showControls = true;
  bool _isCameraInitialized = false;

  // Tap detection and counters for accessibility gestures
  int _tapCount = 0;
  Timer? _tapTimer;
  bool _isLongPress = false;

  // Last time a Gemini description was generated
  DateTime _lastDescriptionTime =
      DateTime.now().subtract(const Duration(seconds: 5));
  // Timer for calling Gemini AI periodically
  Timer? _descriptionTimer;

  ObjectDetectionService _objectDetectionService = ObjectDetectionService();

  @override
  void initState() {
    super.initState();
    _initializeDetector();

    // Wait a moment for the UI to initialize before requesting camera access
    Future.delayed(const Duration(milliseconds: 500), _initializeCamera);

    // Show initial message
    setState(() {
      _statusMessage = 'Initializing vision assist system...';
    });

    // Announce the screen is ready for blind users
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final accessibilityProvider =
          Provider.of<AccessibilityProvider>(context, listen: false);
      if (accessibilityProvider.audioConfirmation) {
        accessibilityProvider.speakText(
            "Vision assist ready. Camera feed will start shortly. Swipe up to open accessibility settings.",
            interrupt: true);
      }
    });
  }

  Future<void> _initializeCamera() async {
    try {
      // Request camera access
      final stream = await html.window.navigator.mediaDevices?.getUserMedia({
        'video': {
          'facingMode': 'environment', // Prefer rear camera
          'width': {'ideal': 1280},
          'height': {'ideal': 720}
        }
      });

      if (stream != null) {
        // Find the video element in the DOM
        final videoElements = html.document.getElementsByTagName('video');
        html.VideoElement? videoElement;

        if (videoElements.isNotEmpty) {
          videoElement = videoElements[0] as html.VideoElement;

          // Connect the stream to the existing video element
          videoElement.srcObject = stream;
          videoElement.play();

          // Store reference to the camera stream for processing
          _cameraStream = videoElement;

          // Create canvas for processing frames
          _canvas = html.CanvasElement();
          _ctx = _canvas!.context2D;

          setState(() {
            _errorMessage = null;
            _statusMessage = 'Camera feed active';
            _isCameraInitialized = true;
          });

          // Set up processing frames
          _startDetection();
          // Start Gemini description timer
          _startDescriptionTimer();
        } else {
          throw Exception("Video element not found in the DOM");
        }
      } else {
        throw Exception("Could not access camera stream");
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error accessing camera: $e';
        _statusMessage = 'Camera access failed';
        _isCameraInitialized = false;
      });

      final accessibilityProvider =
          Provider.of<AccessibilityProvider>(context, listen: false);
      if (accessibilityProvider.audioConfirmation) {
        accessibilityProvider.speakText(
            "Error accessing camera. Please check camera permissions.");
      }
    }
  }

  void _initializeDetector() {
    _objectDetectionService.initialize().then((success) {
      setState(() {
        _isDetectorInitialized = success;
        if (!success) {
          _errorMessage = 'Failed to initialize object detector.';
          _statusMessage = 'Error: Vision assist system not available';
        } else {
          _errorMessage =
              _errorMessage == 'Failed to initialize object detector.'
                  ? null
                  : _errorMessage;
          _statusMessage = 'Vision assist system ready';
        }
      });
    });

    // Listen for detections
    _objectDetectionService.detectionsStream.listen((trackedObjects) {
      if (mounted) {
        setState(() {
          _trackedObjects = trackedObjects;
          _isProcessingFrame = false;

          // Update status message with number of detected objects
          if (_trackedObjects.isNotEmpty) {
            _statusMessage = '${_trackedObjects.length} objects detected';
          } else {
            _statusMessage = 'No objects detected';
          }
        });
      }
    });
  }

  void _captureVideoFrame() {
    if (_cameraStream == null ||
        _canvas == null ||
        _ctx == null ||
        _isProcessingFrame ||
        !_isDetectorInitialized) {
      return;
    }

    _isProcessingFrame = true;

    // Process the current frame
    _objectDetectionService.processCameraFrame(_cameraStream!).then((result) {
      // Processing is done in the service
      _isProcessingFrame = false;
    }).catchError((error) {
      print('Error processing frame: $error');
      _isProcessingFrame = false;
    });
  }

  void _startDetection() {
    // Cancel any existing timer
    _detectionTimer?.cancel();

    // Create a new timer to capture frames periodically
    _detectionTimer =
        Timer.periodic(const Duration(milliseconds: 500), (timer) {
      _captureVideoFrame();
    });
  }

  void _startDescriptionTimer() {
    _descriptionTimer?.cancel();

    // Generate AI descriptions every 5 seconds
    _descriptionTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _generateGeminiDescription();
    });
  }

  Future<void> _generateGeminiDescription() async {
    if (_trackedObjects.isEmpty) return;

    // Check if enough time has passed since the last description
    final now = DateTime.now();
    if (now.difference(_lastDescriptionTime).inSeconds < 5) {
      return;
    }

    _lastDescriptionTime = now;

    // Get the Gemini provider
    final geminiProvider = Provider.of<GeminiProvider>(context, listen: false);
    final accessibilityProvider =
        Provider.of<AccessibilityProvider>(context, listen: false);

    // Generate a description using Gemini
    final description =
        await geminiProvider.generateDescription(_trackedObjects);

    if (description.isNotEmpty && accessibilityProvider.audioConfirmation) {
      // Use the browser's speech synthesis to speak the description
      js.context.callMethod('speakText', [description, true, 1.0, 1.0]);
    }
  }

  void _togglePlayback() {
    if (_cameraStream == null) return;

    setState(() {
      if (_cameraStream!.paused) {
        _cameraStream!.play();
        _startDetection();
        _startDescriptionTimer();
        _statusMessage = 'Analyzing camera feed...';

        // Announce UI state only
        final accessibilityProvider =
            Provider.of<AccessibilityProvider>(context, listen: false);
        if (accessibilityProvider.audioConfirmation) {
          accessibilityProvider.speakText("Camera feed playing",
              interrupt: true);
        }
      } else {
        _cameraStream!.pause();
        _detectionTimer?.cancel();
        _descriptionTimer?.cancel();
        _statusMessage = 'Analysis paused';

        // Announce UI state only
        final accessibilityProvider =
            Provider.of<AccessibilityProvider>(context, listen: false);
        if (accessibilityProvider.audioConfirmation) {
          accessibilityProvider.speakText("Camera feed paused",
              interrupt: true);
        }
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });

    // Announce UI state only
    final accessibilityProvider =
        Provider.of<AccessibilityProvider>(context, listen: false);
    if (accessibilityProvider.audioConfirmation) {
      accessibilityProvider.speakText(
          _showControls ? "Controls visible" : "Controls hidden",
          interrupt: true);
    }
  }

  void _openAccessibilitySettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AccessibilitySettingsScreen(),
      ),
    );
  }

  void _onTap() {
    _tapCount++;

    if (_tapCount == 1) {
      _tapTimer = Timer(const Duration(milliseconds: 300), () {
        if (_tapCount == 1) {
          // Single tap
          _toggleControls();
        } else {
          // Double tap
          if (_errorMessage != null) {
            _initializeCamera();
          } else {
            _togglePlayback();
          }
        }
        _tapCount = 0;
      });
    }
  }

  void _onLongPress() {
    _isLongPress = true;
    final accessibilityProvider =
        Provider.of<AccessibilityProvider>(context, listen: false);
    final geminiProvider = Provider.of<GeminiProvider>(context, listen: false);

    // Announce current status or Gemini description if available
    if (accessibilityProvider.audioConfirmation) {
      if (_errorMessage != null) {
        accessibilityProvider.speakText(
            "Vision assist home screen. No camera feed. Double tap to start camera feed. Swipe up to access settings.",
            interrupt: true);
      } else if (_cameraStream != null) {
        final description = geminiProvider.latestDescription;
        if (description.isNotEmpty) {
          // Use Gemini's description directly
          js.context.callMethod('speakText', [description, true, 1.0, 1.0]);
        } else {
          // Only announce UI state
          accessibilityProvider.speakText(
              "Camera feed active. ${_trackedObjects.length} objects detected. Swipe up for settings.",
              interrupt: true);
        }
      }
    }

    _isLongPress = false;
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _descriptionTimer?.cancel();
    _tapTimer?.cancel();
    _cameraStream?.srcObject?.getTracks().forEach((track) => track.stop());
    _objectDetectionService.dispose();
    super.dispose();
  }

  // Show settings bottom sheet
  void _showSettingsBottomSheet(BuildContext context) {
    final accessibilityProvider =
        Provider.of<AccessibilityProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.contrast),
                title: const Text('High Contrast Mode'),
                trailing: Switch(
                  value: accessibilityProvider.highContrastMode,
                  onChanged: (value) {
                    accessibilityProvider.toggleHighContrastMode();
                    setState(() {});
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.volume_up),
                title: const Text('Audio Confirmation'),
                trailing: Switch(
                  value: accessibilityProvider.audioConfirmation,
                  onChanged: (value) {
                    accessibilityProvider.toggleAudioConfirmation();
                    setState(() {});
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.text_fields),
                title: const Text('Text Size'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () {
                        accessibilityProvider.decreaseTextSize();
                        setState(() {});
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        accessibilityProvider.increaseTextSize();
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.api),
                title: const Text('Gemini API Key'),
                subtitle: const Text('Set up or change your API key'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/api_key');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accessibilityProvider = Provider.of<AccessibilityProvider>(context);
    final geminiProvider = Provider.of<GeminiProvider>(context);
    final screenSize = MediaQuery.of(context).size;

    // Determine if we should show the API key setup button
    final showApiKeyButton = !geminiProvider.isInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (showApiKeyButton)
            IconButton(
              icon: const Icon(Icons.vpn_key, color: Colors.white),
              onPressed: () {
                Navigator.pushNamed(context, '/api_key');
              },
              tooltip: 'Set up Gemini API Key',
            ),
          IconButton(
            icon: Icon(
              Icons.settings,
              color: Colors.white,
              size: 28 * accessibilityProvider.iconScaleFactor,
            ),
            onPressed: () {
              // Show settings or info sheet
              _showSettingsBottomSheet(context);
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: _onTap,
        onLongPress: _onLongPress,
        child: Stack(
          children: [
            // Black background (camera will display on top of this)
            Container(
              color: Colors.black,
              width: screenSize.width,
              height: screenSize.height,
            ),

            // Camera preview - this creates and displays the video element
            Positioned.fill(
              child: HtmlElementView(
                viewType: 'camera-preview',
              ),
            ),

            // Object detection overlay
            if (_trackedObjects.isNotEmpty)
              Positioned.fill(
                child: CustomPaint(
                  painter: ObjectDetectionPainter(
                    trackedObjects: _trackedObjects,
                    frameSize: Size(
                      screenSize.width,
                      screenSize.height,
                    ),
                    highContrast: accessibilityProvider.highContrastMode,
                  ),
                ),
              ),

            // Status overlay
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                color: Colors.black54,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_errorMessage != null)
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      Text(
                        _statusMessage,
                        style: const TextStyle(color: Colors.white),
                      ),
                      if (geminiProvider.latestDescription.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            geminiProvider.latestDescription,
                            style: const TextStyle(
                              color: Colors.white,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),

                      // Debug button for camera access
                      if (!_isCameraInitialized || _errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: ElevatedButton(
                            onPressed: _initializeCamera,
                            child: const Text('Request Camera Access'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Controls overlay
            if (_showControls)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.black54,
                  child: SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _togglePlayback,
                          icon: Icon(
                            _cameraStream?.paused ?? true
                                ? Icons.play_arrow
                                : Icons.pause,
                            size: 24 * accessibilityProvider.iconScaleFactor,
                          ),
                          label: Text(
                            _cameraStream?.paused ?? true ? 'Start' : 'Pause',
                            style: TextStyle(
                              fontSize:
                                  14 * accessibilityProvider.textScaleFactor,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _openAccessibilitySettings,
                          icon: Icon(
                            Icons.accessibility_new,
                            size: 24 * accessibilityProvider.iconScaleFactor,
                          ),
                          label: Text(
                            'Settings',
                            style: TextStyle(
                              fontSize:
                                  14 * accessibilityProvider.textScaleFactor,
                            ),
                          ),
                        ),
                        // Button to force generate a description
                        ElevatedButton.icon(
                          onPressed: _generateGeminiDescription,
                          icon: Icon(
                            Icons.smart_toy,
                            size: 24 * accessibilityProvider.iconScaleFactor,
                          ),
                          label: Text(
                            'Describe',
                            style: TextStyle(
                              fontSize:
                                  14 * accessibilityProvider.textScaleFactor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ObjectDetectionPainter extends CustomPainter {
  final List<TrackedObject> trackedObjects;
  final Size frameSize;
  final bool highContrast;

  ObjectDetectionPainter({
    required this.trackedObjects,
    required this.frameSize,
    this.highContrast = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint boxPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final textPaint = Paint()..style = PaintingStyle.fill;

    for (var object in trackedObjects) {
      // Scale bounding box to fit the canvas
      final double scaleX = size.width / frameSize.width;
      final double scaleY = size.height / frameSize.height;

      final scaledLeft = object.lastBox.left * scaleX;
      final scaledTop = object.lastBox.top * scaleY;
      final scaledWidth = object.lastBox.width * scaleX;
      final scaledHeight = object.lastBox.height * scaleY;

      final Rect rect = Rect.fromLTWH(
        scaledLeft,
        scaledTop,
        scaledWidth,
        scaledHeight,
      );

      // Choose color based on object type
      Color color;
      if (highContrast) {
        color = Colors.yellow;
      } else {
        // Different colors for different object types
        switch (object.categoryName) {
          case 'person':
            color = Colors.red;
            break;
          case 'car':
          case 'truck':
          case 'bus':
            color = Colors.blue;
            break;
          case 'dog':
          case 'cat':
            color = Colors.green;
            break;
          default:
            color = Colors.purple;
        }
      }

      boxPaint.color = color;
      canvas.drawRect(rect, boxPaint);

      // Draw label
      final textSpan = TextSpan(
        text:
            "${object.categoryName} ${(object.confidence * 100).toStringAsFixed(0)}%",
        style: TextStyle(
          color: highContrast ? Colors.black : Colors.white,
          backgroundColor: color,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(scaledLeft, scaledTop > 20 ? scaledTop - 20 : scaledTop),
      );
    }
  }

  @override
  bool shouldRepaint(ObjectDetectionPainter oldDelegate) {
    return oldDelegate.trackedObjects != trackedObjects ||
        oldDelegate.frameSize != frameSize ||
        oldDelegate.highContrast != highContrast;
  }
}
