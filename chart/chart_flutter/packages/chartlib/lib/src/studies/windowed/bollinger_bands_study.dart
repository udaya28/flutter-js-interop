/// Bollinger Bands study.
/// Consists of middle line (SMA) and upper/lower bands.
/// Ported from src/chartlib/studies/windowed/bollingerBands.ts

import 'dart:math' as math;
import '../windowed_study.dart';
import '../../data/ohlc.dart';
import '../../scale/common_scale_manager.dart';
import '../../scale/ordinal_time_scale.dart';
import '../../scale/numeric_scale.dart';
import '../../shapes/batch/band_fill_batch.dart';
import '../../shapes/line.dart';

/// Bollinger Bands data: upper band, middle line (SMA), lower band.
class BollingerBandsData {
  const BollingerBandsData({
    required this.upper,
    required this.middle,
    required this.lower,
  });

  final double upper;
  final double middle;
  final double lower;
}

/// Bollinger Bands study.
/// Consists of:
/// - Middle line: SMA
/// - Upper band: SMA + (multiplier × standard deviation)
/// - Lower band: SMA - (multiplier × standard deviation)
/// Tracks min (lower band) / max (upper band) incrementally and reports to common price scale.
/// Uses batch rendering for efficient band fill and lines.
class BollingerBandsStudy extends WindowedStudy<BollingerBandsData, BandFillPoint> {
  /// Standard deviation multiplier (typically 2)
  final double multiplier;

  BollingerBandsStudy({
    int period = 20,
    double multiplier = 2,
    String? fillColor,
    String? borderColor,
  })  : multiplier = multiplier,
        super(
          'bb',
          'BB($period,$multiplier)',
          period,
          BandFillBatch(
            fillColor: fillColor ?? '#2196f3',
            fillOpacity: 0.1,
            borderColor: borderColor ?? '#2196f3',
            borderWidth: 1,
            showBorders: true,
          ),
        );

  /// Calculate Bollinger Bands from window of candles.
  @override
  BollingerBandsData? calculateValue(List<OHLCData> window) {
    if (window.length < windowSize) return null;

    // Calculate SMA (middle line)
    final sum = window.fold<double>(0, (acc, candle) => acc + candle.close);
    final sma = sum / window.length;

    // Calculate standard deviation
    final squaredDiffs = window.map((candle) {
      final diff = candle.close - sma;
      return diff * diff;
    }).toList();
    final variance = squaredDiffs.fold<double>(0, (acc, val) => acc + val) / window.length;
    final stdDev = math.sqrt(variance);

    // Calculate bands
    final upper = sma + multiplier * stdDev;
    final lower = sma - multiplier * stdDev;

    return BollingerBandsData(
      upper: upper,
      middle: sma,
      lower: lower,
    );
  }

  /// Extract price bounds from Bollinger Bands value.
  /// Returns lower band as min and upper band as max.
  @override
  ({double min, double max})? extractPriceBounds(BollingerBandsData value) {
    return (min: value.lower, max: value.upper);
  }

  /// Convert computed Bollinger Bands value to band fill point for batch rendering.
  /// Transforms data coordinates to pixel coordinates for upper, middle, and lower lines.
  /// Uses O(1) index-based coordinate lookup for optimal performance.
  @override
  BandFillPoint valueToPoint(
    BollingerBandsData value,
    DateTime timestamp,
    int index,
    CommonScaleManager commonScales,
  ) {
    final timeScale = commonScales.timeScale as OrdinalTimeScale;
    final priceScale = commonScales.priceScale as NumericScale;

    final x = timeScale.scaledValueFromIndex(index);

    return BandFillPoint(
      upper: Point(x, priceScale.scaledValue(value.upper)),
      middle: Point(x, priceScale.scaledValue(value.middle)),
      lower: Point(x, priceScale.scaledValue(value.lower)),
    );
  }
}
