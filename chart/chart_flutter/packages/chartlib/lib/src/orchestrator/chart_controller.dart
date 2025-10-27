/// ChartController integrates all chart components and coordinates data flow.
/// Ported from src/chartwrapper/orchestrator/chartController.ts

import '../data/time_series_store.dart';
import '../data/render_batcher.dart';
import '../layout/pane_manager.dart';
import '../scale/common_scale_manager.dart';
import '../data/ohlc.dart';
import '../utils/performance_tracker.dart';

/// ChartController integrates all chart components and coordinates data flow.
///
/// Data flow:
/// 1. Data changes in TimeSeriesStore
/// 2. onChange callback → handle change type
/// 3. Update panes via PaneManager
/// 4. Receive scale domain updates per pane
/// 5. Apply updates to CommonScaleManager
/// 6. Notify panes that scales changed (clears shape caches)
/// 7. Request render via RenderBatcher (60fps throttle)
class ChartController {
  /// Time series data store
  final TimeSeriesStore timeSeriesStore;

  /// Render batcher for 60fps throttling
  final RenderBatcher renderBatcher;

  /// Pane manager coordinating all panes
  final PaneManager paneManager;

  /// Common scale manager (shared time + price scales)
  final CommonScaleManager commonScaleManager;

  /// Create a new ChartController.
  ChartController(
    this.timeSeriesStore,
    this.paneManager,
    this.commonScaleManager,
  ) : renderBatcher = RenderBatcher() {
    // Set up data change notification
    timeSeriesStore.setOnChange((changeType) => _handleDataChange(changeType));
  }

  /// Set the render callback.
  /// Called once per frame when render is requested.
  void setOnRender(void Function() callback) {
    renderBatcher.setOnRender(callback);
  }

  /// Load initial candle data.
  /// Triggers full study reset and render.
  void loadInitialData(List<OHLCData> candles) {
    timeSeriesStore.reset(candles);
    // onChange('reset') will be called automatically
  }

  /// Handle real-time update with new candle data.
  /// Automatically determines if this is an update or append.
  void handleRealtimeUpdate(OHLCData candle) {
    timeSeriesStore.add(candle);
    // onChange('update' or 'append') will be called automatically
  }

  /// Load more historical candles (user scrolled left).
  /// Triggers prepend and study recalculation.
  void loadMoreHistorical(List<OHLCData> historicalCandles) {
    timeSeriesStore.prepend(historicalCandles);
    // onChange('prepend') will be called automatically
  }

