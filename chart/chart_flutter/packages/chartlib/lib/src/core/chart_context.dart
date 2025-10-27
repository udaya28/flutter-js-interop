/// Shared chart context - renderer-agnostic configuration and infrastructure
/// Ported from src/chartlib/chartcore/chartContext.ts

import 'base_definition.dart';
import '../theme/types.dart';
import '../scale/common_scale_manager.dart';

/// Chart configuration values
class ChartConfig {
  const ChartConfig({
    required this.size,
    required this.padding,
    required this.theme,
  });

  /// Chart dimensions in logical pixels
  final ChartSize size;

  /// Chart padding (space for axes, labels)
  final ChartPadding padding;

  /// Chart theme (colors, typography, spacing)
  final ChartTheme theme;

  /// Create a copy with some fields replaced
  ChartConfig copyWith({
    ChartSize? size,
    ChartPadding? padding,
    ChartTheme? theme,
  }) {
    return ChartConfig(
      size: size ?? this.size,
      padding: padding ?? this.padding,
      theme: theme ?? this.theme,
    );
  }
}

/// Shared chart context - renderer-agnostic configuration and infrastructure.
///
/// This context is passed to all chart components (panes, axes, renderers) and
/// provides a single source of truth for:
/// - Chart configuration (size, padding, theme)
/// - Scale management (time and price scales)
///
/// The context is renderer-agnostic - it works with Canvas2D, PixiJS, WebGL, etc.
/// Renderer-specific infrastructure (canvas, ctx, PIXI.Application) is owned by
/// the renderer implementation, NOT stored in this context.
///
/// Benefits:
/// - Single source of truth - no duplication
/// - No manual propagation - components read directly from context
/// - Easy theme updates - just update context.config.theme and render
/// - Future-proof - swap renderer without changing context
class ChartContext {
  ChartContext({
    required this.config,
    required this.scales,
  });

  /// Chart configuration.
  /// These properties change infrequently (user actions like resize, theme toggle).
  ChartConfig config;

  /// Scale management infrastructure.
  /// Shared across all panes for coordinate transformations.
  CommonScaleManager scales;
}
