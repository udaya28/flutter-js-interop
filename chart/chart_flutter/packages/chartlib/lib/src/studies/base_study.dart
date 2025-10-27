/// Abstract base class for all chart studies/indicators.
/// Studies own their data and handle their own calculations.
/// Ported from src/chartlib/studies/baseStudy.ts

import '../scale/common_scale_manager.dart';
import '../layout/layout_types.dart';
import '../core/base_definition.dart';
import '../scale/numeric_scale.dart';

/// Abstract base class for all chart studies/indicators.
/// Studies own their data and handle their own calculations.
///
/// Implementations should extend either InstantStudy or WindowedStudy
/// unless they have special requirements.
///
/// Note: Study placement (overlay vs subpane) is determined by which array
/// the study is added to (overlayStudies[] vs subPaneStudies[]).
///
/// @template TBatchPoint - The batch point type (Point, CandlePoint, etc.)
abstract class Study<TBatchPoint> {
  Study(this.id, this.name);

  /// Unique identifier for this study instance
  final String id;

  /// Display name for this study
  final String name;

  /// Whether this study is currently enabled
  bool enabled = true;

  /// Update the last candle with new data (real-time tick update).
  /// Called when the current candle is still forming.
  ///
  /// @param allCandles - Complete candle dataset with updated last candle
  /// @returns Scale domain update if bounds changed, null otherwise
  ScaleDomainUpdate? updateLastCandle(List<OHLCData> allCandles);

  /// Append a new candle (new time period started).
  /// Called when a new candle period begins.
  ///
  /// @param allCandles - Complete candle dataset with new candle appended
  /// @returns Scale domain update if bounds changed, null otherwise
  ScaleDomainUpdate? appendNewCandle(List<OHLCData> allCandles);

  /// Prepend historical candles (load more history).
  /// Called when user scrolls back and more historical data is loaded.
  ///
  /// @param allCandles - Complete candle dataset with historical candles prepended
  /// @returns Scale domain update if bounds changed, null otherwise
  ScaleDomainUpdate? prependHistoricalCandles(List<OHLCData> allCandles);

  /// Reset all candles (full data reload).
  /// Called when entire dataset is replaced.
  ///
  /// @param allCandles - Complete new candle dataset
  /// @returns Scale domain update if bounds changed, null otherwise
  ScaleDomainUpdate? resetCandles(List<OHLCData> allCandles);

  /// Notification that scales have changed (zoom/pan or price range update).
  /// Studies should clear their shape cache when scales change.
  ///
  /// @param timeScaleChanged - True if time scale changed (zoom/pan)
  /// @param priceScaleChanged - True if price scale changed (new data or bounds update)
  void updateScales(bool timeScaleChanged, bool priceScaleChanged);

  /// Update scale pixel ranges based on pane bounds.
  /// Called by SubPane when pane bounds change during layout recalculation.
  ///
  /// Default implementation does nothing (main pane studies use commonScaleManager.mainPriceScale).
  /// Sub-pane studies should override to update their custom Y-scale pixel ranges.
  ///
  /// @param bounds - New pane bounds with pixel coordinates
  void updateScaleBounds(Bounds bounds) {
    // Default: no-op (main pane studies don't manage their own scale ranges)
  }

  /// Get the custom Y-scale for this study (if any).
  /// Main pane studies use commonScaleManager.priceScale and return null.
  /// Sub-pane studies with custom Y-scales should override this.
  ///
  /// @returns NumericScale if study has custom Y-scale, null otherwise
  NumericScale? getYScale() {
    return null;
  }

  /// Render the study to a compositor.
  /// Called on every frame. Studies should use cache for performance.
  ///
  /// This method renders directly to the compositor without allocating arrays.
  /// The compositor handles immediate rendering based on batch type.
  ///
  /// @param compositor - Compositor to render to (Canvas2D, PixiJS, etc.)
  /// @param commonScales - Common scale manager with shared time + price scales
  /// @param bounds - Pane bounds for rendering
  void renderTo(
    Compositor compositor,
    CommonScaleManager commonScales,
    Bounds bounds,
  );

  /// Render infrastructure elements (labels, text) that should appear OVER y-axis labels.
  /// Called after renderTo() with clip region cleared.
  ///
  /// Use this for value labels that should overlap the y-axis area (e.g., last price label,
  /// Bollinger Bands values, indicator levels).
  ///
  /// Default implementation does nothing. Studies that need to render over y-axis should override.
  ///
  /// @param compositor - Compositor to render to (Canvas2D, PixiJS, etc.)
  /// @param commonScales - Common scale manager with shared time + price scales
  /// @param bounds - Pane bounds for rendering
  void renderInfrastructureTo(
    Compositor compositor,
    CommonScaleManager commonScales,
    Bounds bounds,
  ) {
    // Default: no-op
  }
}
