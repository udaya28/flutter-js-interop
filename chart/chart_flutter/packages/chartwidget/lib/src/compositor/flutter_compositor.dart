/// Flutter implementation of Compositor interface.
/// Bridges chartlib's framework-agnostic rendering to Flutter Canvas API.

import 'dart:ui' as ui;
import 'package:flutter/widgets.dart' as widgets;
import 'package:chartlib/chartlib.dart';

/// Flutter Compositor - implements chartlib's Compositor interface.
/// Renders chart shapes to Flutter Canvas.
class FlutterCompositor implements Compositor {
  final widgets.Canvas canvas;
  final widgets.Size size;
  final ChartTheme theme;

  FlutterCompositor(this.canvas, this.size, this.theme);

  @override
  void setupHighDPI(double width, double height) {
    // Flutter handles DPI automatically, no action needed
  }

  @override
  void clear() {
    try {
      // Flutter's CustomPaint clears automatically before paint()
      // Draw background
      final backgroundPaint = widgets.Paint()..color = theme.colors.background;
      canvas.drawRect(widgets.Offset.zero & size, backgroundPaint);
    } catch (e) {
      // Ignore errors if canvas is disposed (happens during widget rebuilds)
      // This can occur when the widget is disposed while a render is pending
    }
  }

  @override
  void render(dynamic shapeBatch) {
    if (shapeBatch is CandleBatch) {
      _renderCandleBatch(shapeBatch);
    } else if (shapeBatch is BarBatch) {
      _renderBarBatch(shapeBatch);
    } else if (shapeBatch is PolylineBatch) {
      _renderPolylineBatch(shapeBatch);
    } else if (shapeBatch is BandFillBatch) {
      _renderBandFillBatch(shapeBatch);
    }
  }

  @override
  void renderShapes(List<dynamic> shapes) {
    for (final shape in shapes) {
      if (shape is LineShape) {
        _renderLineShape(shape);
      } else if (shape is TextShape) {
        _renderTextShape(shape);
      } else if (shape is BoxedTextShape) {
        _renderBoxedTextShape(shape);
      }
      // Silently skip unknown shapes (grid lines, axis lines, etc. from chartlib)
    }
  }

  @override
  void setClipRegion(Bounds bounds) {
    try {
      canvas.save();
      canvas.clipRect(widgets.Rect.fromLTWH(bounds.x, bounds.y, bounds.width, bounds.height));
    } catch (e) {
      // Ignore if canvas is disposed
    }
  }

  @override
  void clearClipRegion() {
    try {
      canvas.restore();
    } catch (e) {
      // Ignore if canvas is disposed
    }
  }

  @override
  void drawBorder(Bounds bounds) {
    final borderPaint = widgets.Paint()
      ..color = theme.colors.borderColor
      ..style = widgets.PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRect(
      widgets.Rect.fromLTWH(bounds.x, bounds.y, bounds.width, bounds.height),
      borderPaint,
    );
  }

  /// Render a batch of candles
  void _renderCandleBatch(CandleBatch batch) {
    for (final candlePoint in batch.candles) {
      _renderCandle(candlePoint);
    }
  }

  /// Render a single candle
  void _renderCandle(CandlePoint candlePoint) {
    final color = candlePoint.isPositive
        ? theme.colors.candlePositive
        : theme.colors.candleNegative;

    final wickPaint = widgets.Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = widgets.PaintingStyle.stroke;

    final bodyPaint = widgets.Paint()
      ..color = color
      ..style = widgets.PaintingStyle.fill;

    // Draw upper wick
    canvas.drawLine(
      widgets.Offset(candlePoint.x, candlePoint.upperWick.y1),
      widgets.Offset(candlePoint.x, candlePoint.upperWick.y2),
      wickPaint,
    );

    // Draw lower wick
    canvas.drawLine(
      widgets.Offset(candlePoint.x, candlePoint.lowerWick.y1),
      widgets.Offset(candlePoint.x, candlePoint.lowerWick.y2),
      wickPaint,
    );

    // Draw body
    canvas.drawRect(
      widgets.Rect.fromLTWH(
        candlePoint.x - candlePoint.body.width / 2,
        candlePoint.body.y,
        candlePoint.body.width,
        candlePoint.body.height,
      ),
      bodyPaint,
    );
  }

