/// Continuous time scale implementation that supports smooth panning with fractional indices.
/// Unlike OrdinalTimeScale, this can show partial candles and smooth transitions.
/// Ported from src/chartlib/scale/continuousTimeScale.ts

import 'dart:math' as math;
import 'scale.dart';

class ContinuousTimeScale implements Scale<DateTime> {
  /// @param fullDomain Complete array of time values from the dataset
  /// @param rangeMin Minimum value of the output range
  /// @param rangeMax Maximum value of the output range
  /// @param startIndex Starting index in the full domain (can be fractional)
  /// @param endIndex Ending index in the full domain (can be fractional)
  ContinuousTimeScale({
    required List<DateTime> fullDomain,
    required double rangeMin,
    required double rangeMax,
    double startIndex = 0,
    double? endIndex,
  })  : _fullDomain = fullDomain,
        _rangeMin = rangeMin,
        _rangeMax = rangeMax,
        _startIndex = startIndex,
        _endIndex = endIndex ?? (fullDomain.length - 1).toDouble(),
        _step = 0 {
    // Calculate step size based on visible range
    final visibleCount = _endIndex - _startIndex + 1;
    _step = (_rangeMax - _rangeMin) / visibleCount;
  }

  final List<DateTime> _fullDomain;
  double _rangeMin;
  double _rangeMax;
  double _startIndex;
  double _endIndex;
  double _step;

  /// Maps a time value to its corresponding pixel position.
  /// Supports fractional positioning for smooth panning and partial candles.
  @override
  double scaledValue(DateTime value) {
    final fullIndex = _fullDomain.indexWhere(
      (d) => d.millisecondsSinceEpoch == value.millisecondsSinceEpoch,
    );
    if (fullIndex == -1) {
      return double.nan;
    }

    // Calculate position relative to the visible start index
    final relativeIndex = fullIndex - _startIndex;

    // Calculate pixel position with centered candles
    // Don't exclude partially visible candles - let them render at their calculated position
    return _rangeMin + _step / 2 + relativeIndex * _step;
  }

  /// Maps a pixel coordinate back to the domain value (timestamp).
  /// Pixel → fractional index → timestamp.
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

    // Calculate full index (can be fractional for smooth panning)
    final fullIndex = relativeIndex + _startIndex;

    // Round to nearest integer to get actual candle
    final index = fullIndex.round();

    // Clamp to valid range [0, fullDomain.length - 1]
    final clampedIndex = math.max(0, math.min(_fullDomain.length - 1, index));

    return _fullDomain[clampedIndex];
  }

  /// Returns the width available for drawing candles/boxes at each time point.
  double boxWidth() {
    return _step;
  }

  /// Returns the visible domain array (subset of full domain).
  /// This includes partial candles at the edges for smooth panning.
  List<DateTime> getVisibleDomain() {
    final startIdx = _startIndex.floor();
    final endIdx = _endIndex.ceil();

    // Ensure we stay within bounds
    final safeStartIdx = math.max(0, startIdx);
    final safeEndIdx = math.min(_fullDomain.length - 1, endIdx);

    return _fullDomain.sublist(safeStartIdx, safeEndIdx + 1);
  }

  /// Returns the full domain array of time values.
  List<DateTime> getFullDomain() {
    return _fullDomain;
  }

  /// Updates the visible domain indices (fractional indices for smooth panning).
  void updateVisibleDomainIndices(double startIndex, double endIndex) {
    _startIndex = math.max(0, startIndex);
    _endIndex = math.min((_fullDomain.length - 1).toDouble(), endIndex);

    // Recalculate step size
    final visibleCount = _endIndex - _startIndex + 1;
    _step = (_rangeMax - _rangeMin) / visibleCount;
  }

  /// Gets the current visible domain indices (can be fractional for smooth panning).
  ({double startIndex, double endIndex}) getVisibleDomainIndices() {
    return (startIndex: _startIndex, endIndex: _endIndex);
  }

  /// Checks if a candle at the given index would be visible (even partially).
  /// A candle is visible if any part of it appears within the chart bounds.
  bool isIndexVisible(int index) {
    // Very generous range - include candles that might be partially visible
    final expandedStart = _startIndex - 1.0;
    final expandedEnd = _endIndex + 1.0;
    return index >= expandedStart && index <= expandedEnd;
  }

  /// Gets the visibility factor for a candle (0 = not visible, 1 = fully visible).
  /// Used for smooth transitions at the edges.
  double getVisibilityFactor(int index) {
    // Most candles should be fully visible - only apply fade at the very edges
    const fadeDistance = 0.2; // Only fade when candle is 80% or more outside

    if (index >= _startIndex + fadeDistance && index <= _endIndex - fadeDistance) {
      // Candle is well within visible range - fully visible
      return 1.0;
    }

    // Calculate fade for edge candles
    double visibilityFactor = 1.0;

    if (index < _startIndex + fadeDistance) {
      // Fading on the left edge
      final distanceFromStart = index - _startIndex;
      if (distanceFromStart < -fadeDistance) {
        return 0; // Completely outside
      }
      visibilityFactor = math.max(0, (distanceFromStart + fadeDistance) / fadeDistance);
    } else if (index > _endIndex - fadeDistance) {
      // Fading on the right edge
      final distanceFromEnd = _endIndex - index;
      if (distanceFromEnd < -fadeDistance) {
        return 0; // Completely outside
      }
      visibilityFactor = math.max(0, (distanceFromEnd + fadeDistance) / fadeDistance);
    }

    return math.max(0, math.min(1, visibilityFactor));
  }
}
