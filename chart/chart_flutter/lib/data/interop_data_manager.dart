import 'dart:async';

import 'package:chartlib/chartlib.dart';

/// Data manager backed by Vue-provided candle data via JS interop.
///
/// Mimics the behaviour of the TypeScript DataManager used in the Vue shell.
/// - Holds an in-memory sorted list of [OHLCData] candles.
/// - Serves the entire dataset once via [loadHistorical].
/// - Streams incremental updates through the realtime callback provided by the
///   chart orchestration layer.
/// - Buffers realtime updates that arrive before the initial historical batch
///   is consumed.
class InteropDataManager implements DataManager {
  InteropDataManager([List<OHLCData> initialCandles = const []]) {
    if (initialCandles.isNotEmpty) {
      replaceSeries(initialCandles);
    }
  }

  final List<OHLCData> _candles = <OHLCData>[];
  final List<OHLCData> _pendingRealtime = <OHLCData>[];

  bool _initialBatchServed = false;
  void Function(OHLCData candle)? _realtimeCallback;

  /// Replace the entire candle series supplied by Vue.
  /// Resets the historical pointer so the next [loadHistorical] call returns
  /// the refreshed dataset.
  void replaceSeries(List<OHLCData> candles) {
    _candles
      ..clear()
      ..addAll(candles);
    _candles.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    _initialBatchServed = false;
  }

  /// Apply incremental updates from Vue.
  ///
  /// Returns `true` when the change set requires a full chart reload
  /// (e.g. candles removed), otherwise the chart can rely solely on realtime
  /// callbacks for incremental updates.
  bool applyPatch({
    required List<OHLCData> upserts,
    List<DateTime> removals = const [],
  }) {
    var requiresReload = false;

    if (removals.isNotEmpty) {
      requiresReload = true;
      final removalEpochs = removals
          .map((dt) => dt.millisecondsSinceEpoch)
          .toSet();
      _candles.removeWhere(
        (candle) =>
            removalEpochs.contains(candle.timestamp.millisecondsSinceEpoch),
      );
      _pendingRealtime.removeWhere(
        (pending) =>
            removalEpochs.contains(pending.timestamp.millisecondsSinceEpoch),
      );
    }

    if (upserts.isEmpty) {
      return requiresReload;
    }

    for (final candle in upserts) {
      final timestamp = candle.timestamp.millisecondsSinceEpoch;
      final existingIndex = _candles.indexWhere(
        (existing) => existing.timestamp.millisecondsSinceEpoch == timestamp,
      );

      if (existingIndex >= 0) {
        _candles[existingIndex] = candle;
      } else {
        _candles.add(candle);
      }

      if (!requiresReload) {
        _queueRealtime(candle);
      }
    }

    _candles.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return requiresReload;
  }

  /// Provide a snapshot copy of the managed candles.
  List<OHLCData> snapshot() => List<OHLCData>.unmodifiable(_candles);

  @override
  Future<HistoricalBatch> loadHistorical() async {
    final candles = List<OHLCData>.from(_candles);
    final wasFirstBatch = !_initialBatchServed;
    _initialBatchServed = true;

    // Flush any buffered realtime updates on the next microtask so the chart
    // has already processed the initial batch when updates arrive.
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

  void _queueRealtime(OHLCData candle) {
    if (_initialBatchServed && _realtimeCallback != null) {
      _realtimeCallback?.call(candle);
    } else {
      _pendingRealtime.removeWhere(
        (pending) =>
            pending.timestamp.millisecondsSinceEpoch ==
            candle.timestamp.millisecondsSinceEpoch,
      );
      _pendingRealtime.add(candle);
    }
  }
}
