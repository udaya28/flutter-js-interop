import 'dart:async';

import 'package:chartlib/chartlib.dart';

/// Chart controller backed by Vue-provided candle data via JS interop.
///
/// Mirrors the legacy TimeSeriesStore contract so naming and behaviour stay
/// aligned with the previous POC. Maintains an internal [TimeSeriesStore]
/// instance for sorting and change notifications while still satisfying the
/// [DataManager] interface expected by chart orchestration.
class ChartController implements DataManager {
  ChartController([List<OHLCData> initialCandles = const []]) {
    _store.setOnChange(_handleStoreChange);
    if (initialCandles.isNotEmpty) {
      reset(initialCandles);
    }
  }

  final TimeSeriesStore _store = TimeSeriesStore();
  final List<OHLCData> _pendingRealtime = <OHLCData>[];

  bool _initialBatchServed = false;
  void Function(OHLCData candle)? _realtimeCallback;
  TimeSeriesChangeCallback? _externalOnChange;

  /// Match the TimeSeriesStore API so existing orchestration code can observe
  /// store changes directly.
  void setOnChange(TimeSeriesChangeCallback callback) {
    _externalOnChange = callback;
  }

  /// Reset the entire candle series (full data reload from JS shell).
  void reset(List<OHLCData> candles) {
    _pendingRealtime.clear();
    _store.reset(candles);
    _initialBatchServed = false;
  }

  /// Prepend additional historical candles (load-more scenario).
  void prepend(List<OHLCData> candles) {
    _store.prepend(candles);
    _initialBatchServed = false;
  }

  /// Add or update the most recent candle (real-time tick).
  void add(OHLCData candle) {
    _store.add(candle);
  }

  /// Retrieve a snapshot of all stored candles.
  List<OHLCData> getAll() {
    return List<OHLCData>.from(_store.getAll());
  }

  @override
  Future<HistoricalBatch> loadHistorical() async {
    final candles = List<OHLCData>.from(_store.getAll());
    final wasFirstBatch = !_initialBatchServed;
    _initialBatchServed = true;

    if (wasFirstBatch &&
        _pendingRealtime.isNotEmpty &&
        _realtimeCallback != null) {
      final updates = List<OHLCData>.from(_pendingRealtime);
      _pendingRealtime.clear();
      scheduleMicrotask(() {
        for (final candle in updates) {
          _realtimeCallback?.call(candle);
        }
      });
    }

    return HistoricalBatch(candles: candles, hasMore: false);
  }

  @override
  void onRealtimeUpdate(void Function(OHLCData candle) callback) {
    _realtimeCallback = callback;

    if (_initialBatchServed && _pendingRealtime.isNotEmpty) {
      final updates = List<OHLCData>.from(_pendingRealtime);
      _pendingRealtime.clear();
      for (final candle in updates) {
        _realtimeCallback?.call(candle);
      }
    }
  }

  void _handleStoreChange(TimeSeriesChangeType changeType) {
    switch (changeType) {
      case TimeSeriesChangeType.append:
      case TimeSeriesChangeType.update:
        final candles = _store.getAll();
        if (candles.isNotEmpty) {
          _queueRealtime(candles.last);
        }
        break;
      case TimeSeriesChangeType.reset:
      case TimeSeriesChangeType.prepend:
        _initialBatchServed = false;
        break;
    }

    _externalOnChange?.call(changeType);
  }

  void _queueRealtime(OHLCData candle) {
    final timestamp = candle.timestamp.millisecondsSinceEpoch;
    _pendingRealtime.removeWhere(
      (pending) => pending.timestamp.millisecondsSinceEpoch == timestamp,
    );

    if (_initialBatchServed && _realtimeCallback != null) {
      _realtimeCallback!.call(candle);
    } else {
      _pendingRealtime.add(candle);
    }
  }
}
