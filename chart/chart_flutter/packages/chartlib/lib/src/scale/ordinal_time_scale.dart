/// Ordinal time scale implementation for the Scale interface.
/// Maps discrete time values to evenly-spaced positions (by index, not actual time).
///
/// IMPORTANT: Markets have gaps (weekends, holidays, trading hours), so candles
/// are evenly spaced by index regardless of actual time gaps.
///
/// Ported from src/chartlib/scale/ordinalTimeScale.ts

import 'dart:math' as math;
import 'scale.dart';

class OrdinalTimeScale implements Scale<DateTime> {
  /// @param fullDomain Complete array of time values from the dataset (UTC DateTime objects)
  /// @param rangeMin Minimum value of the output range (pixels)
  /// @param rangeMax Maximum value of the output range (pixels)
  /// @param startIndex Starting index in the full domain (default: 0)
  /// @param endIndex Ending index in the full domain (default: all data)
  OrdinalTimeScale({
    required List<DateTime> fullDomain,
    required double rangeMin,
    required double rangeMax,
    double startIndex = 0,
    double? endIndex,
  }) : _fullDomain = fullDomain,
       _rangeMin = rangeMin,
       _rangeMax = rangeMax,
       _startIndex = startIndex,
       _endIndex = endIndex ?? (fullDomain.length - 1).toDouble(),
       _step = 0 {
    // print('[OrdinalTimeScale] Constructor: fullDomain.length=${fullDomain.length}, rangeMin=$rangeMin, rangeMax=$rangeMax, startIndex=$startIndex, endIndex=$endIndex');
    // print('[OrdinalTimeScale] Calculated _endIndex=$_endIndex');

    // Calculate step size based on visible count
    // Use count (not range) to ensure all candles fit within pixel bounds
    final visibleCount = math.max(1, _endIndex - _startIndex + 1);
    _step = (_rangeMax - _rangeMin) / visibleCount;

    // print('[OrdinalTimeScale] visibleCount=$visibleCount, _step=$_step');
    if (_step.isNaN || _step.isInfinite) {
      // print('[OrdinalTimeScale] ERROR: _step is NaN or Infinite!');
    }
  }

  final List<DateTime> _fullDomain;
  double _rangeMin;
  double _rangeMax;
  double _startIndex;
  double _endIndex;
  double _step;

