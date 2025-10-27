/// Market definition for handling trading hours, holidays, and market status
/// Ported from src/chartlib/chartcore/marketDefinition.ts

import 'candle_definition.dart';

/// Market status enum
enum MarketStatus {
  preMarket,
  open,
  closed,
  postMarket,
  holiday,
  specialTrading,
}

/// Market trading session (e.g., regular hours, pre-market, post-market)
class MarketSession {
  const MarketSession({
    this.name,
    required this.open,
    required this.close,
  });

  final String? name;
  final Duration open; // Time of day as Duration from midnight
  final Duration close; // Time of day as Duration from midnight
}

/// Special trading day with custom sessions
class SpecialTradingDay {
  const SpecialTradingDay({
    required this.date,
    required this.name,
    required this.sessions,
  });

  final DateTime date; // Date only (time should be midnight UTC)
  final String name;
  final List<MarketSession> sessions;
}

/// Market day status enum
enum MarketDayStatus {
  open,
  holiday,
  specialTrading,
}

/// Market day type with status and sessions
class MarketDayType {
  const MarketDayType({
    required this.status,
    required this.sessions,
    this.name,
  });

  final MarketDayStatus status;
  final List<MarketSession> sessions;
  final String? name;
}

/// Market definition containing trading hours, holidays, and timezone
class MarketDefinition {
  const MarketDefinition({
    required this.name,
    required this.timezone,
    this.preMarketHours,
    required this.regularHours,
    this.postMarketHours,
    required this.weeklyHolidays,
    required this.holidays,
    this.specialTradingDays = const [],
  });

  final String name;
  final String timezone; // Timezone name (e.g., 'Asia/Kolkata')
  final MarketSession? preMarketHours;
  final List<MarketSession> regularHours;
  final MarketSession? postMarketHours;
  final List<int> weeklyHolidays; // Day of week (0=Sunday, 6=Saturday)
  final List<DateTime> holidays; // Holiday dates (date only, time should be midnight UTC)
  final List<SpecialTradingDay> specialTradingDays;

  /// Determines the market session type and trading hours for a given date.
  ///
  /// Checks in order:
  /// 1. Special trading days (custom sessions)
  /// 2. Weekly holidays (weekends) and declared holidays (empty sessions)
  /// 3. Regular trading days (normal sessions)
  MarketDayType _marketSessionForDate(DateTime date) {
    final dayOfWeek = date.weekday % 7; // Convert to 0=Sunday format

    // Check for special trading day
    final specialDay = specialTradingDays.firstWhere(
      (std) => _isSameDate(std.date, date),
      orElse: () => SpecialTradingDay(
        date: DateTime.fromMillisecondsSinceEpoch(0),
        name: '',
        sessions: const [],
      ),
    );

    if (specialDay.sessions.isNotEmpty) {
      return MarketDayType(
        status: MarketDayStatus.specialTrading,
        sessions: specialDay.sessions,
        name: specialDay.name,
      );
    }

    // Check for weekly holidays or declared holidays
    if (weeklyHolidays.contains(dayOfWeek) ||
        holidays.any((holiday) => _isSameDate(holiday, date))) {
      return const MarketDayType(
        status: MarketDayStatus.holiday,
        sessions: [],
      );
    }

    // Regular trading day
    return MarketDayType(
      status: MarketDayStatus.open,
      sessions: regularHours,
    );
  }

  /// Checks if the market is open at a specific date and time.
  ///
  /// Converts the input to market timezone, determines the market sessions
  /// for that date, and checks if the time falls within any trading session.
  bool isMarketOpen(DateTime dateTime) {
    // Note: In Dart, we'll work with UTC times and assume proper timezone conversion
    // is handled by the caller or using a timezone package
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final timeOfDay = Duration(
      hours: dateTime.hour,
      minutes: dateTime.minute,
      seconds: dateTime.second,
    );

    final marketDay = _marketSessionForDate(date);

    if (marketDay.sessions.isEmpty) {
      return false;
    }

    return marketDay.sessions.any(
      (session) =>
          timeOfDay >= session.open && timeOfDay <= session.close,
    );
  }

