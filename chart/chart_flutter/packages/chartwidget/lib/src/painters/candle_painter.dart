import 'package:flutter/widgets.dart';
import 'package:chartlib/chartlib.dart';

/// CustomPainter for rendering OHLC candles
/// Similar to Canvas2D renderer in JS version
class CandlePainter extends CustomPainter {
  final List<OHLCCandle> candles;
  final ChartTheme theme;

  CandlePainter({
    required this.candles,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    // Draw background
    final backgroundPaint = Paint()..color = theme.colors.background;
    canvas.drawRect(Offset.zero & size, backgroundPaint);

    // Calculate price range for scaling
    double minPrice = double.infinity;
    double maxPrice = double.negativeInfinity;
    for (final candle in candles) {
      if (candle.low < minPrice) minPrice = candle.low;
      if (candle.high > maxPrice) maxPrice = candle.high;
    }

    // Create numeric scale for price -> Y coordinate
    final priceScale = NumericScale(
      domainMin: minPrice,
      domainMax: maxPrice,
      rangeMin: size.height - 20, // Bottom padding
      rangeMax: 20, // Top padding (inverted Y)
    );

    // Calculate candle width
    final candleWidth = size.width / candles.length;
    final bodyWidth = candleWidth * 0.8;

    // Draw candles
    for (int i = 0; i < candles.length; i++) {
      final candle = candles[i];
      final x = i * candleWidth + candleWidth / 2;

      _drawCandle(canvas, candle, x, bodyWidth, priceScale);
    }
  }

  void _drawCandle(
    Canvas canvas,
    OHLCCandle candle,
    double x,
    double bodyWidth,
    NumericScale priceScale,
  ) {
    final color = candle.isBullish
        ? theme.colors.candlePositive
        : theme.colors.candleNegative;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final wickPaint = Paint()
      ..color = color
      ..strokeWidth = 1;

    // Calculate Y coordinates
    final highY = priceScale.scaledValue(candle.high);
    final lowY = priceScale.scaledValue(candle.low);
    final openY = priceScale.scaledValue(candle.open);
    final closeY = priceScale.scaledValue(candle.close);

    // Draw wick (high-low line)
    canvas.drawLine(
      Offset(x, highY),
      Offset(x, lowY),
      wickPaint,
    );

    // Draw body (open-close rectangle)
    final bodyTop = candle.isBullish ? closeY : openY;
    final bodyBottom = candle.isBullish ? openY : closeY;
    final bodyHeight = (bodyBottom - bodyTop).abs().clamp(1.0, double.infinity);

    canvas.drawRect(
      Rect.fromLTWH(
        x - bodyWidth / 2,
        bodyTop,
        bodyWidth,
        bodyHeight,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(CandlePainter oldDelegate) {
    return oldDelegate.candles != candles || oldDelegate.theme != theme;
  }
}
