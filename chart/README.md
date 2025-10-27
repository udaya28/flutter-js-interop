Notes

- the chart folder has two subfolders
  - chart_flutter - this contains the flutter implementation of the chart that is build for web
  - web - this is a view app that integrates the chart_flutter web build as iframe

misc notes
chart_flutter/
├── packages/
│ ├── chartlib/ # Framework-agnostic chart core (mirrors JS chartlib)
│ └── chartwidget/ # Flutter widgets for chart rendering

## Packages

### chartlib

Framework-agnostic chart library core. Contains:

- Core definitions (ChartSize, Bounds, AxisPosition)
- Candle definitions (CandleDuration, OHLC)
- Scale system (NumericScale, TimeScale)
- Shapes (Candle, Line, Point)
- Theme system (light/dark)

**No Flutter dependencies** - pure Dart code.

### chartwidget

Flutter widgets for chart rendering using Canvas:

- `ChartWidget`: Main chart widget
- `CandlePainter`: CustomPainter for rendering candles

Depends on `chartlib` and Flutter SDK.

Goals of POC

- run this chart library in iframe in the vue app, there are two this I want to do in this
  - one similar to the todo-app where the flutter app is built for web and integrated as iframe in the vue app and the flutter acts like as ui part only and vue passes the data to flutter app to render the todo list similaryly for the chart I want to pass the data from vue app to flutter app to render the chart
  - second is to flutter web app runs as standalone app and vue app opens the flutter web app in iframe

Note

- I have already implemented few pocs before
- I'll put the entire poc code as previous_poc folder
- use the existing poc code as reference and reuse the code as much as possible, the ui and functionality should be exactly same as previous poc, I have already copied previously completed packages code to this chart_flutter/packages folder

TODO

- build the first goal where vue app passes the data to flutter app to render the chart this is similar to the todo-app poc where we use flutter js interop to pass the data from vue to flutter app