  /// Gets the market open time for a specific date.
  ///
  /// Returns the first trading session open time for the given date,
  /// or null if the market is closed (holiday, weekend, etc.).
  DateTime? marketOpenDateTime(DateTime date) {
    final marketDay = _marketSessionForDate(date);

    if (marketDay.sessions.isEmpty) {
      return null;
    }

    final firstSession = marketDay.sessions.first;
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).add(firstSession.open);
  }

  /// Gets the market close time for a specific date.
  ///
  /// Returns the last trading session close time for the given date,
  /// or null if the market is closed (holiday, weekend, etc.).
  DateTime? marketCloseDateTime(DateTime date) {
    final marketDay = _marketSessionForDate(date);

    if (marketDay.sessions.isEmpty) {
      return null;
    }

    final lastSession = marketDay.sessions.last;
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).add(lastSession.close);
  }

  /// Finds the next market open time from a given date/time.
  ///
  /// First checks if there's a later trading session on the same date,
  /// then searches forward up to 15 days for the next market open.
  DateTime? nextMarketOpenDate(DateTime fromDateTime) {
    var currentDate = DateTime(
      fromDateTime.year,
      fromDateTime.month,
      fromDateTime.day,
    );
    final currentTime = Duration(
      hours: fromDateTime.hour,
      minutes: fromDateTime.minute,
      seconds: fromDateTime.second,
    );

    final marketDay = _marketSessionForDate(currentDate);
    if (marketDay.sessions.isNotEmpty) {
      final firstSession = marketDay.sessions.first;
      // If before market open, return first session open time
      if (currentTime < firstSession.open) {
        return currentDate.add(firstSession.open);
      }
    }

    // Search next 15 days for market open
    for (var i = 0; i < 15; i++) {
      currentDate = currentDate.add(const Duration(days: 1));
      final marketDay = _marketSessionForDate(currentDate);

      if (marketDay.sessions.isNotEmpty) {
        final firstSession = marketDay.sessions.first;
        return currentDate.add(firstSession.open);
      }
    }

    return null;
  }

  /// Generates a default date range for chart data based on candle duration.
  ///
  /// For intraday durations (< 1 day), calculates approximately 250 trading periods
  /// by estimating points per trading day and finding sufficient trading days backwards
  /// from the end date, accounting for market hours, holidays, and special trading days.
  ///
  /// For daily and longer durations, uses simple calendar day approximations:
  /// - Daily: 90 calendar days (≈ 65 trading days)
  /// - Weekly/Monthly: 360 calendar days (≈ 250 trading days)
  ({DateTime start, DateTime end}) generateDefaultDateRange(
    DateTime endDate,
    CandleDuration duration,
  ) {
    if (!isIntradayDuration(duration)) {
      var daysDuration = const Duration(days: 360);
      if (duration == CandleDuration.oneDay) {
        daysDuration = const Duration(days: 90);
      }
      final startDate = endDate.subtract(daysDuration);
      return (start: startDate, end: endDate);
    }

    final intervalDuration = candleDurationToDuration(duration);

    // Calculate total session minutes per day
    final totalSessionMinutes = regularHours.fold<int>(
      0,
      (total, session) {
        final sessionMinutes =
            (session.close.inMinutes - session.open.inMinutes);
        return total + sessionMinutes;
      },
    );

    final intervalMinutes = intervalDuration.inMinutes;
    final pointsPerTradingDay = (totalSessionMinutes / intervalMinutes).floor();

    final tradingDaysNeeded = (250 / pointsPerTradingDay).ceil();

    var searchDate = DateTime(endDate.year, endDate.month, endDate.day);
    var tradingDaysFound = 0;

    for (var i = 0; i < tradingDaysNeeded * 2; i++) {
      final marketDay = _marketSessionForDate(searchDate);
      if (marketDay.sessions.isNotEmpty) {
        tradingDaysFound++;
        if (tradingDaysFound >= tradingDaysNeeded) {
          break;
        }
      }
      searchDate = searchDate.subtract(const Duration(days: 1));
    }

    return (start: searchDate, end: endDate);
  }

  /// Helper to check if two dates are the same (ignoring time)
  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
