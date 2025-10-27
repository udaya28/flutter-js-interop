<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, reactive, ref } from 'vue';
import {
  ensureChartBridge,
  type ChartBridgeWindow,
} from '@/interop/chartDataManager';
import { initializeChartBridge } from '@/interop/chartBridge';
import type {
  CandleDTO,
  ChartMessage,
  ChartMessageType,
} from '@/interop/chartContracts';
import { generateDemoCandles, Volatility } from '@/demo/dataSimulator';
import {
  ChartSimulator,
  type ChartSimulatorConfig,
  type ChartSimulatorState,
  type SimulatorDuration,
  type SimulatorVolatility,
} from '@/interop/chartSimulator';

defineOptions({
  name: 'ChartPage',
});

const flutterContainer = ref<HTMLDivElement | null>(null);
const targetWindow = ref<ChartBridgeWindow | null>(null);
const cleanupTasks: Array<() => void> = [];

const simulatorRef = ref<ChartSimulator | null>(null);
const dataManagerRef = ref<ReturnType<typeof ensureChartBridge> | null>(null);
const demoSeries = ref<CandleDTO[]>([]);

const volatilityOptions: Array<{ label: string; value: SimulatorVolatility }> =
  [
    { label: 'Low', value: 'low' },
    { label: 'Medium', value: 'medium' },
    { label: 'High', value: 'high' },
  ];

const durationOptions: Array<{ label: string; value: SimulatorDuration }> = [
  { label: '1 Second', value: '1s' },
  { label: '5 Seconds', value: '5s' },
  { label: '30 Seconds', value: '30s' },
  { label: '1 Minute', value: '1m' },
  { label: '5 Minutes', value: '5m' },
  { label: '15 Minutes', value: '15m' },
  { label: '30 Minutes', value: '30m' },
  { label: '1 Hour', value: '1h' },
  { label: '4 Hours', value: '4h' },
  { label: '1 Day', value: '1d' },
  { label: '1 Week', value: '1w' },
  { label: '1 Month', value: '1M' },
];

const simulatorConfig = reactive({
  volatility: 'medium' as SimulatorVolatility,
  candleDuration: '1m' as SimulatorDuration,
  ticksPerSecond: 5,
  initialPrice: 100,
  initialHistoricalCount: 500,
  autoStart: false,
});

const simulatorStatus = reactive<ChartSimulatorState & { chartReady: boolean }>(
  {
    mode: 'interop',
    isConfigured: false,
    isRunning: false,
    wantsRunning: false,
    config: null,
    chartReady: false,
  },
);

const isSimulatorActive = computed(() => simulatorStatus.mode === 'simulator');
const canStartSimulator = computed(
  () =>
    simulatorStatus.mode === 'simulator' &&
    simulatorStatus.isConfigured &&
    !simulatorStatus.isRunning,
);
const canStopSimulator = computed(
  () => simulatorStatus.mode === 'simulator' && simulatorStatus.isRunning,
);
const canResetSimulator = computed(
  () => simulatorStatus.mode === 'simulator' && simulatorStatus.isConfigured,
);

const statusSummary = computed(() => {
  const modeLabel =
    simulatorStatus.mode === 'simulator' ? 'Simulator mode' : 'Demo data mode';
  const runningState = simulatorStatus.isRunning
    ? 'Running'
    : simulatorStatus.wantsRunning
      ? 'Starting…'
      : 'Stopped';
  const readiness = simulatorStatus.chartReady
    ? 'Chart ready'
    : 'Waiting for chart';
  return `${modeLabel} · ${runningState} · ${readiness}`;
});

const BASE_TIMESTAMP = 1_710_000_000_000;
const CANDLE_INTERVAL_MS = 60_000;

async function buildDemoSeries(count = 600): Promise<CandleDTO[]> {
  const startTime = new Date(BASE_TIMESTAMP + CANDLE_INTERVAL_MS);
  const rawCandles = await generateDemoCandles(count, {
    startTime,
    initialPrice: 100,
    candleDurationMs: CANDLE_INTERVAL_MS,
    volatility: Volatility.Medium,
    ticksPerSecond: 5,
    timezone: 'Asia/Kolkata',
  });

  return rawCandles.map(candle => ({
    time: candle.timestamp.getTime(),
    open: Number(candle.open.toFixed(2)),
    high: Number(candle.high.toFixed(2)),
    low: Number(candle.low.toFixed(2)),
    close: Number(candle.close.toFixed(2)),
    volume: Math.max(0, Math.round(candle.volume)),
  }));
}

function buildSimulatorConfig(): ChartSimulatorConfig {
  return {
    volatility: simulatorConfig.volatility,
    candleDuration: simulatorConfig.candleDuration,
    ticksPerSecond: simulatorConfig.ticksPerSecond,
    initialPrice: simulatorConfig.initialPrice,
    initialHistoricalCount: simulatorConfig.initialHistoricalCount,
  };
}

