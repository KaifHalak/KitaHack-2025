import 'package:flutter/material.dart';
import '../models/tracked_object.dart';
import '../utils/constants.dart';

class DetectionHighlight extends CustomPainter {
  final List<TrackedObject> trackedObjects;

  DetectionHighlight({required this.trackedObjects});

  @override
  void paint(Canvas canvas, Size size) {
    for (final object in trackedObjects) {
      final box = object.lastBox;
      final rect = Rect.fromLTWH(
        box.left,
        box.top,
        box.width,
        box.height,
      );

      final areaRatio = (box.width * box.height) / (size.width * size.height);
      
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      if (areaRatio > VERY_CLOSE_RATIO) {
        paint.color = Colors.red;
      } else if (areaRatio > GETTING_CLOSE_RATIO) {
        paint.color = Colors.orange;
      } else {
        paint.color = Colors.green;
      }

      canvas.drawRect(rect, paint);

      // Draw direction arrow if object is moving
      if (object.speed > MIN_SPEED_THRESHOLD) {
        final center = Offset(
          box.left + box.width / 2,
          box.top + box.height / 2,
        );
        
        final arrowLength = box.width * 0.3;
        final endPoint = Offset(
          center.dx + arrowLength * object.velocity.x.sign,
          center.dy + arrowLength * object.velocity.y.sign,
        );

        final arrowPaint = Paint()
          ..color = paint.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        canvas.drawLine(center, endPoint, arrowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(DetectionHighlight oldDelegate) {
    return true;
  }
} 