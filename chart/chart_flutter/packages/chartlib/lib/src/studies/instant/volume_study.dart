/// Volume study - renders volume bars in a sub-panel.
/// Manages its own Y-scale (0 to maxVolume) and does not affect common price scale.
/// Ported from src/chartlib/studies/instant/volumeStudy.ts

import 'dart:math' as math;
import '../instant_study.dart';
import '../../layout/layout_types.dart';
import '../../core/base_definition.dart';
import '../../scale/common_scale_manager.dart';
import '../../scale/numeric_scale.dart';
import '../../shapes/batch/bar_batch.dart';

/// Volume data with price direction for coloring.
class VolumeData {
  const VolumeData({
    required this.volume,
    required this.isPositive,
  });

  final double volume;
  final bool isPositive;
}

/// Volume study - renders volume bars in a sub-panel.
/// Manages its own Y-scale (0 to maxVolume) and does not affect common price scale.
/// Uses batch rendering for efficient bar drawing.
class VolumeStudy extends InstantStudy<VolumeData, BarPoint> {
  VolumeStudy()
      : _customYScale = NumericScale(
          domainMin: 0,
          domainMax: 1,
          rangeMin: 0,
          rangeMax: 100,
          inverted: true,
        ),
        super('volume', 'Volume', BarBatch());

  /// Custom Y-scale for volume (0 to maxVolume)
  final NumericScale _customYScale;

  /// Maximum volume across all candles
  double _maxVolume = 0;

  /// Extract volume and price direction from candle data.
  @override
  VolumeData calculateValue(OHLCData candle) {
    return VolumeData(
      volume: candle.volume,
      isPositive: candle.close >= candle.open,
    );
  }

  /// Volume doesn't track price bounds (uses custom Y-scale).
  @override
  ({double min, double max})? extractPriceBounds(VolumeData value) {
    return null;
  }

  /// Update the last candle with new data (real-time tick update).
  /// Updates custom Y-scale domain but does not report to common scales.
  @override
  ScaleDomainUpdate? updateLastCandle(List<OHLCData> allCandles) {
    // Call parent to handle data updates
    super.updateLastCandle(allCandles);

    if (computedData.isEmpty) return null;

    // Update maxVolume tracking
    final lastValue = computedData[computedData.length - 1].value;
    if (lastValue.volume > _maxVolume) {
      _maxVolume = lastValue.volume;
      _customYScale.updateDomain(0, _maxVolume);
    } else {
      // Check if we need to recompute (in case volume decreased from max)
      _recomputeMax();
      _customYScale.updateDomain(0, _maxVolume);
    }

    return null; // Manages own Y-scale, doesn't affect common scales
  }

  /// Reset all candles (full data reload).
  @override
  ScaleDomainUpdate? resetCandles(List<OHLCData> allCandles) {
    super.resetCandles(allCandles);
    _recomputeMax();
    _customYScale.updateDomain(0, _maxVolume);
    return null;
  }

  /// Prepend historical candles (load more history).
  @override
  ScaleDomainUpdate? prependHistoricalCandles(List<OHLCData> allCandles) {
    super.prependHistoricalCandles(allCandles);
    _recomputeMax();
    _customYScale.updateDomain(0, _maxVolume);
    return null;
  }

  /// Recompute maximum volume from all computed data.
  void _recomputeMax() {
    _maxVolume = 0;
    for (final dataPoint in computedData) {
      _maxVolume = math.max(_maxVolume, dataPoint.value.volume);
    }
  }

  /// Update scale pixel ranges based on pane bounds.
  /// Called by SubPane during layout recalculation.
  @override
  void updateScaleBounds(Bounds bounds) {
    _customYScale.updateRange(bounds.y, bounds.y + bounds.height);
  }

  /// Get the custom Y-scale for volume axis rendering.
  @override
  NumericScale? getYScale() {
    return _customYScale;
  }

  /// Convert computed volume value to pixel bar point for batch rendering.
  /// Uses custom Y-scale (0 to maxVolume) instead of common price scale.
  /// Transforms data coordinates (timestamp, volume) to pixel coordinates (x, y, width, height).
  /// Uses O(1) index-based coordinate lookup for optimal performance.
  @override
  BarPoint valueToPoint(
    VolumeData value,
    DateTime timestamp,
    int index,
    CommonScaleManager commonScales,
  ) {
    final timeScale = commonScales.timeScale;
    final volumeScale = _customYScale;

    final boxWidth = timeScale.boxWidth();
    final barWidth = boxWidth * 0.7; // 70% of available width, matching candles

    final volume = value.volume;
    final isPositive = value.isPositive;

    // Calculate bar position and dimensions
    final centerX = timeScale.scaledValueFromIndex(index);
    final y0 = volumeScale.scaledValue(0);
    final y1 = volumeScale.scaledValue(volume);
    final barHeight = (y1 - y0).abs();
    final topY = math.min(y0, y1);

    return BarPoint(
      x: centerX - barWidth / 2, // Left edge
      y: topY,
      width: barWidth,
      height: barHeight,
      isPositive: isPositive,
    );
  }
}
