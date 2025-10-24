<script setup lang="ts">
import { TodoManagerFlutter } from '@/todo';
import { onMounted, ref } from 'vue';

const flutterContainer = ref<HTMLDivElement | null>(null);

onMounted(() => {
  const iframe = document.createElement('iframe');
  // Load Flutter app
  if (flutterContainer.value) {
    iframe.src = '/flutter/index.html';
    iframe.style.width = '100%';
    iframe.style.height = '600px';
    iframe.style.border = 'none';
    flutterContainer.value.appendChild(iframe);
    iframe.onload = () => {
      // Initialize TodoFlutterUI object on the iframe's window
      const iframeWindow = iframe.contentWindow as any;
      if (iframeWindow) {
        // IMPORTANT: Initialize TodoFlutterUI object FIRST
        // This creates the object that Flutter will attach its callback to
        iframeWindow.TodoFlutterUI = {
          update: null, // Flutter will replace this with its callback
        };

        // Initialize TodoManager on the iframe's window
        // CRITICAL: Pass the iframe window so TodoManager knows which context to use
        iframeWindow.TodoManager = new TodoManagerFlutter(iframeWindow);
      }
    };
  }
});
</script>

<template>
  <div class="todo-page">
    <h1>Flutter Todo App</h1>
    <div ref="flutterContainer" class="flutter-container"></div>
  </div>
</template>

<style scoped>
.todo-page {
  padding: 20px;
}

.flutter-container {
  width: 500px;
  margin-top: 20px;
  border: 1px solid #ccc;
  border-radius: 8px;
  overflow: hidden;
}

h1 {
  font-size: 24px;
  margin-bottom: 16px;
}
</style>
