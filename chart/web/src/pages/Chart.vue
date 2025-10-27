<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue';
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

defineOptions({
  name: 'ChartPage',
});

const flutterContainer = ref<HTMLDivElement | null>(null);
const cleanupTasks: Array<() => void> = [];

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

function sendToFlutter(
  targetWindow: ChartBridgeWindow,
  type: ChartMessageType,
  payload: ChartMessage['payload'],
) {
  const update = targetWindow.ChartFlutterUI?.update;
  if (typeof update === 'function') {
    update({ type, payload });
  } else {
    console.warn('[ChartPage] Flutter bridge not ready for message', type);
  }
}

function waitForFlutterReady(
  targetWindow: ChartBridgeWindow,
  onReady: () => void,
  intervalMs = 250,
  timeoutMs = 15000,
): () => void {
  const start = Date.now();
  const timer = window.setInterval(() => {
    const update = targetWindow.ChartFlutterUI?.update;
    if (typeof update === 'function') {
      window.clearInterval(timer);
      onReady();
      return;
    }

    if (Date.now() - start > timeoutMs) {
      window.clearInterval(timer);
      console.warn(
        '[ChartPage] Timed out waiting for Flutter bridge to become ready',
      );
    }
  }, intervalMs);

  return () => window.clearInterval(timer);
}

onMounted(() => {
  const iframe = document.createElement('iframe');
  // Load Flutter app
  if (flutterContainer.value) {
    iframe.src = '/flutter/index.html';
    iframe.style.width = '100%';
    iframe.style.height = '100%';
    iframe.style.border = 'none';
    flutterContainer.value.appendChild(iframe);
    iframe.onload = async () => {
      const iframeWindow = iframe.contentWindow as ChartBridgeWindow | null;
      if (iframeWindow) {
        try {
          const demoCandles = await buildDemoSeries();
          const dataManager = ensureChartBridge(iframeWindow);
          const bridgeDisposer = initializeChartBridge(
            iframeWindow,
            message => {
              console.log('[Flutter → Vue]', message);
            },
          );
          cleanupTasks.push(bridgeDisposer);

          if (demoCandles.length > 0) {
            dataManager.setSeries({ series: demoCandles }, false);
          }

          const stopPolling = waitForFlutterReady(iframeWindow, () => {
            if (demoCandles.length === 0) {
              console.warn('[ChartPage] No demo data generated for INIT_CHART');
              return;
            }

            console.info(
              '[ChartPage] Flutter bridge ready, sending initial chart data',
            );
            const firstCandle = demoCandles[0] ?? null;
            const lastCandle =
              demoCandles[demoCandles.length - 1] ?? firstCandle;

            if (!firstCandle || !lastCandle) {
              console.warn(
                '[ChartPage] Unable to resolve viewport from demo data',
              );
              return;
            }
            const viewport = {
              startTime: firstCandle.time,
              endTime: lastCandle.time,
            };

            sendToFlutter(iframeWindow, 'INIT_CHART', {
              theme: 'dark',
              series: demoCandles,
              viewport,
            });

            dataManager.setSeries({ series: demoCandles });
          });

          cleanupTasks.push(stopPolling);
        } catch (error) {
          console.error('[ChartPage] Failed to build demo data', error);
        }

        cleanupTasks.push(() => {
          iframe.remove();
        });
      }
    };
  }
});

onBeforeUnmount(() => {
  while (cleanupTasks.length) {
    const dispose = cleanupTasks.pop();
    try {
      dispose?.();
    } catch (error) {
      console.error('[ChartPage] Error during cleanup', error);
    }
  }
});
</script>

<template>
  <div class="chart-page">
    <h1>Flutter Chart POC</h1>
    <div ref="flutterContainer" class="flutter-container"></div>
  </div>
</template>

<style scoped>
.chart-page {
  padding: 20px;
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
