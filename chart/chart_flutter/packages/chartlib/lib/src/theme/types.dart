/// Chart theme type definitions
/// Ported from src/chartlib/theme/types.ts

import 'dart:ui';

/// Color definitions for chart elements
class ChartColors {
  const ChartColors({
    required this.background,
    required this.chartArea,
    required this.gridColor,
    required this.tickColor,
    required this.tickLabelColor,
    required this.titleColor,
    required this.textColor,
    required this.candlePositive,
    required this.candleNegative,
    required this.lastPriceLine,
    required this.hoverColor,
    required this.selectionColor,
    required this.borderColor,
    required this.dividerColor,
  });

  // Background colors
  final Color background;
  final Color chartArea;

  // Grid and axis colors
  final Color gridColor;
  final Color tickColor;
  final Color tickLabelColor;

  // Text colors
  final Color titleColor;
  final Color textColor;

  // Candle colors
  final Color candlePositive;
  final Color candleNegative;

  // Price line
  final Color lastPriceLine;

  // Interactive elements
  final Color hoverColor;
  final Color selectionColor;

  // Borders and dividers
  final Color borderColor;
  final Color dividerColor;

  /// Create a copy with some fields replaced
  ChartColors copyWith({
    Color? background,
    Color? chartArea,
    Color? gridColor,
    Color? tickColor,
    Color? tickLabelColor,
    Color? titleColor,
    Color? textColor,
    Color? candlePositive,
    Color? candleNegative,
    Color? lastPriceLine,
    Color? hoverColor,
    Color? selectionColor,
    Color? borderColor,
    Color? dividerColor,
  }) {
    return ChartColors(
      background: background ?? this.background,
      chartArea: chartArea ?? this.chartArea,
      gridColor: gridColor ?? this.gridColor,
      tickColor: tickColor ?? this.tickColor,
      tickLabelColor: tickLabelColor ?? this.tickLabelColor,
      titleColor: titleColor ?? this.titleColor,
      textColor: textColor ?? this.textColor,
      candlePositive: candlePositive ?? this.candlePositive,
      candleNegative: candleNegative ?? this.candleNegative,
      lastPriceLine: lastPriceLine ?? this.lastPriceLine,
      hoverColor: hoverColor ?? this.hoverColor,
      selectionColor: selectionColor ?? this.selectionColor,
      borderColor: borderColor ?? this.borderColor,
      dividerColor: dividerColor ?? this.dividerColor,
    );
  }
}

/// Typography definitions for chart text elements
class ChartTypography {
  const ChartTypography({
    required this.titleFont,
    required this.axisFont,
    required this.labelsFont,
    required this.tooltipFont,
  });

  /// Base typography shared by light and dark themes
  static const ChartTypography base = ChartTypography(
    titleFont: 'bold 16px sans-serif',
    axisFont: '12px sans-serif',
    labelsFont: '12px sans-serif',
    tooltipFont: '12px sans-serif',
  );

  final String titleFont;
  final String axisFont;
  final String labelsFont;
  final String tooltipFont;

  /// Create a copy with some fields replaced
  ChartTypography copyWith({
    String? titleFont,
    String? axisFont,
    String? labelsFont,
    String? tooltipFont,
  }) {
    return ChartTypography(
      titleFont: titleFont ?? this.titleFont,
      axisFont: axisFont ?? this.axisFont,
      labelsFont: labelsFont ?? this.labelsFont,
      tooltipFont: tooltipFont ?? this.tooltipFont,
    );
  }
}

/// Spacing definitions for chart layout
class ChartSpacing {
  const ChartSpacing({
    required this.paddingSmall,
    required this.paddingMedium,
    required this.paddingLarge,
    required this.tickLength,
    required this.tickOffset,
  });

  /// Base spacing shared by light and dark themes
  static const ChartSpacing base = ChartSpacing(
    paddingSmall: 8,
    paddingMedium: 16,
    paddingLarge: 24,
    tickLength: 6,
    tickOffset: 8,
  );

  final double paddingSmall;
  final double paddingMedium;
  final double paddingLarge;
  final double tickLength;
  final double tickOffset;

  /// Create a copy with some fields replaced
  ChartSpacing copyWith({
    double? paddingSmall,
    double? paddingMedium,
    double? paddingLarge,
    double? tickLength,
    double? tickOffset,
  }) {
    return ChartSpacing(
      paddingSmall: paddingSmall ?? this.paddingSmall,
      paddingMedium: paddingMedium ?? this.paddingMedium,
      paddingLarge: paddingLarge ?? this.paddingLarge,
      tickLength: tickLength ?? this.tickLength,
      tickOffset: tickOffset ?? this.tickOffset,
    );
  }
}

/// Complete chart theme combining colors, typography, and spacing
class ChartTheme {
  const ChartTheme({
    required this.name,
    required this.colors,
    required this.typography,
    required this.spacing,
  });

  final String name;
  final ChartColors colors;
  final ChartTypography typography;
  final ChartSpacing spacing;

  /// Create a copy with some fields replaced
  ChartTheme copyWith({
    String? name,
    ChartColors? colors,
    ChartTypography? typography,
    ChartSpacing? spacing,
  }) {
    return ChartTheme(
      name: name ?? this.name,
      colors: colors ?? this.colors,
      typography: typography ?? this.typography,
      spacing: spacing ?? this.spacing,
    );
  }
}

/// Theme mode enum
enum ThemeMode {
  light,
  dark,
  auto,
}
