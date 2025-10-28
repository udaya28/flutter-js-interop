/// Flutter Chart Widget - integrates chartlib with Flutter's rendering system.

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:chartlib/chartlib.dart';
import '../compositor/flutter_compositor.dart';
import '../data/sample_data_manager.dart';

/// Main chart widget that displays OHLC charts with full orchestration.
///
/// Features:
/// - Multi-pane support (main chart + sub-panels)
/// - Technical studies (SMA, EMA, Volume, etc.)
/// - Zoom and pan gestures
/// - Real-time data updates
/// - Theme support
class ChartWidget extends StatefulWidget {
  /// Data manager for loading candles
  final DataManager dataManager;

  /// Candle study for main chart (required)
  final Study<dynamic> candleStudy;

  /// Overlay studies for main chart (SMA, EMA, etc.)
  final List<Study<dynamic>>? overlayStudies;

  /// Sub-pane definitions (Volume, RSI, MACD, etc.)
  final List<SubPaneConfig>? subPanes;

  /// Chart theme
  final ChartTheme theme;

  /// Chart dimensions (defaults to parent constraints)
  final double? width;
  final double? height;

  /// Chart padding (space for axes and labels)
  final ChartPadding? padding;

  /// Callback fired whenever the visible chart range changes (zoom/pan).
  final void Function(DateTime start, DateTime end)? onViewportChanged;

  /// Callback fired when the pointer hovers over the chart. Passing `null`
  /// indicates the pointer exited the chart area.
  final void Function(ChartHoverEvent? event)? onHover;

  /// Callback fired once the chart finishes its initial asynchronous
  /// initialization cycle. Useful for orchestration layers that need to
  /// coordinate data flows (e.g., starting a simulator once the chart is
  /// ready to consume realtime updates).
  final VoidCallback? onChartInitialized;

  const ChartWidget({
    super.key,
    required this.dataManager,
    required this.candleStudy,
    this.overlayStudies,
    this.subPanes,
    required this.theme,
    this.width,
    this.height,
    this.padding,
    this.onViewportChanged,
    this.onHover,
    this.onChartInitialized,
  });

  @override
  State<ChartWidget> createState() => _ChartWidgetState();
}

/// Pointer hover details emitted by [ChartWidget].
class ChartHoverEvent {
  const ChartHoverEvent({required this.time, this.price, this.candle});

  final DateTime time;
  final double? price;
  final OHLCData? candle;
}

/// Sub-pane configuration
class SubPaneConfig {
  final String id;
  final Study<dynamic> primaryStudy;
  final double heightPercent;
  final List<Study<dynamic>>? otherStudies;

  const SubPaneConfig({
    required this.id,
    required this.primaryStudy,
    required this.heightPercent,
    this.otherStudies,
  });
}

class _ChartWidgetState extends State<ChartWidget> {
  Chart? _chart;
  bool _isInitialized = false;
  String? _error;
  ChartPadding? _resolvedPadding;
  Size? _lastPaintSize;

  @override
  void initState() {
    super.initState();
    // Chart will be initialized in first build when we have size
  }

