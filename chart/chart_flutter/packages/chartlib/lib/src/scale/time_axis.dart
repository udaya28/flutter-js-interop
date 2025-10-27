/// TimeAxis for displaying time labels on the X-axis
/// Ported from src/chartlib/scale/timeAxis.ts

import 'dart:math' as math;
import 'axis.dart';
import 'ordinal_time_scale.dart';

/// TimeAxis for displaying time labels on the X-axis.
///
/// NOTE: Uses native Dart DateTime for performance.
/// Timezone offset is calculated from data and applied at display time.
class TimeAxis extends Axis<DateTime> {
  TimeAxis(
    super.context,
    OrdinalTimeScale super.scale,
    super.position, [
    int tickStep = 1, // Ignored, kept for API compatibility
    super.options,
    this.timezoneOffsetMs = 19800000, // Default: IST (UTC+5:30)
  ]) : _timeScale = scale;

  final OrdinalTimeScale _timeScale;

  /// Timezone offset in milliseconds (e.g., IST = +19800000 = 5.5 hours)
  int timezoneOffsetMs;

  @override
  List<TickInfo<DateTime>> generateTicks() {
    final domain = _timeScale.getVisibleDomain();
    if (domain.isEmpty) return [];

    final firstTime = domain.first;
    final lastTime = domain.last;
    final spanSeconds = (lastTime.millisecondsSinceEpoch - firstTime.millisecondsSinceEpoch) / 1000;

    final tzOffsetMs = timezoneOffsetMs;

    // Target: 5-15 labels (minimum 1)
    int targetTicks;
    if (domain.length <= 5) {
      targetTicks = domain.length; // Show all
    } else if (domain.length <= 15) {
      targetTicks = (domain.length / 2).ceil(); // Show every 2nd candle
    } else {
      targetTicks = 10; // Standard: aim for 10 labels
    }

    // Determine pivot level and subdivision based on span
    final pivotInfo = _choosePivotLevel(spanSeconds, targetTicks);
    final level = pivotInfo.level;
    final subdivision = pivotInfo.subdivision;

    // Get indices for index-based coordinate lookups
    final indices = _timeScale.getVisibleDomainIndices();

    // Guard against NaN or invalid indices
    if (indices.startIndex.isNaN || indices.endIndex.isNaN ||
        indices.startIndex.isInfinite || indices.endIndex.isInfinite) {
      return [];
    }

    final startIndexFloored = indices.startIndex.floor();
    final endIndexFloored = indices.endIndex.floor();

    // Strategy: Sample at regular intervals, but prefer pivot points when nearby
    final tickInterval = math.max(1, (domain.length / targetTicks).floor());
    final ticks = <TickInfo<DateTime>>[];
    int? previousYear;
    int? previousMonth;
    int? previousDay;

    for (var i = 0; i < domain.length; i += tickInterval) {
      // Try to find a pivot point near this sample position
      final searchStart = math.max(0, i - (tickInterval / 2).floor());
      final searchEnd = math.min(domain.length - 1, i + (tickInterval / 2).floor());

      var bestIndex = i;
      var foundPivot = false;

      // Look for pivot point in nearby range
      for (var j = searchStart; j <= searchEnd; j++) {
        if (_isPivotPoint(domain[j], level, subdivision, tzOffsetMs)) {
          bestIndex = j;
          foundPivot = true;
          break;
        }
      }

      // If no pivot found, check for any boundary
      if (!foundPivot) {
        for (var j = searchStart; j <= searchEnd; j++) {
          final t = domain[j];
          final localDate = DateTime.fromMillisecondsSinceEpoch(
            t.millisecondsSinceEpoch + tzOffsetMs,
            isUtc: true,
          );
          final currentYear = localDate.year;
          final currentMonth = localDate.month;
          final currentDay = localDate.day;

          final isYearBoundary = previousYear != null && currentYear != previousYear;
          final isMonthBoundary = previousMonth != null && currentMonth != previousMonth;
          final isDayBoundary = previousDay != null && currentDay != previousDay;

          if (isYearBoundary || isMonthBoundary || (isDayBoundary && spanSeconds < 86400 * 7)) {
            bestIndex = j;
            break;
          }
        }
      }

      final timeValue = domain[bestIndex];
      final absoluteIndex = startIndexFloored + bestIndex;
      final pixelPos = _timeScale.scaledValueFromIndex(absoluteIndex);
      if (pixelPos.isNaN) continue;

      // Determine what changed to choose label format
      final localDate = DateTime.fromMillisecondsSinceEpoch(
        timeValue.millisecondsSinceEpoch + tzOffsetMs,
        isUtc: true,
      );
      final currentYear = localDate.year;
      final currentMonth = localDate.month;
      final currentDay = localDate.day;

      final isYearChange = previousYear != null && currentYear != previousYear;
      final isMonthChange = previousMonth != null && currentMonth != previousMonth;
      final isDayChange = previousDay != null && currentDay != previousDay;

      String label;
      if (level == 'year' || isYearChange) {
        label = _formatDateTime(timeValue, 'year', tzOffsetMs);
      } else if (level == 'month' || isMonthChange) {
        label = _formatDateTime(timeValue, 'month', tzOffsetMs);
      } else if (level == 'day' || isDayChange) {
        label = _formatDateTime(timeValue, 'day', tzOffsetMs);
      } else {
        label = _formatDateTime(timeValue, 'time', tzOffsetMs);
      }

      ticks.add(TickInfo(
        value: timeValue,
        scaledPosition: pixelPos,
        label: label,
      ));

      previousYear = currentYear;
      previousMonth = currentMonth;
      previousDay = currentDay;
    }

    // Ensure we always have at least 2 ticks
    if (ticks.isEmpty) {
      final firstPixel = _timeScale.scaledValueFromIndex(startIndexFloored);
      final lastPixel = _timeScale.scaledValueFromIndex(endIndexFloored);
      return [
        TickInfo(
          value: firstTime,
          scaledPosition: firstPixel,
          label: _formatDateTime(firstTime, 'full', tzOffsetMs),
        ),
        TickInfo(
          value: lastTime,
          scaledPosition: lastPixel,
          label: _formatDateTime(lastTime, 'full', tzOffsetMs),
        ),
      ];
    }

    // Ensure last candle is included if not already
    final lastDomainTime = domain.last;
    final lastTickTime = ticks.last.value;
    if (lastTickTime.millisecondsSinceEpoch != lastDomainTime.millisecondsSinceEpoch) {
      final lastPixel = _timeScale.scaledValueFromIndex(endIndexFloored);
      if (!lastPixel.isNaN) {
        ticks.add(TickInfo(
          value: lastDomainTime,
          scaledPosition: lastPixel,
          label: _formatDateTime(lastDomainTime, spanSeconds > 86400 ? 'day' : 'time', tzOffsetMs),
        ));
      }
    }

    return ticks;
  }

