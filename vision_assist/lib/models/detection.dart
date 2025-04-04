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
    return Detection(
      boundingBox: BoundingBox.fromMap(map['boundingBox']),
      categoryName: map['categoryName'],
      confidence: map['confidence'].toDouble(),
      center: Point(
        x: map['center']['x'].toDouble(),
        y: map['center']['y'].toDouble(),
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