/// Line shape definitions
/// Ported from src/chartlib/shapes/line.ts and shapes/text.ts

class Point {
  const Point(this.x, this.y);

  final double x;
  final double y;

  @override
  String toString() => 'Point($x, $y)';
}

class LineSegment {
  const LineSegment(this.start, this.end);

  final Point start;
  final Point end;

  @override
  String toString() => 'LineSegment($start -> $end)';
}

class Polyline {
  const Polyline(this.points);

  final List<Point> points;

  @override
  String toString() => 'Polyline(${points.length} points)';
}

/// LineShape for rendering lines with color and width
class LineShape {
  const LineShape({
    required this.start,
    required this.end,
    required this.color,
    required this.lineWidth,
    this.lineDash,
  });

  final Point start;
  final Point end;
  final String color; // Hex color string
  final double lineWidth;
  final List<double>? lineDash; // Optional dash pattern [dash, gap, ...]
}

/// TextAlign enum matching Canvas text alignment
enum TextAlign {
  left,
  center,
  right,
  start,
  end,
}

/// TextBaseline enum matching Canvas text baseline
enum TextBaseline {
  top,
  middle,
  bottom,
  alphabetic,
  hanging,
  ideographic,
}

/// TextShape for rendering text labels
class TextShape {
  const TextShape({
    required this.position,
    required this.text,
    required this.color,
    required this.font,
    required this.align,
    required this.baseline,
  });

  final Point position;
  final String text;
  final String color; // Hex color string
  final String font; // CSS-style font string
  final TextAlign align;
  final TextBaseline baseline;
}

/// BoxedTextShape for rendering text with background box (like price labels)
class BoxedTextShape {
  const BoxedTextShape({
    required this.position,
    required this.text,
    required this.textColor,
    required this.backgroundColor,
    this.borderColor,
    required this.font,
    required this.padding,
    required this.align,
    required this.baseline,
    this.lineDash,
  });

  final Point position;
  final String text;
  final String textColor; // Hex color string
  final String backgroundColor; // Hex color string
  final String? borderColor; // Optional border color
  final String font; // CSS-style font string
  final double padding; // Padding around text (all sides)
  final TextAlign align; // Text alignment
  final TextBaseline baseline;
  final List<double>? lineDash; // Optional dash pattern for border
}
