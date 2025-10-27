/// Flutter widgets for chart rendering
///
/// This package provides Flutter widgets for rendering charts using Canvas.
/// It depends on the framework-agnostic chartlib package.
library chartwidget;

// Main widget
export 'src/widgets/chart_widget.dart';

// Compositor
export 'src/compositor/flutter_compositor.dart';

// Data
export 'src/data/sample_data_manager.dart';

// Legacy painter (deprecated - use ChartWidget instead)
export 'src/painters/candle_painter.dart';
