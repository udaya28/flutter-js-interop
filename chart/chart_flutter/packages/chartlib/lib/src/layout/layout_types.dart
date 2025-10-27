/// Placeholder types for layout system dependencies
/// These will be replaced when we port the full rendering system

import '../core/base_definition.dart';

export '../core/base_definition.dart';
export '../data/ohlc.dart';
export '../studies/base_study.dart';

/// Scale domain update for studies
class ScaleDomainUpdate {
  ScaleDomainUpdate({this.xDomain, this.yDomain});

  final ({double min, double max})? xDomain;
  final ({double min, double max})? yDomain;
}

/// Placeholder for Compositor (will be ported from rendering/compositor.ts)
/// This is the rendering backend abstraction
abstract class Compositor {
  /// Setup high-DPI canvas
  void setupHighDPI(double width, double height);

  /// Clear canvas
  void clear();

  /// Render a shape batch to the compositor
  void render(dynamic shapeBatch);

  /// Render multiple shapes
  void renderShapes(List<dynamic> shapes);

  /// Set clip region for rendering
  void setClipRegion(Bounds bounds);

  /// Clear clip region
  void clearClipRegion();

  /// Draw border
  void drawBorder(Bounds bounds);
}
