import 'package:flutter/material.dart';
import '../models/tracked_object.dart';
import '../utils/constants.dart';

class DetectionLabel extends StatelessWidget {
  final TrackedObject object;
  final Size frameSize;

  const DetectionLabel({
    super.key,
    required this.object,
    required this.frameSize,
  });

  @override
  Widget build(BuildContext context) {
    final proximityStatus = object.getProximityStatus(frameSize);
    final areaRatio = (object.lastBox.width * object.lastBox.height) / (frameSize.width * frameSize.height);
    
    Color textColor;
    if (areaRatio > VERY_CLOSE_RATIO) {
      textColor = Colors.red;
    } else if (areaRatio > GETTING_CLOSE_RATIO) {
      textColor = Colors.orange;
    } else {
      textColor = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ID: ${object.id}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${object.categoryName} (${(object.confidence * 100).toInt()}%)',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Text(
            proximityStatus,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          if (object.speed > MIN_SPEED_THRESHOLD)
            Text(
              '${object.speed.toStringAsFixed(1)}px/s',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          Text(
            'Direction: ${object.getDirectionIndicator()}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
} 