import '../models/bounding_box.dart';
import '../models/point.dart';
import '../models/tracked_object.dart';
import 'constants.dart';

class DetectionUtils {
  static double calculateIoU(BoundingBox box1, BoundingBox box2) {
    final xLeft = box1.left > box2.left ? box1.left : box2.left;
    final yTop = box1.top > box2.top ? box1.top : box2.top;
    final xRight = box1.right < box2.right ? box1.right : box2.right;
    final yBottom = box1.bottom < box2.bottom ? box1.bottom : box2.bottom;

    if (xRight < xLeft || yBottom < yTop) return 0.0;

    final intersectionArea = (xRight - xLeft) * (yBottom - yTop);
    final box1Area = box1.width * box1.height;
    final box2Area = box2.width * box2.height;
    final unionArea = box1Area + box2Area - intersectionArea;

    return intersectionArea / unionArea;
  }

  static String getPositionDescription(Point center, double frameWidth, double frameHeight) {
    final horizontal = center.x < frameWidth * 0.33 ? 'left' :
                      center.x > frameWidth * 0.66 ? 'right' :
                      'center';
                      
    final vertical = center.y < frameHeight * 0.33 ? 'above' :
                     center.y > frameHeight * 0.66 ? 'below' :
                     'ahead';

    return '$vertical${horizontal != 'center' ? ' to the $horizontal' : ''}';
  }

  static bool isObjectApproaching(TrackedObject object) {
    return object.speed > SPEED_THRESHOLD;
  }

  static bool isObjectVeryClose(TrackedObject object, double frameArea) {
    final areaRatio = (object.lastBox.width * object.lastBox.height) / frameArea;
    return areaRatio > VERY_CLOSE_RATIO;
  }

  static bool isObjectGettingClose(TrackedObject object, double frameArea) {
    final areaRatio = (object.lastBox.width * object.lastBox.height) / frameArea;
    return areaRatio > GETTING_CLOSE_RATIO;
  }

  static List<List<TrackedObject>> groupOverlappingObjects(
    List<TrackedObject> objects,
  ) {
    final groups = <List<TrackedObject>>[];
    final processed = <String>{};

    for (final obj1 in objects) {
      if (processed.contains(obj1.id)) continue;

      final group = <TrackedObject>[obj1];
      processed.add(obj1.id);

      for (final obj2 in objects) {
        if (obj1.id == obj2.id || processed.contains(obj2.id)) continue;

        final iou = calculateIoU(obj1.lastBox, obj2.lastBox);
        if (iou > TRACKING_IOU_THRESHOLD) {
          group.add(obj2);
          processed.add(obj2.id);
        }
      }

      groups.add(group);
    }

    return groups;
  }

  static String generateWarningMessage(List<TrackedObject> group) {
    final object = group.first;
    final urgency = group.any((obj) => isObjectVeryClose(obj, 1.0)) ? 'very close' : 'getting close';
    final position = getPositionDescription(object.lastCenter, 1.0, 1.0);
    final direction = object.getDirectionIndicator();

    return 'Warning: ${object.categoryName} is $urgency to your $position $direction';
  }
} 