import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

import 'chart_js_bindings.dart';

/// High-level helpers for communicating with the Vue shell.
class ChartBridge {
  ChartBridge({bool enableJsInterop = kIsWeb})
    : _enableJsInterop = enableJsInterop;

  final bool _enableJsInterop;

  void sendToVue(String type, Object? payload) {
    if (!_enableJsInterop) {
      _log('[ChartBridge] JS interop disabled, dropping "$type"');
      return;
    }

    final bridge = chartBridge;
    if (bridge == null) {
      _log(
        '[ChartBridge] ChartBridge object not found on window, cannot send "$type"',
      );
      return;
    }

    try {
      final encoded = jsonEncode({'type': type, 'payload': payload}).toJS;
      bridge.receiveFromFlutter(encoded);
    } catch (error) {
      _log('[ChartBridge] Failed to send message to Vue: $error');
    }
  }

  void _log(String message) {
    // ignore: avoid_print
    // print(message);
  }
}
