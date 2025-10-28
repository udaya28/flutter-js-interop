/// High-level Chart API.
/// Owns and coordinates all chart components.
/// Ported from src/chartwrapper/orchestrator/chart.ts

import '../core/base_definition.dart';
import '../core/chart_context.dart';
import '../data/ohlc.dart';
import '../studies/base_study.dart';
import '../data/data_manager.dart';
import '../layout/main_pane.dart';
import '../layout/sub_pane.dart';
import '../layout/pane_manager.dart';
import '../scale/common_scale_manager.dart';
import '../data/time_series_store.dart';
import '../scale/time_axis.dart';
import '../core/zoom_manager.dart';
import '../layout/layout_types.dart'; // Compositor
import '../theme/types.dart';
import 'chart_controller.dart';
import 'multi_pane_renderer.dart';

/// High-level Chart API.
/// Owns and coordinates all chart components.
///
/// Responsibilities:
/// - Create and wire together: CommonScaleManager, PaneManager, ChartController, MultiPaneRenderer
/// - Provide clean public API for chart operations
/// - Manage component lifecycle
class Chart {
  // Shared context (renderer-agnostic configuration)
  late final ChartContext context;

  // Core infrastructure (owned)
  late final PaneManager paneManager;
  late final TimeSeriesStore timeSeriesStore;
  late final TimeAxis timeAxis;

  // Orchestrators (owned)
  late final ChartController chartController;
  late final MultiPaneRenderer multiPaneRenderer;
  late final ZoomManager zoomManager;

  // Data manager for async data loading
  final DataManager dataManager;
  bool hasMoreHistorical = true;
  bool isLoadingMore = false;

  /// Threshold: Load more historical data when within this many candles of start
  static const int loadMoreThreshold = 20;

  /// Create a new Chart.
  ///
  /// Creates and wires together all chart components:
  /// 1. CommonScaleManager (shared time + price scales)
  /// 2. ChartContext (config + scales)
  /// 3. MainPane + PaneManager (pane structure)
  /// 4. TimeSeriesStore (data storage)
  /// 5. TimeAxis (shared time axis)
  /// 6. ChartController (data flow orchestrator)
  /// 7. MultiPaneRenderer (layout/rendering orchestrator)
  /// 8. ZoomManager (zoom/pan operations)
  Chart({
    required ChartSize chartSize,
    required ChartPadding chartPadding,
    required ChartTheme theme,
    required Study<dynamic> candleStudy,
    required this.dataManager,
    required Compositor compositor,
  }) {
    // print('[Chart] Constructor started');
    // print('[Chart] chartSize: ${chartSize.width}x${chartSize.height}, padding: L${chartPadding.left} R${chartPadding.right} T${chartPadding.top} B${chartPadding.bottom}');

    // 1. Create shared infrastructure - CommonScaleManager
    final canvasWidth =
        chartSize.width - chartPadding.left - chartPadding.right;
    final canvasHeight =
        chartSize.height - chartPadding.top - chartPadding.bottom;

    // print('[Chart] canvasWidth=$canvasWidth, canvasHeight=$canvasHeight');

    final commonScaleManager = CommonScaleManager(
      timeData: [], // Empty - data loaded in initialize()
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
      priceMin: 0,
      priceMax: 100, // Placeholder price range (will be updated by studies)
      initialVisibleStart: 0,
      initialVisibleEnd: 0,
    );

    // print('[Chart] CommonScaleManager created');

    // 2. Create shared context (renderer-agnostic)
    context = ChartContext(
      config: ChartConfig(size: chartSize, padding: chartPadding, theme: theme),
      scales: commonScaleManager,
    );

    // 3. Create pane structure
    final mainPane = MainPane(context, candleStudy);
    paneManager = PaneManager(mainPane);

    // 4. Create time series store
    timeSeriesStore = TimeSeriesStore();

    // 5. Create time axis (shared across all panes)
    timeAxis = TimeAxis(
      context,
      context.scales.timeScale,
      AxisPosition.bottom,
      10, // Show every 10th time value
    );

    // 6. Create data flow orchestrator (ChartController)
    chartController = ChartController(
      timeSeriesStore,
      paneManager,
      commonScaleManager,
    );

    // 7. Create layout/rendering orchestrator (MultiPaneRenderer)
    multiPaneRenderer = MultiPaneRenderer(
      context,
      compositor,
      paneManager,
      timeAxis,
    );

    // 8. Create zoom manager (uses defaults: min 10, max 2500 candles)
    zoomManager = ZoomManager(commonScaleManager);

    // 9. Wire them together: data updates trigger renders
    chartController.setOnRender(() {
      multiPaneRenderer.render();
    });

    // 10. Register realtime callback with DataManager
    dataManager.onRealtimeUpdate((candle) {
      _handleRealtimeUpdate(candle);
    });
  }

