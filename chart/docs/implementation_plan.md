# Chart Flutter ↔ Vue Interop Plan

## Context & Goal

- Integrate the Flutter chart web build inside the existing Vue app (under `chart/web`) via an iframe.
- Reuse the patterns from the `todo-app` POC so Vue owns application state while Flutter handles chart rendering.
- Enable Vue to push candle data (and future chart interactions) into the Flutter app on demand.

## Guiding Constraints & References

- Must keep UI and behavior aligned with the `previous_poc` implementation.
- Prefer reusing shared packages already copied into `chart/chart_flutter/packages` for chart visuals.
- Use Flutter JS interop APIs (`dart:js_interop`) instead of deprecated `dart:js`.
- Mirror the JS handshake style used in `todo-app` (`window.TodoFlutterUI`, `window.TodoManager`) but rename to chart-specific bridges to avoid collisions.

## Proposed Architecture

1. **Iframe Loader (Vue):** Vue route mounts an iframe pointing to the Flutter build under `/public/flutter/index.html` (chart build). On load it seeds the iframe `contentWindow` with a bridge object and a data manager instance.
2. **Data Manager (Vue, TypeScript):** Maintains chart data arrays inside the iframe realm. Exposes mutation methods (`setData`, `updateTheme`, etc.) so Vue can control chart state. Notifies Flutter via a callback when data changes.
3. **Flutter Bridge (Dart):** Flutter registers a JS callback (e.g. `ChartFlutterUI.update`) for Vue to notify state changes, and exposes JS-callable methods (`ChartController.requestData`, `ChartController.emitEvent`) for Flutter-originated events.
4. **Chart Rendering (Flutter):** Flutter reads data out of the JS-managed arrays, transforms it into `chartlib` domain objects, and renders via `chartwidget`. Future events (zoom, click, etc.) flow back to Vue via the bridge.

## Tiny, Testable Implementation Steps

### Step 0.1 – Confirm Build Artifacts Layout ✅

- Script `chart/build-flutter.sh` already targets `chart/web/public/flutter` and existing artifacts (`index.html`, `main.dart.js`, wasm, assets) are present under that folder.
- No changes required; rebuild on demand with `./build-flutter.sh`.
- Definition of done: running the script regenerates Flutter web assets and Vue dev server can serve them under `/flutter/`.

### Step 0.2 – Design JS ↔ Dart Message Contracts ✅

- Documented message schema, bridge objects, and TS/Dart type definitions in `docs/interop_contract.md`.
- Contracts cover handshake (`INIT_CHART`, `CHART_READY`), data flow (`SET_SERIES`, `PATCH_SERIES`), and interaction events (`RANGE_SELECTED`, `CANDLE_HOVERED`).
- DoD: schema available for both stacks and ready for implementation.

### Step 0.3 – Implement Chart Data Manager in Vue ✅

- Added `web/src/interop/chartDataManager.ts` reusing the iframe-aware pattern to manage candles and send `SET_SERIES` / `PATCH_SERIES` messages via `ChartFlutterUI.update`.
- Replaced the legacy todo bootstrap in `web/src/pages/Chart.vue` with the new `ensureChartBridge` helper so the iframe seeds `ChartDataManager` on load.
- DoD: manual tests can seed data in the iframe realm and see notifications fire once Flutter registers its callback.

### Step 0.4 – Build Vue Iframe Loader Page ✅

- Enhanced `web/src/pages/Chart.vue` to mount the Flutter iframe, install the `ChartBridge`, and preload demo candles via `ensureChartBridge`.
- Added readiness polling so `INIT_CHART` and `SET_SERIES` fire only after Flutter registers `ChartFlutterUI.update`, avoiding bridge warnings and enabling console verification today.
- DoD: opening the route now shows the iframe, logs `[ChartPage] Flutter bridge ready...` and `[Flutter → Vue]` messages (once Flutter emits them) proving the handshake path without requiring Flutter changes yet.

### Step 0.5 – Scaffold Flutter JS Interop Layer ✅

- Added `chart_flutter/lib/interop/chart_js_bindings.dart`, `chart_bridge.dart`, and `chart_interop.dart` exposing message handlers that log incoming data and emit `CHART_READY` back to Vue.
- Replaced the counter app in `chart_flutter/lib/main.dart` with a lean `ChartApp` that bootstraps the JS bridge before rendering, matching the Vue handshake flow.
- DoD: loading the iframe now triggers Flutter logs (`[ChartInterop] INIT_CHART ...`) confirming payload ingestion.

### Step 0.6 – Connect Data to Chart Widgets ✅

- Replaced the placeholder app with `ChartApp` + `ChartRoot`, wiring a `ValueListenableBuilder` to the interop view model and rendering `ChartWidget` (candles + SMA overlay + volume sub-pane).
- Added `ChartController` so JS payloads become `OHLCData` batches consumed by `DataManager.loadHistorical` and realtime callbacks; ensured patches trigger chart updates and full reloads when removals occur.
- Promoted the interop layer to publish theme + viewport state, injecting the selected `ChartTheme` into Flutter so visuals match Vue configuration.
- DoD: loading the iframe now displays the live chart populated with Vue demo candles immediately after `INIT_CHART` fires.

### Step 0.7 – Event Callbacks Back to Vue ✅

- `ChartWidget` now emits viewport/hover callbacks; panning, zooming, wheel scroll, and realtime data redraws trigger range updates, while `MouseRegion` hover events compute the nearest candle + price using the shared scales.
- `ChartInterop` gained `sendViewportRange` and `sendHoverUpdate`, serializing payloads into the documented DTO shapes and forwarding them to Vue via `ChartBridge` (with duplicate suppression and clean hover-exit handling).
- `ChartRoot` wires the widget callbacks straight into the interop layer, so events surface automatically without additional UI plumbing. Vue continues to receive `ChartMessage` JSON strings and currently logs them for verification.
- DoD: Manual hover and zoom inside the iframe emit `RANGE_SELECTED` / `CANDLE_HOVERED` logs in the Vue shell console, confirming bidirectional communication.

### Step 0.8 – Testing & Tooling

- Add lightweight Vitest spec for the JS manager to validate update firing.
- Add Flutter widget test (if feasible) or integration logs to ensure data ingestion pipeline works.
- Document manual QA checklist in `docs/testing.md` (load iframe, update data, observe chart, verify reverse events).

### Step 0.9 – Documentation & Cleanup

- Update `chart/README.md` with run instructions, data contract reference, and troubleshooting tips.
- Ensure scripts are documented (build, copy assets).
- DoD: README describes end-to-end flow, repo lint/tests pass.

## Assumptions & Open Questions

- Reusing the existing chart packages provides ready-to-use chart widget(s); confirm exported API surface.
- Required chart interactions mirror previous POC — confirm specific event list before Step 0.7.
- Hosting path `/flutter/` is acceptable in production; otherwise adjust router base.

## Verification Strategy

- Each step produces observable behavior (console logs, visible chart, passing tests).
- Maintain parity with `previous_poc` by visually comparing rendered output and interaction logs.
- Plan to request sign-off after Step 0.6 (data flowing end-to-end) before tackling extra interactions.
