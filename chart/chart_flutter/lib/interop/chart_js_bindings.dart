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
extension type ChartDataManagerJS._(JSObject _) implements JSObject {
  external void loadHistorical(JSFunction callback);
  external void onRealtimeUpdate(JSFunction callback);
}

@JS()
@anonymous
extension type ChartBridgeJS._(JSObject _) implements JSObject {
  external void receiveFromFlutter(JSAny message);
}

@JS('window.ChartDataManager')
external ChartDataManagerJS? get chartDataManager;

@JS('window.ChartBridge')
external ChartBridgeJS? get chartBridge;