  /// Choose pivot level and subdivision based on time span
  ({String level, int subdivision}) _choosePivotLevel(double spanSeconds, int targetTicks) {
    final spanMinutes = spanSeconds / 60;
    final spanHours = spanMinutes / 60;
    final spanDays = spanHours / 24;
    final spanMonths = spanDays / 30;
    final spanYears = spanDays / 365;

    // Year level
    if (spanYears > 3) {
      final ticksPerYear = targetTicks / spanYears;
      if (ticksPerYear < 1) {
        return (level: 'year', subdivision: math.max(1, (1 / ticksPerYear).ceil()));
      }
      return (level: 'month', subdivision: math.max(1, (12 / ticksPerYear).ceil()));
    }

    // Month level
    if (spanMonths > 2) {
      final ticksPerMonth = targetTicks / spanMonths;
      if (ticksPerMonth < 1) {
        return (level: 'month', subdivision: math.max(1, (1 / ticksPerMonth).ceil()));
      }
      final daysPerTick = 30 / ticksPerMonth;
      if (daysPerTick >= 15) return (level: 'day', subdivision: 15);
      if (daysPerTick >= 10) return (level: 'day', subdivision: 10);
      if (daysPerTick >= 5) return (level: 'day', subdivision: 5);
      if (daysPerTick >= 3) return (level: 'day', subdivision: 3);
      if (daysPerTick >= 2) return (level: 'day', subdivision: 2);
      return (level: 'day', subdivision: 1);
    }

    // Day level
    if (spanDays > 1) {
      final ticksPerDay = targetTicks / spanDays;
      final hoursPerTick = 24 / ticksPerDay;
      if (hoursPerTick >= 12) return (level: 'hour', subdivision: 12);
      if (hoursPerTick >= 6) return (level: 'hour', subdivision: 6);
      if (hoursPerTick >= 4) return (level: 'hour', subdivision: 4);
      if (hoursPerTick >= 3) return (level: 'hour', subdivision: 3);
      if (hoursPerTick >= 2) return (level: 'hour', subdivision: 2);
      return (level: 'hour', subdivision: 1);
    }

    // Hour level
    if (spanHours > 1) {
      final ticksPerHour = targetTicks / spanHours;
      final minutesPerTick = 60 / ticksPerHour;
      if (minutesPerTick >= 30) return (level: 'minute', subdivision: 30);
      if (minutesPerTick >= 20) return (level: 'minute', subdivision: 20);
      if (minutesPerTick >= 15) return (level: 'minute', subdivision: 15);
      if (minutesPerTick >= 10) return (level: 'minute', subdivision: 10);
      if (minutesPerTick >= 5) return (level: 'minute', subdivision: 5);
      return (level: 'minute', subdivision: 2);
    }

    // Minute level
    if (spanMinutes > 1) {
      final ticksPerMinute = targetTicks / spanMinutes;
      final secondsPerTick = 60 / ticksPerMinute;
      if (secondsPerTick >= 30) return (level: 'second', subdivision: 30);
      if (secondsPerTick >= 20) return (level: 'second', subdivision: 20);
      if (secondsPerTick >= 15) return (level: 'second', subdivision: 15);
      if (secondsPerTick >= 10) return (level: 'second', subdivision: 10);
      if (secondsPerTick >= 5) return (level: 'second', subdivision: 5);
      return (level: 'second', subdivision: 2);
    }

    // Default to seconds
    return (level: 'second', subdivision: 1);
  }

