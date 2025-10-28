import 'dart:async';
import 'dart:js_interop';

import 'package:chartlib/chartlib.dart' hide ChartController;
import 'package:flutter/foundation.dart';

import '../data/chart_controller.dart';
import 'chart_bridge.dart';
import 'chart_js_bindings.dart';

/// View model representing the current chart configuration for Flutter UI.
class ChartViewModel {
  const ChartViewModel({
    required this.dataManager,
    required this.theme,
    required this.revision,
  });

  final DataManager dataManager;
  final ChartTheme theme;
  final int revision;
}

class ChartInterop {
  ChartInterop({bool enableJsInterop = kIsWeb})
    : _enableJsInterop = enableJsInterop,
      _bridge = ChartBridge(enableJsInterop: enableJsInterop),
      _chartController = ChartController() {
    _publishViewModel(resetRevision: true);
    _ensureJsCallbacks();
  }

  final bool _enableJsInterop;
  final ChartBridge _bridge;
  final ValueNotifier<ChartViewModel?> viewModel = ValueNotifier(null);

  final ChartController _chartController;
  ChartTheme _currentTheme = themes['dark'] ?? darkTheme;
  int _dataRevision = 0;
  bool _callbacksRegistered = false;
  JSFunction? _historicalJsHandler;
  JSFunction? _realtimeJsHandler;

  void dispose() {
    viewModel.dispose();
  }

  void bootstrap() {
    if (!_enableJsInterop) {
      return;
    }
    _bridge.sendToVue('CHART_READY', {'ready': true});
    _ensureJsCallbacks();
  }

  void onChartInitialized() {
    // Retained for compatibility with ChartWidget's callback without additional side-effects.
  }

  void _publishViewModel({bool resetRevision = false}) {
    if (resetRevision) {
      _dataRevision += 1;
    }

    viewModel.value = ChartViewModel(
      dataManager: _chartController,
      theme: _currentTheme,
      revision: _dataRevision,
    );
  }

  void _ensureJsCallbacks() {
    if (_callbacksRegistered || !_enableJsInterop) {
      return;
    }

    final manager = chartDataManager;
    if (manager == null) {
      Future.delayed(const Duration(milliseconds: 100), _ensureJsCallbacks);
      return;
    }

    _bindCallbacks(manager);
  }

  void _bindCallbacks(ChartDataManagerJS manager) {
    _callbacksRegistered = true;

    _historicalJsHandler = ((JSArray<CandleDTO> series) {
      try {
        final candles = _convertCandles(series);
        _chartController.reset(candles);
        _publishViewModel(resetRevision: true);
      } catch (_) {
        // Ignore malformed payloads from JS.
      }
    }).toJS;

    manager.loadHistorical(_historicalJsHandler!);

    _realtimeJsHandler = ((CandleDTO dto) {
      try {
        final candle = _toOHLC(dto);
        _chartController.add(candle);
      } catch (_) {
        // Ignore malformed realtime payloads from JS.
      }
    }).toJS;

    manager.onRealtimeUpdate(_realtimeJsHandler!);
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
}
