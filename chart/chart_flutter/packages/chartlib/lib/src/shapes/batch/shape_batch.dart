/// Abstract base class for shape batches.
/// Batches store arrays of points in pixel coordinates and handle incremental updates.
/// Ported from src/chartlib/shapes/batch/shapeBatch.ts
///
/// Framework-agnostic - no Canvas/rendering knowledge.

/// Abstract base class for shape batches.
/// Batches store arrays of points in pixel coordinates and handle incremental updates.
///
/// @template TPoint - The point type this batch stores (Point, BandFillPoint, etc.)
abstract class ShapeBatch<TPoint> {
  /// Discriminant for renderer type switching
  String get type;

  /// Update the last point (real-time tick update).
  void update(TPoint point);

  /// Append a new point (new candle).
  void append(TPoint point);

  /// Reset all points (full data reload or prepend).
  void reset(List<TPoint> points);
}
