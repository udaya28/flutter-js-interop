/// Simple time series store for OHLC candle data.
/// Manages candle storage with automatic sorting and change notifications.
/// Ported from src/chartlib/data/timeSeriesStore.ts

import 'ohlc.dart';

/// Change event type for time series data updates.
enum TimeSeriesChangeType {
  /// Last candle updated (same timestamp)
  update,

  /// New candle appended (new timestamp)
  append,

  /// Historical candles prepended
  prepend,

  /// Full data reset
  reset,
}

/// Callback function for time series data changes.
typedef TimeSeriesChangeCallback = void Function(TimeSeriesChangeType changeType);

/// Simple time series store for OHLC candle data.
/// Manages candle storage with automatic sorting and change notifications.
class TimeSeriesStore {
  /// Internal candle storage
  final List<OHLCData> _candles = [];

  /// Change notification callback
  TimeSeriesChangeCallback? _onChange;

  /// Set the change notification callback.
  /// Called whenever data changes via add(), prepend(), or reset().
  ///
  /// @param callback - Function to call on data changes
  void setOnChange(TimeSeriesChangeCallback callback) {
    _onChange = callback;
  }

  /// Add new candle data point (real-time updates).
  /// Automatically determines if this is an update (same timestamp) or append (new timestamp).
  /// Triggers 'update' event if replacing last candle, 'append' if adding new candle.
  ///
  /// @param candle - New candle data point
  void add(OHLCData candle) {
    if (_candles.isEmpty) {
      _candles.add(candle);
      _notify(TimeSeriesChangeType.append);
      return;
    }

    final lastCandle = _candles[_candles.length - 1];
    final timestampsMatch = lastCandle.timestamp.millisecondsSinceEpoch == candle.timestamp.millisecondsSinceEpoch;

    if (timestampsMatch) {
      // Replace last candle - same timestamp
      print('[TimeSeriesStore.add] UPDATE - replacing last candle: close ${lastCandle.close} → ${candle.close}');
      _candles[_candles.length - 1] = candle;
      _notify(TimeSeriesChangeType.update);
    } else {
      // Different timestamp - append new candle
      print('[TimeSeriesStore.add] APPEND - new candle: ${candle.timestamp}');
      _candles.add(candle);
      _notify(TimeSeriesChangeType.append);
    }
  }

  /// Prepend historical candles (load more history).
  /// Sorts all candles after prepending and triggers 'prepend' change event.
  ///
  /// @param candles - Historical candles to prepend
  void prepend(List<OHLCData> candles) {
    _candles.insertAll(0, candles);
    _sort();
    _notify(TimeSeriesChangeType.prepend);
  }

  /// Reset all candles (initial load or full data reload).
  /// Use for initial chart load, symbol changes, or timeframe changes.
  /// Sorts candles by timestamp and triggers 'reset' change event.
  ///
  /// @param candles - Complete candle dataset
  void reset(List<OHLCData> candles) {
    _candles.clear();
    _candles.addAll(candles);
    _sort();
    _notify(TimeSeriesChangeType.reset);
  }

  /// Get all candles.
  ///
  /// @returns All stored candles (direct reference, not a copy)
  List<OHLCData> getAll() {
    return _candles;
  }

  /// Sort candles by timestamp in ascending order.
  void _sort() {
    _candles.sort((a, b) => a.timestamp.millisecondsSinceEpoch.compareTo(b.timestamp.millisecondsSinceEpoch));
  }

  /// Notify change callback if set.
  ///
  /// @param changeType - Type of change that occurred
  void _notify(TimeSeriesChangeType changeType) {
    _onChange?.call(changeType);
  }
}