  /// Render a batch of bars (volume)
  void _renderBarBatch(BarBatch batch) {
    for (final barPoint in batch.bars) {
      _renderBar(barPoint);
    }
  }

  /// Render a single bar
  void _renderBar(BarPoint barPoint) {
    final color = barPoint.isPositive
        ? theme.colors.candlePositive
        : theme.colors.candleNegative;

    final barPaint = widgets.Paint()
      ..color = color.withOpacity(0.5)
      ..style = widgets.PaintingStyle.fill;

    canvas.drawRect(
      widgets.Rect.fromLTWH(
        barPoint.x,
        barPoint.y,
        barPoint.width,
        barPoint.height,
      ),
      barPaint,
    );
  }

  /// Render a polyline (SMA, EMA, etc.)
  void _renderPolylineBatch(PolylineBatch batch) {
    if (batch.points.length < 2) return;

    final linePaint = widgets.Paint()
      ..color = _colorFromHex(batch.color)
      ..strokeWidth = batch.lineWidth
      ..style = widgets.PaintingStyle.stroke
      ..strokeCap = widgets.StrokeCap.round
      ..strokeJoin = widgets.StrokeJoin.round;

    // Set dash pattern if specified
    if (batch.lineDash != null && batch.lineDash!.isNotEmpty) {
      // Flutter doesn't have built-in dash support, would need path_drawing package
      // For now, draw solid line
    }

    final path = widgets.Path();
    path.moveTo(batch.points[0].x, batch.points[0].y);

    for (int i = 1; i < batch.points.length; i++) {
      path.lineTo(batch.points[i].x, batch.points[i].y);
    }

    canvas.drawPath(path, linePaint);
  }

  /// Render a band fill (Bollinger Bands)
  void _renderBandFillBatch(BandFillBatch batch) {
    if (batch.upperPoints.isEmpty) return;

    // Draw fill between upper and lower bands
    final fillPaint = widgets.Paint()
      ..color = _colorFromHex(batch.fillColor).withOpacity(batch.fillOpacity)
      ..style = widgets.PaintingStyle.fill;

    final fillPath = widgets.Path();

    // Draw upper band forward
    fillPath.moveTo(batch.upperPoints[0].x, batch.upperPoints[0].y);
    for (int i = 1; i < batch.upperPoints.length; i++) {
      fillPath.lineTo(batch.upperPoints[i].x, batch.upperPoints[i].y);
    }

    // Draw lower band backward
    for (int i = batch.lowerPoints.length - 1; i >= 0; i--) {
      fillPath.lineTo(batch.lowerPoints[i].x, batch.lowerPoints[i].y);
    }

    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    // Draw border lines if enabled
    if (batch.showBorders) {
      final borderPaint = widgets.Paint()
        ..color = _colorFromHex(batch.borderColor)
        ..strokeWidth = batch.borderWidth
        ..style = widgets.PaintingStyle.stroke;

      // Draw upper line
      final upperPath = widgets.Path();
      upperPath.moveTo(batch.upperPoints[0].x, batch.upperPoints[0].y);
      for (int i = 1; i < batch.upperPoints.length; i++) {
        upperPath.lineTo(batch.upperPoints[i].x, batch.upperPoints[i].y);
      }
      canvas.drawPath(upperPath, borderPaint);

      // Draw middle line
      final middlePath = widgets.Path();
      middlePath.moveTo(batch.middlePoints[0].x, batch.middlePoints[0].y);
      for (int i = 1; i < batch.middlePoints.length; i++) {
        middlePath.lineTo(batch.middlePoints[i].x, batch.middlePoints[i].y);
      }
      canvas.drawPath(middlePath, borderPaint);

      // Draw lower line
      final lowerPath = widgets.Path();
      lowerPath.moveTo(batch.lowerPoints[0].x, batch.lowerPoints[0].y);
      for (int i = 1; i < batch.lowerPoints.length; i++) {
        lowerPath.lineTo(batch.lowerPoints[i].x, batch.lowerPoints[i].y);
      }
      canvas.drawPath(lowerPath, borderPaint);
    }
  }

