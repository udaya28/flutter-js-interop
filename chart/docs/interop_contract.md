# Vue ↔ Flutter Chart Interop Contract

This document captures the agreed message schema between the Vue shell (`chart/web`) and the Flutter chart bundle (`chart/chart_flutter`). It mirrors the data flow from the previous POC while renaming the handshake objects to chart-specific terms.

## Runtime Bridge Objects

All bridge objects live on the iframe `contentWindow` so both runtimes operate inside the same JavaScript realm.

| Object                                    | Owner                                                   | Purpose                                                                                                                           |
| ----------------------------------------- | ------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `window.ChartFlutterUI`                   | Vue seeds placeholder; Flutter assigns callbacks        | Flutter registers `update` function so Vue can notify data changes. Additional callbacks (e.g. `setViewport`) can be added later. |
| `window.ChartDataManager`                 | Vue instantiates (`new ChartDataManager(iframeWindow)`) | Holds mutable chart data arrays in the iframe realm; exposes getters for Flutter.                                                 |
| `window.ChartBridge`                      | Vue seeds                                               | Entry point for Flutter → Vue messages (`receiveFromFlutter`). Future extensions can add `sendToVue`.                             |
| `window.ChartEventBus` _(optional later)_ | Vue seeds                                               | Used for future event streams (e.g. pub/sub for selections).                                                                      |

## Message Types

Messages are plain objects with `type` and `payload`. For Vue-originated calls we invoke `ChartFlutterUI.update({ type, payload })`. For Flutter-originated calls we expose a Dart helper `chartBridge.sendToVue(type, payload)` that calls `window.ChartBridge.receiveFromFlutter` (Vue registers this handler).

### Vue → Flutter

| Type           | When sent                                                   | Payload                |
| -------------- | ----------------------------------------------------------- | ---------------------- |
| `INIT_CHART`   | After iframe load + manager bootstrap                       | `ChartInitPayload`     |
| `SET_SERIES`   | Replace entire candle series (`ChartDataManager.setSeries`) | `ChartSeriesPayload`   |
| `PATCH_SERIES` | Append or update specific candles                           | `ChartPatchPayload`    |
| `SET_THEME`    | User toggles theme in Vue                                   | `ChartThemePayload`    |
| `SET_VIEWPORT` | Vue instructs Flutter to show a specific range              | `ChartViewportPayload` |

### Flutter → Vue

| Type             | When sent                                           | Payload                   |
| ---------------- | --------------------------------------------------- | ------------------------- |
| `CHART_READY`    | Flutter finished bootstrapping and can consume data | `{ ready: true }`         |
| `RANGE_SELECTED` | User selects/zooms a range in Flutter               | `ChartViewportPayload`    |
| `CANDLE_HOVERED` | Hover state changes                                 | `ChartHoverPayload`       |
| `DATA_REQUEST`   | Flutter needs more history                          | `ChartDataRequestPayload` |

## TypeScript Definitions (authoritative)

```typescript
// chart/web/src/interop/chartContracts.ts
export interface ChartMessage<TPayload = unknown> {
  type: ChartMessageType;
  payload: TPayload;
}

type ChartMessageType =
  | 'INIT_CHART'
  | 'SET_SERIES'
  | 'PATCH_SERIES'
  | 'SET_THEME'
  | 'SET_VIEWPORT'
  | 'CHART_READY'
  | 'RANGE_SELECTED'
  | 'CANDLE_HOVERED'
  | 'DATA_REQUEST';

export interface CandleDTO {
  time: number; // unix ms
  open: number;
  high: number;
  low: number;
  close: number;
  volume?: number;
}

export interface ChartInitPayload {
  theme: ChartTheme;
  series: CandleDTO[];
  viewport?: ChartViewportPayload;
}

export interface ChartSeriesPayload {
  series: CandleDTO[];
}

export interface ChartPatchPayload {
  upserts: CandleDTO[]; // append or replace by time key
  removals?: number[]; // optional list of unix ms to delete
}

export interface ChartThemePayload {
  theme: ChartTheme;
}

export interface ChartViewportPayload {
  startTime: number; // unix ms inclusive
  endTime: number; // unix ms inclusive
}

export interface ChartHoverPayload {
  time: number;
  price: number;
  candle?: CandleDTO;
}

export interface ChartDataRequestPayload {
  fromTime: number;
  toTime: number;
  reason: 'ZOOM_OUT' | 'SCROLL_BACK' | 'LOAD_INITIAL';
}

export type ChartTheme = 'light' | 'dark';
```

