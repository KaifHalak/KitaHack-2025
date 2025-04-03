import 'dart:math' show atan2, pi, sqrt;
import 'detection.dart';
import 'point.dart';
import 'bounding_box.dart';
import '../utils/constants.dart';

class TrackedObject {
  final String id;
  final List<Point> positions;
  final List<DateTime> timestamps;
  final String categoryName;
  double speed;
  double direction;
  Point velocity;
  DateTime lastSeen;
  int missingFrames;
  BoundingBox lastBox;

  TrackedObject({
    required this.id,
    required this.positions,
    required this.timestamps,
    required this.categoryName,
    required this.speed,
    required this.direction,
    required this.velocity,
    required this.lastSeen,
    required this.missingFrames,
    required this.lastBox,
  });

  factory TrackedObject.fromDetection(Detection detection) {
    return TrackedObject(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      positions: [detection.center],
      timestamps: [DateTime.now()],
      categoryName: detection.categoryName,
      speed: 0,
      direction: 0,
      velocity: Point(x: 0, y: 0),
      lastSeen: DateTime.now(),
      missingFrames: 0,
      lastBox: detection.boundingBox,
    );
  }

  void updateWithDetection(Detection detection, DateTime now) {
    positions.add(detection.center);
    timestamps.add(now);
    lastBox = detection.boundingBox;
    lastSeen = now;
    missingFrames = 0;

    if (positions.length > MAX_POSITION_HISTORY) {
      positions.removeAt(0);
      timestamps.removeAt(0);
    }

    if (positions.length >= 2) {
      final dt = timestamps.last.difference(timestamps[timestamps.length - 2]).inMilliseconds / 1000;
      if (dt > 0) {
        final dx = positions.last.x - positions[positions.length - 2].x;
        final dy = positions.last.y - positions[positions.length - 2].y;
        velocity = Point(x: dx / dt, y: dy / dt);
        speed = sqrt(dx * dx + dy * dy) / dt;
        direction = atan2(dy, dx) * 180 / pi;
      }
    }
  }

  TrackedObject copyWith({
    String? id,
    List<Point>? positions,
    List<DateTime>? timestamps,
    String? categoryName,
    double? speed,
    double? direction,
    Point? velocity,
    DateTime? lastSeen,
    int? missingFrames,
    BoundingBox? lastBox,
  }) {
    return TrackedObject(
      id: id ?? this.id,
      positions: positions ?? this.positions,
      timestamps: timestamps ?? this.timestamps,
      categoryName: categoryName ?? this.categoryName,
      speed: speed ?? this.speed,
      direction: direction ?? this.direction,
      velocity: velocity ?? this.velocity,
      lastSeen: lastSeen ?? this.lastSeen,
      missingFrames: missingFrames ?? this.missingFrames,
      lastBox: lastBox ?? this.lastBox,
    );
  }

  bool isStale(DateTime now) {
    final timeSinceLastSeen = now.difference(lastSeen).inMilliseconds;
    return timeSinceLastSeen > MAX_STALE_TIME || missingFrames > MAX_MISSING_FRAMES;
  }

  String getDirectionIndicator() {
    if (speed < MIN_SPEED_THRESHOLD) return '•';
    const directions = ['→', '↗', '↑', '↖', '←', '↙', '↓', '↘'];
    final index = ((direction + 180) % 360 / 45).round() % 8;
    return directions[index];
  }

  Point get lastCenter => positions.last;
  double get width => lastBox.width;
  double get height => lastBox.height;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackedObject &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
} 