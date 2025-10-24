import 'package:flutter/material.dart';
import 'dart:js_interop';
import 'js_interop.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.dark,
      home: const TodoPage(),
    );
  }
}

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();
  List<TodoItem> _todos = [];

  @override
  void initState() {
    super.initState();
    // Setup JS interop callback first
    _setupJSCallback();
    // Then load initial todos
    _loadTodos();
  }

  void _setupJSCallback() {
    // Register callback to receive updates from JS
    try {
      // Set the update callback on the TodoFlutterUI object
      // Instead of receiving the array, just trigger a refresh
      todoFlutterUI.update = (() {
        // When JS notifies us of a change, reload the todos from TodoManager
        _loadTodos();
      }).toJS;
    } catch (e) {
      print('Error setting up JS callback: $e');
    }
  }

  void _loadTodos() {
    try {
      setState(() {
        _todos = todoManager.getAll().toDart;
      });
    } catch (e) {
      // print
      print('Error loading todos: $e');
    }
  }

  void _addTodo() {
    if (_textController.text.trim().isEmpty) return;

    final newItem = TodoItem(
      id: DateTime.now().millisecondsSinceEpoch,
      title: _textController.text.trim(),
      completed: false,
    );

    todoManager.add(newItem);
    _textController.clear();

    // Request focus back to the text field
    _textFocusNode.requestFocus();
  }

  void _removeTodo(int index) {
    todoManager.remove(index);
  }

  void _toggleComplete(int index) {
    // Get current item
    final currentItem = _todos[index];

    // Remove old item and add updated one
    todoManager.remove(index);

    final updatedItem = TodoItem(
      id: currentItem.id,
      title: currentItem.title,
      completed: !currentItem.completed,
    );

    // Insert at the same position
    final allItems = todoManager.getAll().toDart;
    allItems.insert(index, updatedItem);

    // Clear and re-add all items
    todoManager.clear();
    for (var item in allItems) {
      todoManager.add(item);
    }
  }

  void _clearAll() {
    todoManager.clear();
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo App'),
        actions: [
          if (_todos.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _clearAll,
              tooltip: 'Clear All',
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _textFocusNode,
                    decoration: const InputDecoration(
                      hintText: 'Enter a todo item',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addTodo(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _addTodo, child: const Text('Add')),
              ],
            ),
          ),
          Expanded(
            child: _todos.isEmpty
                ? const Center(
                    child: Text(
                      'No todos yet. Add one above!',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _todos.length,
                    itemBuilder: (context, index) {
                      final todo = _todos[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: Checkbox(
                            value: todo.completed,
                            onChanged: (_) => _toggleComplete(index),
                          ),
                          title: Text(
                            todo.title,
                            style: TextStyle(
                              decoration: todo.completed
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: todo.completed ? Colors.grey : null,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _removeTodo(index),
                            color: Colors.red,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
