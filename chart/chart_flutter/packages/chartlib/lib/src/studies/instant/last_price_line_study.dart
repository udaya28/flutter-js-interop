/// Last Price Line Study - displays horizontal line at last price with label.
/// Similar to TradingView's last price indicator.
/// Ported from src/chartlib/studies/instant/lastPriceLineStudy.ts

import '../../data/ohlc.dart';
import '../base_study.dart';
import '../../core/base_definition.dart';
import '../../scale/common_scale_manager.dart';
import '../../layout/layout_types.dart';
import '../../shapes/line.dart';

/// Last Price Line Study - displays horizontal line at last price with label.
/// Similar to TradingView's last price indicator.
///
/// Features:
/// - Horizontal dotted line across chart at last close price
/// - Price label on right edge (over y-axis)
/// - Auto-updates with real-time data
/// - Doesn't contribute to price scale bounds
class LastPriceLineStudy extends Study<dynamic> {
  /// Last candle close price
  double? lastPrice;

  /// Color for the line and label
  final String color;

  /// Cached line shape for rendering (clipped)
  LineShape? cachedLine;

  /// Cached label shape for infrastructure rendering (unclipped, over y-axis)
  BoxedTextShape? cachedLabel;

  String? lastRenderHash;

  LastPriceLineStudy({String? color})
      : color = color ?? '#2962FF', // Default blue color
        super('lastPriceLine', 'Last Price');

  /// Update last candle - extract close price.
  @override
  ScaleDomainUpdate? updateLastCandle(List<OHLCData> allCandles) {
    if (allCandles.isEmpty) {
      lastPrice = null;
      return null;
    }

    lastPrice = allCandles[allCandles.length - 1].close;
    return null; // Doesn't affect price domain
  }

  /// Append new candle - extract close price.
  @override
  ScaleDomainUpdate? appendNewCandle(List<OHLCData> allCandles) {
    return updateLastCandle(allCandles);
  }

  /// Prepend historical candles - extract close price from last candle.
  @override
  ScaleDomainUpdate? prependHistoricalCandles(List<OHLCData> allCandles) {
    return updateLastCandle(allCandles);
  }

  /// Reset candles - extract close price from last candle.
  @override
  ScaleDomainUpdate? resetCandles(List<OHLCData> allCandles) {
    return updateLastCandle(allCandles);
  }

  /// Update scales - invalidate cache so shapes are regenerated.
  @override
  void updateScales(bool timeScaleChanged, bool priceScaleChanged) {
    if (timeScaleChanged || priceScaleChanged) {
      lastRenderHash = null;
    }
  }

  /// Render last price line (clipped to chart area).
  @override
  void renderTo(Compositor compositor, CommonScaleManager commonScales, Bounds bounds) {
    if (lastPrice == null) return;

    // Only render if last price is within visible price scale domain
    final domain = commonScales.priceScale.getDomain();
    if (lastPrice! < domain.min || lastPrice! > domain.max) return;

    // Generate cache hash
    final renderHash = '$lastPrice-${bounds.x}-${bounds.width}-${domain.min}-${domain.max}';

    if (lastRenderHash != renderHash) {
      _generateShapes(commonScales, bounds);
      lastRenderHash = renderHash;
    }

    // Render line (clipped to chart)
    if (cachedLine != null) {
      compositor.renderShapes([cachedLine!]);
    }
  }

  /// Render last price label (unclipped, appears over y-axis).
  @override
  void renderInfrastructureTo(Compositor compositor, CommonScaleManager commonScales, Bounds bounds) {
    if (lastPrice == null) return;

    // Only render if last price is within visible price scale domain
    final domain = commonScales.priceScale.getDomain();
    if (lastPrice! < domain.min || lastPrice! > domain.max) return;

    // Render label (unclipped, over y-axis)
    if (cachedLabel != null) {
      compositor.renderShapes([cachedLabel!]);
    }
  }

  /// Generate line and label shapes for last price.
  void _generateShapes(CommonScaleManager commonScales, Bounds bounds) {
    if (lastPrice == null) {
      cachedLine = null;
      cachedLabel = null;
      return;
    }

    // Calculate Y position for price
    final y = commonScales.priceScale.scaledValue(lastPrice!);

    // Horizontal dotted line across chart
    cachedLine = LineShape(
      start: Point(bounds.x, y),
      end: Point(bounds.x + bounds.width, y),
      color: color,
      lineWidth: 1,
      lineDash: [5, 5], // Dotted line
    );

    // Price label on right edge (over y-axis)
    final priceText = lastPrice!.toStringAsFixed(1);
    final labelX = bounds.x + bounds.width + 2; // 2px beyond chart edge, over y-axis

    cachedLabel = BoxedTextShape(
      position: Point(labelX, y),
      text: priceText,
      textColor: '#ffffff',
      backgroundColor: color,
      font: '11px sans-serif',
      padding: 3,
      align: TextAlign.left, // Left-aligned extends rightward over y-axis
      baseline: TextBaseline.middle,
    );
  }
}
