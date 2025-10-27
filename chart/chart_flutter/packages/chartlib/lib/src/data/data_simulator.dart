/// Real-time market data simulator for testing and demos.
/// Generates realistic OHLC candles with configurable volatility and duration.
/// Ported from src/ui/testData/dataSimulator.ts

import 'dart:math' as math;
import 'dart:async';
import 'ohlc.dart';
import '../core/candle_definition.dart';

/// Volatility levels for price simulation
enum Volatility {
  low,
  medium,
  high,
}

/// Configuration for DataSimulator
class DataSimulatorConfig {
  const DataSimulatorConfig({
    required this.volatility,
    required this.candleDuration,
    required this.ticksPerSecond,
    this.startPrice = 100.0,
    this.startTime,
  });

  final Volatility volatility;
  final CandleDuration candleDuration;
  final int ticksPerSecond;
  final double startPrice;
  final DateTime? startTime;
}

/// Real-time market data simulator.
/// Generates realistic OHLC candles using random walk with:
/// - Configurable volatility (low/medium/high)
/// - Candle duration support (1m to 1d)
/// - Volume correlation with price movement
/// - Market hours awareness
class DataSimulator {
  DataSimulator(this.config)
      : _random = math.Random(),
        _currentPrice = config.startPrice,
        _lastTimestamp = config.startTime ?? DateTime.now();

  final DataSimulatorConfig config;
  final math.Random _random;

  double _currentPrice;
  DateTime _lastTimestamp;
  Timer? _ticker;
  Function(OHLCData)? _onCandle;

  /// Current candle being built from ticks
  OHLCData? _currentCandle;
  int _tickCount = 0;

  /// Get volatility parameters based on volatility level
  ({double priceChangePercent, double volumeBase, double volumeVariance}) _getVolatilityParams() {
    switch (config.volatility) {
      case Volatility.low:
        return (priceChangePercent: 0.0005, volumeBase: 50000, volumeVariance: 20000);
      case Volatility.medium:
        return (priceChangePercent: 0.001, volumeBase: 100000, volumeVariance: 50000);
      case Volatility.high:
        return (priceChangePercent: 0.002, volumeBase: 200000, volumeVariance: 100000);
    }
  }

  /// Convert CandleDuration to milliseconds
  int candleDurationToMilliseconds(CandleDuration duration) {
    switch (duration) {
      case CandleDuration.oneSecond:
        return 1000;
      case CandleDuration.fiveSeconds:
        return 5 * 1000;
      case CandleDuration.thirtySeconds:
        return 30 * 1000;
      case CandleDuration.oneMinute:
        return 60 * 1000;
      case CandleDuration.fiveMinutes:
        return 5 * 60 * 1000;
      case CandleDuration.fifteenMinutes:
        return 15 * 60 * 1000;
      case CandleDuration.thirtyMinutes:
        return 30 * 60 * 1000;
      case CandleDuration.oneHour:
        return 60 * 60 * 1000;
      case CandleDuration.fourHours:
        return 4 * 60 * 60 * 1000;
      case CandleDuration.oneDay:
        return 24 * 60 * 60 * 1000;
      case CandleDuration.oneWeek:
        return 7 * 24 * 60 * 60 * 1000;
      case CandleDuration.oneMonth:
        return 30 * 24 * 60 * 60 * 1000; // Approximate: 30 days
    }
  }

  /// Calculate volume scaling based on price movement
  double _calculateVolumeScaling(double priceChange, double open) {
    if (open == 0 || open.isNaN || open.isInfinite) return 1.0;
    final changePercent = (priceChange / open).abs();
    if (changePercent.isNaN || changePercent.isInfinite) return 1.0;
    // Higher price movement = higher volume
    return 1.0 + changePercent * 10;
  }

  /// Generate a single candle at given timestamp (forward in time)
  OHLCData generateCandle(DateTime timestamp) {
    final params = _getVolatilityParams();
    final durationMs = candleDurationToMilliseconds(config.candleDuration);

    // Calculate open from current price
    final open = _currentPrice;

    // Generate random walk for high/low/close
    double high = open;
    double low = open;
    double close = open;

    // Simulate multiple ticks within the candle duration
    final ticksInCandle = 20; // Simulate 20 price movements per candle
    for (int i = 0; i < ticksInCandle; i++) {
      final change = (_random.nextDouble() - 0.5) * 2 * params.priceChangePercent * close;
      close += change;

      // Update high/low
      if (close > high) high = close;
      if (close < low) low = close;
    }

    // Ensure high >= max(open, close) and low <= min(open, close)
    high = math.max(high, math.max(open, close));
    low = math.min(low, math.min(open, close));

    // Generate volume based on price movement
    final priceChange = (close - open).abs();
    final volumeScaling = _calculateVolumeScaling(priceChange, open);
    final baseVolume = params.volumeBase + (_random.nextDouble() - 0.5) * params.volumeVariance;
    var volume = baseVolume * volumeScaling;

    // Ensure volume is valid
    if (volume.isNaN || volume.isInfinite || volume < 0) {
      volume = params.volumeBase;
    }

    // Update current price for next candle
    _currentPrice = close;

    return OHLCData(
      timestamp: timestamp,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
    );
  }

