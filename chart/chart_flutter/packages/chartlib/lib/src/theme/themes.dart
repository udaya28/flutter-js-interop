/// Theme management and utilities
/// Ported from src/chartlib/theme/themes.ts

import 'types.dart';
import 'light_theme.dart';
import 'dark_theme.dart';

// Re-export individual themes
export 'light_theme.dart';
export 'dark_theme.dart';

/// Map of available themes
const Map<String, ChartTheme> themes = {
  'light': lightTheme,
  'dark': darkTheme,
};

/// Create a custom theme by merging a base theme with overrides
ChartTheme createCustomTheme(
  ChartTheme baseTheme, {
  String? name,
  ChartColors? colorsOverride,
  ChartTypography? typographyOverride,
  ChartSpacing? spacingOverride,
}) {
  return ChartTheme(
    name: name ?? baseTheme.name,
    colors: colorsOverride != null
        ? baseTheme.colors.copyWith(
            background: colorsOverride.background,
            chartArea: colorsOverride.chartArea,
            gridColor: colorsOverride.gridColor,
            tickColor: colorsOverride.tickColor,
            tickLabelColor: colorsOverride.tickLabelColor,
            titleColor: colorsOverride.titleColor,
            textColor: colorsOverride.textColor,
            candlePositive: colorsOverride.candlePositive,
            candleNegative: colorsOverride.candleNegative,
            lastPriceLine: colorsOverride.lastPriceLine,
            hoverColor: colorsOverride.hoverColor,
            selectionColor: colorsOverride.selectionColor,
            borderColor: colorsOverride.borderColor,
            dividerColor: colorsOverride.dividerColor,
          )
        : baseTheme.colors,
    typography: typographyOverride != null
        ? baseTheme.typography.copyWith(
            titleFont: typographyOverride.titleFont,
            axisFont: typographyOverride.axisFont,
            labelsFont: typographyOverride.labelsFont,
            tooltipFont: typographyOverride.tooltipFont,
          )
        : baseTheme.typography,
    spacing: spacingOverride != null
        ? baseTheme.spacing.copyWith(
            paddingSmall: spacingOverride.paddingSmall,
            paddingMedium: spacingOverride.paddingMedium,
            paddingLarge: spacingOverride.paddingLarge,
            tickLength: spacingOverride.tickLength,
            tickOffset: spacingOverride.tickOffset,
          )
        : baseTheme.spacing,
  );
}
