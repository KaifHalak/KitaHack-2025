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
      final areaRatio = (box.width * box.height) / (size.width * size.height);
      
      // Determine color based on proximity
      Color boxColor;
      if (areaRatio > VERY_CLOSE_RATIO) {
        boxColor = Colors.red.withOpacity(0.3);
      } else if (areaRatio > GETTING_CLOSE_RATIO) {
        boxColor = Colors.orange.withOpacity(0.3);
      } else {
        boxColor = Colors.green.withOpacity(0.3);
      }

      // Draw filled rectangle with transparency
      final fillPaint = Paint()
        ..color = boxColor
        ..style = PaintingStyle.fill;
      
      canvas.drawRect(
        Rect.fromLTWH(box.left, box.top, box.width, box.height),
        fillPaint,
      );

      // Draw border with solid color
      final borderPaint = Paint()
        ..color = boxColor.withOpacity(1.0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawRect(
        Rect.fromLTWH(box.left, box.top, box.width, box.height),
        borderPaint,
      );

      // Draw movement trail if object is moving
      if (object.positions.length > 1 && object.speed > MIN_SPEED_THRESHOLD) {
        final trailPaint = Paint()
          ..color = boxColor.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        final path = Path();
        path.moveTo(object.positions[0].x, object.positions[0].y);
        
        for (var i = 1; i < object.positions.length; i++) {
          path.lineTo(object.positions[i].x, object.positions[i].y);
        }
        
        canvas.drawPath(path, trailPaint);
      }
    }
  }

  @override
  bool shouldRepaint(DetectionHighlight oldDelegate) {
    return true; // Always repaint to show updated positions
  }
} 