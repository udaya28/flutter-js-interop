/// Band fill batch - filled area between two dynamic lines with optional middle line.
/// Used for: Bollinger Bands, Keltner Channels, Donchian Channels, Ichimoku Cloud.
/// Ported from src/chartlib/shapes/batch/bandFillBatch.ts

import 'shape_batch.dart';
import '../line.dart';

/// Band fill point - pixel coordinates for upper, middle, and lower bands.
class BandFillPoint {
  const BandFillPoint({
    required this.upper,
    required this.middle,
    required this.lower,
  });

  final Point upper;
  final Point middle;
  final Point lower;
}

/// Band fill batch - filled area between two dynamic lines with optional middle line.
/// Used for: Bollinger Bands, Keltner Channels, Donchian Channels, Ichimoku Cloud.
class BandFillBatch extends ShapeBatch<BandFillPoint> {
  BandFillBatch({
    required this.fillColor,
    required this.fillOpacity,
    required this.borderColor,
    required this.borderWidth,
    required this.showBorders,
  });

  @override
  String get type => 'bandfill';

  final String fillColor;
  final double fillOpacity;
  final String borderColor;
  final double borderWidth;
  final bool showBorders;

  final List<Point> upperPoints = [];
  final List<Point> middlePoints = [];
  final List<Point> lowerPoints = [];

  /// Update the last point (real-time tick update).
  @override
  void update(BandFillPoint point) {
    final lastIdx = upperPoints.length - 1;
    if (lastIdx >= 0) {
      upperPoints[lastIdx] = point.upper;
      middlePoints[lastIdx] = point.middle;
      lowerPoints[lastIdx] = point.lower;
    } else {
      append(point);
    }
  }

  /// Append a new point (new candle).
  @override
  void append(BandFillPoint point) {
    upperPoints.add(point.upper);
    middlePoints.add(point.middle);
    lowerPoints.add(point.lower);
  }

  /// Reset all points (full data reload or prepend).
  @override
  void reset(List<BandFillPoint> points) {
    upperPoints.clear();
    middlePoints.clear();
    lowerPoints.clear();

    for (final point in points) {
      upperPoints.add(point.upper);
      middlePoints.add(point.middle);
      lowerPoints.add(point.lower);
    }
  }
}
