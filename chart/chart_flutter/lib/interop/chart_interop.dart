import 'dart:js_interop';

import 'package:chartlib/chartlib.dart';
import 'package:flutter/foundation.dart';

import '../data/interop_data_manager.dart';
import 'chart_bridge.dart';
import 'chart_js_bindings.dart';

/// View model representing the current chart configuration for Flutter UI.
class ChartViewModel {
  const ChartViewModel({
    required this.dataManager,
    required this.theme,
    this.viewport,
    required this.revision,
  });

  final DataManager dataManager;
  final ChartTheme theme;
  final ChartViewport? viewport;
  final int revision;
}

/// Viewport hint supplied by Vue.
class ChartViewport {
  const ChartViewport({required this.start, required this.end});

  final DateTime start;
  final DateTime end;
}

class ChartInterop {
  ChartInterop({bool enableJsInterop = kIsWeb})
    : _enableJsInterop = enableJsInterop,
      _bridge = ChartBridge(enableJsInterop: enableJsInterop) {
    _setupHandlers();
  }

  final bool _enableJsInterop;
  final ChartBridge _bridge;
  final ValueNotifier<ChartViewModel?> viewModel = ValueNotifier(null);

  InteropDataManager? _interopDataManager;
  ChartTheme _currentTheme = themes['dark'] ?? darkTheme;
  ChartViewport? _currentViewport;
  int _dataRevision = 0;
  int? _lastViewportStartMs;
  int? _lastViewportEndMs;
  int? _lastHoverTimeMs;
  double? _lastHoverPrice;
  int? _lastHoverCandleMs;

  void dispose() {
    viewModel.dispose();
  }

  void _setupHandlers() {
    _bridge.on('INIT_CHART', _handleInitChart);
    _bridge.on('SET_SERIES', _handleSetSeries);
    _bridge.on('PATCH_SERIES', _handlePatchSeries);
    _bridge.on('SET_THEME', _handleSetTheme);
  }

  void bootstrap() {
    if (!_enableJsInterop) {
      return;
    }
    _bridge.sendToVue('CHART_READY', {'ready': true});
  }

  void _handleInitChart(JSAny? payload) {
    if (payload == null) {
      return;
    }

    try {
      final initPayload = payload as ChartInitPayload;
      final candles = _convertCandles(initPayload.series);
      _currentTheme = _resolveTheme(initPayload.theme);
      _currentViewport = _parseViewport(initPayload.viewport);
      _interopDataManager = InteropDataManager(candles);
      _publishViewModel(resetRevision: true);
    } catch (error) {
      // Silently ignore malformed payloads.
    }
  }

  void _handleSetSeries(JSAny? payload) {
    if (payload == null) {
      return;
    }

    try {
      final seriesPayload = payload as ChartSeriesPayload;
      final candles = _convertCandles(seriesPayload.series);
      _interopDataManager = InteropDataManager(candles);
      _publishViewModel(resetRevision: true);
    } catch (error) {
      // Silently ignore malformed payloads.
    }
  }

  void _handlePatchSeries(JSAny? payload) {
    if (payload == null) {
      return;
    }

    if (_interopDataManager == null) {
      return;
    }

    try {
      final patchPayload = payload as ChartPatchPayload;
      final upserts = _convertCandles(patchPayload.upserts);
      final removals = _convertRemovalTimestamps(patchPayload.removals);
      final requiresReload = _interopDataManager!.applyPatch(
        upserts: upserts,
        removals: removals,
      );
      if (requiresReload) {
        final snapshot = _interopDataManager!.snapshot();
        _interopDataManager = InteropDataManager(snapshot);
        _publishViewModel(bumpRevision: true);
      }
    } catch (error) {
      // Silently ignore malformed payloads.
    }
  }

  void _handleSetTheme(JSAny? payload) {
    if (payload == null) {
      return;
    }

    try {
      final themePayload = payload as ChartThemePayload;
      final nextTheme = _resolveTheme(themePayload.theme);
      if (identical(_currentTheme, nextTheme)) {
        return;
      }
      _currentTheme = nextTheme;
      _publishViewModel();
    } catch (error) {
      // Silently ignore malformed payloads.
    }
  }

  void onChartInitialized() {
    // Retained for compatibility with ChartWidget's callback without additional side-effects.
  }