  /// Initialize chart with data from DataManager.
  /// Must be called after construction, before rendering.
  /// Loads initial historical data and sets up realtime updates.
  Future<void> initialize() async {
    // print('[Chart.initialize] Starting initialization');

    // Wait for compositor initialization (PixiJS is async)
    await multiPaneRenderer.waitForInit();
    // print('[Chart.initialize] Compositor ready');

    // Load initial batch of historical data
    final batch = await dataManager.loadHistorical();
    hasMoreHistorical = batch.hasMore;

    // print(
    //   '[Chart.initialize] Loaded ${batch.candles.length} candles, hasMore=${batch.hasMore}',
    // );

    // Load into chart
    chartController.loadInitialData(batch.candles);

    // Set visible range to show last ~120 candles (or all if fewer)
    final totalCandles = batch.candles.length;

    // print('[Chart.initialize] totalCandles=$totalCandles');

    // Only set up scales if we have data
    if (totalCandles > 0) {
      const defaultVisibleCandles = 120;
      final startIndex = (totalCandles - defaultVisibleCandles).clamp(
        0,
        totalCandles - 1,
      );
      final endIndex = totalCandles - 1;

      // print(
      //   '[Chart.initialize] Setting visible range: startIndex=$startIndex, endIndex=$endIndex',
      // );

      context.scales.updateTimeScale(
        startIndex.toDouble(),
        endIndex.toDouble(),
      );
      chartController.recalculatePriceScalesFromVisibleCandles();
    }

    // print('[Chart.initialize] Initialization complete');
  }

  /// Handle real-time update (called by DataManager).
  void _handleRealtimeUpdate(OHLCData candle) {
    chartController.handleRealtimeUpdate(candle);
  }

  /// Add an overlay study to the main pane.
  void addOverlayStudy(Study<dynamic> study) {
    final mainPane = paneManager.getMainPane();
    mainPane.addOverlayStudy(study);
  }

  /// Create and add a sub-pane (Volume, RSI, MACD, etc.).
  /// Triggers layout recalculation.
  void createSubPane({
    required String id,
    required Study<dynamic> primaryStudy,
    required double heightPercent,
    List<Study<dynamic>> otherStudies = const [],
  }) {
    final subPane = SubPane(
      context,
      id,
      primaryStudy,
      heightPercent,
      otherStudies,
    );
    multiPaneRenderer.addSubPane(subPane);
  }

  /// Update chart theme.
  /// Components read theme from context during render, so no propagation needed.
  void updateTheme(ChartTheme theme) {
    // Update context (all components read from this)
    context.config = context.config.copyWith(theme: theme);

    // Trigger render to apply new theme
    multiPaneRenderer.render();
  }

  /// Resize chart.
  /// Triggers layout recalculation and render.
  void resize(ChartSize chartSize) {
    // Update context
    context.config = context.config.copyWith(size: chartSize);

    // Trigger layout recalculation and render
    multiPaneRenderer.recalculateLayout();
    multiPaneRenderer.render();
  }

  /// Update chart padding.
  /// Triggers layout recalculation and render.
  void updatePadding(ChartPadding chartPadding) {
    // Update context
    context.config = context.config.copyWith(padding: chartPadding);

    // Trigger layout recalculation and render
    multiPaneRenderer.recalculateLayout();
    multiPaneRenderer.render();
  }