  /// Check if a timestamp is at or near a pivot point
  bool _isPivotPoint(DateTime time, String level, int subdivision, int tzOffsetMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(
      time.millisecondsSinceEpoch + tzOffsetMs,
      isUtc: true,
    );
    final year = date.year;
    final month = date.month;
    final day = date.day;
    final hour = date.hour;
    final minute = date.minute;
    final second = date.second;

    switch (level) {
      case 'year':
        return month == 1 && day == 1 && year % subdivision == 0;
      case 'month':
        return day == 1 && (month - 1) % subdivision == 0;
      case 'day':
        return (day - 1) % subdivision == 0;
      case 'hour':
        return hour % subdivision == 0 && minute < 10;
      case 'minute':
        return minute % subdivision == 0;
      case 'second':
        return second % subdivision == 0;
      default:
        return false;
    }
  }

  /// Format datetime for different label types
  String _formatDateTime(DateTime time, String type, int tzOffsetMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(
      time.millisecondsSinceEpoch + tzOffsetMs,
      isUtc: true,
    );

    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    final s = date.second.toString().padLeft(2, '0');
    final month = date.month;
    final day = date.day;
    final year = date.year;
    final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    switch (type) {
      case 'full':
        return '$month/$day $h:$m';
      case 'date':
        return '$month/$day';
      case 'time':
        if (date.second != 0) {
          return '$h:$m:$s';
        }
        return '$h:$m';
      case 'day':
        return '$day';
      case 'month':
        return monthNames[month - 1];
      case 'year':
        return '$year';
      default:
        return '$h:$m';
    }
  }

  void updateTickStep(int tickStep) {
    // Kept for API compatibility, but ignored
  }
}
