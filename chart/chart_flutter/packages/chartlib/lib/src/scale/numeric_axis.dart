/// Numeric axis for displaying numeric values on Y-axis
/// Ported from src/chartlib/scale/numericAxis.ts

import 'axis.dart';
import 'numeric_scale.dart';

class NumericAxis extends Axis<double> {
  NumericAxis(
    super.context,
    NumericScale super.scale,
    super.position, [
    this.tickCount = 12,
    super.options,
  ]) : _numericScale = scale;

  final NumericScale _numericScale;
  int tickCount;

  @override
  List<TickInfo<double>> generateTicks() {
    final ticks = <TickInfo<double>>[];

    // Get the domain from the numeric scale
    final domain = _numericScale.getDomain();
    final tickSpacing = domain.tickSpacing;

    // Generate tick values
    var currentValue = domain.min;
    while (currentValue <= domain.max + tickSpacing / 2) {
      // Add small epsilon to handle floating point precision
      final scaledPosition = _numericScale.scaledValue(currentValue);
      final label = _formatTickLabel(currentValue);

      ticks.add(TickInfo(
        value: currentValue,
        scaledPosition: scaledPosition,
        label: label,
      ));

      currentValue += tickSpacing;
    }

    return ticks;
  }

  String _formatTickLabel(double value) {
    final absValue = value.abs();

    // Large numbers with K/M/B suffixes
    if (absValue >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}B';
    } else if (absValue >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    } else if (absValue >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }

    // Standard formatting for smaller values
    if (absValue >= 100) {
      return '${value.round()}';
    } else if (absValue < 1 && value != 0) {
      return value.toStringAsFixed(4);
    } else {
      return value.toStringAsFixed(2);
    }
  }

  void updateTickCount(int newTickCount) {
    tickCount = newTickCount;
  }
}
