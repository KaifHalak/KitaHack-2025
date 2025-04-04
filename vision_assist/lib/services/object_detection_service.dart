// JavaScript interop
@JS()
library object_detection;

import 'package:js/js.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
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

  Stream<List<TrackedObject>> get detectionsStream => _detectionsStreamController.stream;

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

  // Process video frame and detect objects
  Future<List<TrackedObject>> processVideoFrame(html.VideoElement video) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Create a canvas to capture the video frame
      final canvas = html.CanvasElement(
        width: video.videoWidth,
        height: video.videoHeight,
      );
      canvas.context2D.drawImage(video, 0, 0);
      
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
      final videoWidth = video.videoWidth?.toDouble() ?? 640;
      final videoHeight = video.videoHeight?.toDouble() ?? 480; 
      final trackedObjects = _processDetections(results, videoWidth, videoHeight);
      
      // Broadcast the detections
      _detectionsStreamController.add(trackedObjects);
      
      return trackedObjects;
    } catch (e) {
      print('Error processing video frame: $e');
      return [];
    }
  }

  // Process detection results
  List<TrackedObject> _processDetections(
    Map<String, dynamic> results, 
    double frameWidth, 
    double frameHeight
  ) {
    final List<TrackedObject> trackedObjects = [];
    
    try {
      // Set up callback for tracking results
      final completer = Completer<String>();
      
      js.context['onTrackingComplete'] = js.allowInterop((String trackingJson) {
        completer.complete(trackingJson);
      });
      
      // Call the JavaScript tracking function
      js.context.callMethod('trackObjects', [
        json.encode(results), 
        frameWidth, 
        frameHeight
      ]);
      
      // For now, use simulated detections if no JavaScript results
      List<dynamic> detections = results['detections'] ?? [];
      
      for (var detection in detections) {
        try {
          final bbox = detection['boundingBox'];
          final box = BoundingBox(
            left: bbox['originX'].toDouble(),
            top: bbox['originY'].toDouble(),
            width: bbox['width'].toDouble(),
            height: bbox['height'].toDouble(),
          );
          
          final category = detection['categories'][0];
          final center = Point(
            x: box.left + box.width / 2,
            y: box.top + box.height / 2,
          );
          
          final det = Detection(
            boundingBox: box,
            categoryName: category['categoryName'],
            confidence: category['score'].toDouble(),
            center: center,
          );
          
          final object = TrackedObject.fromDetection(det);
          trackedObjects.add(object);
        } catch (e) {
          print('Error creating tracked object: $e');
        }
      }
    } catch (e) {
      print('Error processing detections: $e');
    }
    
    return trackedObjects;
  }
  
  void dispose() {
    _detectionsStreamController.close();
  }
}

// Static instance for app-wide use
final objectDetectionService = ObjectDetectionService(); 