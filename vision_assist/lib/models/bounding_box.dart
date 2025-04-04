class BoundingBox {
  final double left;
  final double top;
  final double width;
  final double height;

  BoundingBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  double get right => left + width;
  double get bottom => top + height;

  BoundingBox copyWith({
    double? left,
    double? top,
    double? width,
    double? height,
  }) {
    return BoundingBox(
      left: left ?? this.left,
      top: top ?? this.top,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  factory BoundingBox.fromMap(Map<String, dynamic> map) {
    return BoundingBox(
      left: map['left']?.toDouble() ?? 0.0,
      top: map['top']?.toDouble() ?? 0.0,
      width: map['width']?.toDouble() ?? 0.0,
      height: map['height']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'left': left,
      'top': top,
      'width': width,
      'height': height,
    };
  }
} 