/// Generic scale manager for type-safe coordinate transformations
/// Ported from src/chartlib/scale/scaleManager.ts

import 'scale.dart';

/// Generic scale manager for type-safe coordinate transformations.
/// Pairs an X-axis scale with a Y-axis scale to provide bidirectional mapping
/// between domain values and pixel coordinates.
class ScaleManager<X, Y> {
  ScaleManager(this.xScale, this.yScale);

  /// Scale for the X-axis (typically time)
  final Scale<X> xScale;

  /// Scale for the Y-axis (typically price/value)
  final Scale<Y> yScale;

  /// Transforms domain coordinates to pixel coordinates.
  /// Forward mapping: domain → pixels
  ({double x, double y}) toPixel(X x, Y y) {
    return (
      x: xScale.scaledValue(x),
      y: yScale.scaledValue(y),
    );
  }

  /// Transforms pixel coordinates to domain coordinates.
  /// Reverse mapping: pixels → domain
  ({X x, Y y}) fromPixel(double pixelX, double pixelY) {
    return (
      x: xScale.invert(pixelX),
      y: yScale.invert(pixelY),
    );
  }
}

/// Type alias for the most common scale manager:
/// Time (X-axis) × Price (Y-axis)
typedef TimePriceScaleManager = ScaleManager<DateTime, double>;
