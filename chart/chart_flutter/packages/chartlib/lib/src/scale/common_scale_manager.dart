/// CommonScaleManager manages the truly shared scales across chart regions
/// Ported from src/chartlib/scale/commonScaleManager.ts

import 'ordinal_time_scale.dart';
import 'numeric_scale.dart';
import 'scale_manager.dart';

/// CommonScaleManager manages the truly shared scales across chart regions.
///
/// Shared scales:
/// - Time scale (X-axis) - shared by ALL regions (main chart + sub-panels)
/// - Price scale (Y-axis) - shared by main chart + overlay studies (SMA, EMA, etc.)
///
/// NOT shared:
/// - Sub-panel Y-axes (Volume, RSI, MACD) - each study manages its own scale
///
/// IMPORTANT: Uses OrdinalTimeScale (discrete) NOT ContinuousTimeScale because:
/// - Markets are closed on weekends/holidays (gaps in time)
/// - Markets have trading hours (intraday gaps)
/// - Candles are evenly spaced by index, not by actual time
class CommonScaleManager {
  CommonScaleManager({
    required List<DateTime> timeData,
    required double canvasWidth,
    required double canvasHeight,
    required double priceMin,
    required double priceMax,
    double initialVisibleStart = 0,
    double? initialVisibleEnd,
  })  : timeScale = OrdinalTimeScale(
          fullDomain: timeData,
          rangeMin: 0,
          rangeMax: canvasWidth,
          startIndex: initialVisibleStart,
          endIndex: initialVisibleEnd,
        ),
        priceScale = NumericScale(
          domainMin: priceMin,
          domainMax: priceMax,
          rangeMin: 0,
          rangeMax: canvasHeight,
          inverted: true, // Inverted for canvas (Y-axis goes down)
        );

  /// Shared time scale used by all regions (discrete/ordinal for market gaps).
  /// OrdinalTimeScale manages the full domain and visible range internally.
  OrdinalTimeScale timeScale;

  /// Shared price scale used by main chart and overlay studies
  NumericScale priceScale;

  /// Creates a ScaleManager for the main chart region.
  /// Uses the shared time and price scales.
  ScaleManager<DateTime, double> createMainChartScaleManager() {
    return ScaleManager(timeScale, priceScale);
  }

  /// Updates the visible time range (affects ALL regions).
  /// This is called during zoom/pan operations.
  ///
  /// IMPORTANT: Zoom/pan behavior requirements:
  /// - RIGHT-ANCHORED ZOOM: endIndex stays fixed, startIndex changes
  /// - HORIZONTAL PAN: both indices shift by same amount
  /// - Price scales should be recalculated after this (from visible candles)
  void updateTimeScale(double startIndex, double endIndex) {
    // Delegate to OrdinalTimeScale - no recreation needed
    timeScale.updateVisibleDomainIndices(startIndex, endIndex);
  }

  /// Updates the shared price scale domain.
  /// Called after zoom/pan when price domain needs to be recalculated from visible candles.
  void updatePriceScale(double min, double max) {
    priceScale.updateDomain(min, max);
  }

  /// Gets the current visible domain indices.
  /// Delegates to OrdinalTimeScale.
  ({double startIndex, double endIndex}) getVisibleDomainIndices() {
    return timeScale.getVisibleDomainIndices();
  }

  /// Updates the time scale domain with new timestamps.
  /// Called when candles are appended or prepended.
  void updateTimeScaleDomain(List<DateTime> newTimeData) {
    timeScale.updateFullDomain(newTimeData);
  }

  /// Updates the canvas dimensions (e.g., on window resize).
  /// Updates pixel ranges for scales.
  void updateCanvasDimensions(double width, {double? height}) {
    timeScale.updateRange(0, width);

    if (height != null) {
      priceScale.updateRange(0, height);
    }
  }
}
