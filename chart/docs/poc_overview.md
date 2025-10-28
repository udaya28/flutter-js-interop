# Flutter Chart JS Interop POC Guide

Welcome! This document explains the changes introduced in the current proof of concept (POC) and walks through how the Vue + Flutter chart integration works end to end. It is meant to be a newcomer's fast track: use it to understand the architecture, the data flow, and the dev workflow without having to reverse engineer the code base.

---

## At a Glance

- Vue hosts the application shell while the Flutter chart renders inside an iframe served from `public/flutter/`.
- All candle data is owned by JavaScript. Vue keeps a single candle array that lives in the iframe realm so Flutter can read it without copies.
- A TypeScript `ChartSimulator` runs entirely on the JS side to generate live ticks, keeping Flutter focused on rendering.
- Messages travel over a tiny bridge (`window.ChartFlutterUI.update` → Flutter, `window.ChartBridge.receiveFromFlutter` → Vue) with a documented DTO contract.
- Flutter converts the shared JS candle array into `chartlib` data structures through `ChartController` and redraws the chart.

---

## Key Changes Introduced in This POC

1. **JS-first data ownership** – Added `chart/web/src/interop/chartDataManager.ts` so Vue creates and mutates the candle array inside the iframe window. Flutter now consumes data that already lives in JS memory, mirroring the todo POC pattern.
2. **Realtime simulator in TypeScript** – Implemented `chart/web/src/interop/chartSimulator.ts` plus UI controls in `Chart.vue`. This replaces Flutter-side simulators and keeps interop messages identical to production feeds.
3. **Bridge bootstrap & handshake** – `Chart.vue` now mounts the iframe, installs `ChartBridge`, waits for `ChartFlutterUI.update`, and only then publishes `INIT_CHART`, eliminating race conditions seen in earlier experiments.
4. **Bidirectional events** – `chart/chart_flutter/lib/interop/chart_interop.dart` gained handlers for incoming messages and emits `RANGE_SELECTED` / `CANDLE_HOVERED` back to Vue through the bridge.
5. **Shared chart packages wired up** – Flutter renders the real `chartwidget` stack (candles, studies, zoom/pan) using the JS-managed `ChartController`, giving parity with the previous standalone POC.
6. **Docs & contracts** – Message schemas live in `chart/docs/interop_contract.md`, and this overview ties the moving pieces together for new contributors.

---

## Directory Cheat Sheet

| Path                                  | Purpose                                                                                               |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `chart/web/src/pages/Chart.vue`       | Vue route that mounts the Flutter iframe, exposes simulator controls, and owns the interop lifecycle. |
| `chart/web/src/interop/`              | TypeScript bridge pieces (`chartDataManager`, `chartSimulator`, `chartBridge`, DTO types).            |
| `chart/web/src/demo/dataSimulator.ts` | Deterministic OHLC generator reused by both demo seed data and the realtime simulator.                |
| `chart/chart_flutter/lib/interop/`    | Flutter JS-interop layer (`ChartInterop`, bridge helpers, DTO bindings).                              |
| `chart/chart_flutter/lib/view/`       | Flutter UI hierarchy (`ChartRoot`, widgets, ValueListenable wiring).                                  |
| `chart/docs/interop_contract.md`      | Formal JSON contract for every interop message.                                                       |
| `chart/build-flutter.sh`              | Convenience script that builds Flutter Web into `chart/web/public/flutter/`.                          |

---

## How the Interop Works

### 1. Bootstrapping the iframe (Vue → Flutter)

1. User opens the `/chart` route. `Chart.vue` mounts and creates an `<iframe>` pointing at `/flutter/index.html`.
2. Once the iframe loads, Vue grabs `iframe.contentWindow` and calls `ensureChartBridge`, which:
   - Ensures `window.ChartFlutterUI` exists with an `update` callback placeholder.
   - Installs a `ChartDataManager` that keeps the shared candle array.
3. Vue preloads historical candles using `generateDemoCandles`, seeds the manager via `setSeries`, and stores the array instance for future patches.
4. Vue installs `initializeChartBridge`, exposing `window.ChartBridge.receiveFromFlutter` so Dart can call back into JS.
5. Vue polls until Flutter has registered `ChartFlutterUI.update`. When available, it emits the initial `INIT_CHART` message (theme + series + viewport) followed by `SET_SERIES` to guarantee Flutter reads the shared array.

### 2. JS data plane

- `ChartDataManager` owns:
  - `setSeries` – replaces the candle array contents while preserving the array identity (important for Dart `JSArray` reads).
  - `patchSeries` – applies removals/upserts and notifies Flutter with the same payload.
- Both methods forward messages through `ChartFlutterUI.update`, so the bridge behaves exactly like previous POCs where Flutter waited for external feeds.

### 3. Realtime simulator

- `ChartSimulator` exposes `configure`, `start`, `stop`, `reset`, and `disable`.
- It tracks state (`ChartSimulatorState`) and notifies listeners (the Vue page) of status changes so the UI can enable/disable controls.
- Tick loop:
  1. Each interval recalculates price using configurable volatility profiles.
  2. Updates the in-flight candle and calls `ChartDataManager.patchSeries` with a single-candle upsert.
  3. Rolls to a fresh candle after `ticksPerCandle` ticks, ensuring the array only ever grows by one element per completed candle.

