import 'dart:math' show atan2, pi, sqrt, Random, cos, sin;
import 'package:flutter/material.dart' show Size;
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
  double confidence;

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
    required this.confidence,
  });

  factory TrackedObject.fromDetection(Detection detection) {
    return TrackedObject(
      id: 'obj_${DateTime.now().millisecondsSinceEpoch % 100}',
      positions: [detection.center],
      timestamps: [DateTime.now()],
      categoryName: detection.categoryName,
      speed: 0,
      direction: 0,
      velocity: Point(x: 0, y: 0),
      lastSeen: DateTime.now(),
      missingFrames: 0,
      lastBox: detection.boundingBox,
      confidence: detection.confidence,
    );
  }

  // Create a simulated moving object for testing
  static TrackedObject createSimulated(Size frameSize) {
    final random = Random();
    final width = 100.0 + random.nextDouble() * 50;
    final height = 100.0 + random.nextDouble() * 50;
    final left = random.nextDouble() * (frameSize.width - width);
    final top = random.nextDouble() * (frameSize.height - height);

    final box = BoundingBox(
      left: left,
      top: top,
      width: width,
      height: height,
    );

    final detection = Detection(
      boundingBox: box,
      categoryName: 'person',
      confidence: 0.6 + random.nextDouble() * 0.3,
      center: Point(x: left + width / 2, y: top + height / 2),
    );

    final obj = TrackedObject.fromDetection(detection);
    obj.speed = 10 + random.nextDouble() * 30; // Random speed between 10-40 px/s
    obj.direction = random.nextDouble() * 360; // Random direction 0-360 degrees
    return obj;
  }

  void updateWithDetection(Detection detection, DateTime now) {
    positions.add(detection.center);
    timestamps.add(now);
    lastBox = detection.boundingBox;
    lastSeen = now;
    missingFrames = 0;
    confidence = detection.confidence;

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

  // Simulate movement for testing
  void simulateMovement(Size frameSize) {
    final radians = direction * pi / 180;
    final dx = speed * cos(radians);
    final dy = speed * sin(radians);

    var newLeft = lastBox.left + dx;
    var newTop = lastBox.top + dy;

    // Bounce off edges
    if (newLeft < 0 || newLeft + lastBox.width > frameSize.width) {
      direction = 180 - direction;
      newLeft = lastBox.left;
    }
    if (newTop < 0 || newTop + lastBox.height > frameSize.height) {
      direction = -direction;
      newTop = lastBox.top;
    }

    lastBox = BoundingBox(
      left: newLeft,
      top: newTop,
      width: lastBox.width,
      height: lastBox.height,
    );

    final center = Point(
      x: lastBox.left + lastBox.width / 2,
      y: lastBox.top + lastBox.height / 2,
    );

    positions.add(center);
    timestamps.add(DateTime.now());

    if (positions.length > MAX_POSITION_HISTORY) {
      positions.removeAt(0);
      timestamps.removeAt(0);
    }
  }

  String getProximityStatus(Size frameSize) {
    final areaRatio = (lastBox.width * lastBox.height) / (frameSize.width * frameSize.height);
    if (areaRatio > VERY_CLOSE_RATIO) return 'VERY CLOSE!';
    if (areaRatio > GETTING_CLOSE_RATIO) return 'Getting Close';
    return 'Safe Distance';
  }

  String getDirectionIndicator() {
    if (speed < MIN_SPEED_THRESHOLD) return '•';
    const directions = ['→', '↗', '↑', '↖', '←', '↙', '↓', '↘'];
    final index = ((direction + 180) % 360 / 45).round() % 8;
    return directions[index];
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
    double? confidence,
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
      confidence: confidence ?? this.confidence,
    );
  }

  bool isStale(DateTime now) {
    final timeSinceLastSeen = now.difference(lastSeen).inMilliseconds;
    return timeSinceLastSeen > MAX_STALE_TIME || missingFrames > MAX_MISSING_FRAMES;
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