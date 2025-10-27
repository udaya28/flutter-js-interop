/// DataManager implementation using DataSimulator.
/// Provides on-demand generated OHLC data with real-time simulation.
/// Ported from src/ui/testData/simulatorDataManager.ts

import 'dart:async';
import 'data_manager.dart';
import 'data_simulator.dart';
import 'ohlc.dart';

/// DataManager implementation wrapping DataSimulator.
///
/// Usage:
/// ```dart
/// final manager = SimulatorDataManager(
///   config: DataSimulatorConfig(
///     volatility: Volatility.medium,
///     candleDuration: CandleDuration.oneMinute,
///     ticksPerSecond: 10,
///   ),
/// );
///
/// // Chart loads historical data
/// final batch = await manager.loadHistorical();
///
/// // Chart registers for real-time updates
/// manager.onRealtimeUpdate((candle) {
///   print('New candle: $candle');
/// });
///
/// // UI controls start/stop
/// manager.start();
/// // ... later ...
/// manager.stop();
/// ```
class SimulatorDataManager implements DataManager {
  SimulatorDataManager({
    required this.config,
    this.historicalBatchSize = 100,
    this.initialHistoricalCount = 500,
  }) : _simulator = DataSimulator(config);

  /// Simulator configuration
  final DataSimulatorConfig config;

  /// Number of candles to load per historical batch
  final int historicalBatchSize;

  /// Total number of historical candles to generate
  final int initialHistoricalCount;

  /// The underlying data simulator
  final DataSimulator _simulator;

  /// Callback for real-time updates
  void Function(OHLCData candle)? _realtimeCallback;

  /// Number of historical candles loaded so far
  int _historicalLoadedCount = 0;

  /// Whether the simulator ticker is running
  bool _isRunning = false;

  /// All generated candles (for tracking purposes)
  final List<OHLCData> _allCandles = [];

  @override
  Future<HistoricalBatch> loadHistorical() async {
    print('[SimulatorDataManager.loadHistorical] Called: _historicalLoadedCount=$_historicalLoadedCount, historicalBatchSize=$historicalBatchSize');

    // First call: generate initial batch of historical candles
    if (_historicalLoadedCount == 0) {
      final candles = await _simulator.generateHistoricalCandles(historicalBatchSize);
      _allCandles.addAll(candles);
      _historicalLoadedCount = candles.length;

      final hasMore = _historicalLoadedCount < initialHistoricalCount;
      print('[SimulatorDataManager.loadHistorical] Initial batch: ${candles.length} candles, hasMore=$hasMore');

      return HistoricalBatch(candles: candles, hasMore: hasMore);
    }

    // Subsequent calls: generate more historical data going backwards
    if (_historicalLoadedCount >= initialHistoricalCount) {
      // No more historical data
      print('[SimulatorDataManager.loadHistorical] No more data to load');
      return HistoricalBatch(candles: [], hasMore: false);
    }

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 100));

    // Calculate how many candles to generate in this batch
    final remaining = initialHistoricalCount - _historicalLoadedCount;
    final batchSize = remaining < historicalBatchSize ? remaining : historicalBatchSize;

    // Generate next batch
    final candles = await _simulator.generateHistoricalCandles(batchSize);

    // Insert at beginning (older data goes first)
    _allCandles.insertAll(0, candles);
    _historicalLoadedCount += candles.length;

    final hasMore = _historicalLoadedCount < initialHistoricalCount;
    print('[SimulatorDataManager.loadHistorical] Loaded batch: ${candles.length} candles, hasMore=$hasMore, total=$_historicalLoadedCount');

    return HistoricalBatch(candles: candles, hasMore: hasMore);
  }

  @override
  void onRealtimeUpdate(void Function(OHLCData candle) callback) {
    _realtimeCallback = callback;
    print('[SimulatorDataManager.onRealtimeUpdate] Callback registered');
  }

  /// Start the real-time simulator ticker.
  ///
  /// Begins generating candles at the configured tick rate.
  /// New candles are sent to the callback registered via onRealtimeUpdate().
  void start() {
    if (_isRunning) {
      print('[SimulatorDataManager.start] Already running');
      return;
    }

    print('[SimulatorDataManager.start] Starting simulator ticker');
    _isRunning = true;

    _simulator.startTicker((candle) {
      // Add to our tracking list
      _allCandles.add(candle);

      // Forward to chart callback
      _realtimeCallback?.call(candle);
    });
  }

  /// Stop the real-time simulator ticker.
  ///
  /// Stops generating new candles.
  void stop() {
    if (!_isRunning) {
      print('[SimulatorDataManager.stop] Not running');
      return;
    }

    print('[SimulatorDataManager.stop] Stopping simulator ticker');
    _isRunning = false;
    _simulator.stopTicker();
  }

  /// Reset the data manager.
  ///
  /// Clears all loaded data and resets to initial state.
  /// Stops the ticker if running.
  void reset() {
    print('[SimulatorDataManager.reset] Resetting - current _historicalLoadedCount=$_historicalLoadedCount');
    stop();
    _historicalLoadedCount = 0;
    _allCandles.clear();
    print('[SimulatorDataManager.reset] Reset complete - new _historicalLoadedCount=$_historicalLoadedCount');
  }

  /// Get the total number of candles generated.
  int get totalCandles => _allCandles.length;

  /// Get the number of historical candles loaded.
  int get loadedHistoricalCandles => _historicalLoadedCount;

  /// Check if the simulator is running.
  bool get isRunning => _isRunning;

  /// Get current price from simulator.
  double get currentPrice => _simulator.getCurrentPrice();

  /// Get current partially-formed candle.
  OHLCData? get currentCandle => _simulator.getCurrentCandle();

  /// Get tick count in current candle.
  int get tickCount => _simulator.getTickCount();

  /// Dispose resources.
  void dispose() {
    stop();
    _simulator.dispose();
    print('[SimulatorDataManager.dispose] Disposed');
  }
}
