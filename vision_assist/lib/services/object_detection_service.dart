// JavaScript interop
@JS()
library object_detection;

import 'package:js/js.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import '../models/bounding_box.dart';
import '../models/detection.dart';
import '../models/point.dart';
import '../models/tracked_object.dart';

@JS('initObjectDetector')
external Future<bool> initObjectDetector();

@JS('detectObjects')
external Future<String> detectObjects(String imageUrl);

class ObjectDetectionService {
  bool _isInitialized = false;
  final StreamController<List<TrackedObject>> _detectionsStreamController =
      StreamController<List<TrackedObject>>.broadcast();

  Stream<List<TrackedObject>> get detectionsStream =>
      _detectionsStreamController.stream;

  // Initialize the object detector
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      final completer = Completer<bool>();

      // Set up a callback for when initialization is complete
      js.context['onDetectorInitialized'] = js.allowInterop((bool success) {
        completer.complete(success);
      });

      // Call the JavaScript initialization function
      js.context.callMethod('initDetector');

      // Wait for the callback
      _isInitialized = await completer.future;
      return _isInitialized;
    } catch (e) {
      print('Error initializing object detector: $e');
      return false;
    }
  }

  // Process camera frame and detect objects
  Future<List<TrackedObject>> processCameraFrame(
    html.VideoElement cameraStream,
  ) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Create a canvas to capture the camera frame
      final canvas = html.CanvasElement(
        width: cameraStream.videoWidth,
        height: cameraStream.videoHeight,
      );
      canvas.context2D.drawImage(cameraStream, 0, 0);

      // Convert canvas to data URL
      final dataUrl = canvas.toDataUrl('image/jpeg');

      // Use a completer to handle the asynchronous JavaScript call
      final completer = Completer<String>();

      // Set up callback for detection results
      js.context['onDetectionComplete'] = js.allowInterop((String resultsJson) {
        completer.complete(resultsJson);
      });

      // Call the JavaScript detection function
      js.context.callMethod('detectObjectsFromImage', [dataUrl]);

      // Wait for the callback with results
      final resultsJson = await completer.future;
      final results = json.decode(resultsJson);

      // Process the detections
      final videoWidth = cameraStream.videoWidth.toDouble();
      final videoHeight = cameraStream.videoHeight.toDouble();
      final trackedObjects = _processDetections(
        results,
        videoWidth,
        videoHeight,
      );

      // Broadcast the detections
      _detectionsStreamController.add(trackedObjects);

      return trackedObjects;
    } catch (e) {
      print('Error processing camera frame: $e');
      return [];
    }
  }

  List<TrackedObject> _processDetections(
    List<dynamic> detections,
    double videoWidth,
    double videoHeight,
  ) {
    return detections.map((detection) {
      final box = BoundingBox(
        left: detection['bbox'][0].toDouble(),
        top: detection['bbox'][1].toDouble(),
        width: detection['bbox'][2].toDouble(),
        height: detection['bbox'][3].toDouble(),
      );

      final center = Point(
        x: box.left + (box.width / 2),
        y: box.top + (box.height / 2),
      );

      return TrackedObject(
        id: detection['id'].toString(),
        positions: [center],
        timestamps: [DateTime.now()],
        categoryName: detection['class'],
        speed: 0.0,
        direction: 0.0,
        velocity: Point(x: 0, y: 0),
        lastSeen: DateTime.now(),
        missingFrames: 0,
        lastBox: box,
        confidence: detection['score'].toDouble(),
      );
    }).toList();
  }

  void dispose() {
    _detectionsStreamController.close();
  }
}

// Static instance for app-wide use
final objectDetectionService = ObjectDetectionService();
