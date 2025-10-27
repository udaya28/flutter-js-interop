/// Exponential Moving Average (EMA) study.
/// Applies exponential weighting to recent values.
/// Ported from src/chartlib/studies/windowed/emaStudy.ts

import '../windowed_study.dart';
import '../../layout/layout_types.dart';
import '../../scale/common_scale_manager.dart';
import '../../shapes/batch/polyline_batch.dart';
import '../../shapes/line.dart';

/// Exponential Moving Average (EMA) study.
/// Applies exponential weighting to recent values.
/// Tracks min/max incrementally and reports to common price scale.
/// Uses batch rendering for efficient polyline drawing.
class EMAStudy extends WindowedStudy<double, Point> {
  EMAStudy({int period = 12, String color = '#ff6b6b'})
      : _multiplier = 2 / (period + 1),
        _color = color,
        super(
          'ema',
          'EMA($period)',
          period,
          PolylineBatch(color: color, lineWidth: 2),
        );

  /// EMA multiplier: 2 / (period + 1)
  final double _multiplier;

  /// Line color
  final String _color;

  /// Previous EMA value (for incremental calculation)
  double? _previousEMA;

  /// Get the period (for external adapters like ECharts).
  int getPeriod() {
    return windowSize;
  }

  /// Get the color (for external adapters like ECharts).
  String getColor() {
    return _color;
  }

  /// Calculate EMA from window of candles.
  /// First value uses SMA, subsequent values use EMA formula.
  @override
  double? calculateValue(List<OHLCData> window) {
    if (window.length < windowSize) return null;

    final currentClose = window[window.length - 1].close;

    // First value: use SMA as seed
    if (_previousEMA == null) {
      final sum = window.fold<double>(0, (acc, candle) => acc + candle.close);
      _previousEMA = sum / window.length;
      return _previousEMA;
    }

    // EMA formula: (Close - PreviousEMA) × multiplier + PreviousEMA
    final ema = (currentClose - _previousEMA!) * _multiplier + _previousEMA!;
    _previousEMA = ema;
    return ema;
  }

  /// Extract price bounds from EMA value.
  /// EMA is a single value, so min and max are the same.
  @override
  ({double min, double max})? extractPriceBounds(double value) {
    return (min: value, max: value);
  }

  /// Reset all candles (full data reload).
  /// Resets EMA state and delegates to base class.
  @override
  ScaleDomainUpdate? resetCandles(List<OHLCData> allCandles) {
    _previousEMA = null;
    return super.resetCandles(allCandles);
  }

  /// Prepend historical candles (load more history).
  /// Resets EMA state and delegates to base class.
  @override
  ScaleDomainUpdate? prependHistoricalCandles(List<OHLCData> allCandles) {
    _previousEMA = null;
    return super.prependHistoricalCandles(allCandles);
  }

  /// Convert computed EMA value to pixel point for batch rendering.
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
