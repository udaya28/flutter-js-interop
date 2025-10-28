/// Sample data manager for testing and demos.
/// Provides in-memory OHLC data with configurable batch sizes.

import 'dart:math' as math;
import 'package:chartlib/chartlib.dart';

/// In-memory data manager for testing.
/// Provides sample OHLC data in batches.
class SampleDataManager implements DataManager {
  final List<OHLCData> _allData;
  int _loadedCount = 0;
  final int _batchSize;

  /// Callback for realtime updates (not used in sample data)
  void Function(OHLCData candle)? _realtimeCallback;

  /// Create a sample data manager with pre-generated data.
  ///
  /// @param data - All OHLC data (will be served in batches)
  /// @param batchSize - Number of candles to load per batch (default: 100)
  SampleDataManager(this._allData, {int batchSize = 100})
    : _batchSize = batchSize;

  /// Create a sample data manager with generated sine wave data.
  ///
  /// Useful for quick testing without real market data.
  factory SampleDataManager.generateSineWave({
    int candleCount = 500,
    int batchSize = 100,
  }) {
    final data = <OHLCData>[];
    final basePrice = 100.0;
    final amplitude = 10.0;
    final now = DateTime.now();

    for (int i = 0; i < candleCount; i++) {
      final timestamp = now.subtract(Duration(minutes: candleCount - i));

      // Generate sine wave with some randomness
      final angle = (i / 20.0) * math.pi;
      final sineValue = amplitude * (0.5 + 0.5 * (1.0 + (i % 3) * 0.1));
      final price = basePrice + sineValue * math.sin(angle);

      // Add some candle variation
      final open = price;
      final close = price + (i % 2 == 0 ? 0.5 : -0.5);
      final high = (open > close ? open : close) + 0.3;
      final low = (open < close ? open : close) - 0.3;
      final volume = 1000000.0 + (i % 10) * 100000.0;

      data.add(
        OHLCData(
          timestamp: timestamp,
          open: open,
          high: high,
          low: low,
          close: close,
          volume: volume,
        ),
      );
    }

    return SampleDataManager(data, batchSize: batchSize);
  }

  @override
  Future<HistoricalBatch> loadHistorical() async {
    // print('[SampleDataManager.loadHistorical] Called: _allData.length=${_allData.length}, _loadedCount=$_loadedCount, _batchSize=$_batchSize');

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 100));

    if (_loadedCount >= _allData.length) {
      // No more data
      // print('[SampleDataManager.loadHistorical] No more data to load');
      return HistoricalBatch(candles: [], hasMore: false);
    }

    // Calculate batch range
    final endIndex = (_loadedCount + _batchSize).clamp(0, _allData.length);
    final batch = _allData.sublist(_loadedCount, endIndex);
    _loadedCount = endIndex;

    final hasMore = _loadedCount < _allData.length;

    // print('[SampleDataManager.loadHistorical] Returning batch: ${batch.length} candles, hasMore=$hasMore');

    return HistoricalBatch(candles: batch, hasMore: hasMore);
  }

  @override
  void onRealtimeUpdate(void Function(OHLCData candle) callback) {
    _realtimeCallback = callback;
  }

  /// Simulate a realtime update (for testing).
  /// Adds a new candle to the end of the data.
  void simulateRealtimeUpdate() {
    if (_allData.isEmpty) return;

    final lastCandle = _allData.last;
    final newCandle = OHLCData(
      timestamp: lastCandle.timestamp.add(const Duration(minutes: 1)),
      open: lastCandle.close,
      high: lastCandle.close + 0.5,
      low: lastCandle.close - 0.5,
      close: lastCandle.close + (DateTime.now().second % 2 == 0 ? 0.3 : -0.3),
      volume:
          lastCandle.volume * (0.9 + DateTime.now().millisecond / 1000 * 0.2),
    );

    _allData.add(newCandle);
    _realtimeCallback?.call(newCandle);
  }

  /// Reset the data manager (start loading from beginning again).
  void reset() {
    _loadedCount = 0;
  }

  /// Get the total number of candles in the dataset.
  int get totalCandles => _allData.length;

  /// Get the number of candles loaded so far.
  int get loadedCandles => _loadedCount;
}
