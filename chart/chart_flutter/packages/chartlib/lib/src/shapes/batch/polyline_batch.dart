/// Polyline batch - continuous line through multiple points.
/// Used for: SMA, EMA, RSI, MACD lines, and other line indicators.
/// Ported from src/chartlib/shapes/batch/polylineBatch.ts

import 'shape_batch.dart';
import '../line.dart';

/// Polyline batch - continuous line through multiple points.
/// Used for: SMA, EMA, RSI, MACD lines, and other line indicators.
class PolylineBatch extends ShapeBatch<Point> {
  PolylineBatch({
    required this.color,
    required this.lineWidth,
    this.lineDash,
  });

  @override
  String get type => 'polyline';

  final String color;
  final double lineWidth;
  final List<double>? lineDash;

  final List<Point> points = [];

  /// Update the last point (real-time tick update).
  @override
  void update(Point point) {
    if (points.isEmpty) {
      points.add(point);
    } else {
      points[points.length - 1] = point;
    }
  }

  /// Append a new point (new candle).
  @override
  void append(Point point) {
    points.add(point);
  }

  /// Reset all points (full data reload or prepend).
  @override
  void reset(List<Point> newPoints) {
    points.clear();
    points.addAll(newPoints);
  }
}