  /// Handle data change from TimeSeriesStore.
  /// Coordinates: data → panes → scales → render.
  void _handleDataChange(TimeSeriesChangeType changeType) {
    print('[ChartController._handleDataChange] changeType=$changeType');
    PerformanceTracker.start('update');
    final allCandles = timeSeriesStore.getAll();

    // Get visible range (for checking if updates affect visible area)
    final indices = commonScaleManager.getVisibleDomainIndices();
    final startIndex = indices.startIndex;
    final endIndex = indices.endIndex;

    // Save old full domain length for prepend calculation
    final oldDomainLength = commonScaleManager.timeScale.getFullDomain().length;

    // Update time scale domain if candles were added/removed
    if (changeType == TimeSeriesChangeType.append ||
        changeType == TimeSeriesChangeType.prepend ||
        changeType == TimeSeriesChangeType.reset) {
      final timestamps = allCandles.map((c) => c.timestamp).toList();

      // For append: pan time axis left by 1 if viewing rightmost candle
      if (changeType == TimeSeriesChangeType.append) {
        final wasViewingLatest =
            endIndex ==
            allCandles.length - 2; // Before append, last index was length - 2

        commonScaleManager.updateTimeScaleDomain(timestamps);

        // IMPORTANT: Tell panes about the new candle so studies can recalculate
        paneManager.updateLastCandle(allCandles);

        if (wasViewingLatest) {
          // Pan to show new candle while maintaining zoom
          commonScaleManager.updateTimeScale(startIndex + 1, endIndex + 1);

          // Recalculate price scale from new visible range
          recalculatePriceScalesFromVisibleCandles();
          PerformanceTracker.end('update', 'type=$changeType');
          return; // Price scale already updated and render requested
        } else {
          // Not viewing latest - just update time domain, don't change visible range or price scale
          // Just render with new data
          renderBatcher.requestRender();
          PerformanceTracker.end('update', 'type=$changeType (no recalc)');
          return;
        }
      } else if (changeType == TimeSeriesChangeType.prepend) {
        // For prepend: shift visible indices to account for new candles
        commonScaleManager.updateTimeScaleDomain(timestamps);
        final newDomainLength = allCandles.length;
        final prependedCount = newDomainLength - oldDomainLength;

        final newStartIndex = startIndex + prependedCount;
        final newEndIndex = endIndex + prependedCount;

        // Shift visible indices by prepended count to maintain view
        commonScaleManager.updateTimeScale(newStartIndex, newEndIndex);

        // IMPORTANT: Tell studies to recalculate with new candles
        paneManager.prependHistoricalCandles(allCandles);

        // Recalculate price scale from visible range (this also clears caches and renders)
        recalculatePriceScalesFromVisibleCandles();

        PerformanceTracker.end(
          'update',
          'type=$changeType, prepended=$prependedCount',
        );
        return; // Done - studies recalculated, price scale updated, render requested
      } else {
        // Reset case
        commonScaleManager.updateTimeScaleDomain(timestamps);
      }
    }

    // For 'update' changes: Always update studies, but only recalculate price scale if visible
    if (changeType == TimeSeriesChangeType.update) {
      final lastCandleIndex = allCandles.length - 1;
      final isLastCandleVisible =
          lastCandleIndex >= startIndex && lastCandleIndex <= endIndex;

      print(
        '[ChartController._handleDataChange] UPDATE - lastCandleIndex=$lastCandleIndex, visible=$isLastCandleVisible',
      );

      // Always update studies (e.g., LastPriceLineStudy needs last price even when not visible)
      paneManager.updateLastCandle(allCandles);
      print(
        '[ChartController._handleDataChange] UPDATE - paneManager.updateLastCandle() completed',
      );

      if (isLastCandleVisible) {
        // Last candle is visible - recalculate price scale in case high/low changed
        // IMPORTANT: Recalculate price scale from visible candles
        // This ensures scale expands if candle high/low extends beyond current range
        // TODO: Optimize this - only recalculate if new price extends beyond current scale range
        //       Currently recalculates on every update even if price is within range.
        //       Optimization: Check lastCandle.high/low against priceScale.domain, only
        //       recalculate if it exceeds bounds. Otherwise just requestRender().
        print(
          '[ChartController._handleDataChange] UPDATE - calling recalculatePriceScalesFromVisibleCandles()',
        );
        recalculatePriceScalesFromVisibleCandles();
        PerformanceTracker.end('update', 'type=$changeType');
      } else {
        // Last candle not visible - just render (e.g., for LastPriceLineStudy)
        // Skip price scale recalculation since visible candles haven't changed
        print(
          '[ChartController._handleDataChange] UPDATE - calling renderBatcher.requestRender()',
        );
        renderBatcher.requestRender();
        PerformanceTracker.end(
          'update',
          'type=$changeType (not visible, render only)',
        );
      }
      return;
    }

    // For 'reset': recalculate everything
    if (changeType == TimeSeriesChangeType.reset) {
      paneManager.resetCandles(allCandles);
      recalculatePriceScalesFromVisibleCandles();
      PerformanceTracker.end('update', 'type=$changeType');
      return;
    }
  }

  /// Recalculate price scales from visible candles.
  /// Called after zoom/pan operations.
  ///
  /// Steps:
  /// 1. Get visible candle indices from CommonScaleManager
  /// 2. Get visible candles from TimeSeriesStore
  /// 3. Calculate price domain from visible candles (all panes)
  /// 4. Update CommonScaleManager with new price domain
  /// 5. Notify panes that scales changed (clears shape caches)
  /// 6. Request render
  void recalculatePriceScalesFromVisibleCandles() {
    PerformanceTracker.start('recalculation');

    final allCandles = timeSeriesStore.getAll();
    if (allCandles.isEmpty) return;

    // Get visible indices
    final indices = commonScaleManager.getVisibleDomainIndices();

    // Guard against NaN or invalid indices
    if (indices.startIndex.isNaN ||
        indices.endIndex.isNaN ||
        indices.startIndex.isInfinite ||
        indices.endIndex.isInfinite) {
      return;
    }

    final rawStartIndex = indices.startIndex.floor();
    final rawEndIndex = indices.endIndex.ceil();

    final lastIndex = allCandles.length - 1;
    final int clampedStart = rawStartIndex.clamp(0, lastIndex);
    final int clampedEnd = rawEndIndex.clamp(clampedStart, lastIndex);

    final int endExclusive = (clampedEnd + 1).clamp(0, allCandles.length);

    // Get visible candles
    final visibleCandles = allCandles.sublist(clampedStart, endExclusive);
    if (visibleCandles.isEmpty) return;

    // Calculate price domain from visible candles (high/low)
    double priceMin = double.infinity;
    double priceMax = double.negativeInfinity;

    for (final candle in visibleCandles) {
      if (candle.high > priceMax) priceMax = candle.high;
      if (candle.low < priceMin) priceMin = candle.low;
    }

    // Add 2% padding to price range for better visibility
    final priceRange = priceMax - priceMin;
    final padding = priceRange * 0.02;
    priceMin -= padding;
    priceMax += padding;

    // Update price scale
    commonScaleManager.updatePriceScale(priceMin, priceMax);

    // Notify panes that scales changed (time scale changed, price scale changed)
    paneManager.updateScales(true, true);

    PerformanceTracker.end('recalculation', 'visible=${visibleCandles.length}');

    // Request render (render time tracked in renderer)
    renderBatcher.requestRender();
  }

  /// Clean up resources.
  void destroy() {
    renderBatcher.destroy();
  }
}
