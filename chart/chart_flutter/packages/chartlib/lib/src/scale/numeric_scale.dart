/// Numeric scale implementation for mapping numbers linearly.
/// Ported from src/chartlib/scale/numericScale.ts

import 'dart:math' as math;
import 'scale.dart';

/// Returns a "nice" number approximately equal to localRange.
/// Rounds the number if round is true, otherwise takes the ceiling.
double _niceNum(double localRange, bool round) {
  // Handle edge cases
  if (localRange.isNaN || localRange.isInfinite || localRange <= 0) {
    return 1.0;
  }

  final exponent = (math.log(localRange) / math.ln10).floor();
  final fractions = localRange / math.pow(10, exponent);

  double niceFraction;
  if (round) {
    if (fractions < 1.5) {
      niceFraction = 1.0;
    } else if (fractions < 3.0) {
      niceFraction = 2.0;
    } else if (fractions < 7.0) {
      niceFraction = 5.0;
    } else {
      niceFraction = 10.0;
    }
  } else {
    if (fractions <= 1.0) {
      niceFraction = 1.0;
    } else if (fractions <= 2.0) {
      niceFraction = 2.0;
    } else if (fractions <= 5.0) {
      niceFraction = 5.0;
    } else {
      niceFraction = 10.0;
    }
  }
  return niceFraction * math.pow(10, exponent);
}

/// Calculates "nice" minimum, maximum, and tick spacing for a scale.
(double, double, double) scaleNice(
  double minVal,
  double maxVal,
  int tickCount,
) {
  final range = _niceNum(maxVal - minVal, false);
  final tickSpacing = _niceNum(range / (tickCount - 1.0), true);
  final niceMin = (minVal / tickSpacing).floor() * tickSpacing;
  final niceMax = (maxVal / tickSpacing).ceil() * tickSpacing;

  return (niceMin, niceMax, tickSpacing);
}

/// Numeric scale implementation for mapping numbers linearly.
class NumericScale implements Scale<double> {
  NumericScale({
    required double domainMin,
    required double domainMax,
    required double rangeMin,
    required double rangeMax,
    bool inverted = false,
    int tickCount = 10,
  })  : _tickCount = tickCount,
        _rangeMin = rangeMin,
        _rangeMax = rangeMax,
        _inverted = inverted,
        _domainMin = 0,
        _domainMax = 0,
        _tickSpacing = 0 {
    final (niceMin, niceMax, tickSpacing) = scaleNice(domainMin, domainMax, tickCount);

    _domainMin = niceMin;
    _domainMax = niceMax;
    _tickSpacing = tickSpacing;
  }

  double _domainMin;
  double _domainMax;
  double _rangeMin;
  double _rangeMax;
  int _tickCount;
  double _tickSpacing;
  bool _inverted;

  /// Updates the domain minimum and maximum values.
  /// Automatically recalculates "nice" domain values.
  void updateDomain(double domainMin, double domainMax) {
    final (niceMin, niceMax, tickSpacing) = scaleNice(domainMin, domainMax, _tickCount);

    _domainMin = niceMin;
    _domainMax = niceMax;
    _tickSpacing = tickSpacing;
  }

  /// Updates the range minimum and maximum values.
  void updateRange(double rangeMin, double rangeMax) {
    _rangeMin = rangeMin;
    _rangeMax = rangeMax;
  }

  /// Sets whether the scale is inverted.
  void setInverted(bool inverted) {
    _inverted = inverted;
  }

  /// Maps an input value to the corresponding output value on the numeric scale.
  @override
  double scaledValue(double value) {
    if (_domainMax == _domainMin) {
      return _rangeMin;
    }
    final ratio = (value - _domainMin) / (_domainMax - _domainMin);
    if (_inverted) {
      return _rangeMax - ratio * (_rangeMax - _rangeMin);
    } else {
      return _rangeMin + ratio * (_rangeMax - _rangeMin);
    }
  }

  /// Maps a pixel coordinate back to the domain value.
  /// Reverse linear interpolation.
  @override
  double invert(double pixel) {
    final rangeSpan = _rangeMax - _rangeMin;

    // Handle edge case: zero range
    if (rangeSpan == 0) {
      return _domainMin;
    }

    // Calculate ratio based on inverted flag
    final ratio = _inverted
        ? (_rangeMax - pixel) / rangeSpan
        : (pixel - _rangeMin) / rangeSpan;

    // Map ratio to domain value
    return _domainMin + ratio * (_domainMax - _domainMin);
  }

  /// Returns the domain information for the scale.
  ({double min, double max, double tickSpacing}) getDomain() {
    return (min: _domainMin, max: _domainMax, tickSpacing: _tickSpacing);
  }
}
