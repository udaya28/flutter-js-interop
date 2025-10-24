<script setup lang="ts">
import { RouterView } from 'vue-router';
</script>

<template>
  <nav>
    <RouterLink to="/">Home</RouterLink> |
    <RouterLink to="/todo">Todo</RouterLink>
  </nav>
  <RouterView />
</template>

<style scoped></style>
