/// Dark theme implementation
/// Ported from src/chartlib/theme/themes.ts

import 'dart:ui';
import 'types.dart';

/// Dark theme (matches JS darkTheme)
const ChartTheme darkTheme = ChartTheme(
  name: 'dark',
  colors: ChartColors(
    // Background colors
    background: Color(0xFF000000),
    chartArea: Color(0xFF16181C),
    // Grid and axis colors
    gridColor: Color(0xFF2F3336),
    tickColor: Color(0xFF71767B),
    tickLabelColor: Color(0xFF8B98A5),
    // Text colors
    titleColor: Color(0xFFE7E9EA),
    textColor: Color(0xFFCFD2D6),
    // Candle colors
    candlePositive: Color(0xFF00D084),
    candleNegative: Color(0xFFF4212E),
    // Price line
    lastPriceLine: Color(0xFF2962FF),
    // Interactive elements
    hoverColor: Color(0xFF1D9BF0),
    selectionColor: Color(0xFF1D9BF0),
    // Borders and dividers
    borderColor: Color(0xFF3E4144),
    dividerColor: Color(0xFF2F3336),
  ),
  typography: ChartTypography.base,
  spacing: ChartSpacing.base,
);
