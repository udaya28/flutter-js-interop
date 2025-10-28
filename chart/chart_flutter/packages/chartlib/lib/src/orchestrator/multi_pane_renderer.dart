/// Multi-pane renderer - manages layout calculation and rendering.
/// Ported from src/chartwrapper/orchestrator/multiPaneRenderer.ts

import '../core/base_definition.dart';
import '../core/chart_context.dart';
import '../layout/pane_manager.dart';
import '../layout/sub_pane.dart';
import '../layout/main_pane.dart';
import '../layout/layout_types.dart'; // Compositor placeholder
import '../scale/time_axis.dart';
import '../utils/performance_tracker.dart';

/// Multi-pane renderer - manages layout calculation and rendering.
///
/// Responsibilities:
/// - Calculate pane bounds (on layout changes only)
/// - Apply bounds to panes and their scales
/// - Render all panes (60fps using cached bounds)
/// - Setup high-DPI canvas
class MultiPaneRenderer {
  static const double paneSpacing = 16.0; // Gap between panes in pixels

  final ChartContext context;
  final PaneManager paneManager;

  /// Compositor for rendering (can be replaced for Flutter integration)
  Compositor compositor;

  /// Time axis (shared across all panes, owned by Chart)
  final TimeAxis timeAxis;

  /// Create multi-pane renderer.
  ///
  /// @param context - Shared chart context (config + scales)
  /// @param compositor - Rendering backend (Canvas2D, PixiJS, or Flutter CustomPainter)
  /// @param paneManager - Pane manager
  /// @param timeAxis - Time axis (shared across all panes)
  MultiPaneRenderer(
    this.context,
    this.compositor,
    this.paneManager,
    this.timeAxis,
  ) {
    // Setup high-DPI and initial layout
    compositor.setupHighDPI(
      context.config.size.width,
      context.config.size.height,
    );
    recalculateLayout();
  }

  /// Wait for compositor initialization to complete (if async).
  /// For Canvas2D, this returns immediately.
  /// For PixiJS or Flutter, this may wait for initialization.
  Future<void> waitForInit() async {
    // Compositor may provide an async init method
    // For now, return immediately (Flutter CustomPainter doesn't need async init)
    return;
  }

  /// Add a sub-pane.
  /// Triggers layout recalculation.
  void addSubPane(SubPane subPane) {
    paneManager.addSubPane(subPane);
    recalculateLayout();
  }

  /// Recalculate layout - compute bounds for all panes.
  /// Called on layout changes (add/remove pane, resize, padding change).
  /// Public so Chart can trigger it after updating context.
  void recalculateLayout() {
    // print('[MultiPaneRenderer.recalculateLayout] Starting layout calculation');

    // Get panes from manager
    final mainPane = _getMainPane();
    final subPanes = _getSubPanes();

    // Calculate chart area (excluding padding)
    final chartAreaX = context.config.padding.left;
    final chartAreaY = context.config.padding.top;
    final chartAreaWidth =
        context.config.size.width -
        context.config.padding.left -
        context.config.padding.right;
    final chartAreaHeight =
        context.config.size.height -
        context.config.padding.top -
        context.config.padding.bottom;

    // 1. Calculate heights accounting for spacing between panes
    final totalSpacing = subPanes.length * paneSpacing;
    final availableHeight = chartAreaHeight - totalSpacing;

    final totalSubHeight = subPanes.fold<double>(
      0.0,
      (sum, sp) => sum + sp.heightPercent,
    );
    final mainHeightPercent = 1.0 - totalSubHeight;

    if (mainHeightPercent <= 0) {
      throw Exception(
        'Main pane height must be positive (sub-panes total height >= 1.0)',
      );
    }

    // 2. Calculate and update bounds in each pane (also updates scale ranges)
    double currentY = chartAreaY;

    // Main pane bounds
    final mainHeight = availableHeight * mainHeightPercent;
    mainPane.updateBounds(
      Bounds(
        x: chartAreaX,
        y: currentY,
        width: chartAreaWidth,
        height: mainHeight,
      ),
      context.scales.priceScale,
    );
    currentY += mainHeight + paneSpacing;

    // Sub-pane bounds
    for (final subPane in subPanes) {
      final height = availableHeight * subPane.heightPercent;
      subPane.updateBounds(
        Bounds(
          x: chartAreaX,
          y: currentY,
          width: chartAreaWidth,
          height: height,
        ),
      );
      currentY += height + paneSpacing;
    }

    // 3. Update time scale range (shared by all panes)
    context.scales.timeScale.updateRange(
      chartAreaX,
      chartAreaX + chartAreaWidth,
    );

    // Note: Time axis is owned by Chart and passed via constructor
  }

