import 'dart:async';
import 'dart:html' as html;
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:path_provider/path_provider.dart';
import '../models/detection.dart';
import '../models/tracked_object.dart';
import '../services/gemini_service.dart';
import '../services/speech_service.dart';
import '../utils/constants.dart';
import '../utils/detection_utils.dart';
import '../widgets/detection_highlight.dart';
import '../widgets/detection_label.dart';
import 'package:video_player/video_player.dart';
import 'package:image_picker/image_picker.dart';
import '../models/point.dart';
import '../models/bounding_box.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  VideoPlayerController? _videoController;
  bool _isCameraInitialized = false;
  bool _isRecording = false;
  bool _isVideoMode = false;
  String? _errorMessage;
  List<TrackedObject> _trackedObjects = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'No cameras found. You can still upload a video to test.';
        });
        return;
      }

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Camera initialization failed. You can still upload a video to test.\nError: $e';
      });
    }
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
          // Add a sample tracked object for testing the UI
          _addSampleObject();
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading video: $e';
      });
    }
  }

  void _addSampleObject() {
    // Create a sample object for testing the UI
    final box = BoundingBox(
      left: 100,
      top: 100,
      width: 150,
      height: 150,
    );

    final detection = Detection(
      boundingBox: box,
      categoryName: 'Sample Object',
      confidence: 0.95,
      center: Point(x: box.left + box.width / 2, y: box.top + box.height / 2),
    );

    final trackedObject = TrackedObject.fromDetection(detection);
    _trackedObjects = [trackedObject];
  }

  void _togglePlayback() {
    if (_videoController == null) return;

    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
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
                    ),
                    ..._trackedObjects.map((object) => Positioned(
                      left: object.lastBox.left,
                      top: object.lastBox.top,
                      child: DetectionLabel(
                        object: object,
                        frameSize: Size(
                          _videoController!.value.size.width,
                          _videoController!.value.size.height,
                        ),
                      ),
                    )),
                  ],
                ),
              ),
            )
          else if (_isCameraInitialized)
            CameraPreview(_cameraController!),

          // Controls Overlay
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isVideoMode = false;
                      _videoController?.pause();
                      _trackedObjects.clear();
                    });
                  },
                  icon: const Icon(Icons.camera),
                  label: const Text('Camera'),
                ),
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
                  Text(
                    'Mode: ${_isVideoMode ? "Video" : "Camera"}',
                    style: const TextStyle(color: Colors.white),
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