  @override
  void didUpdateWidget(ChartWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Recreate chart if key dependencies changed
    if (oldWidget.dataManager != widget.dataManager ||
        oldWidget.candleStudy != widget.candleStudy ||
        oldWidget.theme != widget.theme) {
      _isInitialized = false;
      _chart = null;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _chart?.destroy();
    super.dispose();
  }

  /// Initialize the chart with the given size
  Future<void> _initializeChart(Size size) async {
    if (_isInitialized) return;

    // CRITICAL: Reset dataManager state before creating new chart
    // This ensures fresh data loading when widget rebuilds (e.g., on study toggles)
    if (widget.dataManager is SampleDataManager) {
      (widget.dataManager as SampleDataManager).reset();
    }

    try {
      final chartSize = ChartSize(width: size.width, height: size.height);

      final chartPadding =
          widget.padding ??
          const ChartPadding(left: 60, right: 80, top: 10, bottom: 40);

      _resolvedPadding = chartPadding;

      // Create a temporary compositor (will be replaced during paint)
      final tempCompositor = _TempCompositor();

      // Create chart instance
      final chart = Chart(
        chartSize: chartSize,
        chartPadding: chartPadding,
        theme: widget.theme,
        candleStudy: widget.candleStudy,
        dataManager: widget.dataManager,
        compositor: tempCompositor,
      );

      // Add overlay studies
      if (widget.overlayStudies != null) {
        for (final study in widget.overlayStudies!) {
          chart.addOverlayStudy(study);
        }
      }

      // Add sub-panes
      if (widget.subPanes != null) {
        for (final subPane in widget.subPanes!) {
          chart.createSubPane(
            id: subPane.id,
            primaryStudy: subPane.primaryStudy,
            heightPercent: subPane.heightPercent,
            otherStudies: subPane.otherStudies ?? [],
          );
        }
      }

      // Override render callback to trigger Flutter setState()
      // This ensures Flutter repaints when chart receives real-time updates
      chart.chartController.setOnRender(() {
        if (!mounted) {
          return;
        }

        // Trigger Flutter repaint; render occurs inside CustomPainter.paint
        setState(() {});
        _notifyViewportChanged();
      });

      // Initialize with data
      await chart.initialize();

      setState(() {
        _chart = chart;
        _isInitialized = true;
        _error = null;
      });

      _notifyViewportChanged();

      widget.onChartInitialized?.call();
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize chart: $e';
        _isInitialized = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          _lastPaintSize = size;

          // Initialize chart if needed
          if (!_isInitialized && _chart == null) {
            _initializeChart(size);
          }

          // Show error if initialization failed
          if (_error != null) {
            return Center(
              child: Text(
                _error!,
                style: const TextStyle(color: Color(0xFFFF0000)),
              ),
            );
          }

          // Show loading while initializing
          if (!_isInitialized || _chart == null) {
            return const Center(child: Text('Loading chart...'));
          }

          // Render chart
          return Listener(
            onPointerSignal: _handlePointerSignal,
            child: MouseRegion(
              onHover: _handleHover,
              onExit: (_) => _emitHover(null),
              child: GestureDetector(
                onScaleStart: _handleScaleStart,
                onScaleUpdate: _handleScaleUpdate,
                onScaleEnd: _handleScaleEnd,
                child: CustomPaint(
                  painter: _ChartPainter(chart: _chart!, theme: widget.theme),
                  size: size,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Gesture handling state
  double _lastScale = 1.0;
  Offset? _lastFocalPoint;
  double _pendingPan = 0.0;

  void _handleScaleStart(ScaleStartDetails details) {
    _lastScale = 1.0;
    _lastFocalPoint = details.focalPoint;
    _pendingPan = 0.0;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (_chart == null) return;

    // Handle zoom (pinch gesture)
    if (details.scale != 1.0) {
      final scaleDelta = details.scale / _lastScale;
      _lastScale = details.scale;

      if (scaleDelta > 1.01) {
        // Zoom in
        _chart!.zoomIn(scaleDelta);
        setState(() {});
        _notifyViewportChanged();
        _pendingPan = 0.0; // reset accumulated pan since zoom changes state
      } else if (scaleDelta < 0.99) {
        // Zoom out
        _chart!.zoomOut(1 / scaleDelta);
        setState(() {});
        _notifyViewportChanged();
        _pendingPan = 0.0;
      }
    }

    // Handle pan (single finger drag)
    if (_lastFocalPoint != null && details.scale == 1.0) {
      final delta = details.focalPoint - _lastFocalPoint!;
      _lastFocalPoint = details.focalPoint;

      // Convert pixel delta to candle delta
      final boxWidth = _chart!.getBoxWidth();
      if (boxWidth > 0) {
        _pendingPan += -(delta.dx / boxWidth);
        final int candleDelta = _pendingPan.truncate();
        if (candleDelta != 0) {
          _pendingPan -= candleDelta.toDouble();
          _chart!.pan(candleDelta);
          setState(() {});
          _notifyViewportChanged();
        }
      }
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _lastScale = 1.0;
    _lastFocalPoint = null;
    _pendingPan = 0.0;
    _notifyViewportChanged();
  }

  /// Handle mouse scroll wheel for zooming (desktop)
  void _handlePointerSignal(PointerSignalEvent event) {
    if (_chart == null) return;

    if (event is PointerScrollEvent) {
      // Normalize scroll delta (positive = scroll down = zoom out)
      final scrollDelta = event.scrollDelta.dy;

      if (scrollDelta > 0) {
        // Scroll down = zoom out
        _chart!.zoomOut(1.1);
        setState(() {});
        _notifyViewportChanged();
      } else if (scrollDelta < 0) {
        // Scroll up = zoom in
        _chart!.zoomIn(1.1);
        setState(() {});
        _notifyViewportChanged();
      }
    }
  }

  void _notifyViewportChanged() {
    if (widget.onViewportChanged == null || _chart == null) {
      return;
    }

    final candles = _chart!.timeSeriesStore.getAll();
    if (candles.isEmpty) {
      return;
    }

    final indices = _chart!.context.scales.getVisibleDomainIndices();
    final startIndex = indices.startIndex.floor().clamp(0, candles.length - 1);
    final endIndex = indices.endIndex.ceil().clamp(0, candles.length - 1);

    final startTime = candles[startIndex].timestamp;
    final endTime = candles[endIndex].timestamp;

    widget.onViewportChanged?.call(startTime, endTime);
  }

  void _handleHover(PointerHoverEvent event) {
    _emitHover(event.localPosition);
  }

  void _emitHover(Offset? position) {
    if (widget.onHover == null) {
      return;
    }

    if (position == null || _chart == null) {
      widget.onHover?.call(null);
      return;
    }

    final chart = _chart!;
    final size = _lastPaintSize;
    final padding =
        _resolvedPadding ??
        const ChartPadding(left: 60, right: 80, top: 10, bottom: 40);

    if (size == null) {
      widget.onHover?.call(null);
      return;
    }

    final chartWidth = size.width - padding.left - padding.right;
    final chartHeight = size.height - padding.top - padding.bottom;

    if (chartWidth <= 0 || chartHeight <= 0) {
      widget.onHover?.call(null);
      return;
    }

    final localX = position.dx - padding.left;
    final localY = position.dy - padding.top;

    if (localX < 0 ||
        localX > chartWidth ||
        localY < 0 ||
        localY > chartHeight) {
      widget.onHover?.call(null);
      return;
    }

    final timeScale = chart.context.scales.timeScale;
    final priceScale = chart.context.scales.priceScale;

    DateTime timestamp;
    try {
      timestamp = timeScale.invert(localX);
    } catch (_) {
      widget.onHover?.call(null);
      return;
    }

    final price = priceScale.invert(localY);

    final candles = chart.timeSeriesStore.getAll();
    if (candles.isEmpty) {
      widget.onHover?.call(
        ChartHoverEvent(time: timestamp, price: price, candle: null),
      );
      return;
    }

    final nearest = _findNearestCandle(timestamp, candles);
    widget.onHover?.call(
      ChartHoverEvent(time: timestamp, price: price, candle: nearest),
    );
  }

  OHLCData? _findNearestCandle(DateTime timestamp, List<OHLCData> candles) {
    if (candles.isEmpty) {
      return null;
    }

    final target = timestamp.millisecondsSinceEpoch;

    var low = 0;
    var high = candles.length - 1;

    while (low <= high) {
      final mid = (low + high) >> 1;
      final midValue = candles[mid].timestamp.millisecondsSinceEpoch;
      if (midValue == target) {
        return candles[mid];
      } else if (midValue < target) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    final leftIndex = math.max(0, high);
    final rightIndex = math.min(candles.length - 1, low);

    final leftDiff =
        (candles[leftIndex].timestamp.millisecondsSinceEpoch - target).abs();
    final rightDiff =
        (candles[rightIndex].timestamp.millisecondsSinceEpoch - target).abs();

    return leftDiff <= rightDiff ? candles[leftIndex] : candles[rightIndex];
  }
}

/// Custom painter that renders the chart using FlutterCompositor
class _ChartPainter extends CustomPainter {
  final Chart chart;
  final ChartTheme theme;

  _ChartPainter({required this.chart, required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    // print('[_ChartPainter.paint] REPAINT STARTED');
    // Create Flutter compositor
    final compositor = FlutterCompositor(canvas, size, theme);

    // Replace chart's compositor with Flutter compositor
    // This is a bit hacky but necessary since Chart is created once
    // and we need to provide a new Canvas on each paint
    chart.multiPaneRenderer.compositor = compositor;

    // Render the chart
    chart.multiPaneRenderer.render();
    // print('[_ChartPainter.paint] REPAINT COMPLETED');
  }

  @override
  bool shouldRepaint(_ChartPainter oldDelegate) {
    // Always repaint (chart handles caching internally)
    return true;
  }
}

/// Temporary compositor used during chart initialization
class _TempCompositor implements Compositor {
  @override
  void setupHighDPI(double width, double height) {}

  @override
  void clear() {}

  @override
  void render(dynamic shapeBatch) {}

  @override
  void renderShapes(List<dynamic> shapes) {}

  @override
  void setClipRegion(Bounds bounds) {}

  @override
  void clearClipRegion() {}

  @override
  void drawBorder(Bounds bounds) {}
}
