/// Abstract base class for studies that calculate per-candle without needing history.
/// Use for: Candle rendering, Volume, Open Interest - anything calculated from individual candles.
/// Ported from src/chartlib/studies/instantStudy.ts

import 'dart:math' as math;
import '../layout/layout_types.dart';
import '../core/base_definition.dart';
import '../scale/common_scale_manager.dart';
import '../shapes/batch/shape_batch.dart';

/// Abstract base class for studies that calculate per-candle without needing history.
/// Use for: Candle rendering, Volume, Open Interest - anything calculated from individual candles.
///
/// Subclasses must implement:
/// - calculateValue(candle): TValue - compute value from single candle
/// - extractPriceBounds(value): bounds | null - extract price bounds for scaling
/// - valueToPoint(value, timestamp, scales): TBatchPoint - convert value to pixel point
/// - Pass shapeBatch to super() constructor
///
/// Base class automatically handles:
/// - Data storage and incremental updates
/// - Batch cache invalidation on scale changes
///
/// @template TValue - The computed value type (CandleData, VolumeData, etc.)
/// @template TBatchPoint - The batch point type (CandlePoint, BarPoint, etc.)
abstract class InstantStudy<TValue, TBatchPoint> extends Study<TBatchPoint> {
  InstantStudy(super.id, super.name, this.shapeBatch);

  /// Computed data for each candle
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

  /// Calculate value for a single candle.
  /// Subclass must implement this method.
  ///
  /// @param candle - Candle data
  /// @returns Calculated value
  TValue calculateValue(OHLCData candle);

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
  @override
  ScaleDomainUpdate? updateLastCandle(List<OHLCData> allCandles) {
    if (allCandles.isEmpty) return null;

    final candle = allCandles[allCandles.length - 1];
    final newValue = calculateValue(candle);

    // First candle - append it
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

    // Check if we're updating existing last candle or appending new one
    final lastComputed = computedData[computedData.length - 1];
    final timestampsMatch = lastComputed.timestamp.millisecondsSinceEpoch ==
        candle.timestamp.millisecondsSinceEpoch;

    bool rangeChanged = false;

    if (timestampsMatch) {
      // Update existing last candle
      final oldValue = lastComputed.value;
      final oldBounds = extractPriceBounds(oldValue);

      computedData[computedData.length - 1] = ComputedDataPoint(
        timestamp: candle.timestamp,
        value: newValue,
        index: allCandles.length - 1,
      );

      // Invalidate render cache since data changed
      _lastRenderHash = null;

      // Update price domain if applicable
      final newBounds = extractPriceBounds(newValue);
      if (newBounds != null) {
        rangeChanged = updatePriceDomain(newBounds, oldBounds);
      }
    } else {
      // Append new candle
      computedData.add(ComputedDataPoint(
        timestamp: candle.timestamp,
        value: newValue,
        index: allCandles.length - 1,
      ));

      // Invalidate render cache since data changed
      _lastRenderHash = null;

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
  @override
  ScaleDomainUpdate? appendNewCandle(List<OHLCData> allCandles) {
    if (allCandles.isEmpty) return null;

    final candle = allCandles[allCandles.length - 1];
    final newValue = calculateValue(candle);
    computedData.add(ComputedDataPoint(
      timestamp: candle.timestamp,
      value: newValue,
      index: allCandles.length - 1,
    ));

    // Invalidate render cache since data changed
    _lastRenderHash = null;

    return null;
  }

  /// Prepend historical candles (load more history).
  /// Recalculates all computed data from the complete dataset.
  @override
  ScaleDomainUpdate? prependHistoricalCandles(List<OHLCData> allCandles) {
    return resetCandles(allCandles);
  }

  /// Reset all candles (full data reload).
  /// Recalculates all computed data from the complete dataset.
  @override
  ScaleDomainUpdate? resetCandles(List<OHLCData> allCandles) {
    computedData.clear();

    for (int i = 0; i < allCandles.length; i++) {
      computedData.add(ComputedDataPoint(
        timestamp: allCandles[i].timestamp,
        value: calculateValue(allCandles[i]),
        index: i,
      ));
    }

    // Invalidate render cache since all data changed
    _lastRenderHash = null;

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
      // Get visible range with buffer for smooth zoom and edge rendering
      final indices = commonScales.timeScale.getVisibleDomainIndices();

      // Guard against NaN or invalid indices
      if (indices.startIndex.isNaN || indices.endIndex.isNaN ||
          indices.startIndex.isInfinite || indices.endIndex.isInfinite) {
        return; // Skip rendering if indices are invalid
      }

      const buffer = 2;
      // Floor/ceil for array iteration - renders all partially visible candles
      final renderStart =
          math.max(0, (indices.startIndex - buffer).floor());
      final renderEnd =
          math.min(computedData.length - 1, (indices.endIndex + buffer).ceil());

      // Convert visible computed data to pixel points
      final points = <TBatchPoint>[];
      for (int i = renderStart; i <= renderEnd; i++) {
        final dp = computedData[i];
        points.add(valueToPoint(dp.value, dp.timestamp, dp.index, commonScales));
      }

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
    return '${computedData.length}-${indices.startIndex}-${indices.endIndex}-${domain.min}-${domain.max}';
  }
}
