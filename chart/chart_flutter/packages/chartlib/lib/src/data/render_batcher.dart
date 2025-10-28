/// Batches render calls to prevent duplicate frames.
/// In Flutter, this integrates with the framework's rendering pipeline.
/// Ported from src/chartlib/data/renderBatcher.ts

/// Callback function for render execution.
typedef RenderCallback = void Function();

/// Batches render calls to prevent duplicate frames.
/// Multiple calls within the same frame are batched into one render.
///
/// Note: This is a simplified version for framework-agnostic chartlib.
/// The Flutter integration layer should use SchedulerBinding.addPostFrameCallback()
/// or CustomPainter's implicit rebuild mechanism for optimal performance.
class RenderBatcher {
  /// Render callback to execute on next frame
  RenderCallback? _onRender;

  /// Whether a render is already pending
  bool _isPending = false;

  /// Set the render callback.
  /// Called once per frame when render is requested.
  void setOnRender(RenderCallback callback) {
    _onRender = callback;
  }

  /// Request a render on the next frame.
  /// Multiple calls within the same frame are batched into one render.
  ///
  /// Note: In the actual Flutter integration, this should be replaced with:
  /// - SchedulerBinding.instance.scheduleFrameCallback() for manual control
  /// - Or rely on CustomPainter's markNeedsPaint() for automatic repaints
  void requestRender() {
    // Already have a pending frame, no need to schedule another
    if (_isPending) {
      // print('[RenderBatcher.requestRender] BATCHED - render already pending');
      return;
    }

    // print('[RenderBatcher.requestRender] SCHEDULED - new render request');
    _isPending = true;

    // Schedule render on next microtask (immediate in Flutter)
    // In actual Flutter integration, replace this with:
    // SchedulerBinding.instance.scheduleFrameCallback((_) { ... })
    Future.microtask(() {
      _isPending = false;
      // print('[RenderBatcher.requestRender] EXECUTING - calling onRender callback');

      // Execute render callback
      _onRender?.call();
    });
  }

  /// Cancel any pending render request.
  void cancel() {
    _isPending = false;
  }

  /// Clean up resources.
  /// Call this when destroying the batcher.
  void destroy() {
    cancel();
    _onRender = null;
  }
}