  /// Render a line shape
  void _renderLineShape(LineShape shape) {
    try {
      final linePaint = widgets.Paint()
        ..color = _colorFromHex(shape.color)
        ..strokeWidth = shape.lineWidth
        ..style = widgets.PaintingStyle.stroke;

      // Apply dash pattern if specified
      if (shape.lineDash != null && shape.lineDash!.isNotEmpty) {
        // Flutter doesn't have built-in dash support in Paint
        // We'll draw it as solid for now (would need path_drawing package for true dashed lines)
        // TODO: Add path_drawing package and implement dashed lines
      }

      canvas.drawLine(
        widgets.Offset(shape.start.x, shape.start.y),
        widgets.Offset(shape.end.x, shape.end.y),
        linePaint,
      );
    } catch (e) {
      // Ignore if canvas is disposed
    }
  }

  /// Render a text shape
  void _renderTextShape(TextShape shape) {
    final textSpan = widgets.TextSpan(
      text: shape.text,
      style: widgets.TextStyle(
        color: _colorFromHex(shape.color),
        fontSize: _parseFontSize(shape.font),
        fontFamily: _parseFontFamily(shape.font),
      ),
    );

    final textPainter = widgets.TextPainter(
      text: textSpan,
      textAlign: _convertTextAlign(shape.align),
      textDirection: widgets.TextDirection.ltr,
    );

    textPainter.layout();

    // Calculate offset based on alignment and baseline
    final offset = _calculateTextOffset(
      shape.position,
      textPainter.size,
      shape.align,
      shape.baseline,
    );

    textPainter.paint(canvas, offset);
  }

  /// Render a boxed text shape (text with background box)
  void _renderBoxedTextShape(BoxedTextShape shape) {
    final textSpan = widgets.TextSpan(
      text: shape.text,
      style: widgets.TextStyle(
        color: _colorFromHex(shape.textColor),
        fontSize: _parseFontSize(shape.font),
        fontFamily: _parseFontFamily(shape.font),
      ),
    );

    final textPainter = widgets.TextPainter(
      text: textSpan,
      textAlign: _convertTextAlign(shape.align),
      textDirection: widgets.TextDirection.ltr,
    );

    textPainter.layout();

    // Calculate box dimensions with padding
    final boxWidth = textPainter.width + shape.padding * 2;
    final boxHeight = textPainter.height + shape.padding * 2;

    // Calculate box position based on alignment
    final boxOffset = _calculateBoxOffset(
      shape.position,
      widgets.Size(boxWidth, boxHeight),
      shape.align,
      shape.baseline,
    );

    // Draw background box
    final boxPaint = widgets.Paint()
      ..color = _colorFromHex(shape.backgroundColor)
      ..style = widgets.PaintingStyle.fill;

    canvas.drawRect(
      widgets.Rect.fromLTWH(boxOffset.dx, boxOffset.dy, boxWidth, boxHeight),
      boxPaint,
    );

    // Draw border if specified
    if (shape.borderColor != null) {
      final borderPaint = widgets.Paint()
        ..color = _colorFromHex(shape.borderColor!)
        ..style = widgets.PaintingStyle.stroke
        ..strokeWidth = 1;

      canvas.drawRect(
        widgets.Rect.fromLTWH(boxOffset.dx, boxOffset.dy, boxWidth, boxHeight),
        borderPaint,
      );
    }

    // Draw text on top of box
    textPainter.paint(
      canvas,
      widgets.Offset(boxOffset.dx + shape.padding, boxOffset.dy + shape.padding),
    );
  }

  /// Convert chartlib TextAlign enum to Flutter TextAlign
  widgets.TextAlign _convertTextAlign(TextAlign align) {
    switch (align) {
      case TextAlign.left:
        return widgets.TextAlign.left;
      case TextAlign.center:
        return widgets.TextAlign.center;
      case TextAlign.right:
        return widgets.TextAlign.right;
      case TextAlign.start:
        return widgets.TextAlign.start;
      case TextAlign.end:
        return widgets.TextAlign.end;
    }
  }