  /// Zoom in (show fewer candles, more detail).
  /// RIGHT-ANCHORED: Most recent candle stays visible on right edge.
  void zoomIn([double? factor]) {
    if (factor != null) {
      zoomManager.zoomIn(factor: factor);
    } else {
      zoomManager.zoomIn();
    }
    chartController.recalculatePriceScalesFromVisibleCandles();
  }

  /// Zoom out (show more candles, less detail).
  /// RIGHT-ANCHORED: Most recent candle stays visible on right edge.
  void zoomOut([double? factor]) {
    if (factor != null) {
      zoomManager.zoomOut(factor: factor);
    } else {
      zoomManager.zoomOut();
    }
    chartController.recalculatePriceScalesFromVisibleCandles();
  }

  /// Pan horizontally (shift time axis left or right).
  /// HORIZONTAL ONLY: No vertical panning.
  /// Auto-loads more historical data when panning near start.
  void pan(int deltaCandles) {
    zoomManager.pan(deltaCandles.toDouble());
    chartController.recalculatePriceScalesFromVisibleCandles();

    // Check if we should load more historical data
    _checkAndLoadMore();
  }

  /// Reset zoom to show all candles.
  void resetZoom() {
    zoomManager.resetZoom();
    chartController.recalculatePriceScalesFromVisibleCandles();
  }

  /// Get current zoom level as a percentage.
  /// 100% = showing all candles, <100% = zoomed in.
  double getZoomLevel() {
    return zoomManager.getZoomLevel();
  }

  /// Check if can zoom in further.
  bool canZoomIn() {
    return zoomManager.canZoomIn();
  }

  /// Check if can zoom out further.
  bool canZoomOut() {
    return zoomManager.canZoomOut();
  }

  /// Check if can pan left.
  bool canPanLeft() {
    return zoomManager.canPanLeft();
  }

  /// Check if can pan right.
  bool canPanRight() {
    return zoomManager.canPanRight();
  }

  /// Get current visible indices.
  /// Used for detecting when to load more historical data.
  ({int startIndex, int endIndex}) getVisibleIndices() {
    final indices = context.scales.getVisibleDomainIndices();

    // Guard against NaN or invalid indices
    if (indices.startIndex.isNaN ||
        indices.endIndex.isNaN ||
        indices.startIndex.isInfinite ||
        indices.endIndex.isInfinite) {
      return (startIndex: 0, endIndex: 0);
    }

    return (
      startIndex: indices.startIndex.floor(),
      endIndex: indices.endIndex.ceil(),
    );
  }

  /// Get current box width (width of each candle in pixels).
  /// Used for calculating zoom-independent pan speed.
  double getBoxWidth() {
    return context.scales.timeScale.boxWidth();
  }

  /// Check if near start of data and load more historical if needed.
  /// Called automatically after pan operations.
  void _checkAndLoadMore() {
    // Skip if already loading or no more data
    if (isLoadingMore || !hasMoreHistorical) {
      return;
    }

    // Check if near start
    final indices = getVisibleIndices();
    if (indices.startIndex < loadMoreThreshold) {
      // print('[CHART] Near start (startIndex=${indices.startIndex}), loading more historical data...');
      _loadMoreHistoricalFromDataManager();
    }
  }

  /// Load more historical data from DataManager.
  /// Async operation that doesn't block the UI.
  Future<void> _loadMoreHistoricalFromDataManager() async {
    if (isLoadingMore) {
      return;
    }

    isLoadingMore = true;

    try {
      final batch = await dataManager.loadHistorical();
      hasMoreHistorical = batch.hasMore;

      if (batch.candles.isNotEmpty) {
        // print('[CHART] Loaded ${batch.candles.length} more historical candles (hasMore=${batch.hasMore})');
        chartController.loadMoreHistorical(batch.candles);
      }
    } catch (error) {
      // print('[CHART] Failed to load more historical data: $error');
    } finally {
      isLoadingMore = false;
    }
  }

  /// Clean up resources.
  void destroy() {
    chartController.destroy();
  }
}
