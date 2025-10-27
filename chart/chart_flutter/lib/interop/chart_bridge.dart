import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

import 'chart_js_bindings.dart';

/// High-level helpers for communicating with the Vue shell.
class ChartBridge {
  ChartBridge({bool enableJsInterop = kIsWeb})
    : _enableJsInterop = enableJsInterop {
    if (_enableJsInterop) {
      _registerUpdateHandler();
    }
  }

  final bool _enableJsInterop;
  final Map<String, void Function(JSAny? payload)> _messageHandlers = {};

  void on(String type, void Function(JSAny? payload) handler) {
    _messageHandlers[type] = handler;
  }

  void _registerUpdateHandler() {
    chartFlutterUI.update = (JSAny? message) {
      if (message == null) {
        return;
      }
      try {
        final chartMessage = message as ChartMessage;
        final type = chartMessage.type;
        final payload = chartMessage.payload;
        final handler = _messageHandlers[type];
        if (handler != null) {
          handler(payload);
        } else {
          _log('[ChartBridge] No handler registered for message type "$type"');
        }
      } catch (error) {
        _log('[ChartBridge] Failed to process message: $error');
      }
    }.toJS;
  }

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
    print(message);
  }
}