  /// Calculate text offset based on position, alignment, and baseline
  widgets.Offset _calculateTextOffset(
    Point position,
    widgets.Size textSize,
    TextAlign align,
    TextBaseline baseline,
  ) {
    double x = position.x;
    double y = position.y;

    // Adjust X based on alignment
    switch (align) {
      case TextAlign.left:
      case TextAlign.start:
        // No adjustment needed
        break;
      case TextAlign.center:
        x -= textSize.width / 2;
        break;
      case TextAlign.right:
      case TextAlign.end:
        x -= textSize.width;
        break;
    }

    // Adjust Y based on baseline
    switch (baseline) {
      case TextBaseline.top:
        // No adjustment needed
        break;
      case TextBaseline.middle:
        y -= textSize.height / 2;
        break;
      case TextBaseline.bottom:
        y -= textSize.height;
        break;
      case TextBaseline.alphabetic:
      case TextBaseline.hanging:
      case TextBaseline.ideographic:
        // Approximate as middle for now
        y -= textSize.height / 2;
        break;
    }

    return widgets.Offset(x, y);
  }

  /// Calculate box offset for BoxedTextShape
  widgets.Offset _calculateBoxOffset(
    Point position,
    widgets.Size boxSize,
    TextAlign align,
    TextBaseline baseline,
  ) {
    double x = position.x;
    double y = position.y;

    // Adjust X based on alignment
    switch (align) {
      case TextAlign.left:
      case TextAlign.start:
        // No adjustment needed
        break;
      case TextAlign.center:
        x -= boxSize.width / 2;
        break;
      case TextAlign.right:
      case TextAlign.end:
        x -= boxSize.width;
        break;
    }

    // Adjust Y based on baseline
    switch (baseline) {
      case TextBaseline.top:
        // No adjustment needed
        break;
      case TextBaseline.middle:
        y -= boxSize.height / 2;
        break;
      case TextBaseline.bottom:
        y -= boxSize.height;
        break;
      case TextBaseline.alphabetic:
      case TextBaseline.hanging:
      case TextBaseline.ideographic:
        // Approximate as middle for now
        y -= boxSize.height / 2;
        break;
    }

    return widgets.Offset(x, y);
  }

  /// Parse font size from CSS-style font string (e.g., "11px sans-serif")
  double _parseFontSize(String font) {
    final match = RegExp(r'(\d+)px').firstMatch(font);
    if (match != null) {
      return double.parse(match.group(1)!);
    }
    return 12.0; // Default font size
  }

  /// Parse font family from CSS-style font string
  String _parseFontFamily(String font) {
    // Extract font family after size (e.g., "11px sans-serif" -> "sans-serif")
    final parts = font.split(' ');
    if (parts.length > 1) {
      return parts.skip(1).join(' ');
    }
    return 'sans-serif'; // Default font family
  }

  /// Convert hex color string to Flutter Color
  ui.Color _colorFromHex(String hexString) {
    // DEFENSIVE: Handle case where Color.toString() was accidentally used
    // If string starts with "Color(", it's a Color().toString() output
    if (hexString.startsWith('Color(')) {
      // Extract RGB values from "Color(alpha: 1.0000, red: 0.1843, green: 0.2000, blue: 0.2118, ...)"
      final redMatch = RegExp(r'red:\s*([\d.]+)').firstMatch(hexString);
      final greenMatch = RegExp(r'green:\s*([\d.]+)').firstMatch(hexString);
      final blueMatch = RegExp(r'blue:\s*([\d.]+)').firstMatch(hexString);

      if (redMatch != null && greenMatch != null && blueMatch != null) {
        final red = (double.parse(redMatch.group(1)!) * 255).round();
        final green = (double.parse(greenMatch.group(1)!) * 255).round();
        final blue = (double.parse(blueMatch.group(1)!) * 255).round();
        return ui.Color.fromARGB(255, red, green, blue);
      }
      // Fallback to black if parsing fails
      return ui.Color(0xFF000000);
    }

    // Normal hex string parsing
    // Remove '#' if present
    var hex = hexString.replaceFirst('#', '');

    // Add alpha if not present (hex is 6 characters, RGB only)
    if (hex.length == 6) {
      hex = 'ff$hex';
    }

    // Parse and return Color
    return ui.Color(int.parse(hex, radix: 16));
  }
}
