/// Light theme implementation
/// Ported from src/chartlib/theme/themes.ts

import 'dart:ui';
import 'types.dart';

/// Light theme (matches JS lightTheme)
const ChartTheme lightTheme = ChartTheme(
  name: 'light',
  colors: ChartColors(
    // Background colors
    background: Color(0xFFFFFFFF),
    chartArea: Color(0xFFFAFBFC),
    // Grid and axis colors
    gridColor: Color(0xFFE1E8ED),
    tickColor: Color(0xFF8899A6),
    tickLabelColor: Color(0xFF657786),
    // Text colors
    titleColor: Color(0xFF14171A),
    textColor: Color(0xFF536471),
    // Candle colors
    candlePositive: Color(0xFF00BA7C),
    candleNegative: Color(0xFFFA533D),
    // Price line
    lastPriceLine: Color(0xFF2962FF),
    // Interactive elements
    hoverColor: Color(0xFF1D9BF0),
    selectionColor: Color(0xFF1D9BF0),
    // Borders and dividers
    borderColor: Color(0xFFCFD9DE),
    dividerColor: Color(0xFFEFF3F4),
  ),
  typography: ChartTypography.base,
  spacing: ChartSpacing.base,
);
