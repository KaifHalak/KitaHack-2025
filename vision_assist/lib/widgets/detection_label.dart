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
    final areaRatio = (object.lastBox.width * object.lastBox.height) / 
                     (frameSize.width * frameSize.height);
    
    final isVeryClose = areaRatio > VERY_CLOSE_RATIO;
    final isGettingClose = areaRatio > GETTING_CLOSE_RATIO;

    final backgroundColor = isVeryClose 
        ? Colors.red.withOpacity(0.8)
        : isGettingClose 
            ? Colors.orange.withOpacity(0.8)
            : Colors.green.withOpacity(0.8);

    final warningText = isVeryClose 
        ? 'VERY CLOSE!'
        : isGettingClose 
            ? 'Getting Close'
            : 'Safe Distance';

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            object.categoryName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            warningText,
            style: const TextStyle(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Speed: ${object.speed.toStringAsFixed(1)} px/s',
            style: const TextStyle(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Direction: ${object.getDirectionIndicator()}',
            style: const TextStyle(
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
} 