  /// Generate a single candle backwards in time
  OHLCData generateCandleBackwards(DateTime timestamp) {
    final params = _getVolatilityParams();

    // For backwards generation, work from current price
    final close = _currentPrice;

    // Generate random walk backwards
    double high = close;
    double low = close;
    double open = close;

    // Simulate multiple ticks
    final ticksInCandle = 20;
    for (int i = 0; i < ticksInCandle; i++) {
      final change = (_random.nextDouble() - 0.5) * 2 * params.priceChangePercent * open;
      open += change;

      // Update high/low
      if (open > high) high = open;
      if (open < low) low = open;
    }

    // Ensure high/low bounds
    high = math.max(high, math.max(open, close));
    low = math.min(low, math.min(open, close));

    // Generate volume
    final priceChange = (close - open).abs();
    final volumeScaling = _calculateVolumeScaling(priceChange, open);
    final baseVolume = params.volumeBase + (_random.nextDouble() - 0.5) * params.volumeVariance;
    var volume = baseVolume * volumeScaling;

    // Ensure volume is valid
    if (volume.isNaN || volume.isInfinite || volume < 0) {
      volume = params.volumeBase;
    }

    // Update current price for next backwards candle
    _currentPrice = open;

    return OHLCData(
      timestamp: timestamp,
      open: open,
      high: high,
      low: low,
      close: close,
      volume: volume,
    );
  }

  /// Generate historical candles (backwards from start time)
  /// Returns candles in chronological order (oldest first)
  Future<List<OHLCData>> generateHistoricalCandles(int count) async {
    final candles = <OHLCData>[];
    final durationMs = candleDurationToMilliseconds(config.candleDuration);

    // Generate backwards from lastTimestamp
    DateTime currentTime = _lastTimestamp;

    for (int i = 0; i < count; i++) {
      // Move back one candle duration
      currentTime = currentTime.subtract(Duration(milliseconds: durationMs));

      final candle = generateCandleBackwards(currentTime);
      candles.add(candle);

      // Simulate loading delay every 100 candles
      if (i > 0 && i % 100 == 0) {
        await Future.delayed(const Duration(milliseconds: 10));
      }
    }

    // Reverse to get chronological order (oldest first)
    final chronological = candles.reversed.toList();

    // Reset current price to the close of the last historical candle
    if (chronological.isNotEmpty) {
      _currentPrice = chronological.last.close;
    }

    return chronological;
  }

  /// Start real-time tick generation
  /// Calls onCandle callback when a complete candle is formed
  void startTicker(Function(OHLCData) onCandle) {
    _onCandle = onCandle;
    _currentCandle = null;
    _tickCount = 0;

    final tickInterval = Duration(milliseconds: (1000 / config.ticksPerSecond).round());

    _ticker = Timer.periodic(tickInterval, (timer) {
      _generateTick();
    });
  }

  /// Stop real-time tick generation
  void stopTicker() {
    _ticker?.cancel();
    _ticker = null;
    _onCandle = null;
    _currentCandle = null;
    _tickCount = 0;
  }

  /// Generate a single tick and update current candle
  void _generateTick() {
    final now = DateTime.now();
    final durationMs = candleDurationToMilliseconds(config.candleDuration);
    final candleStartTime = _getCandleStartTime(now, durationMs);

    // Check if we need to start a new candle
    if (_currentCandle == null || _currentCandle!.timestamp != candleStartTime) {
      // Emit previous candle if exists
      if (_currentCandle != null && _onCandle != null) {
        _onCandle!(_currentCandle!);
      }

      // Start new candle
      _currentCandle = OHLCData(
        timestamp: candleStartTime,
        open: _currentPrice,
        high: _currentPrice,
        low: _currentPrice,
        close: _currentPrice,
        volume: 0,
      );
      _tickCount = 0;
    }

    // Generate price tick
    final params = _getVolatilityParams();
    final change = (_random.nextDouble() - 0.5) * 2 * params.priceChangePercent * _currentPrice;
    _currentPrice += change;

    // Update current candle
    final high = math.max(_currentCandle!.high, _currentPrice);
    final low = math.min(_currentCandle!.low, _currentPrice);
    final priceChange = (_currentPrice - _currentCandle!.open).abs();
    final volumeScaling = _calculateVolumeScaling(priceChange, _currentCandle!.open);
    var tickVolume = params.volumeBase / 100 * volumeScaling; // ~1% of base volume per tick

    // Ensure tick volume is valid
    if (tickVolume.isNaN || tickVolume.isInfinite || tickVolume < 0) {
      tickVolume = params.volumeBase / 100;
    }

    _currentCandle = OHLCData(
      timestamp: _currentCandle!.timestamp,
      open: _currentCandle!.open,
      high: high,
      low: low,
      close: _currentPrice,
      volume: _currentCandle!.volume + tickVolume,
    );

    _tickCount++;

    // IMPORTANT: Emit current candle on EVERY tick (not just on new candle)
    // This allows the chart to show real-time price updates within the candle
    // TimeSeriesStore will determine if this is an UPDATE (same timestamp) or APPEND (new timestamp)
    if (_onCandle != null) {
      _onCandle!(_currentCandle!);
    }

    // Update last timestamp
    _lastTimestamp = now;
  }

  /// Get candle start time by truncating to candle boundary
  DateTime _getCandleStartTime(DateTime time, int durationMs) {
    final ms = time.millisecondsSinceEpoch;
    final truncated = (ms ~/ durationMs) * durationMs;
    return DateTime.fromMillisecondsSinceEpoch(truncated);
  }

  /// Check if market is open (for NSE or other markets)
  /// Currently returns true (24/7 crypto-style)
  bool isMarketOpen(DateTime time) {
    // TODO: Implement market hours checking
    // For now, simulate 24/7 market (crypto-style)
    return true;
  }

  /// Get current price
  double getCurrentPrice() => _currentPrice;

  /// Get current candle (partially formed)
  OHLCData? getCurrentCandle() => _currentCandle;

  /// Get tick count in current candle
  int getTickCount() => _tickCount;

  /// Dispose resources
  void dispose() {
    stopTicker();
  }
}
