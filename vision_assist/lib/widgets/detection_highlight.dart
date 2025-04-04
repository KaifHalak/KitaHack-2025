import 'package:flutter/material.dart';
import 'dart:math';
import '../models/tracked_object.dart';
import '../utils/constants.dart';

class DetectionHighlight extends CustomPainter {
  final List<TrackedObject> trackedObjects;
  final bool highContrast;
  
  const DetectionHighlight({
    required this.trackedObjects,
    this.highContrast = false,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    for (var object in trackedObjects) {
      // Determine box color based on object type and confidence
      Color boxColor;
      double strokeWidth;
      
      if (highContrast) {
        // High contrast mode - use yellow boxes
        boxColor = Colors.yellow;
        strokeWidth = 5.0;
      } else {
        // Normal mode - use different colors based on object category
        if (object.categoryName == 'person') {
          boxColor = Colors.green;
        } else if (['car', 'truck', 'bus', 'motorcycle'].contains(object.categoryName)) {
          boxColor = Colors.red;
        } else if (['dog', 'cat'].contains(object.categoryName)) {
          boxColor = Colors.orange;
        } else {
          boxColor = Colors.blue;
        }
        
        // Adjust opacity based on confidence
        boxColor = boxColor.withOpacity(0.3 + object.confidence * 0.7);
        strokeWidth = 3.0;
      }
      
      // Draw bounding box
      final rect = Rect.fromLTWH(
        object.lastBox.left, 
        object.lastBox.top,
        object.lastBox.width,
        object.lastBox.height,
      );
      
      final boxPaint = Paint()
        ..color = boxColor.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      
      final strokePaint = Paint()
        ..color = boxColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      
      // Draw box with fill and stroke
      canvas.drawRect(rect, boxPaint);
      canvas.drawRect(rect, strokePaint);
      
      // Draw motion indicators for high contrast mode
      if (highContrast && object.speed > 5.0) {
        // Draw motion arrow in direction of movement
        final center = Offset(
          object.lastBox.left + object.lastBox.width / 2,
          object.lastBox.top + object.lastBox.height / 2,
        );
        
        final radians = object.direction * 3.14159 / 180;
        final arrowLength = 30.0;
        
        final endPoint = Offset(
          center.dx + arrowLength * cos(radians),
          center.dy + arrowLength * sin(radians),
        );
        
        final arrowPaint = Paint()
          ..color = Colors.yellow
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0;
        
        // Draw arrow line
        canvas.drawLine(center, endPoint, arrowPaint);
        
        // Draw arrow head
        final arrowHeadSize = 10.0;
        final arrowHeadAngle1 = radians + 2.5;
        final arrowHeadAngle2 = radians - 2.5;
        
        final arrowHead1 = Offset(
          endPoint.dx - arrowHeadSize * cos(arrowHeadAngle1),
          endPoint.dy - arrowHeadSize * sin(arrowHeadAngle1),
        );
        
        final arrowHead2 = Offset(
          endPoint.dx - arrowHeadSize * cos(arrowHeadAngle2),
          endPoint.dy - arrowHeadSize * sin(arrowHeadAngle2),
        );
        
        canvas.drawLine(endPoint, arrowHead1, arrowPaint);
        canvas.drawLine(endPoint, arrowHead2, arrowPaint);
      }
    }
  }
  
  @override
  bool shouldRepaint(DetectionHighlight oldDelegate) {
    return oldDelegate.trackedObjects != trackedObjects || 
           oldDelegate.highContrast != highContrast;
  }
} 