function handleSimulatorState(state: ChartSimulatorState | null) {
  if (!state) {
    simulatorStatus.mode = 'interop';
    simulatorStatus.isConfigured = false;
    simulatorStatus.isRunning = false;
    simulatorStatus.wantsRunning = false;
    simulatorStatus.config = null;
    simulatorStatus.chartReady = false;
    return;
  }

  simulatorStatus.mode = state.mode;
  simulatorStatus.isConfigured = state.isConfigured;
  simulatorStatus.isRunning = state.isRunning;
  simulatorStatus.wantsRunning = state.wantsRunning;
  simulatorStatus.config = state.config ? { ...state.config } : null;

  if (state.config) {
    simulatorConfig.volatility = state.config.volatility;
    simulatorConfig.candleDuration = state.config.candleDuration;
    simulatorConfig.ticksPerSecond = state.config.ticksPerSecond;
    simulatorConfig.initialPrice = state.config.initialPrice;
    simulatorConfig.initialHistoricalCount =
      state.config.initialHistoricalCount;
    simulatorConfig.autoStart = state.wantsRunning;
  }
}

function sendToFlutter(
  target: ChartBridgeWindow,
  type: ChartMessageType,
  payload: ChartMessage['payload'],
) {
  const update = target.ChartFlutterUI?.update;
  if (typeof update === 'function') {
    update({ type, payload });
  }
}

function notifyFlutter(
  type: ChartMessageType,
  payload: ChartMessage['payload'],
) {
  const target = targetWindow.value;
  if (!target) {
    return;
  }
  sendToFlutter(target, type, payload);
}

async function applySimulatorConfig(autoStartOverride?: boolean) {
  const instance = simulatorRef.value;
  if (!instance) {
    return;
  }

  const autoStart = autoStartOverride ?? simulatorConfig.autoStart;
  await instance.configure(buildSimulatorConfig(), { autoStart });
}

function applyAndStartSimulator() {
  void applySimulatorConfig(true);
}

function startSimulator() {
  simulatorRef.value?.start();
}

function stopSimulator() {
  simulatorRef.value?.stop();
}

function resetSimulator() {
  void simulatorRef.value?.reset();
}

function disableSimulator() {
  simulatorRef.value?.disable();
  simulatorConfig.autoStart = false;

  const dataManager = dataManagerRef.value;
  if (dataManager && demoSeries.value.length > 0) {
    dataManager.setSeries({ series: demoSeries.value });
  }
}

function waitForFlutterReady(
  target: ChartBridgeWindow,
  onReady: () => void,
  intervalMs = 250,
  timeoutMs = 15_000,
): () => void {
  const start = Date.now();
  const timer = window.setInterval(() => {
    const update = target.ChartFlutterUI?.update;
    if (typeof update === 'function') {
      window.clearInterval(timer);
      onReady();
      return;
    }

    if (Date.now() - start > timeoutMs) {
      window.clearInterval(timer);
    }
  }, intervalMs);

  return () => window.clearInterval(timer);
}

onMounted(() => {
  const container = flutterContainer.value;
  if (!container) {
    return;
  }

  const iframe = document.createElement('iframe');
  iframe.src = '/flutter/index.html';
  iframe.style.width = '100%';
  iframe.style.height = '100%';
  iframe.style.border = 'none';
  container.appendChild(iframe);

  iframe.onload = async () => {
    const iframeWindow = iframe.contentWindow as ChartBridgeWindow | null;
    if (!iframeWindow) {
      return;
    }

    targetWindow.value = iframeWindow;
    cleanupTasks.push(() => {
      targetWindow.value = null;
      dataManagerRef.value = null;
      handleSimulatorState(null);
    });

    try {
      const candles = await buildDemoSeries();
      demoSeries.value = candles;

      const dataManager = ensureChartBridge(iframeWindow);
      dataManagerRef.value = dataManager;

      const simulator = new ChartSimulator(dataManager);
      const unsubscribe = simulator.subscribe(state => {
        handleSimulatorState(state);
      });
      simulatorRef.value = simulator;

      cleanupTasks.push(() => {
        unsubscribe();
        simulator.dispose();
        simulatorRef.value = null;
      });

      const bridgeDisposer = initializeChartBridge(iframeWindow, message => {
        if (message.type === 'CHART_READY') {
          const payload = message.payload as { ready?: boolean } | null;
          simulatorStatus.chartReady = payload?.ready ?? true;
        }
      });
      cleanupTasks.push(bridgeDisposer);

      if (candles.length > 0) {
        dataManager.setSeries({ series: candles }, false);
      }

      const stopPolling = waitForFlutterReady(iframeWindow, () => {
        if (candles.length === 0) {
          return;
        }

        simulatorStatus.chartReady = true;

        const firstCandle = candles[0] ?? null;
        const lastCandle = candles[candles.length - 1] ?? firstCandle;
        if (!firstCandle || !lastCandle) {
          return;
        }

        const viewport = {
          startTime: firstCandle.time,
          endTime: lastCandle.time,
        };

        notifyFlutter('INIT_CHART', {
          theme: 'dark',
          series: candles,
          viewport,
        });

        dataManager.setSeries({ series: candles });
      });

      cleanupTasks.push(stopPolling);
    } catch {
      // Swallow initialization failures to keep UI responsive.
    } finally {
      cleanupTasks.push(() => {
        iframe.remove();
      });
    }
  };
});

