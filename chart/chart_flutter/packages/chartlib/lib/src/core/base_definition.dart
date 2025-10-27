/// Base chart definitions (size, padding, bounds, axis positions)
/// Ported from src/chartlib/chartcore/baseDefinition.ts

/// Chart dimensions
class ChartSize {
  const ChartSize({required this.width, required this.height});

  final double width;
  final double height;

  @override
  String toString() => 'ChartSize(width: $width, height: $height)';
}

/// Chart padding (margins around the chart area)
class ChartPadding {
  const ChartPadding({
    required this.top,
    required this.right,
    required this.bottom,
    required this.left,
  });

  factory ChartPadding.defaultPadding() {
    return const ChartPadding(
      top: 60,
      right: 60,
      bottom: 60,
      left: 60,
    );
  }

  final double top;
  final double right;
  final double bottom;
  final double left;

  @override
  String toString() =>
      'ChartPadding(top: $top, right: $right, bottom: $bottom, left: $left)';
}

/// Pane bounds (pixel coordinates).
/// Defines a rectangular region for rendering.
class Bounds {
  const Bounds({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  @override
  String toString() =>
      'Bounds(x: $x, y: $y, width: $width, height: $height)';
}

/// Calculate X range (horizontal pixel range for chart content)
(double, double) calcXRange(ChartSize chartSize, ChartPadding chartPadding) {
  // The X range is from left padding to width - right padding
  return (chartPadding.left, chartSize.width - chartPadding.right);
}

/// Calculate Y range (vertical pixel range for chart content)
(double, double) calcYRange(ChartSize chartSize, ChartPadding chartPadding) {
  // The Y range is from top padding to height - bottom padding
  return (chartPadding.top, chartSize.height - chartPadding.bottom);
}

/// Axis position enum
enum AxisPosition {
  top,
  right,
  bottom,
  left,
}
