/// Candle study - renders OHLC candlesticks in the main chart region.
/// Tracks price range incrementally and reports updates to common price scale.
/// Ported from src/chartlib/studies/instant/candleStudy.ts

import 'dart:math' as math;
import '../instant_study.dart';
import '../../layout/layout_types.dart';
import '../../scale/common_scale_manager.dart';
import '../../shapes/batch/candle_batch.dart';

/// OHLC values for a candle.
class CandleData {
  const CandleData({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
  });

  final double open;
  final double high;
  final double low;
  final double close;
}

/// Candle study - renders OHLC candlesticks in the main chart region.
/// Tracks price range incrementally and reports updates to common price scale.
/// Uses batch rendering for efficient candle drawing.
class CandleStudy extends InstantStudy<CandleData, CandlePoint> {
  CandleStudy() : super('candle', 'Candles', CandleBatch());

  /// Extract OHLC values from candle data.
  @override
  CandleData calculateValue(OHLCData candle) {
    return CandleData(
      open: candle.open,
      high: candle.high,
      low: candle.low,
      close: candle.close,
    );
  }

  /// Extract price bounds from candle data.
  /// Returns low as min and high as max.
  @override
  ({double min, double max})? extractPriceBounds(CandleData value) {
    return (min: value.low, max: value.high);
  }

  /// Convert computed candle value to pixel point for batch rendering.
  /// Transforms OHLC data coordinates to pixel coordinates for wicks and body.
  /// Uses O(1) index-based coordinate lookup for optimal performance.
  @override
  CandlePoint valueToPoint(
    CandleData value,
    DateTime timestamp,
    int index,
    CommonScaleManager commonScales,
  ) {
    final timeScale = commonScales.timeScale;
    final priceScale = commonScales.priceScale;

    final x = timeScale.scaledValueFromIndex(index);
    final boxWidth = timeScale.boxWidth();
    final candleWidth = boxWidth * 0.7; // 70% of available width

    final bodyTop = math.max(value.open, value.close);
    final bodyBottom = math.min(value.open, value.close);

    return CandlePoint(
      x: x,
      upperWick: (
        y1: priceScale.scaledValue(bodyTop),
        y2: priceScale.scaledValue(value.high),
      ),
      lowerWick: (
        y1: priceScale.scaledValue(value.low),
        y2: priceScale.scaledValue(bodyBottom),
      ),
      body: (
        y: priceScale.scaledValue(bodyTop),
        height: (priceScale.scaledValue(bodyTop) - priceScale.scaledValue(bodyBottom)).abs(),
        width: candleWidth,
      ),
      isPositive: value.close >= value.open,
    );
  }
}
