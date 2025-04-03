class Point {
  final double x;
  final double y;

  Point({
    required this.x,
    required this.y,
  });

  double distanceTo(Point other) {
    return (x - other.x) * (x - other.x) + (y - other.y) * (y - other.y);
  }

  Point operator +(Point other) {
    return Point(x: x + other.x, y: y + other.y);
  }

  Point operator -(Point other) {
    return Point(x: x - other.x, y: y - other.y);
  }

  Point operator *(double scalar) {
    return Point(x: x * scalar, y: y * scalar);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Point && runtimeType == other.runtimeType && x == other.x && y == other.y;

  @override
  int get hashCode => x.hashCode ^ y.hashCode;
} 