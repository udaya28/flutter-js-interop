/// Sub-pane container for studies with custom Y-scales
/// Ported from src/chartlib/layout/subPane.ts

import 'layout_types.dart';
import '../scale/common_scale_manager.dart';
import '../core/base_definition.dart';
import '../core/chart_context.dart';
import '../scale/numeric_axis.dart';
import '../scale/numeric_scale.dart';
import '../shapes/line.dart';

/// Sub-pane container for studies with custom Y-scales.
/// Wraps one or more studies and manages their layout, rendering, and scale synchronization.
class SubPane {
  SubPane(
    ChartContext context,
    this.id,
    this.primaryStudy,
    this.heightPercent, [
    List<Study<dynamic>>? otherStudies,
  ]) : otherStudies = otherStudies ?? [] {
    // Create price axis from primary study's Y-scale
    final yScale = primaryStudy.getYScale();
    if (yScale == null) {
      throw Exception('SubPane primary study must have a Y-scale');
    }
    priceAxis = NumericAxis(context, yScale, AxisPosition.right, 6);
  }

  /// Unique sub-panel identifier
  final String id;

  /// Layout bounds - set by MultiPaneRenderer during layout recalculation
  Bounds bounds = const Bounds(x: 0, y: 0, width: 0, height: 0);

  /// Height percentage relative to total chart height (0-1)
  final double heightPercent;

  /// Primary study (typically determines the sub-panel's purpose, e.g., Volume, RSI)
  final Study<dynamic> primaryStudy;

  /// Additional studies in this sub-panel (e.g., SMA overlay on volume)
  final List<Study<dynamic>> otherStudies;

  /// Price axis for this pane (right side)
  late final NumericAxis priceAxis;

  /// Get all studies in this sub-panel.
  List<Study<dynamic>> get allStudies => [primaryStudy, ...otherStudies];

  /// Update the last candle with new data (real-time tick update).
  /// Broadcasts to all studies and merges scale updates.
  ScaleDomainUpdate? updateLastCandle(List<OHLCData> allCandles) {
    final updates = allStudies
        .map((study) => study.updateLastCandle(allCandles))
        .where((update) => update != null)
        .cast<ScaleDomainUpdate>()
        .toList();

    return _mergeUpdates(updates);
  }

  /// Append a new candle (new time period started).
  /// Broadcasts to all studies and merges scale updates.
  ScaleDomainUpdate? appendNewCandle(List<OHLCData> allCandles) {
    final updates = allStudies
        .map((study) => study.appendNewCandle(allCandles))
        .where((update) => update != null)
        .cast<ScaleDomainUpdate>()
        .toList();

    return _mergeUpdates(updates);
  }

  /// Prepend historical candles (load more history).
  /// Broadcasts to all studies and merges scale updates.
  ScaleDomainUpdate? prependHistoricalCandles(List<OHLCData> allCandles) {
    final updates = allStudies
        .map((study) => study.prependHistoricalCandles(allCandles))
        .where((update) => update != null)
        .cast<ScaleDomainUpdate>()
        .toList();

    return _mergeUpdates(updates);
  }

  /// Reset all candles (full data reload).
  /// Broadcasts to all studies and merges scale updates.
  ScaleDomainUpdate? resetCandles(List<OHLCData> allCandles) {
    final updates = allStudies
        .map((study) => study.resetCandles(allCandles))
        .where((update) => update != null)
        .cast<ScaleDomainUpdate>()
        .toList();

    return _mergeUpdates(updates);
  }

  /// Notification that scales have changed.
  /// Broadcasts to all studies (for shape cache clearing).
  void updateScales(bool timeScaleChanged, bool priceScaleChanged) {
    for (final study in allStudies) {
      study.updateScales(timeScaleChanged, priceScaleChanged);
    }
  }

  /// Update pane bounds and scale ranges.
  /// Called during layout recalculation.
  void updateBounds(Bounds newBounds) {
    bounds = newBounds;
    _applyBoundsToScales();
  }

  /// Apply pane bounds to study scales.
  /// Updates the pixel ranges of all wrapped studies' custom Y-scales.
  /// Called by updateBounds() during layout recalculation.
  void _applyBoundsToScales() {
    for (final study in allStudies) {
      study.updateScaleBounds(bounds);
    }
  }

  /// Get the Y-scale for this sub-pane (from primary study).
  /// Used for rendering the sub-pane's price axis.
  NumericScale? getYScale() {
    return primaryStudy.getYScale();
  }

  /// Render all studies in this sub-panel to a compositor.
  /// Studies render directly to compositor with zero allocations.
  /// Called by MultiPaneRenderer during render cycle.
  void renderTo(Compositor compositor, CommonScaleManager commonScaleManager) {
    for (final study in allStudies) {
      study.renderTo(compositor, commonScaleManager, bounds);
    }
  }

  /// Render infrastructure elements (labels, text) that appear OVER y-axis.
  /// Called by MultiPaneRenderer after clearing clip region.
  /// Studies render directly to compositor with zero allocations.
  void renderInfrastructureTo(
    Compositor compositor,
    CommonScaleManager commonScaleManager,
  ) {
    for (final study in allStudies) {
      study.renderInfrastructureTo(compositor, commonScaleManager, bounds);
    }
  }

  /// Merge scale updates from multiple studies.
  /// Takes min of all xDomain.min, max of all xDomain.max,
  /// min of all yDomain.min, max of all yDomain.max.
  ScaleDomainUpdate? _mergeUpdates(List<ScaleDomainUpdate> updates) {
    if (updates.isEmpty) return null;

    ({double min, double max})? xDomain;
    ({double min, double max})? yDomain;

    // Merge xDomain (time domain)
    final xDomains = updates.where((u) => u.xDomain != null).map((u) => u.xDomain!).toList();
    if (xDomains.isNotEmpty) {
      final xMin = xDomains.map((d) => d.min).reduce((a, b) => a < b ? a : b);
      final xMax = xDomains.map((d) => d.max).reduce((a, b) => a > b ? a : b);
      xDomain = (min: xMin, max: xMax);
    }

    // Merge yDomain (price/value domain)
    final yDomains = updates.where((u) => u.yDomain != null).map((u) => u.yDomain!).toList();
    if (yDomains.isNotEmpty) {
      final yMin = yDomains.map((d) => d.min).reduce((a, b) => a < b ? a : b);
      final yMax = yDomains.map((d) => d.max).reduce((a, b) => a > b ? a : b);
      yDomain = (min: yMin, max: yMax);
    }

    return (xDomain != null || yDomain != null)
        ? ScaleDomainUpdate(xDomain: xDomain, yDomain: yDomain)
        : null;
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
