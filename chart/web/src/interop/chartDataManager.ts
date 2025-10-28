import type {
  CandleDTO,
  ChartMessage,
  ChartSeriesPayload,
} from './chartContracts';

export type ChartBridgeWindow = (Window & typeof globalThis) & {
  ChartDataManager?: ChartDataManager;
  ChartBridge?: {
    receiveFromFlutter: (message: ChartMessage) => void;
  };
};

type HistoricalListener = (candles: CandleDTO[]) => void;
type RealtimeListener = (candle: CandleDTO) => void;

/**
 * Maintains chart candle series and exposes a minimal DataManager-style
 * contract for Flutter: `loadHistorical` and `onRealtimeUpdate`.
 */
export class ChartDataManager {
  private readonly targetWindow: ChartBridgeWindow;
  private candles: CandleDTO[];
  private historicalListener: HistoricalListener | null = null;
  private realtimeListener: RealtimeListener | null = null;

  constructor(targetWindow?: ChartBridgeWindow) {
    this.targetWindow = (targetWindow || window) as ChartBridgeWindow;
    this.candles = this.createRealmArray();
  }

  /**
   * Flutter registers a callback to receive the latest historical snapshot.
   * The callback is invoked immediately with the current dataset if available
   * and again whenever Vue replaces the underlying candle series.
   */
  loadHistorical(listener: HistoricalListener): void {
    this.historicalListener = listener;
    if (this.candles.length > 0) {
      listener(this.cloneCandles(this.candles));
    }
  }

  /**
   * Flutter registers a callback for realtime updates. Vue triggers the
   * callback whenever simulator ticks push a new/updated candle.
   */
  onRealtimeUpdate(listener: RealtimeListener): void {
    this.realtimeListener = listener;
  }

  /** Vue Helpers **/

  setHistoricalData(payload: ChartSeriesPayload): void {
    const sorted = [...payload.series].sort((a, b) => a.time - b.time);
    const next = this.createRealmArray();
    sorted.forEach(candle => {
      next.push({ ...candle });
    });
    this.candles = next;
    this.notifyHistorical();
  }

  pushRealtime(candle: CandleDTO): void {
    // const clone = { ...candle };
    // const index = this.candles.findIndex(item => item.time === clone.time);
    // if (index >= 0) {
    //   this.candles[index] = clone;
    // } else {
    //   this.candles.push(clone);
    //   this.candles.sort((a, b) => a.time - b.time);
    // }

    if (this.realtimeListener) {
      this.realtimeListener({ ...candle });
    }
  }

  clear(): void {
    this.candles = this.createRealmArray();
    this.notifyHistorical();
  }

  private notifyHistorical(): void {
    if (!this.historicalListener) {
      return;
    }
    this.historicalListener(this.cloneCandles(this.candles));
  }

  private createRealmArray(): CandleDTO[] {
    return new (this.targetWindow.Array as ArrayConstructor)() as CandleDTO[];
  }

  private cloneCandles(list: CandleDTO[]): CandleDTO[] {
    const clone = this.createRealmArray();
    list.forEach(candle => {
      clone.push({ ...candle });
    });
    return clone;
  }
}

export function ensureChartBridge(
  targetWindow: ChartBridgeWindow,
): ChartDataManager {
  if (!targetWindow.ChartDataManager) {
    targetWindow.ChartDataManager = new ChartDataManager(targetWindow);
  }

  return targetWindow.ChartDataManager;
}

declare global {
  interface Window {
    ChartDataManager?: ChartDataManager;
    ChartBridge?: {
      receiveFromFlutter: (message: ChartMessage) => void;
    };
  }
}
