/// Candle batch - collection of OHLC candlesticks.
/// Stores wicks and bodies in pixel coordinates for efficient rendering.
/// Ported from src/chartlib/shapes/batch/candleBatch.ts

import 'shape_batch.dart';

/// Candle point data in pixel coordinates.
class CandlePoint {
  const CandlePoint({
    required this.x,
    required this.upperWick,
    required this.lowerWick,
    required this.body,
    required this.isPositive,
  });

  /// Center X position
  final double x;

  /// Upper wick: from y1 (body top) to y2 (high)
  final ({double y1, double y2}) upperWick;

  /// Lower wick: from y1 (low) to y2 (body bottom)
  final ({double y1, double y2}) lowerWick;

  /// Body rectangle
  final ({double y, double height, double width}) body;

  /// Price direction for coloring
  final bool isPositive;
}

/// Candle batch - collection of OHLC candlesticks.
/// Stores wicks and bodies in pixel coordinates for efficient rendering.
/// Used for: Main chart candles, Heikin-Ashi, etc.
class CandleBatch extends ShapeBatch<CandlePoint> {
  @override
  String get type => 'candle';

  final List<CandlePoint> candles = [];

  /// Update the last candle (real-time tick update).
  @override
  void update(CandlePoint point) {
    if (candles.isEmpty) {
      candles.add(point);
    } else {
      candles[candles.length - 1] = point;
    }
  }

  /// Append a new candle (new time period).
  @override
  void append(CandlePoint point) {
    candles.add(point);
  }

  /// Reset all candles (full data reload or prepend).
  @override
  void reset(List<CandlePoint> points) {
    candles.clear();
    candles.addAll(points);
  }
}