  void _publishViewModel({
    bool bumpRevision = false,
    bool resetRevision = false,
  }) {
    final manager = _interopDataManager;
    if (manager == null) {
      viewModel.value = null;
      return;
    }

    if (resetRevision || bumpRevision) {
      _dataRevision += 1;
    }

    viewModel.value = ChartViewModel(
      dataManager: manager,
      theme: _currentTheme,
      viewport: _currentViewport,
      revision: _dataRevision,
    );
  }

  void sendViewportRange(DateTime start, DateTime end) {
    if (!_enableJsInterop) {
      return;
    }

    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;

    if (_lastViewportStartMs == startMs && _lastViewportEndMs == endMs) {
      return;
    }

    _lastViewportStartMs = startMs;
    _lastViewportEndMs = endMs;

    _bridge.sendToVue('RANGE_SELECTED', {
      'startTime': startMs,
      'endTime': endMs,
    });
  }

  void sendHoverUpdate({DateTime? time, double? price, OHLCData? candle}) {
    if (!_enableJsInterop) {
      return;
    }

    if (time == null) {
      if (_lastHoverTimeMs != null) {
        _lastHoverTimeMs = null;
        _lastHoverPrice = null;
        _lastHoverCandleMs = null;
        _bridge.sendToVue('CANDLE_HOVERED', null);
      }
      return;
    }

    final timeMs = time.millisecondsSinceEpoch;
    final candleMs = candle?.timestamp.millisecondsSinceEpoch;
    final priceValue = price?.isFinite == true ? price : null;

    if (_lastHoverTimeMs == timeMs &&
        _lastHoverPrice == priceValue &&
        _lastHoverCandleMs == candleMs) {
      return;
    }

    _lastHoverTimeMs = timeMs;
    _lastHoverPrice = priceValue;
    _lastHoverCandleMs = candleMs;

    final payload = <String, dynamic>{
      'time': timeMs,
      if (priceValue != null) 'price': priceValue,
      if (candle != null) 'candle': _serializeCandle(candle),
    };

    _bridge.sendToVue('CANDLE_HOVERED', payload);
  }

  List<OHLCData> _convertCandles(JSArray<CandleDTO> jsArray) {
    final candles = <OHLCData>[];
    for (var i = 0; i < jsArray.length; i++) {
      final dto = jsArray[i];
      candles.add(_toOHLC(dto));
    }
    candles.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return candles;
  }

  OHLCData _toOHLC(CandleDTO dto) {
    final volumeValue = dto.volume;
    return OHLCData(
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        dto.time.toInt(),
        isUtc: true,
      ),
      open: dto.open.toDouble(),
      high: dto.high.toDouble(),
      low: dto.low.toDouble(),
      close: dto.close.toDouble(),
      volume: volumeValue == null ? 0 : volumeValue.toDouble(),
    );
  }

  List<DateTime> _convertRemovalTimestamps(JSArray<JSNumber>? removalArray) {
    if (removalArray == null) {
      return const [];
    }

    final removals = <DateTime>[];
    for (var i = 0; i < removalArray.length; i++) {
      final timestamp = removalArray[i].toDartDouble.toInt();
      removals.add(DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true));
    }
    return removals;
  }

  ChartTheme _resolveTheme(String? themeKey) {
    if (themeKey == null) {
      return themes['dark'] ?? darkTheme;
    }
    return themes[themeKey] ?? darkTheme;
  }

  ChartViewport? _parseViewport(JSObject? rawViewport) {
    if (rawViewport == null) {
      return null;
    }

    try {
      final viewport = rawViewport as ChartViewportPayload;
      return ChartViewport(
        start: DateTime.fromMillisecondsSinceEpoch(
          viewport.startTime.toInt(),
          isUtc: true,
        ),
        end: DateTime.fromMillisecondsSinceEpoch(
          viewport.endTime.toInt(),
          isUtc: true,
        ),
      );
    } catch (error) {
      return null;
    }
  }

  Map<String, dynamic> _serializeCandle(OHLCData candle) {
    return {
      'time': candle.timestamp.millisecondsSinceEpoch,
      'open': candle.open,
      'high': candle.high,
      'low': candle.low,
      'close': candle.close,
      'volume': candle.volume,
      if (candle.oi != null) 'oi': candle.oi,
    };
  }
}
