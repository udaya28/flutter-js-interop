/// Simple Moving Average (SMA) study.
/// Calculates average of close prices over a window period.
/// Ported from src/chartlib/studies/windowed/smaStudy.ts

import '../windowed_study.dart';
import '../../layout/layout_types.dart';
import '../../scale/common_scale_manager.dart';
import '../../shapes/batch/polyline_batch.dart';
import '../../shapes/line.dart';

/// Simple Moving Average (SMA) study.
/// Calculates average of close prices over a window period.
/// Tracks min/max incrementally and reports to common price scale.
/// Uses batch rendering for efficient polyline drawing.
class SMAStudy extends WindowedStudy<double, Point> {
  SMAStudy({int period = 20, String color = '#4285f4'})
      : _color = color,
        super(
          'sma',
          'SMA($period)',
          period,
          PolylineBatch(color: color, lineWidth: 2),
        );

  final String _color;

  /// Get the period (for external adapters like ECharts).
  int getPeriod() {
    return windowSize;
  }

  /// Get the color (for external adapters like ECharts).
  String getColor() {
    return _color;
  }

  /// Calculate SMA from window of candles.
  /// Returns average of close prices.
  @override
  double? calculateValue(List<OHLCData> window) {
    if (window.length < windowSize) return null;

    final sum = window.fold<double>(0, (acc, candle) => acc + candle.close);
    return sum / window.length;
  }

  /// Extract price bounds from SMA value.
  /// SMA is a single value, so min and max are the same.
  @override
  ({double min, double max})? extractPriceBounds(double value) {
    return (min: value, max: value);
  }

  /// Convert computed SMA value to pixel point for batch rendering.
  /// Transforms data coordinates (timestamp, price) to pixel coordinates (x, y).
  /// Uses O(1) index-based coordinate lookup for optimal performance.
  @override
  Point valueToPoint(
    double value,
    DateTime timestamp,
    int index,
    CommonScaleManager commonScales,
  ) {
    final timeScale = commonScales.timeScale;
    final priceScale = commonScales.priceScale;

    return Point(
      timeScale.scaledValueFromIndex(index),
      priceScale.scaledValue(value),
    );
  }
}
