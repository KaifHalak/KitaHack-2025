import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:location/location.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:js/js.dart';
import '../models/navigation_state.dart';
import '../providers/gemini_provider.dart';
import 'dart:convert' as json;

class NavigationService {
  final _stateController = StreamController<NavigationState>.broadcast();
  final Location _location = Location();
  StreamSubscription<LocationData>? _locationSubscription;
  Timer? _updateTimer;
  NavigationState _currentState = NavigationState();
  final BuildContext context;
  GeminiProvider? _geminiProvider;
  List<String> _navigationSteps = [];

  Stream<NavigationState> get stateStream => _stateController.stream;

  NavigationService(this.context) {
    _geminiProvider = Provider.of<GeminiProvider>(context, listen: false);
  }

  Future<void> initialize() async {
    // Initialize location service
    await _location.requestPermission();
    await _location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 1000,
    );

    // Initialize Google Maps
    await _initializeMap();
  }

  Future<void> _initializeMap() async {
    try {
      // Get API key from .env file
      final apiKey = dotenv.env['MAPS_API_KEY'];
      if (apiKey == null ||
          apiKey.isEmpty ||
          apiKey == 'MAPS_API_KEY_PLACEHOLDER') {
        throw Exception('Google Maps API key not found in .env file');
      }

      // Set API key in JavaScript context
      js.context.callMethod('eval', [
        '''
        window.MAPS_API_KEY = '$apiKey';
        console.log("Set Maps API key from Dart:", window.MAPS_API_KEY);
      '''
      ]);

      // Initialize map with a delay to ensure the key is set
      await Future.delayed(Duration(milliseconds: 500));

      js.context.callMethod('eval', [
        '''
        if (typeof initMap === 'function') {
          initMap();
        } else {
          console.error('initMap function not found');
        }
      '''
      ]);

      // Start location updates
      _startLocationUpdates();
    } catch (e) {
      print('Error initializing map: $e');
      rethrow;
    }
  }

  void _startLocationUpdates() {
    _locationSubscription =
        _location.onLocationChanged.listen((LocationData location) {
      if (location.latitude != null && location.longitude != null) {
        _updateLocationOnMap(location.latitude!, location.longitude!);
      }
    });
  }

  Future<void> startNavigation(
      String destination, double latitude, double longitude) async {
    try {
      print(
          'Starting navigation to $destination at lat: $latitude, lng: $longitude');

      // Get current location
      final location = await _location.getLocation();
      if (location.latitude == null || location.longitude == null) {
        throw Exception('Could not get current location');
      }

      print('Current location: ${location.latitude}, ${location.longitude}');

      // Update state
      _currentState = NavigationState(
        isNavigating: true,
        destination: destination,
        currentLocation: [location.latitude!, location.longitude!],
        destinationLocation: [latitude, longitude],
        navigationInstruction: "Starting navigation to $destination",
      );
      _stateController.add(_currentState);

      print('Navigation state updated, sending to GeminiProvider');

      // Send navigation state to GeminiProvider
      _geminiProvider?.updateNavigationState(_currentState);

      // Calculate route
      print('Calculating route...');
      await _calculateRoute(
        location.latitude!,
        location.longitude!,
        latitude,
        longitude,
      );

      // Start location updates
      _updateTimer?.cancel();
      _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _updateLocation();
      });

      print('Navigation started successfully');
    } catch (e) {
      print('Error starting navigation: $e');
      rethrow;
    }
  }

  Future<void> _calculateRoute(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    try {
      // Use the global calculateRoute function
      print(
          'Calling calculateRoute with origin: $startLat,$startLng, destination: $endLat,$endLng');

      // Check if the JavaScript function exists
      final bool calculateRouteExists =
          js.context.hasProperty('calculateRoute');
      print('calculateRoute function exists: $calculateRouteExists');

      if (!calculateRouteExists) {
        print(
            'ERROR: calculateRoute function not found in JavaScript context!');
        return;
      }

      // Create a Completer to handle the promise
      final completer = Completer();

      // Generate a unique callback name to avoid conflicts
      final callbackName =
          'dartRouteCallback_${DateTime.now().millisecondsSinceEpoch}';

      // Define a separate data extraction function in JavaScript
      final extractDataFunctionName =
          'extractRouteData_${DateTime.now().millisecondsSinceEpoch}';

      // Define functions in JavaScript
      js.context.callMethod('eval', [
        '''
        // Extract data function
        window["$extractDataFunctionName"] = function(result) {
          try {
            // Copy data into a simple format Dart can read
            var extractedData = {
              distance: result && result.distance ? result.distance : "Unknown",
              duration: result && result.duration ? result.duration : "Unknown",
              instructionsList: []
            };
            
            // Extract instructions from steps
            if (result && result.steps && result.steps.length) {
              for (var i = 0; i < result.steps.length; i++) {
                var step = result.steps[i];
                if (step && step.instruction) {
                  // Clean HTML from instructions
                  var cleanInstruction = step.instruction.replace(/<[^>]*>/g, '');
                  extractedData.instructionsList.push(cleanInstruction);
                }
              }
            }
            
            console.log("Extracted data:", extractedData);
            return extractedData;
          } catch(e) {
            console.error("Error extracting route data:", e);
            return {
              distance: "Unknown",
              duration: "Unknown",
              instructionsList: []
            };
          }
        };
        
        // Callback function
        window["$callbackName"] = function(result) {
          // Extract data first
          var extractedData = window["$extractDataFunctionName"](result);
          // Then call Dart with the extracted data
          window.dartReceiveRouteData(extractedData.distance, extractedData.duration, extractedData.instructionsList);
        };
      '''
      ]);

      // Define Dart callback to receive the data
      js.context['dartReceiveRouteData'] = js.allowInterop(
          (String distance, String duration, List<dynamic> instructionsList) {
        print(
            'Received route data in Dart: distance=$distance, duration=$duration, steps=${instructionsList.length}');

        // Convert dynamic list to string list
        final List<String> steps = [];
        if (instructionsList != null) {
          for (var i = 0; i < instructionsList.length; i++) {
            if (instructionsList[i] is String) {
              steps.add(instructionsList[i]);
            }
          }
        }

        // Pass data to the completer
        completer.complete(
            {'distance': distance, 'duration': duration, 'steps': steps});
      });

      // Call the JavaScript function and pass the callback
      js.context.callMethod('eval', [
        '''
        (function() {
          try {
            calculateRoute(
              {lat: ${startLat}, lng: ${startLng}}, 
              {lat: ${endLat}, lng: ${endLng}}
            )
            .then(function(result) {
              console.log("Route calculation successful:", 
                result.distance, 
                result.duration, 
                "with " + (result.steps ? result.steps.length : 0) + " steps");
              
              if (window["$callbackName"]) {
                window["$callbackName"](result);
              }
            })
            .catch(function(error) {
              console.error("Error in route calculation promise:", error);
              if (window["$callbackName"]) {
                window["$callbackName"]({
                  steps: [],
                  distance: "Unknown",
                  duration: "Unknown"
                });
              }
            });
          } catch(e) {
            console.error("Error in route calculation:", e);
            if (window["$callbackName"]) {
              window["$callbackName"]({
                steps: [],
                distance: "Unknown",
                duration: "Unknown"
              });
            }
          }
        })();
      '''
      ]);

      // Wait for the result with a timeout
      final result = await completer.future.timeout(const Duration(seconds: 5),
          onTimeout: () {
        print('Route calculation timed out');
        return {
          'distance': 'Unknown',
          'duration': 'Unknown',
          'steps': <String>[]
        };
      });

      print('Route calculation completed, processing result');

      try {
        final String distance = result['distance'] as String;
        final String duration = result['duration'] as String;
        final List<String> steps = result['steps'] as List<String>;

        print(
            'Received route data: distance=$distance, duration=$duration, steps=${steps.length}');

        // Store navigation steps
        _navigationSteps = steps;

        // Update state with navigation instruction
        String instruction =
            "Navigate to ${_currentState.destination} ($distance, $duration)";
        if (_navigationSteps.isNotEmpty) {
          instruction = _navigationSteps[0];
        }

        _currentState = _currentState.copyWith(
          navigationInstruction: instruction,
          currentStep: _navigationSteps.isNotEmpty ? _navigationSteps[0] : null,
          distance: distance,
          duration: duration,
        );
        _stateController.add(_currentState);

        // Send updated navigation state to GeminiProvider
        _geminiProvider?.updateNavigationState(_currentState);

        print('Navigation state updated with route information');

        // Clean up JavaScript callbacks
        js.context.callMethod('eval', [
          '''
          window["$callbackName"] = null;
          window["$extractDataFunctionName"] = null;
        '''
        ]);
      } catch (e) {
        print('Error processing route data: $e');
      }
    } catch (e) {
      print('Error calculating route: $e');
    }
  }

  Future<void> _updateLocationOnMap(double latitude, double longitude) async {
    try {
      js.context.callMethod('eval', [
        '''
        if (typeof updateCurrentLocation === 'function') {
          updateCurrentLocation($latitude, $longitude);
        }
      '''
      ]);
    } catch (e) {
      print('Error updating location on map: $e');
    }
  }

  Future<void> _updateLocation() async {
    final location = await _location.getLocation();
    if (location.latitude == null || location.longitude == null) {
      return;
    }

    final currentLatLng = [location.latitude!, location.longitude!];

    // Update state
    _currentState = _currentState.copyWith(
      currentLocation: currentLatLng,
    );
    _stateController.add(_currentState);

    // Update map center and marker using global function
    js.context.callMethod(
        'updateCurrentLocation', [location.latitude!, location.longitude!]);

    // Check if we've reached a navigation step or the destination
    if (_currentState.isNavigating &&
        _currentState.destinationLocation != null) {
      // Calculate distance to destination
      final destLat = _currentState.destinationLocation![0];
      final destLng = _currentState.destinationLocation![1];
      final distance = _calculateDistance(
        location.latitude!,
        location.longitude!,
        destLat,
        destLng,
      );

      // Check if reached destination (within 20 meters)
      if (distance < 20) {
        _currentState = _currentState.copyWith(
          hasReachedDestination: true,
          navigationInstruction:
              "You have reached your destination: ${_currentState.destination}",
        );
        _stateController.add(_currentState);
        _geminiProvider?.updateNavigationState(_currentState);
        return;
      }

      // Update current navigation step based on progress
      _updateCurrentNavigationStep(location.latitude!, location.longitude!);

      // Send updated navigation state to GeminiProvider
      _geminiProvider?.updateNavigationState(_currentState);
    }
  }

  void _updateCurrentNavigationStep(double lat, double lng) {
    // This method would determine which navigation step the user is currently on
    // based on their location and update the instruction accordingly
    // For now, we'll keep the existing implementation

    // Recalculate route periodically to keep it fresh
    if (_currentState.destinationLocation != null) {
      _calculateRoute(
        lat,
        lng,
        _currentState.destinationLocation![0],
        _currentState.destinationLocation![1],
      );
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    // Implementation of Haversine formula to calculate distance in meters
    const R = 6371e3; // Earth radius in meters
    final phi1 = lat1 * (3.14159265359 / 180);
    final phi2 = lat2 * (3.14159265359 / 180);
    final deltaPhi = (lat2 - lat1) * (3.14159265359 / 180);
    final deltaLambda = (lon2 - lon1) * (3.14159265359 / 180);

    final a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) * sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  Future<void> stopNavigation() async {
    _updateTimer?.cancel();
    _currentState = NavigationState();
    _stateController.add(_currentState);

    // Clear the route on the map using global function
    js.context.callMethod('clearRoute');

    // Update GeminiProvider
    _geminiProvider?.updateNavigationState(null);
  }

  void dispose() {
    _updateTimer?.cancel();
    _stateController.close();
  }
}

// Helper functions for math calculations
double sin(double x) => math.sin(x);
double cos(double x) => math.cos(x);
double atan2(double y, double x) => math.atan2(y, x);
double sqrt(double x) => math.sqrt(x);
