declare global {
  interface Window {
    TodoManager: TodoManagerFlutter;
    TodoFlutterUI: {
      update: (() => void) | null;
    };
  }
}

type TodoItem = {
  id: number;
  title: string;
  completed: boolean;
};

export class TodoManagerFlutter {
  private items: TodoItem[];

  // Store reference to the window context where this manager is running
  private targetWindow: Window & typeof globalThis;

  constructor(targetWindow?: Window & typeof globalThis) {
    // Use the provided window context, or default to globalThis/window
    this.targetWindow = (targetWindow || globalThis) as Window &
      typeof globalThis;
    // Create the backing array in the target window's realm so Flutter sees a true JSArray
    this.items = new (this.targetWindow.Array as typeof Array)() as TodoItem[];
  }

  // Add a new todo item
  add(item: TodoItem): void {
    this.items.push(item);
    if (
      this.targetWindow.TodoFlutterUI?.update &&
      typeof this.targetWindow.TodoFlutterUI.update === 'function'
    ) {
      this.targetWindow.TodoFlutterUI.update();
    }
  }

  // Remove a todo item by its index
  remove(index: number): void {
    if (index >= 0 && index < this.items.length) {
      this.items.splice(index, 1);
    } else {
      throw new Error('Index out of bounds');
    }
    if (
      this.targetWindow.TodoFlutterUI?.update &&
      typeof this.targetWindow.TodoFlutterUI.update === 'function'
    ) {
      this.targetWindow.TodoFlutterUI.update();
    }
  }

  // Get all todo items
  getAll(): TodoItem[] {
    return this.items;
  }

  // Clear all todo items
  clear(): void {
    this.items.length = 0;
    if (
      this.targetWindow.TodoFlutterUI?.update &&
      typeof this.targetWindow.TodoFlutterUI.update === 'function'
    ) {
      this.targetWindow.TodoFlutterUI.update();
    }
  }
}
