/// OHLC Candle data structure
/// Ported from src/chartlib/shapes/candle.ts

class OHLCCandle {
  const OHLCCandle({
    required this.timestamp,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume,
  });

  final DateTime timestamp;
  final double open;
  final double high;
  final double low;
  final double close;
  final double? volume;

  /// Check if candle is bullish (close >= open)
  bool get isBullish => close >= open;

  /// Check if candle is bearish (close < open)
  bool get isBearish => close < open;

  /// Body size (absolute difference between open and close)
  double get bodySize => (close - open).abs();

  /// Upper wick size
  double get upperWick => high - (isBullish ? close : open);

  /// Lower wick size
  double get lowerWick => (isBullish ? open : close) - low;

  @override
  String toString() =>
      'OHLCCandle(timestamp: $timestamp, O: $open, H: $high, L: $low, C: $close, V: $volume)';
}
