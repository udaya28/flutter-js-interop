/// Framework-agnostic chart library core
///
/// Mirrors the TypeScript chartlib structure from src/chartlib/
/// - Core chart definitions (ChartSize, ChartPadding, AxisPosition, ChartContext)
/// - Scale system (NumericScale, ContinuousTimeScale, OrdinalTimeScale, Axes, ScaleManager)
/// - Zoom and market utilities (ZoomManager, MarketDefinition)
/// - Layout system (MainPane, SubPane, PaneManager)
/// - Drawing system (shapes, lines)
/// - Theme system (light/dark themes)
library chartlib;

// Core definitions
export 'src/core/base_definition.dart';
export 'src/core/candle_definition.dart';
export 'src/core/chart_context.dart';
export 'src/core/zoom_manager.dart';
export 'src/core/market_definition.dart';

// Scale system
export 'src/scale/scale.dart';
export 'src/scale/numeric_scale.dart';
export 'src/scale/continuous_time_scale.dart';
export 'src/scale/ordinal_time_scale.dart';
export 'src/scale/axis.dart';
export 'src/scale/numeric_axis.dart';
export 'src/scale/time_axis.dart';
export 'src/scale/scale_manager.dart';
export 'src/scale/common_scale_manager.dart';

// Layout system
export 'src/layout/layout_types.dart';
export 'src/layout/main_pane.dart';
export 'src/layout/sub_pane.dart';
export 'src/layout/pane_manager.dart';

// Shapes
export 'src/shapes/candle.dart';
export 'src/shapes/line.dart';
export 'src/shapes/batch/shape_batch.dart';
export 'src/shapes/batch/candle_batch.dart';
export 'src/shapes/batch/bar_batch.dart';
export 'src/shapes/batch/polyline_batch.dart';
export 'src/shapes/batch/band_fill_batch.dart';

// Theme system
export 'src/theme/types.dart';
export 'src/theme/themes.dart';

// Data system
export 'src/data/ohlc.dart';
export 'src/data/time_series_store.dart';
export 'src/data/data_manager.dart';
export 'src/data/data_simulator.dart';
export 'src/data/simulator_data_manager.dart';

// Studies system
export 'src/studies/base_study.dart';
export 'src/studies/instant_study.dart';
export 'src/studies/windowed_study.dart';
export 'src/studies/instant/candle_study.dart';
export 'src/studies/instant/volume_study.dart';
export 'src/studies/instant/last_price_line_study.dart';
export 'src/studies/windowed/sma_study.dart';
export 'src/studies/windowed/ema_study.dart';
export 'src/studies/windowed/rsi_study.dart';
export 'src/studies/windowed/bollinger_bands_study.dart';

// Utilities
export 'src/utils/performance_tracker.dart';

// Orchestration layer
export 'src/orchestrator/chart.dart';
export 'src/orchestrator/chart_controller.dart';
export 'src/orchestrator/multi_pane_renderer.dart';
