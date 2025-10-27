/// Main chart pane containing candle study and overlay studies
/// Ported from src/chartlib/layout/mainPane.ts

import 'layout_types.dart';
import '../scale/common_scale_manager.dart';
import '../core/base_definition.dart';
import '../core/chart_context.dart';
import '../scale/numeric_axis.dart';
import '../scale/numeric_scale.dart';
import '../shapes/line.dart';

/// Main chart pane.
/// Contains candle study (required) and overlay studies (optional).
/// All studies share the commonScaleManager.mainPriceScale.
class MainPane {
  MainPane(
    ChartContext context,
    this.candleStudy,
  ) : priceAxis = NumericAxis(
          context,
          context.scales.priceScale,
          AxisPosition.right,
          8,
        );

  /// Candle study (always present - renders OHLC price data)
  final Study<dynamic> candleStudy;

  /// Overlay studies (0 or more - SMA, EMA, Bollinger Bands, etc.)
  final List<Study<dynamic>> overlayStudies = [];

  /// Calculated pane bounds (updated during layout recalculation)
  Bounds bounds = const Bounds(x: 0, y: 0, width: 0, height: 0);

  /// Price axis for this pane (right side)
  final NumericAxis priceAxis;

  /// Update pane bounds and scale ranges.
  /// Called during layout recalculation.
  void updateBounds(Bounds newBounds, NumericScale priceScale) {
    bounds = newBounds;
    priceScale.updateRange(newBounds.y, newBounds.y + newBounds.height);
  }

  /// Add an overlay study to the main pane.
  void addOverlayStudy(Study<dynamic> study) {
    overlayStudies.add(study);
  }

  /// Remove an overlay study from the main pane.
  void removeOverlayStudy(String studyId) {
    overlayStudies.removeWhere((s) => s.id == studyId);
  }

  /// Get all studies in the main pane (candles + overlays).
  List<Study<dynamic>> get allStudies => [candleStudy, ...overlayStudies];

  /// Render all studies in the main pane to a compositor.
  /// Renders candles first, then overlays on top.
  /// Studies render directly to compositor with zero allocations.
  /// Called by MultiPaneRenderer during render cycle.
  void renderTo(Compositor compositor, CommonScaleManager commonScaleManager) {
    // Render candles first
    candleStudy.renderTo(compositor, commonScaleManager, bounds);

    // Render overlays on top
    for (final overlay in overlayStudies) {
      overlay.renderTo(compositor, commonScaleManager, bounds);
    }
  }

  /// Render infrastructure elements (labels, text) that appear OVER y-axis.
  /// Called by MultiPaneRenderer after clearing clip region.
  /// Studies render directly to compositor with zero allocations.
  void renderInfrastructureTo(
    Compositor compositor,
    CommonScaleManager commonScaleManager,
  ) {
    // Render candle study infrastructure (if any)
    candleStudy.renderInfrastructureTo(compositor, commonScaleManager, bounds);

    // Render overlay study infrastructure (if any)
    for (final overlay in overlayStudies) {
      overlay.renderInfrastructureTo(compositor, commonScaleManager, bounds);
    }
  }

  /// Generate price axis grid line shapes.
  List<LineShape> generatePriceAxisGridShapes() {
    return priceAxis.generateGridShapes(bounds);
  }

  /// Generate price axis line shape.
  LineShape? generatePriceAxisLineShape() {
    return priceAxis.generateAxisLineShape(bounds);
  }

  /// Generate price axis label shapes.
  List<TextShape> generatePriceAxisLabelShapes() {
    return priceAxis.generateLabelShapes(bounds);
  }
}
