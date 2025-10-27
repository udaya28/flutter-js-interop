/// Base axis class for rendering axes, grid lines, and labels
/// Ported from src/chartlib/scale/axis.ts

import 'dart:ui';
import 'scale.dart';
import '../core/base_definition.dart';
import '../core/chart_context.dart';
import '../shapes/line.dart';

/// Convert dart:ui Color to hex string (e.g., "#2f2f2f")
String _colorToHex(Color color) {
  final hex = color.value.toRadixString(16).padLeft(8, '0');
  return '#${hex.substring(2)}'; // Skip alpha bytes (AARRGGBB -> RRGGBB)
}

/// Axis configuration options
class AxisOptions {
  const AxisOptions({
    this.tickLength = 6,
    this.tickLabelOffset = 8,
    this.showGrid = true,
    this.showLabels = true,
  });

  final double tickLength;
  final double tickLabelOffset;
  final bool showGrid;
  final bool showLabels;

  AxisOptions copyWith({
    double? tickLength,
    double? tickLabelOffset,
    bool? showGrid,
    bool? showLabels,
  }) {
    return AxisOptions(
      tickLength: tickLength ?? this.tickLength,
      tickLabelOffset: tickLabelOffset ?? this.tickLabelOffset,
      showGrid: showGrid ?? this.showGrid,
      showLabels: showLabels ?? this.showLabels,
    );
  }
}

/// Default axis options
AxisOptions getDefaultAxisOptions() {
  return const AxisOptions();
}

/// Tick information containing value, position, and label
class TickInfo<T> {
  const TickInfo({
    required this.value,
    required this.scaledPosition,
    this.label,
  });

  final T value;
  final double scaledPosition;
  final String? label;
}

/// Base abstract class for chart axes
abstract class Axis<T> {
  Axis(
    this.context,
    this.scale,
    this.position, [
    AxisOptions? options,
  ]) : options = options ?? getDefaultAxisOptions();

  final ChartContext context;
  Scale<T> scale;
  final AxisPosition position;
  AxisOptions options;

  /// Abstract method to generate tick values for the axis
  List<TickInfo<T>> generateTicks();

  /// Generate grid line shapes for multi-pane charts.
  /// Returns array of LineShapes for grid lines.
  List<LineShape> generateGridShapes(Bounds bounds) {
    if (!options.showGrid) return [];

    final xRange = (bounds.x, bounds.x + bounds.width);
    final yRange = (bounds.y, bounds.y + bounds.height);
    final ticks = generateTicks();
    final shapes = <LineShape>[];

    for (final tick in ticks) {
      if (_isHorizontalAxis()) {
        // Vertical grid lines for horizontal axes
        shapes.add(LineShape(
          start: Point(tick.scaledPosition, yRange.$1),
          end: Point(tick.scaledPosition, yRange.$2),
          color: _colorToHex(context.config.theme.colors.gridColor),
          lineWidth: 1,
        ));
      } else {
        // Horizontal grid lines for vertical axes
        shapes.add(LineShape(
          start: Point(xRange.$1, tick.scaledPosition),
          end: Point(xRange.$2, tick.scaledPosition),
          color: _colorToHex(context.config.theme.colors.gridColor),
          lineWidth: 1,
        ));
      }
    }

    return shapes;
  }

  /// Generate axis line shape for multi-pane charts.
  /// Returns LineShape for the axis border line.
  LineShape? generateAxisLineShape(Bounds bounds) {
    final baseColor = _colorToHex(context.config.theme.colors.tickColor);

    switch (position) {
      case AxisPosition.bottom:
        return LineShape(
          start: Point(bounds.x, bounds.y + bounds.height),
          end: Point(bounds.x + bounds.width, bounds.y + bounds.height),
          color: baseColor,
          lineWidth: 1,
        );
      case AxisPosition.top:
        return LineShape(
          start: Point(bounds.x, bounds.y),
          end: Point(bounds.x + bounds.width, bounds.y),
          color: baseColor,
          lineWidth: 1,
        );
      case AxisPosition.left:
        return LineShape(
          start: Point(bounds.x, bounds.y),
          end: Point(bounds.x, bounds.y + bounds.height),
          color: baseColor,
          lineWidth: 1,
        );
      case AxisPosition.right:
        return LineShape(
          start: Point(bounds.x + bounds.width, bounds.y),
          end: Point(bounds.x + bounds.width, bounds.y + bounds.height),
          color: baseColor,
          lineWidth: 1,
        );
    }
  }

  /// Generate label shapes for multi-pane charts.
  /// Returns array of TextShapes for axis labels.
  List<TextShape> generateLabelShapes(Bounds bounds) {
    if (!options.showLabels) return [];

    final xRange = (bounds.x, bounds.x + bounds.width);
    final yRange = (bounds.y, bounds.y + bounds.height);
    final ticks = generateTicks();
    final shapes = <TextShape>[];

    final alignment = _getTextAlignment();

    for (final tick in ticks) {
      if (tick.label != null) {
        // Only add labels for positions within bounds
        if (_isHorizontalAxis()) {
          if (tick.scaledPosition < xRange.$1 || tick.scaledPosition > xRange.$2) {
            continue;
          }
        } else {
          if (tick.scaledPosition < yRange.$1 || tick.scaledPosition > yRange.$2) {
            continue;
          }
        }

        final labelPos = _getLabelPositionWithBounds(tick.scaledPosition, bounds);
        shapes.add(TextShape(
          position: labelPos,
          text: tick.label!,
          color: _colorToHex(context.config.theme.colors.tickLabelColor),
          font: context.config.theme.typography.axisFont,
          align: alignment.textAlign,
          baseline: alignment.textBaseline,
        ));
      }
    }

    return shapes;
  }

  /// Updates the axis scale
  void updateScale(Scale<T> newScale) {
    scale = newScale;
  }

  /// Updates axis options
  void updateOptions(AxisOptions newOptions) {
    options = options.copyWith(
      tickLength: newOptions.tickLength,
      tickLabelOffset: newOptions.tickLabelOffset,
      showGrid: newOptions.showGrid,
      showLabels: newOptions.showLabels,
    );
  }

  bool _isHorizontalAxis() {
    return position == AxisPosition.top || position == AxisPosition.bottom;
  }

  Point _getLabelPositionWithBounds(double scaledPosition, Bounds bounds) {
    final xRange = (bounds.x, bounds.x + bounds.width);
    final yRange = (bounds.y, bounds.y + bounds.height);
    final offset = options.tickLength + options.tickLabelOffset;

    switch (position) {
      case AxisPosition.bottom:
        return Point(scaledPosition, yRange.$2 + offset);
      case AxisPosition.top:
        return Point(scaledPosition, yRange.$1 - offset);
      case AxisPosition.left:
        return Point(xRange.$1 - offset, scaledPosition);
      case AxisPosition.right:
        return Point(xRange.$2 + offset, scaledPosition);
    }
  }

  ({TextAlign textAlign, TextBaseline textBaseline}) _getTextAlignment() {
    switch (position) {
      case AxisPosition.bottom:
        return (textAlign: TextAlign.center, textBaseline: TextBaseline.top);
      case AxisPosition.top:
        return (textAlign: TextAlign.center, textBaseline: TextBaseline.bottom);
      case AxisPosition.left:
        return (textAlign: TextAlign.right, textBaseline: TextBaseline.middle);
      case AxisPosition.right:
        return (textAlign: TextAlign.left, textBaseline: TextBaseline.middle);
    }
  }
}
