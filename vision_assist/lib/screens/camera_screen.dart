import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/detection.dart';
import '../models/tracked_object.dart';
import '../models/point.dart';
import '../models/bounding_box.dart';
import '../widgets/detection_highlight.dart';
import '../widgets/detection_label.dart';
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
  
  @override
  void initState() {
    super.initState();
    _initializeDetector();
    
    // Show initial message
    setState(() {
      _errorMessage = 'Please upload a video to begin object detection.';
    });
  }
  
  void _initializeDetector() {
    // Set up callback for when detector is initialized
    js.context['onDetectorInitialized'] = js.allowInterop((bool success) {
      setState(() {
        _isDetectorInitialized = success;
        if (!success) {
          _errorMessage = 'Failed to initialize object detector.';
        } else {
          _errorMessage = _errorMessage == 'Failed to initialize object detector.' ? null : _errorMessage;
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

      await input.onChange.first;
      if (input.files?.isEmpty ?? true) return;

      final file = input.files![0];
      final url = html.Url.createObjectUrl(file);
      await _loadVideo(url);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking video: $e';
      });
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
        });
        
        _startDetection();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading video: $e';
      });
    }
  }

  void _togglePlayback() {
    if (_videoController == null) return;

    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
        _detectionTimer?.cancel();
      } else {
        _videoController!.play();
        _startDetection();
      }
    });
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
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

          // Controls Overlay
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickVideo,
                  icon: const Icon(Icons.video_library),
                  label: const Text('Upload Video'),
                ),
                if (_isVideoMode && _videoController != null)
                  ElevatedButton.icon(
                    onPressed: _togglePlayback,
                    icon: Icon(
                      _videoController!.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                    label: Text(
                      _videoController!.value.isPlaying ? 'Pause' : 'Play',
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
              padding: const EdgeInsets.all(16),
              color: Colors.black54,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Mode: Video with Real-time Detection',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Objects Detected: ${_trackedObjects.length}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 