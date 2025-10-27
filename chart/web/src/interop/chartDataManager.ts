import type {
  CandleDTO,
  ChartMessage,
  ChartMessageType,
  ChartPatchPayload,
  ChartSeriesPayload,
} from './chartContracts';

export type ChartBridgeWindow = (Window & typeof globalThis) & {
  ChartFlutterUI?: {
    update: ((message: ChartMessage) => void) | null;
  };
  ChartDataManager?: ChartDataManager;
  ChartBridge?: {
    receiveFromFlutter: (message: ChartMessage) => void;
  };
};

/**
 * Maintains chart candle series inside the iframe realm and notifies Flutter when data changes.
 * Mirrors the todo POC pattern but adapted for chart-specific payloads.
 */
export class ChartDataManager {
  private readonly targetWindow: ChartBridgeWindow;
  private readonly series: CandleDTO[];
  private readonly candlesByTime: Map<number, CandleDTO>;

  constructor(targetWindow?: ChartBridgeWindow) {
    this.targetWindow = (targetWindow || window) as ChartBridgeWindow;

    // Backing array must be created using the iframe window so Flutter receives a JSArray from the same realm.
    this.series = new (this.targetWindow
      .Array as ArrayConstructor)() as CandleDTO[];
    this.candlesByTime = new Map<number, CandleDTO>();
  }

  /**
   * Returns the live candle array (same instance shared with Flutter side).
   */
  getSeries(): CandleDTO[] {
    return this.series;
  }

  /**
   * Replace entire series and notify Flutter with SET_SERIES payload.
   */
  setSeries(payload: ChartSeriesPayload, notify = true): void {
    this.series.length = 0;
    this.candlesByTime.clear();

    const sorted = [...payload.series].sort((a, b) => a.time - b.time);
    sorted.forEach(candle => {
      const clone = { ...candle };
      this.candlesByTime.set(clone.time, clone);
      this.series.push(clone);
    });

    if (notify) {
      this.notifyFlutter('SET_SERIES', { series: this.series });
    }
  }

  /**
   * Apply upserts/removals then emit PATCH_SERIES.
   */
  patchSeries(payload: ChartPatchPayload): void {
    if (payload.removals?.length) {
      const removals = new Set(payload.removals);
      // Remove from map first
      removals.forEach(timestamp => {
        this.candlesByTime.delete(timestamp);
      });
      // Filter backing array in-place to maintain the same instance
      let writeIndex = 0;
      for (let readIndex = 0; readIndex < this.series.length; readIndex++) {
        const candle = this.series[readIndex];
        if (!candle || removals.has(candle.time)) {
          continue;
        }
        this.series[writeIndex++] = candle;
      }
      this.series.length = writeIndex;
    }

    if (payload.upserts.length) {
      payload.upserts.forEach(upsert => {
        const clone = { ...upsert };
        this.candlesByTime.set(clone.time, clone);
      });
    }

    // Reconcile backing array ordering after removals/upserts
    const ordered = Array.from(this.candlesByTime.values()).sort(
      (a, b) => a.time - b.time,
    );
    this.series.length = 0;
    ordered.forEach(candle => {
      this.series.push(candle);
    });

    this.notifyFlutter('PATCH_SERIES', {
      upserts: payload.upserts,
      removals: payload.removals,
    });
  }

  clear(): void {
    this.series.length = 0;
    this.candlesByTime.clear();
    this.notifyFlutter('SET_SERIES', { series: this.series });
  }

  /**
   * Helper to emit ChartMessage into the iframe bridge if Flutter registered a listener.
   */
  private notifyFlutter(
    type: ChartMessageType,
    payload: ChartMessage['payload'],
  ): void {
    const bridge = this.targetWindow.ChartFlutterUI;
    if (typeof bridge?.update === 'function') {
      try {
        bridge.update({ type, payload });
      } catch {
        // Swallow notification errors to avoid noisy logging in the host shell.
      }
    }
  }
}

export function ensureChartBridge(
  targetWindow: ChartBridgeWindow,
): ChartDataManager {
  if (!targetWindow.ChartFlutterUI) {
    targetWindow.ChartFlutterUI = { update: null };
  }

  if (!targetWindow.ChartDataManager) {
    targetWindow.ChartDataManager = new ChartDataManager(targetWindow);
  }

  return targetWindow.ChartDataManager;
}

declare global {
  interface Window {
    ChartFlutterUI?: {
      update: ((message: ChartMessage) => void) | null;
    };
    ChartDataManager?: ChartDataManager;
    ChartBridge?: {
      receiveFromFlutter: (message: ChartMessage) => void;
    };
  }
}
