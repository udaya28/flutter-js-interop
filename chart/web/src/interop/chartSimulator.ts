import { generateDemoCandles, Volatility } from '@/demo/dataSimulator';
import type { CandleDTO } from './chartContracts';
import type { ChartDataManager } from './chartDataManager';

export type SimulatorVolatility = 'low' | 'medium' | 'high';
export type SimulatorDuration =
  | '1s'
  | '5s'
  | '30s'
  | '1m'
  | '5m'
  | '15m'
  | '30m'
  | '1h'
  | '4h'
  | '1d'
  | '1w'
  | '1M';

export interface ChartSimulatorConfig {
  volatility: SimulatorVolatility;
  candleDuration: SimulatorDuration;
  ticksPerSecond: number;
  initialPrice: number;
  initialHistoricalCount: number;
}

export interface ChartSimulatorState {
  mode: 'interop' | 'simulator';
  isConfigured: boolean;
  isRunning: boolean;
  wantsRunning: boolean;
  config: ChartSimulatorConfig | null;
}

const CANDLE_DURATION_MS: Record<SimulatorDuration, number> = {
  '1s': 1_000,
  '5s': 5_000,
  '30s': 30_000,
  '1m': 60_000,
  '5m': 300_000,
  '15m': 900_000,
  '30m': 1_800_000,
  '1h': 3_600_000,
  '4h': 14_400_000,
  '1d': 86_400_000,
  '1w': 604_800_000,
  '1M': 2_592_000_000,
};

const DEFAULT_CONFIG: ChartSimulatorConfig = {
  volatility: 'medium',
  candleDuration: '1m',
  ticksPerSecond: 5,
  initialPrice: 100,
  initialHistoricalCount: 500,
};

const MIN_TICKS_PER_SECOND = 1;
const MAX_TICKS_PER_SECOND = 120;
const MIN_INITIAL_PRICE = 1;
const MIN_HISTORICAL_CANDLES = 50;
const MAX_HISTORICAL_CANDLES = 5_000;

interface VolatilityParams {
  tickRange: number;
  jumpChance: number;
  jumpRange: number;
}

export class ChartSimulator {
  constructor(private readonly dataManager: ChartDataManager) {}

  private state: ChartSimulatorState = {
    mode: 'interop',
    isConfigured: false,
    isRunning: false,
    wantsRunning: false,
    config: null,
  };

  private timerId: number | null = null;
  private currentCandle: CandleDTO | null = null;
  private currentPrice = DEFAULT_CONFIG.initialPrice;
  private nextTimestamp = Date.now();
  private candleDurationMs = CANDLE_DURATION_MS[DEFAULT_CONFIG.candleDuration];
  private ticksPerCandle = this.resolveTicksPerCandle(
    this.candleDurationMs,
    DEFAULT_CONFIG.ticksPerSecond,
  );
  private ticksInCurrentCandle = 0;
  private readonly listeners = new Set<(state: ChartSimulatorState) => void>();

  subscribe(listener: (state: ChartSimulatorState) => void): () => void {
    this.listeners.add(listener);
    listener(this.getState());
    return () => {
      this.listeners.delete(listener);
    };
  }

  getState(): ChartSimulatorState {
    return {
      ...this.state,
      config: this.state.config ? { ...this.state.config } : null,
    };
  }

  async configure(
    config: ChartSimulatorConfig,
    options: { autoStart?: boolean } = {},
  ): Promise<void> {
    const normalized = this.normalizeConfig(config);
    this.stopTicker();

    const durationMs = this.resolveDurationMs(normalized.candleDuration);
    const ticksPerCandle = this.resolveTicksPerCandle(
      durationMs,
      normalized.ticksPerSecond,
    );

    const historical = await this.buildHistoricalSeries(normalized, durationMs);
    this.dataManager.setHistoricalData({ series: historical });

    const lastCandle = historical[historical.length - 1] ?? null;
    this.currentPrice = lastCandle?.close ?? normalized.initialPrice;
    this.nextTimestamp = (lastCandle?.time ?? Date.now()) + durationMs;
    this.candleDurationMs = durationMs;
    this.ticksPerCandle = ticksPerCandle;
    this.currentCandle = null;
    this.ticksInCurrentCandle = 0;

    this.setState({
      mode: 'simulator',
      isConfigured: true,
      isRunning: false,
      wantsRunning: options.autoStart ?? false,
      config: normalized,
    });

    if (options.autoStart) {
      this.start();
    }
  }

