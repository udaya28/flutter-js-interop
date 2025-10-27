/// ZoomManager handles zoom and pan operations for the chart
/// Ported from src/chartlib/chartcore/zoomManager.ts

import 'dart:math' as math;
import '../scale/common_scale_manager.dart';

/// ZoomManager handles zoom and pan operations for the chart.
///
/// CRITICAL BEHAVIOR:
/// - RIGHT-ANCHORED ZOOM: Most recent candle always stays visible on right edge
///   - endIndex stays FIXED during zoom
///   - startIndex changes (zooms to the LEFT)
/// - HORIZONTAL PAN ONLY: Pan is horizontal only (left/right movement)
///   - Both indices shift by same amount
/// - PRICE AUTO-UPDATES: Price axis recalculates from visible candles after zoom/pan
///
/// The caller (Chart or ChartController) is responsible for:
/// - Recalculating price scales from visible candles after zoom/pan
/// - Triggering a re-render after zoom/pan operations
class ZoomManager {
  ZoomManager(
    this._scaleManager, {
    this.minVisibleCandles = 10,
    this.maxVisibleCandles = 2500,
  });

  final CommonScaleManager _scaleManager;
  final double minVisibleCandles;
  final double maxVisibleCandles;

  /// Zoom in (show fewer candles, more detail).
  /// RIGHT-ANCHORED: endIndex stays fixed, startIndex increases.
  /// Supports smooth fractional zoom for continuous feel.
  void zoomIn({double factor = 1.2}) {
    final indices = _scaleManager.getVisibleDomainIndices();
    final startIndex = indices.startIndex;
    final endIndex = indices.endIndex;
    final visibleRange = endIndex - startIndex;

    // Remove floor for smooth zoom - allow fractional range
    final newVisibleRange = math.max(
      minVisibleCandles,
      visibleRange / factor,
    );

    // RIGHT-ANCHORED: endIndex stays fixed, startIndex changes
    final newStartIndex = endIndex - newVisibleRange;

    _scaleManager.updateTimeScale(newStartIndex, endIndex);
  }

  /// Zoom out (show more candles, less detail).
  /// RIGHT-ANCHORED: endIndex stays fixed, startIndex decreases.
  /// Supports smooth fractional zoom for continuous feel.
  void zoomOut({double factor = 1.2}) {
    final indices = _scaleManager.getVisibleDomainIndices();
    final startIndex = indices.startIndex;
    final endIndex = indices.endIndex;
    final visibleRange = endIndex - startIndex;

    // Remove floor for smooth zoom - allow fractional range
    final newVisibleRange = math.min(
      maxVisibleCandles,
      visibleRange * factor,
    );

    // RIGHT-ANCHORED: endIndex stays fixed, startIndex changes
    final newStartIndex = endIndex - newVisibleRange;

    _scaleManager.updateTimeScale(
      math.max(0, newStartIndex),
      endIndex,
    );
  }

  /// Pan horizontally (shift time axis left or right).
  /// HORIZONTAL ONLY: Both indices shift by same amount.
  /// Stops cleanly at boundaries without changing visible range.
  ///
  /// @param deltaCandles - Number of candles to pan (positive = right, negative = left)
  void pan(double deltaCandles) {
    final indices = _scaleManager.getVisibleDomainIndices();
    final startIndex = indices.startIndex;
    final endIndex = indices.endIndex;
    final fullLength = _scaleManager.timeScale.getFullDomain().length;
    final visibleRange = endIndex - startIndex;

    var newStartIndex = startIndex + deltaCandles;
    var newEndIndex = endIndex + deltaCandles;

    // Clamp to valid bounds - maintain exact visible range
    if (newStartIndex < 0) {
      newStartIndex = 0;
      newEndIndex = visibleRange; // Start from 0, maintain range
    }

    if (newEndIndex >= fullLength) {
      newEndIndex = (fullLength - 1).toDouble();
      newStartIndex = newEndIndex - visibleRange; // End at last candle, maintain range
    }

    // Only update if indices actually changed (avoid unnecessary updates at boundaries)
    if (newStartIndex != startIndex || newEndIndex != endIndex) {
      _scaleManager.updateTimeScale(newStartIndex, newEndIndex);
    }
  }

  /// Reset zoom to show all candles.
  /// Sets visible range to entire dataset.
  void resetZoom() {
    final fullLength = _scaleManager.timeScale.getFullDomain().length;
    _scaleManager.updateTimeScale(0, (fullLength - 1).toDouble());
  }

  /// Get current zoom level as a percentage.
  /// 100% = showing all candles, <100% = zoomed in, can't go >100%.
  ///
  /// Returns zoom level (0-100)
  double getZoomLevel() {
    final indices = _scaleManager.getVisibleDomainIndices();
    final visibleRange = indices.endIndex - indices.startIndex;
    final fullLength = _scaleManager.timeScale.getFullDomain().length;
    return (visibleRange / fullLength) * 100;
  }

  /// Check if can zoom in further.
  bool canZoomIn() {
    final indices = _scaleManager.getVisibleDomainIndices();
    final visibleRange = indices.endIndex - indices.startIndex;
    return visibleRange > minVisibleCandles;
  }

  /// Check if can zoom out further.
  bool canZoomOut() {
    final indices = _scaleManager.getVisibleDomainIndices();
    final visibleRange = indices.endIndex - indices.startIndex;
    return visibleRange < maxVisibleCandles;
  }

  /// Check if can pan left.
  bool canPanLeft() {
    final indices = _scaleManager.getVisibleDomainIndices();
    return indices.startIndex > 0;
  }

  /// Check if can pan right.
  bool canPanRight() {
    final indices = _scaleManager.getVisibleDomainIndices();
    final fullLength = _scaleManager.timeScale.getFullDomain().length;
    return indices.endIndex < fullLength - 1;
  }
}
