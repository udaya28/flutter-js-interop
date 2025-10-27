/// DataManager interface for chart data sources.
/// Separates chart logic from data source implementation.
/// Ported from src/chartlib/data/dataManager.ts

import 'ohlc.dart';

/// Historical data batch with pagination info.
class HistoricalBatch {
  const HistoricalBatch({
    required this.candles,
    required this.hasMore,
  });

  /// Historical candles (oldest to newest)
  final List<OHLCData> candles;

  /// True if more historical data exists, false if this is the earliest data
  final bool hasMore;
}

/// DataManager interface for chart data sources.
///
/// Separates chart logic from data source implementation.
/// Implementations can be:
/// - SimulatorDataManager (for testing with generated data)
/// - WebSocketDataManager (for real-time data from WebSocket)
/// - RESTDataManager (for data from REST API)
///
/// Usage:
/// 1. Chart calls loadHistorical() for initial data and when user pans left
/// 2. Chart registers callback via onRealtimeUpdate() for live updates
/// 3. Lifecycle (start/stop) is controlled outside this interface
abstract class DataManager {
  /// Load next batch of historical candles going backwards in time.
  /// Called multiple times as user pans left through history.
  ///
  /// First call returns most recent historical data.
  /// Subsequent calls return progressively older data.
  ///
  /// @returns Future with candles and hasMore flag
  Future<HistoricalBatch> loadHistorical();

  /// Register callback for real-time candle updates.
  /// Chart is passive - doesn't control when updates start.
  ///
  /// For simulator: UI controls start/stop
  /// For WebSocket: Auto-connects on registration
  ///
  /// @param callback - Called when candle is updated or new candle arrives
  void onRealtimeUpdate(void Function(OHLCData candle) callback);
}
