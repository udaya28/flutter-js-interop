/// Abstract base class for studies that need a window of historical data.
/// Use for: SMA, EMA, RSI, Bollinger Bands - anything needing multiple candles to calculate.
/// Ported from src/chartlib/studies/windowedStudy.ts

import 'dart:math' as math;
import '../layout/layout_types.dart';
import '../core/base_definition.dart';
import '../scale/common_scale_manager.dart';
import '../shapes/batch/shape_batch.dart';

/// Abstract base class for studies that need a window of historical data.
/// Use for: SMA, EMA, RSI, Bollinger Bands - anything needing multiple candles to calculate.
///
/// Subclasses must implement:
/// - calculateValue(window): TValue | null - compute value from window of candles
/// - extractPriceBounds(value): bounds | null - extract price bounds for scaling
/// - valueToPoint(value, timestamp, scales): TBatchPoint - convert value to pixel point
/// - Pass shapeBatch to super() constructor
///
/// Base class automatically handles:
/// - Extracting window from allCandles parameter
/// - Incremental recalculation (only last value on updateLastCandle)
/// - Full recomputation on prepend/reset
/// - Batch cache invalidation on scale changes
///
/// Note: Does NOT store candles to avoid memory duplication.
///
/// @template TValue - The computed value type (number, BollingerBandsData, etc.)
/// @template TBatchPoint - The batch point type (Point, BandFillPoint, etc.)
abstract class WindowedStudy<TValue, TBatchPoint> extends Study<TBatchPoint> {
  WindowedStudy(super.id, super.name, this.windowSize, this.shapeBatch);

  /// Window size needed for calculation
  final int windowSize;

  /// Computed data for each candle (starts after windowSize candles)
  final List<ComputedDataPoint<TValue>> computedData = [];

  /// Batch shape for efficient rendering
  final ShapeBatch<TBatchPoint> shapeBatch;

  /// Last render hash for cache invalidation
  String? _lastRenderHash;

  /// Minimum Y-axis price domain value tracked across all computed data
  double yPriceDomainMin = double.infinity;

  /// Maximum Y-axis price domain value tracked across all computed data
  double yPriceDomainMax = double.negativeInfinity;

  /// Get computed data values (for external adapters like ECharts).
  /// Returns array of raw values without timestamps.
  List<TValue> getComputedValues() {
    return computedData.map((dp) => dp.value).toList();
  }

  /// Calculate value for a window of candles.
  /// Subclass must implement this method.
  ///
  /// @param window - Array of candles (length = windowSize)
  /// @returns Calculated value, or null if cannot calculate
  TValue? calculateValue(List<OHLCData> window);

  /// Extract price bounds from computed value.
  /// Return null if this study doesn't track price bounds.
  ///
  /// @param value - Computed value
  /// @returns Price bounds or null
  ({double min, double max})? extractPriceBounds(TValue value);

  /// Convert computed value to batch point (pixel coordinates).
  /// Subclass must implement this method.
  ///
  /// @param value - Computed study value
  /// @param timestamp - Timestamp for this data point
  /// @param index - Index in the full candle array (for O(1) coordinate lookups)
  /// @param commonScales - Scale manager for coordinate transformation
  /// @returns Batch point in pixel coordinates
  TBatchPoint valueToPoint(
    TValue value,
    DateTime timestamp,
    int index,
    CommonScaleManager commonScales,
  );

  /// Update price domain tracking with new value.
  /// Returns true if range changed.
  ///
  /// @param newBounds - New price bounds
  /// @param oldBounds - Old price bounds (optional, for update case)
  /// @returns True if price range changed
  bool updatePriceDomain(
    ({double min, double max}) newBounds, [
    ({double min, double max})? oldBounds,
  ]) {
    // If old bounds were at extremes, need full recompute
    if (oldBounds != null &&
        (oldBounds.min == yPriceDomainMin ||
            oldBounds.max == yPriceDomainMax)) {
      recomputePriceDomain();
      return true;
    }

    // Otherwise check if new value extends range
    bool changed = false;
    if (newBounds.min < yPriceDomainMin) {
      yPriceDomainMin = newBounds.min;
      changed = true;
    }
    if (newBounds.max > yPriceDomainMax) {
      yPriceDomainMax = newBounds.max;
      changed = true;
    }
    return changed;
  }

  /// Recompute price domain from all computed data.
  void recomputePriceDomain() {
    yPriceDomainMin = double.infinity;
    yPriceDomainMax = double.negativeInfinity;

    for (final dataPoint in computedData) {
      final bounds = extractPriceBounds(dataPoint.value);
      if (bounds != null) {
        yPriceDomainMin = math.min(yPriceDomainMin, bounds.min);
        yPriceDomainMax = math.max(yPriceDomainMax, bounds.max);
      }
    }
  }