onBeforeUnmount(() => {
  while (cleanupTasks.length) {
    const dispose = cleanupTasks.pop();
    try {
      dispose?.();
    } catch {
      // Ignore cleanup errors.
    }
  }
});
</script>

<template>
  <div class="chart-page">
    <h1>Flutter Chart POC</h1>
    <div class="control-panel">
      <div class="control-grid">
        <label class="control-field">
          <span>Volatility</span>
          <select v-model="simulatorConfig.volatility">
            <option
              v-for="option in volatilityOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </select>
        </label>
        <label class="control-field">
          <span>Candle Duration</span>
          <select v-model="simulatorConfig.candleDuration">
            <option
              v-for="option in durationOptions"
              :key="option.value"
              :value="option.value"
            >
              {{ option.label }}
            </option>
          </select>
        </label>
        <label class="control-field">
          <span>Ticks / sec</span>
          <input
            type="number"
            v-model.number="simulatorConfig.ticksPerSecond"
            min="1"
            max="120"
          />
        </label>
        <label class="control-field">
          <span>Initial Price</span>
          <input
            type="number"
            v-model.number="simulatorConfig.initialPrice"
            min="1"
            step="1"
          />
        </label>
        <label class="control-field">
          <span>Initial Candles</span>
          <input
            type="number"
            v-model.number="simulatorConfig.initialHistoricalCount"
            min="100"
            step="25"
          />
        </label>
        <label class="control-field auto-start">
          <span>Auto start when ready</span>
          <input type="checkbox" v-model="simulatorConfig.autoStart" />
        </label>
      </div>
      <div class="button-row">
        <button type="button" @click="applySimulatorConfig()">
          Apply Config
        </button>
        <button type="button" @click="applyAndStartSimulator()">
          Apply &amp; Start
        </button>
        <button
          type="button"
          @click="startSimulator()"
          :disabled="!canStartSimulator"
        >
          Start
        </button>
        <button
          type="button"
          @click="stopSimulator()"
          :disabled="!canStopSimulator"
        >
          Stop
        </button>
        <button
          type="button"
          @click="resetSimulator()"
          :disabled="!canResetSimulator"
        >
          Reset
        </button>
        <button
          type="button"
          @click="disableSimulator()"
          :disabled="!isSimulatorActive"
        >
          Use Demo Data
        </button>
      </div>
      <p class="status-line">{{ statusSummary }}</p>
    </div>
    <div ref="flutterContainer" class="flutter-container"></div>
  </div>
</template>

<style scoped>
.chart-page {
  padding: 20px;
}

.control-panel {
  margin-top: 16px;
  padding: 16px;
  border: 1px solid #d0d7de;
  border-radius: 8px;
  background-color: #fafbfc;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.control-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 12px;
}

.control-field {
  display: flex;
  flex-direction: column;
  font-size: 13px;
  color: #1f2933;
}

.control-field span {
  font-weight: 600;
}

.control-field select,
.control-field input {
  margin-top: 6px;
  padding: 6px 8px;
  border-radius: 4px;
  border: 1px solid #cbd5e1;
  background-color: #ffffff;
  font-size: 13px;
  color: #111827;
}

.auto-start {
  align-self: flex-end;
  justify-content: flex-end;
}

.auto-start input {
  margin-top: 12px;
  width: auto;
}

.button-row {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.button-row button {
  padding: 6px 14px;
  border-radius: 4px;
  border: 1px solid #2563eb;
  background-color: #2563eb;
  color: #ffffff;
  font-size: 13px;
  cursor: pointer;
  transition: background-color 0.15s ease;
}

.button-row button:hover:not(:disabled) {
  background-color: #1d4ed8;
}

.button-row button:disabled {
  background-color: #94a3b8;
  border-color: #94a3b8;
  cursor: not-allowed;
}

.button-row button:last-child {
  background-color: #64748b;
  border-color: #64748b;
}

.button-row button:last-child:hover:not(:disabled) {
  background-color: #475569;
}

.status-line {
  margin: 0;
  font-size: 13px;
  color: #475569;
}

.flutter-container {
  height: 500px;
  width: 100%;
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
