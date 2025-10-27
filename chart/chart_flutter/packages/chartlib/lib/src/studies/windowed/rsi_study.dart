/// Relative Strength Index (RSI) study.
/// Measures momentum on a 0-100 scale.
/// Ported from src/chartlib/studies/windowed/rsiStudy.ts

import 'dart:math' as math;
import '../windowed_study.dart';
import '../../data/ohlc.dart';
import '../../core/base_definition.dart';
import '../../scale/common_scale_manager.dart';
import '../../scale/ordinal_time_scale.dart';
import '../../scale/numeric_scale.dart';
import '../../shapes/batch/polyline_batch.dart';
import '../../shapes/line.dart';

/// Relative Strength Index (RSI) study.
/// Measures momentum on a 0-100 scale.
/// Values above 70 indicate overbought, below 30 indicate oversold.
/// Manages its own Y-scale (fixed 0-100) and does not affect common price scale.
/// Uses batch rendering for efficient polyline drawing.
class RSIStudy extends WindowedStudy<double, Point> {
  /// Custom Y-scale for RSI (fixed 0-100 domain)
  /// Initialized with default range, updated by updateScaleBounds()
  late NumericScale customYScale;

  /// Line color
  final String color;

  RSIStudy({int period = 14, String? color})
      : color = color ?? '#9c27b0',
        super('rsi', 'RSI($period)', period, PolylineBatch(color: color ?? '#9c27b0', lineWidth: 2)) {
    // Initialize custom Y-scale with default range (will be updated by updateScaleBounds)
    customYScale = NumericScale(
      domainMin: 0,
      domainMax: 100,
      rangeMin: 0,
      rangeMax: 100,
      inverted: true,
    );
  }

  /// Get the period (for external adapters like ECharts).
  int getPeriod() {
    return windowSize;
  }

  /// Get the color (for external adapters like ECharts).
  String getColor() {
    return color;
  }

  /// Calculate RSI from window of candles.
  /// RSI = 100 - (100 / (1 + RS))
  /// where RS = Average Gain / Average Loss
  @override
  double? calculateValue(List<OHLCData> window) {
    if (window.length < windowSize) return null;

    double totalGain = 0;
    double totalLoss = 0;

    // Calculate gains and losses
    for (int i = 1; i < window.length; i++) {
      final change = window[i].close - window[i - 1].close;
      if (change > 0) {
        totalGain += change;
      } else {
        totalLoss += change.abs();
      }
    }

    final avgGain = totalGain / (window.length - 1);
    final avgLoss = totalLoss / (window.length - 1);

    // Avoid division by zero
    if (avgLoss == 0) {
      return 100.0; // All gains, RSI = 100
    }

    final rs = avgGain / avgLoss;
    final rsi = 100 - 100 / (1 + rs);

    return rsi;
  }

  /// RSI doesn't track price bounds (uses custom Y-scale with fixed 0-100 domain).
  @override
  ({double min, double max})? extractPriceBounds(double value) {
    return null;
  }

  /// Get the custom Y-scale for RSI (0-100 domain).
  /// Required by SubPane to create the price axis.
  @override
  NumericScale? getYScale() {
    return customYScale;
  }

  /// Update scale pixel ranges based on pane bounds.
  /// Called by SubPane during layout recalculation.
  @override
  void updateScaleBounds(Bounds bounds) {
    // Initialize custom Y-scale with fixed 0-100 domain if not already created
    customYScale = NumericScale(
      domainMin: 0,
      domainMax: 100,
      rangeMin: bounds.y,
      rangeMax: bounds.y + bounds.height,
      inverted: true, // Y-axis is inverted in graphics (0 at top)
    );
  }

  /// Convert computed RSI value to pixel point for batch rendering.
  /// Uses custom Y-scale (0-100) instead of common price scale.
  /// Transforms data coordinates (timestamp, RSI value) to pixel coordinates (x, y).
  /// Uses O(1) index-based coordinate lookup for optimal performance.
  @override
  Point valueToPoint(
    double value,
    DateTime timestamp,
    int index,
    CommonScaleManager commonScales,
  ) {
    final timeScale = commonScales.timeScale as OrdinalTimeScale;
    final rsiScale = customYScale;

    return Point(
      timeScale.scaledValueFromIndex(index),
      rsiScale.scaledValue(value),
    );
  }

  // TODO: Add reference lines at 70 (overbought) and 30 (oversold)
  // These could be implemented as separate horizontal line shapes
}
