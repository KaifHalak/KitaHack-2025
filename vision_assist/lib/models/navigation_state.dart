import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'route_models.dart';

class NavigationState {
  final bool isNavigating;
  final String? destination;
  final List<double>? currentLocation;
  final List<double>? destinationLocation;
  final String? currentStep;
  final String? navigationInstruction;
  final bool hasReachedDestination;
  final String? distance;
  final String? duration;

  NavigationState({
    this.isNavigating = false,
    this.destination,
    this.currentLocation,
    this.destinationLocation,
    this.currentStep,
    this.navigationInstruction,
    this.hasReachedDestination = false,
    this.distance,
    this.duration,
  });

  NavigationState copyWith({
    bool? isNavigating,
    String? destination,
    List<double>? currentLocation,
    List<double>? destinationLocation,
    String? currentStep,
    String? navigationInstruction,
    bool? hasReachedDestination,
    String? distance,
    String? duration,
  }) {
    return NavigationState(
      isNavigating: isNavigating ?? this.isNavigating,
      destination: destination ?? this.destination,
      currentLocation: currentLocation ?? this.currentLocation,
      destinationLocation: destinationLocation ?? this.destinationLocation,
      currentStep: currentStep ?? this.currentStep,
      navigationInstruction:
          navigationInstruction ?? this.navigationInstruction,
      hasReachedDestination:
          hasReachedDestination ?? this.hasReachedDestination,
      distance: distance ?? this.distance,
      duration: duration ?? this.duration,
    );
  }
}