  /// Binary search for timestamp in domain array within a specified range.
  /// Returns index of exact match, or closest match if not found.
  /// Searches directly on the array without slicing for better performance.
  ///
  /// @param domain - Array of timestamps to search (DateTime objects)
  /// @param target - Timestamp to find (DateTime object)
  /// @param startIdx - Start index of the search range (inclusive)
  /// @param endIdx - End index of the search range (inclusive)
  /// @returns Index in the domain array
  int _binarySearchTimestamp(
    List<DateTime> domain,
    DateTime target,
    int startIdx,
    int endIdx,
  ) {
    int left = startIdx;
    int right = endIdx;
    final targetTime = target.millisecondsSinceEpoch;

    while (left <= right) {
      final mid = ((left + right) / 2).floor();
      final midTime = domain[mid].millisecondsSinceEpoch;

      if (midTime == targetTime) {
        return mid; // Exact match found
      } else if (midTime < targetTime) {
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }

    // No exact match - return closest
    if (left >= domain.length) return domain.length - 1;
    if (left == 0) return 0;

    // Check which neighbor is closer
    final distLeft = (domain[left - 1].millisecondsSinceEpoch - targetTime)
        .abs();
    final distRight = (domain[left].millisecondsSinceEpoch - targetTime).abs();

    return distLeft <= distRight ? left - 1 : left;
  }

  /// Maps a time value to its corresponding pixel position.
  /// Uses binary search on buffered visible range for O(log n) performance.
  /// Buffer matches what studies render (±2 candles) to avoid clamping edge candles.
  /// Optimized to search directly on fullDomain without array slicing.
  @override
  double scaledValue(DateTime value) {
    // Guard against invalid state
    if (_fullDomain.isEmpty ||
        _startIndex.isNaN ||
        _endIndex.isNaN ||
        _startIndex.isInfinite ||
        _endIndex.isInfinite) {
      return double.nan;
    }

    // Search buffered range (matching what studies render: visible ± 2)
    const buffer = 2;
    final searchStart = math.max(0, (_startIndex - buffer).floor());
    final searchEnd = math.min(
      _fullDomain.length - 1,
      (_endIndex + buffer).ceil(),
    );

    // Search directly on fullDomain without slicing (performance optimization)
    final actualCandleIndex = _binarySearchTimestamp(
      _fullDomain,
      value,
      searchStart,
      searchEnd,
    );

    // Convert to relativeIndex (relative to fractional startIndex)
    final relativeIndex = actualCandleIndex - _startIndex;

    // Calculate pixel position with centered candles
    // With fractional indices, candles at the edges will be partially clipped
    return _rangeMin + _step / 2 + relativeIndex * _step;
  }

  /// Maps an index directly to its pixel position.
  /// This is the optimal path for rendering - O(1) pure arithmetic with no lookups.
  /// Used when the index is already known (e.g., from ComputedDataPoint.index).
  ///
  /// Matches TradingView's production implementation pattern: indexToCoordinate(index)
  ///
  /// @param index - The index in the full domain array
  /// @returns Pixel coordinate for this index
  double scaledValueFromIndex(int index) {
    final relativeIndex = index - _startIndex;
    return _rangeMin + _step / 2 + relativeIndex * _step;
  }

  /// Maps a pixel coordinate back to the domain value (timestamp).
  /// Pixel → integer index → timestamp.
  /// Handles edge cases by clamping to valid range.
  @override
  DateTime invert(double pixel) {
    // Handle edge case: empty domain
    if (_fullDomain.isEmpty) {
      throw Exception('Cannot invert on empty domain');
    }

    // Calculate relative index: pixel = rangeMin + step/2 + relativeIndex * step
    // Therefore: relativeIndex = (pixel - rangeMin - step/2) / step
    final relativeIndex = (pixel - _rangeMin - _step / 2) / _step;

    // Calculate full index
    final fullIndex = relativeIndex + _startIndex;

    // Round to nearest integer (ordinal/discrete scale)
    final index = fullIndex.round();

    // Clamp to valid range [0, fullDomain.length - 1]
    final clampedIndex = math.max(0, math.min(_fullDomain.length - 1, index));

    return _fullDomain[clampedIndex];
  }

  /// Returns the width available for drawing candles/boxes at each time point.
  /// This represents the horizontal space allocated to each time period.
  double boxWidth() {
    return _step;
  }

  /// Updates the visible domain indices (supports fractional indices for smooth zoom).
  /// Called during zoom/pan operations - no scale recreation needed.
  void updateVisibleDomainIndices(double startIndex, double endIndex) {
    // Store fractional indices for smooth zoom/pan
    _startIndex = math.max(0, startIndex);
    _endIndex = math.min((_fullDomain.length - 1).toDouble(), endIndex);

    // Recalculate step size (use count to ensure all candles fit within pixel bounds)
    final visibleCount = math.max(1, _endIndex - _startIndex + 1);
    _step = (_rangeMax - _rangeMin) / visibleCount;
  }

  /// Updates the pixel range (e.g., on canvas resize).
  void updateRange(double rangeMin, double rangeMax) {
    _rangeMin = rangeMin;
    _rangeMax = rangeMax;

    // Recalculate step size (use count to ensure all candles fit within pixel bounds)
    final visibleCount = math.max(1, _endIndex - _startIndex + 1);
    _step = (_rangeMax - _rangeMin) / visibleCount;
  }

  /// Gets the current visible domain indices.
  ({double startIndex, double endIndex}) getVisibleDomainIndices() {
    return (startIndex: _startIndex, endIndex: _endIndex);
  }

  /// Updates the full domain with new timestamps.
  /// Called when candles are appended or prepended.
  ///
  /// @param newDomain - Updated complete array of timestamps (DateTime objects)
  void updateFullDomain(List<DateTime> newDomain) {
    // Note: This creates a new reference. Consider if we need to modify in place.
    // For now, keeping it simple like the JS version.
    _fullDomain.clear();
    _fullDomain.addAll(newDomain);

    // Ensure endIndex doesn't exceed new domain length
    _endIndex = math.min(_endIndex, (newDomain.length - 1).toDouble());
  }

  /// Returns the visible domain array (subset of full domain).
  List<DateTime> getVisibleDomain() {
    // Guard against NaN or invalid indices
    if (_fullDomain.isEmpty ||
        _startIndex.isNaN ||
        _endIndex.isNaN ||
        _startIndex.isInfinite ||
        _endIndex.isInfinite) {
      return [];
    }

    final startIdx = _startIndex.floor();
    final endIdx = _endIndex.ceil();
    return _fullDomain.sublist(
      math.max(0, startIdx),
      math.min(_fullDomain.length, endIdx + 1),
    );
  }

  /// Returns the full domain array of time values.
  List<DateTime> getFullDomain() {
    return _fullDomain;
  }
}