  /// Update the last candle with new data (real-time tick update).
  /// Only recalculates the last value using the window.
  @override
  ScaleDomainUpdate? updateLastCandle(List<OHLCData> allCandles) {
    if (allCandles.length < windowSize) return null;

    final candle = allCandles[allCandles.length - 1];
    final window = allCandles.sublist(allCandles.length - windowSize);
    final newValue = calculateValue(window);

    if (newValue == null) return null;

    // First computed value - append it
    if (computedData.isEmpty) {
      computedData.add(ComputedDataPoint(
        timestamp: candle.timestamp,
        value: newValue,
        index: allCandles.length - 1,
      ));

      // Initialize price domain if applicable
      final bounds = extractPriceBounds(newValue);
      if (bounds != null) {
        yPriceDomainMin = bounds.min;
        yPriceDomainMax = bounds.max;
        return ScaleDomainUpdate(
            yDomain: (min: yPriceDomainMin, max: yPriceDomainMax));
      }
      return null;
    }

    // Check if we're updating existing last value or appending new one
    final lastComputed = computedData[computedData.length - 1];
    final timestampsMatch = lastComputed.timestamp.millisecondsSinceEpoch ==
        candle.timestamp.millisecondsSinceEpoch;

    bool rangeChanged = false;

    if (timestampsMatch) {
      // Update existing last value
      final oldValue = lastComputed.value;
      final oldBounds = extractPriceBounds(oldValue);

      computedData[computedData.length - 1] = ComputedDataPoint(
        timestamp: candle.timestamp,
        value: newValue,
        index: allCandles.length - 1,
      );

      // Update price domain if applicable
      final newBounds = extractPriceBounds(newValue);
      if (newBounds != null) {
        rangeChanged = updatePriceDomain(newBounds, oldBounds);
      }
    } else {
      // Append new value
      computedData.add(ComputedDataPoint(
        timestamp: candle.timestamp,
        value: newValue,
        index: allCandles.length - 1,
      ));

      // Update price domain if applicable
      final newBounds = extractPriceBounds(newValue);
      if (newBounds != null) {
        rangeChanged = updatePriceDomain(newBounds);
      }
    }

    return rangeChanged
        ? ScaleDomainUpdate(
            yDomain: (min: yPriceDomainMin, max: yPriceDomainMax))
        : null;
  }

  /// Append a new candle (new time period started).
  /// Only recalculates the last value using the window.
  @override
  ScaleDomainUpdate? appendNewCandle(List<OHLCData> allCandles) {
    if (allCandles.length < windowSize) return null;

    final candle = allCandles[allCandles.length - 1];
    final window = allCandles.sublist(allCandles.length - windowSize);
    final newValue = calculateValue(window);

    if (newValue != null) {
      computedData.add(ComputedDataPoint(
        timestamp: candle.timestamp,
        value: newValue,
        index: allCandles.length - 1,
      ));
    }

    return null;
  }

  /// Prepend historical candles (load more history).
  /// Triggers full recomputation since window calculations shift.
  @override
  ScaleDomainUpdate? prependHistoricalCandles(List<OHLCData> allCandles) {
    return resetCandles(allCandles);
  }

  /// Reset all candles (full data reload).
  /// Triggers full recomputation.
  @override
  ScaleDomainUpdate? resetCandles(List<OHLCData> allCandles) {
    _recomputeAll(allCandles);

    // Recompute price domain
    recomputePriceDomain();

    return computedData.isNotEmpty && yPriceDomainMin != double.infinity
        ? ScaleDomainUpdate(
            yDomain: (min: yPriceDomainMin, max: yPriceDomainMax))
        : null;
  }

  /// Notification that scales have changed.
  /// Invalidates batch cache so batch is regenerated with new scales.
  @override
  void updateScales(bool timeScaleChanged, bool priceScaleChanged) {
    if (timeScaleChanged || priceScaleChanged) {
      _lastRenderHash = null; // Invalidate batch cache
    }
  }

  /// Render the study to a compositor.
  /// Converts computed data to pixel coordinates and renders batch directly.
  @override
  void renderTo(
      Compositor compositor, CommonScaleManager commonScales, Bounds bounds) {
    if (computedData.isEmpty) return;

    final renderHash = _getRenderHash(commonScales);
    final needsRebuild =
        _lastRenderHash == null || _lastRenderHash != renderHash;

    if (needsRebuild) {
      // Convert all computed data to pixel points
      final points = computedData
          .map((dp) =>
              valueToPoint(dp.value, dp.timestamp, dp.index, commonScales))
          .toList();

      // Reset batch with new pixel coordinates
      shapeBatch.reset(points);
      _lastRenderHash = renderHash;
    }

    // Render directly to compositor - no allocation, no return
    compositor.render(shapeBatch);
  }

  /// Generate hash for cache invalidation.
  /// Hash includes data length and scale state to detect when rebuild is needed.
  String _getRenderHash(CommonScaleManager commonScales) {
    final ts = commonScales.timeScale;
    final ps = commonScales.priceScale;
    final indices = ts.getVisibleDomainIndices();
    final domain = ps.getDomain();

    // Include data length, visible range, and price domain
    // Range (pixel coordinates) changes are handled by layout recalculation, not here
    return '${computedData.length}-${indices.startIndex}-${indices.endIndex}-${domain.min}-${domain.max}';
  }

  /// Recompute all values from all candles.
  /// Called when prepending or resetting data.
  void _recomputeAll(List<OHLCData> allCandles) {
    computedData.clear();

    // Need at least windowSize candles
    if (allCandles.length < windowSize) {
      return;
    }

    // Calculate for each window
    for (int i = windowSize - 1; i < allCandles.length; i++) {
      final window = allCandles.sublist(i - windowSize + 1, i + 1);
      final value = calculateValue(window);

      if (value != null) {
        computedData.add(ComputedDataPoint(
          timestamp: allCandles[i].timestamp,
          value: value,
          index: i,
        ));
      }
    }
  }
}
