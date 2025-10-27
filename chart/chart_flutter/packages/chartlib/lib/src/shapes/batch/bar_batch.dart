/// Bar batch - collection of vertical bars (rectangles).
/// Used for: Volume bars, MACD histogram, RSI histogram, etc.
/// Ported from src/chartlib/shapes/batch/barBatch.ts

import 'shape_batch.dart';

/// Bar point data in pixel coordinates.
class BarPoint {
  const BarPoint({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.isPositive,
  });

  /// Left edge X position
  final double x;

  /// Top edge Y position
  final double y;

  /// Bar width
  final double width;

  /// Bar height
  final double height;

  /// Metadata for coloring (e.g., bullish/bearish, strength)
  final bool isPositive;
}

/// Bar batch - collection of vertical bars (rectangles).
/// Used for: Volume bars, MACD histogram, RSI histogram, etc.
class BarBatch extends ShapeBatch<BarPoint> {
  @override
  String get type => 'bar';

  final List<BarPoint> bars = [];

  /// Update the last bar (real-time tick update).
  @override
  void update(BarPoint point) {
    if (bars.isEmpty) {
      bars.add(point);
    } else {
      bars[bars.length - 1] = point;
    }
  }

  /// Append a new bar (new time period).
  @override
  void append(BarPoint point) {
    bars.add(point);
  }

  /// Reset all bars (full data reload or prepend).
  @override
  void reset(List<BarPoint> points) {
    bars.clear();
    bars.addAll(points);
  }
}
