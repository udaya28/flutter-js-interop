/// OHLC (Open, High, Low, Close) candle data.
/// Represents a single time period's price action and volume.
/// Ported from src/chartlib/data/ohlc.ts
///
/// NOTE: Timestamps are stored as native DateTime objects in UTC.
/// For timezone-aware display, apply timezone offset at the display layer.

/// OHLC (Open, High, Low, Close) candle data.
/// Represents a single time period's price action and volume.
class OHLCData {
  const OHLCData({
    required this.timestamp,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    this.oi,
  });

  /// Timestamp of the candle (UTC)
  final DateTime timestamp;

  /// Opening price
  final double open;

  /// Highest price during the period
  final double high;

  /// Lowest price during the period
  final double low;

  /// Closing price
  final double close;

  /// Trading volume
  final double volume;

  /// Open interest (optional, for derivatives)
  final double? oi;
}

/// Generic computed data point with timestamp and calculated value.
/// Used by studies to store calculated indicator values.
///
/// NOTE: Timestamps are stored as native DateTime objects in UTC.
class ComputedDataPoint<T> {
  const ComputedDataPoint({
    required this.timestamp,
    required this.value,
    required this.index,
  });

  /// Timestamp of the data point (UTC)
  final DateTime timestamp;

  /// Calculated value
  final T value;

  /// Index in the full candle array (for O(1) coordinate lookups)
  final int index;
}
