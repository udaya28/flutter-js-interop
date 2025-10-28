/// Performance tracking stub.
/// Provides same API as TypeScript version but with no-op implementations.
/// Can be replaced with full implementation using a Dart histogram library.
/// Ported from src/chartlib/utils/performanceTracker.ts

class PerformanceTracker {
  static bool enabled = false; // Disabled by default for production

  static final Map<String, DateTime> _measurements = {};

  /// Start timing an operation
  static void start(String label) {
    if (!enabled) return;
    _measurements[label] = DateTime.now();
  }

  /// End timing and return duration in milliseconds
  static double end(String label, [String? additionalInfo]) {
    if (!enabled) return 0;

    final startTime = _measurements[label];
    if (startTime == null) {
      return 0;
    }

    final duration = DateTime.now().difference(startTime).inMicroseconds / 1000;
    _measurements.remove(label);

    return duration;
  }

  /// Log a message (only if enabled)
  static void log(String message) {
    if (!enabled) return;
    // ignore: avoid_print
    // print('[PERF] $message');
  }

  /// Measure an operation and return result
  static T measure<T>(String label, T Function() fn, [String? additionalInfo]) {
    if (!enabled) return fn();

    final startTime = DateTime.now();
    final result = fn();
    final duration = DateTime.now().difference(startTime).inMicroseconds / 1000;

    // Could record to histogram here if needed
    log('$label: ${duration.toStringAsFixed(1)}ms');

    return result;
  }

  /// Print statistics for all tracked labels (stub)
  static void printAllStats() {
    if (!enabled) return;
    log('Stats collection not implemented in stub');
  }

  /// Reset all statistics (stub)
  static void resetStats() {
    _measurements.clear();
  }

  /// Start periodic logging (stub)
  static void startPeriodicLogging([int intervalMs = 10000]) {
    if (!enabled) return;
    log('Periodic logging not implemented in stub');
  }

  /// Stop periodic logging (stub)
  static void stopPeriodicLogging() {
    // No-op
  }
}
