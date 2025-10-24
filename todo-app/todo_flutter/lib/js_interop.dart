import 'dart:js_interop';

@JS('alert')
external void showAlert(String message);

// TodoItem class matching the TypeScript interface
@JS()
@anonymous
extension type TodoItem._(JSObject _) implements JSObject {
  external factory TodoItem({int id, String title, bool completed});

  external int get id;
  external String get title;
  external bool get completed;
}

// TodoManagerFlutter class from window object
@JS('TodoManager')
extension type TodoManagerFlutter._(JSObject _) implements JSObject {
  external void add(TodoItem item);
  external void remove(int index);
  external JSArray<TodoItem> getAll();
  external void clear();
}

// TodoFlutterUI interface to expose update callback
@JS('TodoFlutterUI')
extension type TodoFlutterUI._(JSObject _) implements JSObject {
  external set update(JSFunction callback);
}

// Get TodoManager from window
@JS('window.TodoManager')
external TodoManagerFlutter get todoManager;

// Get TodoFlutterUI from window
@JS('window.TodoFlutterUI')
external TodoFlutterUI get todoFlutterUI;