  start(): void {
    if (!this.state.config) {
      return;
    }

    if (this.timerId != null) {
      this.updateState({ wantsRunning: true, isRunning: true });
      return;
    }

    if (!this.currentCandle) {
      this.currentCandle = this.createNextCandle();
      this.publishRealTimeTick(this.currentCandle);
    }

    const intervalMs = Math.max(
      8,
      Math.floor(1_000 / this.state.config.ticksPerSecond),
    );
    this.timerId = window.setInterval(() => this.tick(), intervalMs);

    this.updateState({ isRunning: true, wantsRunning: true });
  }

  stop(): void {
    if (this.timerId == null) {
      this.updateState({ wantsRunning: false, isRunning: false });
      return;
    }

    this.stopTicker();
    this.updateState({ wantsRunning: false, isRunning: false });
  }

  async reset(): Promise<void> {
    const activeConfig = this.state.config;
    if (!activeConfig) {
      return;
    }

    const shouldAutoStart = this.state.isRunning || this.state.wantsRunning;
    await this.configure(activeConfig, { autoStart: shouldAutoStart });
  }

  disable(): void {
    this.stopTicker();
    this.currentCandle = null;
    this.setState({
      mode: 'interop',
      isConfigured: false,
      isRunning: false,
      wantsRunning: false,
      config: null,
    });
  }

  dispose(): void {
    this.disable();
  }

  private tick(): void {
    const activeConfig = this.state.config;
    if (!activeConfig) {
      return;
    }

    if (!this.currentCandle) {
      this.currentCandle = this.createNextCandle();
      this.publishRealTimeTick(this.currentCandle);
    }

    const params = this.resolveVolatilityParams(
      activeConfig.volatility,
      activeConfig.ticksPerSecond,
    );

    const normalMove = (Math.random() - 0.5) * params.tickRange;
    const jumpMove =
      Math.random() < params.jumpChance
        ? (Math.random() - 0.5) * params.jumpRange
        : 0;
    const totalMove = normalMove + jumpMove;

    const nextPrice = this.roundPrice(
      Math.max(0.01, this.currentPrice * (1 + totalMove)),
    );

    this.currentPrice = nextPrice;

    const candle = this.currentCandle;
    candle.close = nextPrice;
    candle.high = Math.max(candle.high, nextPrice);
    candle.low = Math.min(candle.low, nextPrice);
    candle.volume = (candle.volume ?? 0) + this.randomVolumeIncrement();

    this.publishRealTimeTick(candle);

    this.ticksInCurrentCandle += 1;
    if (this.ticksInCurrentCandle < this.ticksPerCandle) {
      return;
    }

    this.ticksInCurrentCandle = 0;
    this.currentCandle = this.createNextCandle();
    this.publishRealTimeTick(this.currentCandle);
  }

  private stopTicker(): void {
    if (this.timerId != null) {
      window.clearInterval(this.timerId);
      this.timerId = null;
    }
  }

  private createNextCandle(): CandleDTO {
    const open = this.roundPrice(this.currentPrice);
    const timestamp = this.nextTimestamp;
    this.nextTimestamp = timestamp + this.candleDurationMs;

    return {
      time: timestamp,
      open,
      high: open,
      low: open,
      close: open,
      volume: 0,
    };
  }

  private publishRealTimeTick(candle: CandleDTO): void {
    this.dataManager.pushRealtime({ ...candle });
  }

  private resolveDurationMs(duration: SimulatorDuration): number {
    return (
      CANDLE_DURATION_MS[duration] ??
      CANDLE_DURATION_MS[DEFAULT_CONFIG.candleDuration]
    );
  }

  private resolveTicksPerCandle(
    durationMs: number,
    ticksPerSecond: number,
  ): number {
    const clampedTicks = Math.max(
      MIN_TICKS_PER_SECOND,
      Math.min(MAX_TICKS_PER_SECOND, ticksPerSecond),
    );
    const ticks = Math.max(1, Math.round((durationMs / 1_000) * clampedTicks));
    return ticks;
  }

