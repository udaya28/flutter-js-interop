# Flutter + Vue Todo Interop

This proof of concept shows how a Flutter web application can live inside a Vue 3 single-page app while both sides share state through `dart:js_interop`. The Vue host bootstraps routing, navigation, and the JavaScript bridge; the Flutter build delivers the visual todo experience and reads/writes todos by calling back into the bridge.

## Project layout

```
todo-app/
├─ build-flutter.sh        # Helper to rebuild Flutter for the web and copy assets
├─ todo_flutter/           # Flutter source (built to wasm-optimized web bundle)
└─ web/                    # Vite + Vue shell that loads the Flutter bundle
```

## How the pieces talk to each other

- `web/src/todo.ts` provides a `TodoManagerFlutter` class that stores todos in plain JavaScript arrays and exposes CRUD operations.
- When `/todo` loads, `web/src/pages/Todo.vue` inserts the Flutter bundle inside an iframe, injects the `TodoManager` instance, and plants a `TodoFlutterUI.update` callback placeholder on the iframe window.
- The Flutter side (`todo_flutter/lib/js_interop.dart`) binds to those globals. It calls `TodoManager` to mutate todos and registers its own refresh callback under `TodoFlutterUI.update` so the JS host can notify the Flutter UI whenever data changes.
- `todo_flutter/lib/main.dart` renders the Material todo interface and drives the interop helpers.

## Prerequisites

- Flutter SDK with web support enabled (test with `flutter --version`).
- Node.js 20.19+ (or 22.12+) and npm.

## Getting started

1. Build or refresh the Flutter bundle so the web app can load it:

   ```bash
   ./build-flutter.sh
   ```

   This wraps `flutter build web --base-href=/flutter/` and copies the output to `web/public/flutter`.

2. Install and run the Vue host:

   ```bash
   cd web
   npm install
   npm run dev
   ```

3. Open the Vite dev server URL printed in the terminal (defaults to http://localhost:5173). Visit `/todo` to see the embedded Flutter experience.

## Rebuilding after Flutter changes

Any change inside `todo_flutter/` requires a rebuild so the generated assets in `web/public/flutter` stay in sync:

```bash
./build-flutter.sh
```

Restart the Vite dev server after the build so it serves the refreshed Flutter bundle.

## Production build

To ship a combined build, rebuild Flutter first, then run the Vue production build:

```bash
./build-flutter.sh
cd web
npm run build
```

The static site lands in `web/dist/` and already includes the Flutter bundle under `dist/flutter`.

## Useful scripts

- `flutter test` inside `todo_flutter/` runs Flutter widget tests.
- `npm run lint` and `npm run type-check` inside `web/` keep the Vue side clean.
- `npm run preview` serves the built site locally for smoke testing.
