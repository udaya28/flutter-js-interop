/// Manages all panes in the chart
/// Ported from src/chartlib/layout/paneManager.ts

import 'layout_types.dart';
import 'main_pane.dart';
import 'sub_pane.dart';
import 'dart:math' as math;

/// Manages all panes in the chart.
/// Broadcasts data updates to all panes and collects scale updates per pane.
class PaneManager {
  PaneManager(this._mainPane);

  /// Main pane (contains candle study + optional overlay studies)
  final MainPane _mainPane;

  /// Sub-panes (render in separate panes with custom scales)
  final List<SubPane> _subPanes = [];

  /// Add a sub-pane (separate pane with one or more studies).
  void addSubPane(SubPane subPane) {
    _subPanes.add(subPane);
  }

  /// Get main pane.
  MainPane getMainPane() => _mainPane;

  /// Get all sub-panes.
  List<SubPane> getSubPanes() => _subPanes;

  /// Update the last candle with new data (real-time tick update).
  /// Returns scale updates per pane.
  Map<String, ScaleDomainUpdate> updateLastCandle(List<OHLCData> allCandles) {
    final scaleUpdates = <String, ScaleDomainUpdate>{};

    // Update main pane (candle study + overlays)
    final mainUpdate = _collectMainPaneUpdates(
      (study) => study.updateLastCandle(allCandles),
    );
    if (mainUpdate != null) {
      scaleUpdates['main'] = mainUpdate;
    }

    // Update sub-panes (separate panes with custom scales)
    for (var i = 0; i < _subPanes.length; i++) {
      final update = _subPanes[i].updateLastCandle(allCandles);
      if (update != null) {
        scaleUpdates['subpane-$i'] = update;
      }
    }

    return scaleUpdates;
  }

  /// Append a new candle (new time period started).
  /// Returns scale updates per pane.
  Map<String, ScaleDomainUpdate> appendNewCandle(List<OHLCData> allCandles) {
    final scaleUpdates = <String, ScaleDomainUpdate>{};

    // Update main pane (candle study + overlays)
    final mainUpdate = _collectMainPaneUpdates(
      (study) => study.appendNewCandle(allCandles),
    );
    if (mainUpdate != null) {
      scaleUpdates['main'] = mainUpdate;
    }

    // Update sub-panes (separate panes with custom scales)
    for (var i = 0; i < _subPanes.length; i++) {
      final update = _subPanes[i].appendNewCandle(allCandles);
      if (update != null) {
        scaleUpdates['subpane-$i'] = update;
      }
    }

    return scaleUpdates;
  }

  /// Prepend historical candles (load more history).
  /// Returns scale updates per pane.
  Map<String, ScaleDomainUpdate> prependHistoricalCandles(
    List<OHLCData> allCandles,
  ) {
    final scaleUpdates = <String, ScaleDomainUpdate>{};

    // Update main pane (candle study + overlays)
    final mainUpdate = _collectMainPaneUpdates(
      (study) => study.prependHistoricalCandles(allCandles),
    );
    if (mainUpdate != null) {
      scaleUpdates['main'] = mainUpdate;
    }

    // Update sub-panes (separate panes with custom scales)
    for (var i = 0; i < _subPanes.length; i++) {
      final update = _subPanes[i].prependHistoricalCandles(allCandles);
      if (update != null) {
        scaleUpdates['subpane-$i'] = update;
      }
    }

    return scaleUpdates;
  }

  /// Reset all candles (full data reload).
  /// Returns scale updates per pane.
  Map<String, ScaleDomainUpdate> resetCandles(List<OHLCData> allCandles) {
    final scaleUpdates = <String, ScaleDomainUpdate>{};

    // Update main pane (candle study + overlays)
    final mainUpdate = _collectMainPaneUpdates(
      (study) => study.resetCandles(allCandles),
    );
    if (mainUpdate != null) {
      scaleUpdates['main'] = mainUpdate;
    }

    // Update sub-panes (separate panes with custom scales)
    for (var i = 0; i < _subPanes.length; i++) {
      final update = _subPanes[i].resetCandles(allCandles);
      if (update != null) {
        scaleUpdates['subpane-$i'] = update;
      }
    }

    return scaleUpdates;
  }

  /// Notification that scales have changed.
  /// Broadcasts to all studies (for shape cache clearing).
  void updateScales(bool timeScaleChanged, bool priceScaleChanged) {
    // Update main pane studies (candle + overlays)
    for (final study in _mainPane.allStudies) {
      study.updateScales(timeScaleChanged, priceScaleChanged);
    }

    // Update sub-panes (broadcasts to all studies in each pane)
    for (final subPane in _subPanes) {
      subPane.updateScales(timeScaleChanged, priceScaleChanged);
    }
  }

  /// Collect scale updates from main pane studies (candle + overlays).
  /// Merges all updates from main pane.
  ScaleDomainUpdate? _collectMainPaneUpdates(
    ScaleDomainUpdate? Function(Study<dynamic> study) updateFn,
  ) {
    final updates = <ScaleDomainUpdate>[];

    // Collect from all main pane studies (candle + overlays)
    for (final study in _mainPane.allStudies) {
      final update = updateFn(study);
      if (update != null) updates.add(update);
    }

    // Merge all updates
    if (updates.isEmpty) return null;
    return updates.reduce(_mergeDomainUpdates);
  }

  /// Merge two scale domain updates.
  /// Takes min of xDomain.min, max of xDomain.max, min of yDomain.min, max of yDomain.max.
  ScaleDomainUpdate _mergeDomainUpdates(
    ScaleDomainUpdate a,
    ScaleDomainUpdate b,
  ) {
    ({double min, double max})? xDomain;
    ({double min, double max})? yDomain;

    // Merge xDomain
    if (a.xDomain != null || b.xDomain != null) {
      final xMin = math.min(
        a.xDomain?.min ?? double.infinity,
        b.xDomain?.min ?? double.infinity,
      );
      final xMax = math.max(
        a.xDomain?.max ?? double.negativeInfinity,
        b.xDomain?.max ?? double.negativeInfinity,
      );
      if (xMin != double.infinity && xMax != double.negativeInfinity) {
        xDomain = (min: xMin, max: xMax);
      }
    }

    // Merge yDomain
    if (a.yDomain != null || b.yDomain != null) {
      final yMin = math.min(
        a.yDomain?.min ?? double.infinity,
        b.yDomain?.min ?? double.infinity,
      );
      final yMax = math.max(
        a.yDomain?.max ?? double.negativeInfinity,
        b.yDomain?.max ?? double.negativeInfinity,
      );
      if (yMin != double.infinity && yMax != double.negativeInfinity) {
        yDomain = (min: yMin, max: yMax);
      }
    }

    return ScaleDomainUpdate(xDomain: xDomain, yDomain: yDomain);
  }
}