  private normalizeConfig(config: ChartSimulatorConfig): ChartSimulatorConfig {
    const normalized: ChartSimulatorConfig = {
      volatility: config.volatility ?? DEFAULT_CONFIG.volatility,
      candleDuration: config.candleDuration ?? DEFAULT_CONFIG.candleDuration,
      ticksPerSecond: Math.max(
        MIN_TICKS_PER_SECOND,
        Math.min(
          MAX_TICKS_PER_SECOND,
          Math.round(config.ticksPerSecond ?? DEFAULT_CONFIG.ticksPerSecond),
        ),
      ),
      initialPrice: Math.max(
        MIN_INITIAL_PRICE,
        Number.isFinite(config.initialPrice)
          ? Number(config.initialPrice)
          : DEFAULT_CONFIG.initialPrice,
      ),
      initialHistoricalCount: Math.max(
        MIN_HISTORICAL_CANDLES,
        Math.min(
          MAX_HISTORICAL_CANDLES,
          Math.round(
            config.initialHistoricalCount ??
              DEFAULT_CONFIG.initialHistoricalCount,
          ),
        ),
      ),
    };

    return normalized;
  }

  private async buildHistoricalSeries(
    config: ChartSimulatorConfig,
    durationMs: number,
  ): Promise<CandleDTO[]> {
    const raw = await generateDemoCandles(config.initialHistoricalCount, {
      candleDurationMs: durationMs,
      initialPrice: config.initialPrice,
      volatility: this.toVolatilityEnum(config.volatility),
      ticksPerSecond: config.ticksPerSecond,
      startTime: new Date(this.nextTimestamp - durationMs),
      timezone: 'Asia/Kolkata',
    });

    return raw.map(candle => ({
      time: candle.timestamp.getTime(),
      open: this.roundPrice(candle.open),
      high: this.roundPrice(candle.high),
      low: this.roundPrice(candle.low),
      close: this.roundPrice(candle.close),
      volume: Math.max(0, Math.round(candle.volume)),
    }));
  }

  private toVolatilityEnum(volatility: SimulatorVolatility): Volatility {
    switch (volatility) {
      case 'low':
        return Volatility.Low;
      case 'high':
        return Volatility.High;
      default:
        return Volatility.Medium;
    }
  }

  private resolveVolatilityParams(
    volatility: SimulatorVolatility,
    ticksPerSecond: number,
  ): VolatilityParams {
    const tickScaleFactor = Math.sqrt(1 / Math.max(1, ticksPerSecond));
    const jumpChanceScaleFactor = 1 / Math.max(1, ticksPerSecond);

    switch (volatility) {
      case 'low':
        return {
          tickRange: 0.003 * tickScaleFactor,
          jumpChance: 0.03 * jumpChanceScaleFactor,
          jumpRange: 0.1,
        };
      case 'high':
        return {
          tickRange: 0.012 * tickScaleFactor,
          jumpChance: 0.08 * jumpChanceScaleFactor,
          jumpRange: 0.3,
        };
      default:
        return {
          tickRange: 0.006 * tickScaleFactor,
          jumpChance: 0.05 * jumpChanceScaleFactor,
          jumpRange: 0.2,
        };
    }
  }

  private randomVolumeIncrement(): number {
    const basePerCandle =
      120_000 * Math.max(0.5, this.candleDurationMs / 60_000);
    const meanPerTick = basePerCandle / Math.max(1, this.ticksPerCandle);
    const variation = meanPerTick * 0.6;
    return Math.max(
      1,
      Math.round(meanPerTick + (Math.random() - 0.5) * variation),
    );
  }

  private roundPrice(price: number): number {
    return Math.round(price * 100) / 100;
  }

  private setState(next: ChartSimulatorState): void {
    this.state = next;
    this.emitState();
  }

  private updateState(patch: Partial<ChartSimulatorState>): void {
    this.setState({ ...this.state, ...patch });
  }

  private emitState(): void {
    const snapshot = this.getState();
    this.listeners.forEach(listener => {
      listener(snapshot);
    });
  }
}
