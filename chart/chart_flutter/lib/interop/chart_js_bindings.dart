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
extension type ChartSeriesPayload._(JSObject _) implements JSObject {
  external factory ChartSeriesPayload({JSArray<CandleDTO> series});
  external JSArray<CandleDTO> get series;
}

@JS()
@anonymous
extension type ChartInitPayload._(JSObject _) implements JSObject {
  external factory ChartInitPayload({
    JSArray<CandleDTO> series,
    JSObject? viewport,
    String? theme,
  });

  external JSArray<CandleDTO> get series;
  external JSObject? get viewport;
  external String? get theme;
}

@JS()
@anonymous
extension type ChartMessage._(JSObject _) implements JSObject {
  external factory ChartMessage({String type, JSAny? payload});
  external String get type;
  external JSAny? get payload;
}

@JS()
@anonymous
extension type ChartFlutterUI._(JSObject _) implements JSObject {
  external set update(JSFunction? callback);
}

@JS()
@anonymous
extension type ChartDataManagerJS._(JSObject _) implements JSObject {
  external JSArray<CandleDTO> getSeries();
  external void setSeries(JSArray<CandleDTO> series);
  external void patchSeries(JSObject payload);
}

@JS()
@anonymous
extension type ChartPatchPayload._(JSObject _) implements JSObject {
  external factory ChartPatchPayload({
    JSArray<CandleDTO> upserts,
    JSArray<JSNumber>? removals,
  });

  external JSArray<CandleDTO> get upserts;
  external JSArray<JSNumber>? get removals;
}

@JS()
@anonymous
extension type ChartThemePayload._(JSObject _) implements JSObject {
  external factory ChartThemePayload({String theme});
  external String get theme;
}

@JS()
@anonymous
extension type ChartViewportPayload._(JSObject _) implements JSObject {
  external factory ChartViewportPayload({num startTime, num endTime});

  external num get startTime;
  external num get endTime;
}

@JS()
@anonymous
extension type ChartBridgeJS._(JSObject _) implements JSObject {
  external void receiveFromFlutter(JSAny message);
}

@JS('window.ChartFlutterUI')
external ChartFlutterUI get chartFlutterUI;

@JS('window.ChartDataManager')
external ChartDataManagerJS get chartDataManager;

@JS('window.ChartBridge')
external ChartBridgeJS? get chartBridge;
