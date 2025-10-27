/// Candle duration definitions and utilities
/// Ported from src/chartlib/chartcore/candleDefinition.ts

enum CandleDuration {
  oneSecond('1s'),
  fiveSeconds('5s'),
  thirtySeconds('30s'),
  oneMinute('1m'),
  fiveMinutes('5m'),
  fifteenMinutes('15m'),
  thirtyMinutes('30m'),
  oneHour('1h'),
  fourHours('4h'),
  oneDay('1d'),
  oneWeek('1w'),
  oneMonth('1M');

  const CandleDuration(this.value);

  final String value;

  @override
  String toString() => value;
}

const _intradayDurations = [
  CandleDuration.oneSecond,
  CandleDuration.fiveSeconds,
  CandleDuration.thirtySeconds,
  CandleDuration.oneMinute,
  CandleDuration.fiveMinutes,
  CandleDuration.fifteenMinutes,
  CandleDuration.thirtyMinutes,
  CandleDuration.oneHour,
  CandleDuration.fourHours,
];

/// Check if a duration is intraday (less than 1 day)
bool isIntradayDuration(CandleDuration duration) {
  return _intradayDurations.contains(duration);
}

/// Convert CandleDuration to Dart Duration
Duration candleDurationToDuration(CandleDuration duration) {
  switch (duration) {
    case CandleDuration.oneSecond:
      return const Duration(seconds: 1);
    case CandleDuration.fiveSeconds:
      return const Duration(seconds: 5);
    case CandleDuration.thirtySeconds:
      return const Duration(seconds: 30);
    case CandleDuration.oneMinute:
      return const Duration(minutes: 1);
    case CandleDuration.fiveMinutes:
      return const Duration(minutes: 5);
    case CandleDuration.fifteenMinutes:
      return const Duration(minutes: 15);
    case CandleDuration.thirtyMinutes:
      return const Duration(minutes: 30);
    case CandleDuration.oneHour:
      return const Duration(hours: 1);
    case CandleDuration.fourHours:
      return const Duration(hours: 4);
    case CandleDuration.oneDay:
      return const Duration(days: 1);
    case CandleDuration.oneWeek:
      return const Duration(days: 7);
    case CandleDuration.oneMonth:
      // Approximate: 30 days
      return const Duration(days: 30);
  }
}

/// Convert CandleDuration to milliseconds
int candleDurationToMilliseconds(CandleDuration duration) {
  return candleDurationToDuration(duration).inMilliseconds;
}
