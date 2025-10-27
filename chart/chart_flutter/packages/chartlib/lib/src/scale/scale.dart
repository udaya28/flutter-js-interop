/// Common interface for chart scales.
/// Ported from src/chartlib/scale/scale.ts
abstract class Scale<TInput> {
  /// Maps an input value to the corresponding output value on the scale.
  double scaledValue(TInput value);

  /// Maps a pixel coordinate back to the domain value.
  /// Required for mouse interactions (crosshair, tooltips, drawing).
  TInput invert(double pixel);
}
