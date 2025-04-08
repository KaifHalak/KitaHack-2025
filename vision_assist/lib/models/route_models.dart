import 'package:google_maps_flutter/google_maps_flutter.dart';

class Route {
  final List<LatLng> points;
  final List<RouteStep> steps;
  final int distance; // in meters
  final int duration; // in seconds

  Route({
    required this.points,
    required this.steps,
    required this.distance,
    required this.duration,
  });

  factory Route.fromJson(Map<String, dynamic> json) {
    final points =
        (json['overview_polyline']['points'] as String).split('').map((point) {
      final coords = point.split(',');
      return LatLng(
        double.parse(coords[0]),
        double.parse(coords[1]),
      );
    }).toList();

    final steps = (json['legs'][0]['steps'] as List)
        .map((step) => RouteStep.fromJson(step))
        .toList();

    return Route(
      points: points,
      steps: steps,
      distance: json['legs'][0]['distance']['value'],
      duration: json['legs'][0]['duration']['value'],
    );
  }
}

class RouteStep {
  final String htmlInstructions;
  final LatLng startLocation;
  final LatLng endLocation;
  final int distance; // in meters
  final int duration; // in seconds
  final String maneuver;

  RouteStep({
    required this.htmlInstructions,
    required this.startLocation,
    required this.endLocation,
    required this.distance,
    required this.duration,
    required this.maneuver,
  });

  factory RouteStep.fromJson(Map<String, dynamic> json) {
    return RouteStep(
      htmlInstructions: json['html_instructions'],
      startLocation: LatLng(
        json['start_location']['lat'],
        json['start_location']['lng'],
      ),
      endLocation: LatLng(
        json['end_location']['lat'],
        json['end_location']['lng'],
      ),
      distance: json['distance']['value'],
      duration: json['duration']['value'],
      maneuver: json['maneuver'] ?? '',
    );
  }
}