### 4. Flutter ingestion & rendering

- `ChartInterop` listens for `INIT_CHART`, `SET_SERIES`, `PATCH_SERIES`, and `SET_THEME`.
- Incoming JS DTOs are converted into `OHLCData` via `ChartController`, which feeds the shared `DataManager` used by `chartwidget`.
- A `ValueNotifier` (`viewModel`) carries the latest theme + data pointer. `ChartRoot` binds this to the actual widget tree.
- When Flutter needs to send information back (viewport changes, hover updates) it calls `_bridge.sendToVue`, which serializes the payload and invokes `window.ChartBridge.receiveFromFlutter` inside the iframe.
- Vue currently logs these messages; wiring them into stores/UI is trivial because the data already arrives in TypeScript.

### 5. Message contract essentials

Refer to `chart/docs/interop_contract.md` for the full schema. The most important payloads are:

- `INIT_CHART` `{ theme, series, viewport }`
- `SET_SERIES` `{ series }`
- `PATCH_SERIES` `{ upserts, removals }`
- `CHART_READY` `{ ready: true }` (Flutter → Vue)
- `RANGE_SELECTED` `{ startTime, endTime }` (Flutter → Vue)
- `CANDLE_HOVERED` `{ time, price?, candle? }` (Flutter → Vue)

Every timestamp is milliseconds since epoch. Candles use UTC to avoid timezone drift.

---

## Running the POC Locally

1. **Install dependencies**

   ```bash
   cd chart/web
   pnpm install
   ```

2. **Build the Flutter artefacts** (any time Dart code changes)

   ```bash
   cd ../
   ./build-flutter.sh
   ```

   This drops the web build into `chart/web/public/flutter/`.

3. **Start the Vue dev server**

   ```bash
   cd web
   pnpm dev
   ```

   Visit `http://localhost:5173/#/chart` to load the POC.

4. **Optional: rebuild Flutter automatically** – use `flutter run -d web-server` or a custom watch script if you need rapid iteration, then copy the build output into `public/flutter/`.

---

## Simulator & Control Panel Walkthrough

- Controls in the left panel map 1:1 to `ChartSimulatorConfig` (volatility, candle duration, ticks/sec, initial price, historical depth, auto-start).
- `Configure` applies the selected options and loads a fresh historical series.
- `Start`/`Stop` toggle the realtime loop. `Reset` rebuilds the historical window using existing config and resumes the previous running state.
- `Disable` returns the chart to static demo mode by repushing the pre-generated series and halting the simulator entirely.
- Status pill above the controls shows `mode · running-state · readiness` so you know if Flutter has acknowledged the bridge.

---

## Flutter Side Highlights

- `chart/chart_flutter/lib/interop/chart_interop.dart`
  - Maintains the current theme, viewport, and data revision.
  - Deduplicates viewport/hover events to avoid noisy message spam.
  - Converts JS arrays into `OHLCData` while keeping everything sorted.
- `chart/chart_flutter/lib/view/chart_root.dart`
  - Listens to the interop view model and rebuilds the chart when the revision increments.
  - Forwards pointer interactions (hover, zoom) back into the interop layer.
- `ChartController` (in `lib/data/chart_controller.dart`)
  - Bridges the JS-managed candles with the `chartlib` `DataManager`, handling patches and full reloads.

---

## Extending the POC

- **Adding a new message from Vue → Flutter**

  1. Define the payload type in `chartContracts.ts` and `chart_js_bindings.dart`.
  2. Send it via `notifyFlutter` (Vue) and handle it in `ChartInterop._setupHandlers` (Flutter).

- **Surfacing a new event from Flutter → Vue**

  1. Emit it inside Flutter using `_bridge.sendToVue('EVENT_NAME', payload)`.
  2. Handle it in `Chart.vue` inside the `initializeChartBridge` callback and route it to a store or component.

- **Feeding real market data**

  - Swap `ChartSimulator` calls with your transport (WebSocket, HTTP polling) and continue using `ChartDataManager.setSeries` / `.patchSeries` to keep Flutter in sync.

- **Sharing state with other Vue pages**
  - Move simulator state into a Pinia store or composable and reuse it elsewhere. The bridge remains the same; just pass the store-driven callbacks into `Chart.vue`.

---

## Validation Checklist

Use this quick runbook after making changes:

- [ ] `./build-flutter.sh` succeeds and regenerates `public/flutter/`.
- [ ] `pnpm dev` (in `chart/web`) launches without TypeScript or Vite errors.
- [ ] Visiting the chart route shows demo candles immediately.
- [ ] Clicking `Configure` + `Start` begins streaming ticks (notice candle updates).
- [ ] Hovering and panning the chart logs `CANDLE_HOVERED` and `RANGE_SELECTED` in the browser console.
- [ ] `ChartSimulator` controls remain responsive (Stop/Reset/Disable work as expected).

---

## Further Reading

- [`chart/docs/interop_contract.md`](./interop_contract.md) – DTO reference shared with Flutter.
- [`chart/docs/implementation_plan.md`](./implementation_plan.md) – Original task breakdown and acceptance criteria.
- Flutter packages under `chart/chart_flutter/packages/chartlib` and `chartwidget` for rendering internals.

If you spot gaps or have ideas for improvement, add them as follow-up notes in this directory so future contributors stay aligned. Happy hacking!