Vue will:

1. Seed the iframe window with:

```typescript
iframeWindow.ChartFlutterUI = { update: null };
iframeWindow.ChartDataManager = new ChartDataManager(iframeWindow);
iframeWindow.ChartBridge = {
  receiveFromFlutter(message: ChartMessage) {
    vueEmitter.emit(message.type, message.payload);
  },
};
```

2. Call `ChartFlutterUI.update({ type: 'INIT_CHART', payload: ... })` once Flutter emits `CHART_READY`.

## Dart Bindings

Flutter mirrors the TypeScript contracts via `@JS` extension types.

```dart
// chart_flutter/lib/interop/chart_js_bindings.dart
import 'dart:js_interop';

@JS()
@anonymous
extension type CandleDTO._(JSObject _) implements JSObject {
  external factory CandleDTO({
    num time,
    num open,
    num high,
    num low,
    num close,
    num? volume,
  });

  external num get time;
  external num get open;
  external num get high;
  external num get low;
  external num get close;
  external num? get volume;
}

@JS()
@anonymous
extension type ChartMessage._(JSObject _) implements JSObject {
  external factory ChartMessage({String type, JSAny? payload});
  external String get type;
  external JSAny? get payload;
}

@JS('window.ChartFlutterUI')
external ChartFlutterUI get chartFlutterUI;

@JS()
@anonymous
extension type ChartFlutterUI._(JSObject _) implements JSObject {
  external set update(JSFunction? callback);
}

@JS('window.ChartDataManager')
external ChartDataManager get chartDataManager;

@JS()
@anonymous
extension type ChartDataManager._(JSObject _) implements JSObject {
  external JSArray<CandleDTO> getSeries();
  external JSVoid setSeries(JSArray<CandleDTO> candles);
}

@JS('window.ChartBridge')
external ChartBridge get chartBridge;

@JS()
@anonymous
extension type ChartBridge._(JSObject _) implements JSObject {
  external void receiveFromVue(JSAny message);
  external void sendToVue(JSAny message);
}
```

Flutter usage sketch:

```dart
void bootstrapInterop() {
  chartFlutterUI.update = ((JSAny message) {
    final chartMessage = message as ChartMessage;
    switch (chartMessage.type) {
      case 'INIT_CHART':
        handleInit(chartMessage.payload.cast<ChartInitPayload>());
        break;
      case 'SET_SERIES':
        // ...
        break;
    }
  }).toJS;

  chartBridge.sendToVue(
    ChartMessage(type: 'CHART_READY', payload: jsObjectLiteral({'ready': true})),
  );
}
```

(Actual Dart code will convert JS payloads into `chartlib` models.)

## Sequencing

1. Vue loads iframe → seeds bridge objects.
2. Flutter main() runs → registers `chartFlutterUI.update` → emits `CHART_READY`.
3. Vue receives `CHART_READY` → pushes `INIT_CHART` with initial dataset.
4. Further updates use `SET_SERIES`/`PATCH_SERIES`.
5. Flutter emits user events (`RANGE_SELECTED`, `CANDLE_HOVERED`) via `chartBridge.sendToVue`.

## Future Extensions

- Add binary search helpers on the JS manager for efficient patching.
- Support multiple series (e.g. overlays) by adding `seriesId` to payloads.
- Introduce streaming updates using `MessageChannel` if latency becomes an issue.
