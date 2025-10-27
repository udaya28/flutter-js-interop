import type { ChartMessage } from './chartContracts';
import type { ChartBridgeWindow } from './chartDataManager';

export type FlutterMessageHandler = (message: ChartMessage) => void;

/**
 * Installs a ChartBridge object on the iframe window so Flutter can deliver messages back into Vue.
 * Returns a disposer that removes the bridge if it is still attached.
 */
export function initializeChartBridge(
  targetWindow: ChartBridgeWindow,
  handler: FlutterMessageHandler,
): () => void {
  const bridge = {
    receiveFromFlutter(message: unknown) {
      if (typeof message === 'string') {
        try {
          const parsed = JSON.parse(message) as ChartMessage;
          handler(parsed);
          return;
        } catch {
          // Ignore malformed payloads and fall back to raw message handling below.
        }
      }

      handler(message as ChartMessage);
    },
  };

  targetWindow.ChartBridge = bridge;

  return () => {
    if (targetWindow.ChartBridge === bridge) {
      delete targetWindow.ChartBridge;
    }
  };
}
