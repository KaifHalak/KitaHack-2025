import 'package:flutter/material.dart';
import '../models/tracked_object.dart';
import '../utils/constants.dart';

class DetectionLabel extends StatelessWidget {
  final TrackedObject object;
  final Size frameSize;

  const DetectionLabel({
    Key? key,
    required this.object,
    required this.frameSize,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Calculate color based on confidence
    final color = _getColorForConfidence(object.confidence);
    
    // Get the proximity status color
    final proximityColor = _getProximityColor(object);
    
    // Format the confidence percentage
    final confidenceStr = '${(object.confidence * 100).toStringAsFixed(0)}%';
    
    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: proximityColor,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Object class and confidence
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getIconForCategory(object.categoryName),
                color: color,
                size: 16,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  object.categoryName,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  confidenceStr,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          
          // Proximity status
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getIconForProximity(object),
                  color: proximityColor,
                  size: 12,
                ),
                const SizedBox(width: 4),
                Text(
                  _getProximityText(object),
                  style: TextStyle(
                    color: proximityColor,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Get appropriate icon for object category
  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'person':
        return Icons.person;
      case 'car':
      case 'truck':
      case 'bus':
        return Icons.directions_car;
      case 'bicycle':
        return Icons.pedal_bike;
      case 'dog':
      case 'cat':
        return Icons.pets;
      case 'chair':
        return Icons.chair;
      case 'couch':
        return Icons.weekend;
      case 'bed':
        return Icons.bed;
      case 'toilet':
        return Icons.wc;
      case 'tv':
        return Icons.tv;
      case 'laptop':
        return Icons.laptop;
      case 'cell phone':
        return Icons.smartphone;
      case 'book':
        return Icons.menu_book;
      case 'clock':
        return Icons.access_time;
      case 'refrigerator':
        return Icons.kitchen;
      case 'oven':
        return Icons.microwave;
      case 'sink':
        return Icons.water;
      case 'door':
        return Icons.door_front_door;
      default:
        return Icons.circle;
    }
  }
  
  // Get color based on confidence level
  Color _getColorForConfidence(double confidence) {
    if (confidence >= 0.8) {
      return Colors.green;
    } else if (confidence >= 0.6) {
      return Colors.yellow;
    } else if (confidence >= 0.4) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
  
  // Get color based on proximity status
  Color _getProximityColor(TrackedObject object) {
    final areaRatio = (object.lastBox.width * object.lastBox.height) / (frameSize.width * frameSize.height);
    
    if (areaRatio > 0.15) {
      return Colors.red;
    } else if (areaRatio > 0.08) {
      return Colors.orange;
    } else {
      return Colors.green;
    }
  }
  
  // Get icon based on proximity status
  IconData _getIconForProximity(TrackedObject object) {
    final areaRatio = (object.lastBox.width * object.lastBox.height) / (frameSize.width * frameSize.height);
    
    if (areaRatio > 0.15) {
      return Icons.warning;
    } else if (areaRatio > 0.08) {
      return Icons.info;
    } else {
      return Icons.check_circle;
    }
  }
  
  // Get text based on proximity status
  String _getProximityText(TrackedObject object) {
    final areaRatio = (object.lastBox.width * object.lastBox.height) / (frameSize.width * frameSize.height);
    
    if (areaRatio > 0.15) {
      return 'VERY CLOSE!';
    } else if (areaRatio > 0.08) {
      return 'Getting Close';
    } else {
      return 'Safe Distance';
    }
  }
} 