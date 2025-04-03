import 'bounding_box.dart';
import 'point.dart';

class Detection {
  final BoundingBox boundingBox;
  final String categoryName;
  final double confidence;
  final Point center;

  Detection({
    required this.boundingBox,
    required this.categoryName,
    required this.confidence,
    required this.center,
  });

  factory Detection.fromMap(Map<String, dynamic> map) {
    final box = BoundingBox.fromMap(map['boundingBox']);
    return Detection(
      boundingBox: box,
      categoryName: map['categoryName'] ?? '',
      confidence: map['confidence']?.toDouble() ?? 0.0,
      center: Point(
        x: box.left + box.width / 2,
        y: box.top + box.height / 2,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'boundingBox': boundingBox.toMap(),
      'categoryName': categoryName,
      'confidence': confidence,
      'center': {
        'x': center.x,
        'y': center.y,
      },
    };
  }

  Detection copyWith({
    BoundingBox? boundingBox,
    String? categoryName,
    double? confidence,
    Point? center,
  }) {
    return Detection(
      boundingBox: boundingBox ?? this.boundingBox,
      categoryName: categoryName ?? this.categoryName,
      confidence: confidence ?? this.confidence,
      center: center ?? this.center,
    );
  }
} 