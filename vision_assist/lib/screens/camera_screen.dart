import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../models/detection.dart';
import '../models/tracked_object.dart';
import '../models/point.dart';
import '../models/bounding_box.dart';
import '../widgets/detection_highlight.dart';
import '../widgets/detection_label.dart';
import '../providers/accessibility_provider.dart';
import 'accessibility_settings_screen.dart';
import 'dart:convert';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with SingleTickerProviderStateMixin {
  VideoPlayerController? _videoController;
  bool _isVideoMode = true; // Default to video mode for web
  String? _errorMessage;
  List<TrackedObject> _trackedObjects = [];
  Timer? _detectionTimer;
  bool _isDetectorInitialized = false;
  String? _videoUrl;
  bool _isProcessingFrame = false;
  bool _showControls = true;
  bool _audioEnabled = true;
  String _statusMessage = '';
  
  // Tap detection and counters for accessibility gestures
  int _tapCount = 0;
  Timer? _tapTimer;
  bool _isLongPress = false;
  
  @override
  void initState() {
    super.initState();
    _initializeDetector();
    
    // Show initial message
    setState(() {
      _errorMessage = 'Please upload a video to begin object detection.';
      _statusMessage = 'Initializing vision assist system...';
    });
    
    // Announce the screen is ready for blind users
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final accessibilityProvider = Provider.of<AccessibilityProvider>(context, listen: false);
      if (accessibilityProvider.audioConfirmation) {
        accessibilityProvider.speakText(
          "Vision assist ready. Double tap to upload a video. Swipe up to open accessibility settings.",
          interrupt: true
        );
      }
    });
  }
  
  void _initializeDetector() {
    // Set up callback for when detector is initialized
    js.context['onDetectorInitialized'] = js.allowInterop((bool success) {
      setState(() {
        _isDetectorInitialized = success;
        if (!success) {
          _errorMessage = 'Failed to initialize object detector.';
          _statusMessage = 'Error: Vision assist system not available';
        } else {
          _errorMessage = _errorMessage == 'Failed to initialize object detector.' ? null : _errorMessage;
          _statusMessage = 'Vision assist system ready';
        }
      });
      print("Detector initialized: $success");
    });
    
    // Set up callback for detection results
    js.context['onDetectionComplete'] = js.allowInterop((String resultsJson) {
      final results = json.decode(resultsJson);
      _processDetectionResults(results);
    });
    
    // Set up callback for tracking results
    js.context['onTrackingComplete'] = js.allowInterop((String trackedObjectsJson) {
      final List<dynamic> trackedObjectsData = json.decode(trackedObjectsJson);
      
      setState(() {
        _trackedObjects = trackedObjectsData.map((data) {
          final box = BoundingBox(
            left: data['lastBox']['left'].toDouble(),
            top: data['lastBox']['top'].toDouble(),
            width: data['lastBox']['width'].toDouble(),
            height: data['lastBox']['height'].toDouble(),
          );
          
          final center = Point(
            x: data['center']['x'].toDouble(),
            y: data['center']['y'].toDouble(),
          );
          
          final detection = Detection(
            boundingBox: box,
            categoryName: data['label'],
            confidence: data['confidence'].toDouble(),
            center: center,
          );
          
          // Create a new TrackedObject with all required properties
          return TrackedObject(
            id: data['id'].toString(),
            positions: [center],
            timestamps: [DateTime.now()],
            categoryName: data['label'],
            speed: data['speed'].toDouble(),
            direction: data['direction'].toDouble(),
            velocity: Point(x: 0, y: 0),
            lastSeen: DateTime.now(),
            missingFrames: 0,
            lastBox: box,
            confidence: data['confidence'].toDouble(),
          );
        }).toList();
        
        // Update status message with number of detected objects
        if (_trackedObjects.isNotEmpty) {
          _statusMessage = '${_trackedObjects.length} objects detected';
          
          // Find the closest object for status display
          TrackedObject? closestObject;
          double maxArea = 0;
          Map<String, dynamic>? closestData;
          
          // Store the corresponding data for the closest object
          for (var i = 0; i < _trackedObjects.length; i++) {
            var obj = _trackedObjects[i];
            final area = obj.lastBox.width * obj.lastBox.height;
            if (area > maxArea) {
              maxArea = area;
              closestObject = obj;
              if (i < trackedObjectsData.length) {
                closestData = trackedObjectsData[i];
              }
            }
          }
          
          if (closestObject != null && closestData != null) {
            final relativeDirection = closestData['relativeDirection'] ?? 'front';
            _statusMessage = '${closestObject.categoryName} ${relativeDirection}, ${closestData['proximityStatus'] ?? 'detected'}';
          }
        } else {
          _statusMessage = 'No objects detected';
        }
        
        _isProcessingFrame = false;
      });
    });
    
    // Initialize the detector in JavaScript
    js.context.callMethod('initDetector');
  }
  
  void _processDetectionResults(Map<String, dynamic> results) {
    if (_videoController == null || !mounted) return;
    
    final frameWidth = _videoController!.value.size.width;
    final frameHeight = _videoController!.value.size.height;
    
    // Forward the detection results to the tracking function
    js.context.callMethod('trackObjects', [
      json.encode(results),
      frameWidth,
      frameHeight,
    ]);
  }
  
  void _captureVideoFrame() {
    if (_videoController == null || 
        !_videoController!.value.isInitialized || 
        !_videoController!.value.isPlaying ||
        _isProcessingFrame ||
        !_isDetectorInitialized ||
        _videoUrl == null) {
      return;
    }
    
    _isProcessingFrame = true;
    
    // Extract the current video time
    final videoPosition = _videoController!.value.position.inMilliseconds / 1000.0;
    
    // Create a video element to capture the current frame
    final videoElement = html.VideoElement()
      ..src = _videoUrl!
      ..currentTime = videoPosition;
    
    // When the video has loaded to the specified time
    videoElement.onTimeUpdate.listen((_) {
      // Create a canvas to draw the video frame
      final canvas = html.CanvasElement(
        width: _videoController!.value.size.width.toInt(),
        height: _videoController!.value.size.height.toInt(),
      );
      
      // Draw the current video frame to the canvas - fix parameter count
      canvas.context2D.drawImageScaled(
        videoElement, 
        0, 
        0, 
        _videoController!.value.size.width, 
        _videoController!.value.size.height
      );
      
      // Convert canvas to data URL
      final frameUrl = canvas.toDataUrl('image/jpeg');
      
      // Call the JavaScript detection function with the frame
      js.context.callMethod('detectObjectsFromImage', [frameUrl]);
      
      // Clean up
      videoElement.remove();
    });
    
    // Handle errors
    videoElement.onError.listen((_) {
      print("Error capturing video frame");
      _isProcessingFrame = false;
    });
  }
  
  void _startDetection() {
    // Cancel any existing timer
    _detectionTimer?.cancel();
    
    // Create a new timer to capture frames periodically
    _detectionTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      _captureVideoFrame();
    });
  }

  Future<void> _pickVideo() async {
    try {
      final input = html.FileUploadInputElement()..accept = 'video/*';
      input.click();

      // Get accessibility provider
      final accessibilityProvider = Provider.of<AccessibilityProvider>(context, listen: false);
      if (accessibilityProvider.audioConfirmation) {
        accessibilityProvider.speakText("Please select a video file");
      }

      await input.onChange.first;
      if (input.files?.isEmpty ?? true) return;

      final file = input.files![0];
      final url = html.Url.createObjectUrl(file);
      
      if (accessibilityProvider.audioConfirmation) {
        accessibilityProvider.speakText("Video selected, loading...");
      }
      
      await _loadVideo(url);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking video: $e';
      });
      
      // Announce error
      final accessibilityProvider = Provider.of<AccessibilityProvider>(context, listen: false);
      if (accessibilityProvider.audioConfirmation) {
        accessibilityProvider.speakText("Error selecting video: $e");
      }
    }
  }

  Future<void> _loadVideo(String videoUrl) async {
    try {
      _videoController?.dispose();
      _videoController = VideoPlayerController.network(videoUrl);

      await _videoController!.initialize();
      await _videoController!.setLooping(true);
      
      if (mounted) {
        setState(() {
          _isVideoMode = true;
          _errorMessage = null;
          _videoUrl = videoUrl;
          _trackedObjects = [];
          _statusMessage = 'Video loaded, starting analysis...';
        });
        
        // Get accessibility provider
        final accessibilityProvider = Provider.of<AccessibilityProvider>(context, listen: false);
        if (accessibilityProvider.audioConfirmation) {
          accessibilityProvider.speakText("Video loaded. Starting object detection.");
        }
        
        _startDetection();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading video: $e';
      });
      
      // Announce error
      final accessibilityProvider = Provider.of<AccessibilityProvider>(context, listen: false);
      if (accessibilityProvider.audioConfirmation) {
        accessibilityProvider.speakText("Error loading video: $e");
      }
    }
  }

  void _togglePlayback() {
    if (_videoController == null) return;

    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
        _detectionTimer?.cancel();
        _statusMessage = 'Analysis paused';
        
        // Announce pause
        final accessibilityProvider = Provider.of<AccessibilityProvider>(context, listen: false);
        if (accessibilityProvider.audioConfirmation) {
          accessibilityProvider.speakText("Video paused");
        }
      } else {
        _videoController!.play();
        _startDetection();
        _statusMessage = 'Analyzing video...';
        
        // Announce play
        final accessibilityProvider = Provider.of<AccessibilityProvider>(context, listen: false);
        if (accessibilityProvider.audioConfirmation) {
          accessibilityProvider.speakText("Video playing");
        }
      }
    });
  }
  
  void _toggleAudio() {
    final accessibilityProvider = Provider.of<AccessibilityProvider>(context, listen: false);
    accessibilityProvider.toggleAudioConfirmation();
    
    setState(() {
      _audioEnabled = accessibilityProvider.audioConfirmation;
      _statusMessage = _audioEnabled ? 'Audio feedback enabled' : 'Audio feedback disabled';
    });
  }
  
  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    
    // Announce control visibility
    final accessibilityProvider = Provider.of<AccessibilityProvider>(context, listen: false);
    if (accessibilityProvider.audioConfirmation) {
      accessibilityProvider.speakText(_showControls ? "Controls visible" : "Controls hidden");
    }
  }
  
  void _openAccessibilitySettings() {
    final accessibilityProvider = Provider.of<AccessibilityProvider>(context, listen: false);
    if (accessibilityProvider.audioConfirmation) {
      accessibilityProvider.speakText("Opening accessibility settings");
    }
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AccessibilitySettingsScreen(),
      ),
    );
  }
  
  // Handle tap count for multi-tap gestures
  void _handleTap() {
    _tapCount++;
    
    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(milliseconds: 300), () {
      if (_tapCount == 1) {
        // Single tap
        _toggleControls();
      } else if (_tapCount == 2) {
        // Double tap
        if (_errorMessage != null) {
          _pickVideo();
        } else {
          _togglePlayback();
        }
      } else if (_tapCount == 3) {
        // Triple tap - stop all audio
        js.context.callMethod('speakText', ["", true]);
      }
      
      _tapCount = 0;
    });
  }
  
  // Handle long press for detailed description
  void _handleLongPressStart() {
    _isLongPress = true;
    
    // Describe the current screen for blind users
    final accessibilityProvider = Provider.of<AccessibilityProvider>(context, listen: false);
    if (accessibilityProvider.audioConfirmation) {
      if (_errorMessage != null) {
        accessibilityProvider.speakText(
          "Vision assist home screen. No video loaded. Double tap to upload a video. Swipe up to access settings.",
          interrupt: true
        );
      } else if (_videoController != null) {
        final objectCount = _trackedObjects.length;
        final videoStatus = _videoController!.value.isPlaying ? "playing" : "paused";
        
        accessibilityProvider.speakText(
          "Video $videoStatus. $objectCount objects detected. $_statusMessage. Double tap to ${videoStatus == 'playing' ? 'pause' : 'play'}. Swipe up for settings.",
          interrupt: true
        );
      }
    }
  }
  
  void _handleLongPressEnd() {
    _isLongPress = false;
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _tapTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AccessibilityProvider>(
      builder: (context, accessibilityProvider, child) {
        return Scaffold(
          body: GestureDetector(
            // Basic tap detection
            onTap: _handleTap,
            
            // Long press for detailed description
            onLongPressStart: (_) => _handleLongPressStart(),
            onLongPressEnd: (_) => _handleLongPressEnd(),
            
            // Swipe gestures for navigation
            onVerticalDragEnd: (details) {
              if (!accessibilityProvider.swipeNavigation) return;
              
              // Swipe up to open settings
              if (details.primaryVelocity! < -500) {
                _openAccessibilitySettings();
              }
              // Swipe down to show controls
              else if (details.primaryVelocity! > 500 && !_showControls) {
                setState(() {
                  _showControls = true;
                });
                
                if (accessibilityProvider.audioConfirmation) {
                  accessibilityProvider.speakText("Controls visible");
                }
              }
            },
            
            child: Stack(
              children: [
                // Main Content
                if (_errorMessage != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _pickVideo,
                            icon: const Icon(Icons.video_library),
                            label: const Text('Upload Video'),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                horizontal: 30 * accessibilityProvider.uiScaleFactor, 
                                vertical: 15 * accessibilityProvider.uiScaleFactor
                              ),
                              textStyle: TextStyle(
                                fontSize: 18 * accessibilityProvider.textScaleFactor
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _statusMessage,
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 30),
                          // Accessibility options
                          ElevatedButton.icon(
                            onPressed: _openAccessibilitySettings,
                            icon: const Icon(Icons.accessibility_new),
                            label: const Text('Accessibility Settings'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              padding: EdgeInsets.symmetric(
                                horizontal: 20 * accessibilityProvider.uiScaleFactor, 
                                vertical: 12 * accessibilityProvider.uiScaleFactor
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_isVideoMode && _videoController != null)
                  Center(
                    child: AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: Stack(
                        children: [
                          VideoPlayer(_videoController!),
                          CustomPaint(
                            painter: DetectionHighlight(
                              trackedObjects: _trackedObjects,
                              highContrast: accessibilityProvider.highContrastMode,
                            ),
                            size: Size(
                              _videoController!.value.size.width,
                              _videoController!.value.size.height,
                            ),
                          ),
                          ..._trackedObjects.map((object) {
                            final frameSize = Size(
                              _videoController!.value.size.width,
                              _videoController!.value.size.height,
                            );
                            return Positioned(
                              left: object.lastBox.left,
                              top: object.lastBox.top - 40,
                              child: DetectionLabel(
                                object: object,
                                frameSize: frameSize,
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
    
                // Controls Overlay (Only show when _showControls is true)
                if (_showControls)
                  Positioned(
                    top: 40,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickVideo,
                              icon: Icon(
                                Icons.video_library,
                                size: 24 * accessibilityProvider.iconScaleFactor,
                              ),
                              label: Text(
                                'Upload Video',
                                style: TextStyle(
                                  fontSize: 14 * accessibilityProvider.textScaleFactor,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 20 * accessibilityProvider.uiScaleFactor, 
                                  vertical: 15 * accessibilityProvider.uiScaleFactor
                                ),
                              ),
                            ),
                            if (_isVideoMode && _videoController != null)
                              ElevatedButton.icon(
                                onPressed: _togglePlayback,
                                icon: Icon(
                                  _videoController!.value.isPlaying
                                      ? Icons.pause
                                      : Icons.play_arrow,
                                  size: 24 * accessibilityProvider.iconScaleFactor,
                                ),
                                label: Text(
                                  _videoController!.value.isPlaying ? 'Pause' : 'Play',
                                  style: TextStyle(
                                    fontSize: 14 * accessibilityProvider.textScaleFactor,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 20 * accessibilityProvider.uiScaleFactor, 
                                    vertical: 15 * accessibilityProvider.uiScaleFactor
                                  ),
                                ),
                              ),
                            IconButton(
                              onPressed: _toggleAudio, 
                              icon: Icon(
                                accessibilityProvider.audioConfirmation ? Icons.volume_up : Icons.volume_off,
                                size: 32 * accessibilityProvider.iconScaleFactor,
                              ),
                              tooltip: accessibilityProvider.audioConfirmation ? 'Disable audio feedback' : 'Enable audio feedback',
                              color: Colors.white,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                padding: EdgeInsets.all(10 * accessibilityProvider.uiScaleFactor),
                              ),
                            ),
                            IconButton(
                              onPressed: _openAccessibilitySettings, 
                              icon: Icon(
                                Icons.accessibility_new,
                                size: 32 * accessibilityProvider.iconScaleFactor,
                              ),
                              tooltip: 'Accessibility Settings',
                              color: Colors.white,
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.teal,
                                padding: EdgeInsets.all(10 * accessibilityProvider.uiScaleFactor),
                              ),
                            ),
                          ],
                        ),
                        // Help text
                        const SizedBox(height: 10),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 20 * accessibilityProvider.uiScaleFactor, 
                            vertical: 10 * accessibilityProvider.uiScaleFactor
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Tap screen to hide controls',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14 * accessibilityProvider.textScaleFactor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Detection Info Overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(16 * accessibilityProvider.uiScaleFactor),
                    color: Colors.black54,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Mode: Video with Real-time Detection',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14 * accessibilityProvider.textScaleFactor,
                          ),
                        ),
                        SizedBox(height: 8 * accessibilityProvider.uiScaleFactor),
                        Row(
                          children: [
                            Text(
                              'Objects Detected: ${_trackedObjects.length}',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14 * accessibilityProvider.textScaleFactor,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10 * accessibilityProvider.uiScaleFactor, 
                                vertical: 5 * accessibilityProvider.uiScaleFactor
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade700,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Text(
                                _statusMessage,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14 * accessibilityProvider.textScaleFactor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Gesture hints
                        if (accessibilityProvider.swipeNavigation)
                          Padding(
                            padding: EdgeInsets.only(top: 8 * accessibilityProvider.uiScaleFactor),
                            child: Text(
                              'Swipe up for settings • Double tap for video controls • Long press for description',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12 * accessibilityProvider.textScaleFactor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 