  /// Render all panes.
  /// Called at 60fps - uses cached bounds from panes.
  /// Rendering order: grids (bottom) -> content -> border -> axis lines -> labels (top)
  void render() {
    PerformanceTracker.start('render');

    // Clear canvas
    compositor.clear();

    // Get panes
    final mainPane = _getMainPane();
    final subPanes = _getSubPanes();

    // Calculate chart area bounds
    final chartAreaX = context.config.padding.left;
    final chartAreaY = context.config.padding.top;
    final chartAreaWidth =
        context.config.size.width -
        context.config.padding.left -
        context.config.padding.right;
    final chartAreaHeight =
        context.config.size.height -
        context.config.padding.top -
        context.config.padding.bottom;

    // Layer 1: Grid lines (bottom layer)
    compositor.renderShapes(mainPane.generatePriceAxisGridShapes());
    for (final subPane in subPanes) {
      compositor.renderShapes(subPane.generatePriceAxisGridShapes());
    }
    compositor.renderShapes(timeAxis.generateGridShapes(mainPane.bounds));
    for (final subPane in subPanes) {
      compositor.renderShapes(timeAxis.generateGridShapes(subPane.bounds));
    }

    // Layer 2: Pane content (middle layer) - with clipping to prevent overflow
    _renderPaneWithClip(mainPane, mainPane.bounds);

    for (final subPane in subPanes) {
      _renderPaneWithClip(subPane, subPane.bounds);
    }

    // Layer 2.5: Study infrastructure (labels over y-axis) - unclipped
    mainPane.renderInfrastructureTo(compositor, context.scales);
    for (final subPane in subPanes) {
      subPane.renderInfrastructureTo(compositor, context.scales);
    }

    // Layer 2.6: Chart border (below axis lines)
    compositor.drawBorder(
      Bounds(
        x: chartAreaX,
        y: chartAreaY,
        width: chartAreaWidth,
        height: chartAreaHeight,
      ),
    );

    // Layer 3: Axis lines
    final mainAxisLine = mainPane.generatePriceAxisLineShape();
    if (mainAxisLine != null) {
      compositor.renderShapes([mainAxisLine]);
    }
    for (final subPane in subPanes) {
      final axisLine = subPane.generatePriceAxisLineShape();
      if (axisLine != null) {
        compositor.renderShapes([axisLine]);
      }
    }
    final lastPaneBounds = subPanes.isNotEmpty
        ? subPanes.last.bounds
        : mainPane.bounds;
    final axisLine = timeAxis.generateAxisLineShape(lastPaneBounds);
    if (axisLine != null) {
      compositor.renderShapes([axisLine]);
    }

    // Layer 4: Axis labels (top layer)
    compositor.renderShapes(mainPane.generatePriceAxisLabelShapes());
    for (final subPane in subPanes) {
      compositor.renderShapes(subPane.generatePriceAxisLabelShapes());
    }
    compositor.renderShapes(timeAxis.generateLabelShapes(lastPaneBounds));

    // TODO: Render crosshair

    PerformanceTracker.end('render');
  }

  /// Render pane with clipping to prevent overflow outside bounds.
  /// Uses canvas clip region to restrict rendering to pane area.
  /// Studies render directly to compositor with zero allocations.
  void _renderPaneWithClip(dynamic pane, Bounds bounds) {
    // Set clip region matching pane bounds
    compositor.setClipRegion(bounds);

    // Render pane directly to compositor - zero allocations
    if (pane is MainPane) {
      pane.renderTo(compositor, context.scales);
    } else if (pane is SubPane) {
      pane.renderTo(compositor, context.scales);
    }

    // Clear clip region
    compositor.clearClipRegion();
  }

  /// Get main pane from manager.
  MainPane _getMainPane() {
    return paneManager.getMainPane();
  }

  /// Get sub-panes from manager.
  List<SubPane> _getSubPanes() {
    return paneManager.getSubPanes();
  }
}
