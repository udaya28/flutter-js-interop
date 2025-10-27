# chartwidget

Flutter widgets for chart rendering using Canvas.

This package provides Flutter-specific widgets and CustomPainters for rendering charts:

- **ChartWidget**: Main widget for displaying OHLC charts
- **CandlePainter**: CustomPainter for rendering candles using Flutter Canvas API

This mirrors the Canvas2D renderer approach from the JS version but uses Flutter's native Canvas API.

## Usage

```dart
import 'package:chartwidget/chartwidget.dart';
import 'package:chartlib/chartlib.dart';

ChartWidget(
  candles: myCandles,
  theme: ChartTheme.dark,
  width: 1200,
  height: 600,
)
```
