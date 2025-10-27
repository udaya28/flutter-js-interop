export enum Volatility {
  Low = 'low',
  Medium = 'medium',
  High = 'high',
}

export interface DemoDataSimulatorConfig {
  /** Candle duration in milliseconds (defaults to 1 minute). */
  candleDurationMs?: number;
  /** Starting price for the series. */
  initialPrice?: number;
  /** Volatility regime to emulate. */
  volatility?: Volatility;
  /** Ticks per second used when scaling volatility (matches legacy simulator defaults). */
  ticksPerSecond?: number;
  /** Timestamp used as the reference point for backwards generation. */
  startTime?: Date;
  /** Timezone identifier (currently only 'Asia/Kolkata' receives a custom offset). */
  timezone?: string;
}

export interface DemoCandle {
  timestamp: Date;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
}

const ONE_MINUTE_MS = 60_000;
const IST_OFFSET_MS = 19_800_000; // +05:30

export class DemoDataSimulator {
  private readonly config: Required<DemoDataSimulatorConfig>;
  private readonly candleDurationMs: number;
  private readonly timezoneOffsetMs: number;
  private readonly durationSeconds: number;
  private currentPrice: number;
  private oldestTimestamp: Date | null = null;
  private oldestCandleOpen: number | null = null;

  private readonly MARKET_OPEN_HOUR = 6;
  private readonly MARKET_OPEN_MINUTE = 0;
  private readonly MARKET_CLOSE_HOUR = 23;
  private readonly MARKET_CLOSE_MINUTE = 45;

  constructor(config: DemoDataSimulatorConfig = {}) {
    const defaults: Required<DemoDataSimulatorConfig> = {
      candleDurationMs: ONE_MINUTE_MS,
      initialPrice: 100,
      volatility: Volatility.Medium,
      ticksPerSecond: 5,
      startTime: new Date(),
      timezone: 'Asia/Kolkata',
    };

    this.config = { ...defaults, ...config };
    this.candleDurationMs = this.config.candleDurationMs;
    this.timezoneOffsetMs =
      this.config.timezone === 'Asia/Kolkata' ? IST_OFFSET_MS : 0;
    this.durationSeconds = this.candleDurationMs / 1000;
    this.currentPrice = this.roundPrice(this.config.initialPrice);
  }

  async generateHistoricalCandles(count: number): Promise<DemoCandle[]> {
    // Simulate network latency (same as legacy POC)
    await new Promise(resolve => setTimeout(resolve, 50 + Math.random() * 50));

    const candles: DemoCandle[] = [];
    const isFirstBatch = this.oldestCandleOpen === null;
    let timestamp = this.oldestTimestamp
      ? this.oldestTimestamp
      : this.truncateToCandle(this.config.startTime);

    const timestamps: Date[] = [];
    for (let i = 0; i < count; i += 1) {
      timestamp = this.previousCandleTimestamp(timestamp);
      timestamps.push(timestamp);
    }

    if (isFirstBatch) {
      timestamps.reverse();
      for (const ts of timestamps) {
        candles.push(this.generateCandle(ts));
      }
    } else {
      if (this.oldestCandleOpen !== null) {
        this.currentPrice = this.oldestCandleOpen;
      }
      for (const ts of timestamps) {
        candles.push(this.generateCandleBackwards(ts));
      }
      candles.reverse();
    }

    if (candles.length > 0) {
      const first = candles[0] ?? null;
      const last = candles[candles.length - 1] ?? first;

      if (first) {
        this.oldestTimestamp = first.timestamp;
        this.oldestCandleOpen = first.open;
      }

      if (last) {
        this.currentPrice = last.close;
      }
    }

    return candles;
  }

  private generateCandle(timestamp: Date): DemoCandle {
    const { normalRange, bigJumpChance, bigJumpRange } =
      this.getVolatilityParams();

    const normalMove = (Math.random() - 0.5) * normalRange;
    const bigJump =
      Math.random() < bigJumpChance ? (Math.random() - 0.5) * bigJumpRange : 0;
    const totalMove = normalMove + bigJump;

    const open = this.roundPrice(this.currentPrice);
    const close = this.roundPrice(open * (1 + totalMove));

    const range = Math.abs(close - open);
    const extraRange = range * (0.1 + Math.random() * 0.4);
    const high = this.roundPrice(Math.max(open, close) + extraRange);
    const low = this.roundPrice(Math.min(open, close) - extraRange);

    const durationFactor = Math.max(1, this.durationSeconds / 3600);
    const baseMin = 10_000 * durationFactor;
    const baseMax = 1_000_000 * durationFactor;
    const volume = Math.floor(baseMin + Math.random() * (baseMax - baseMin));

    this.currentPrice = close;

    return { timestamp, open, high, low, close, volume };
  }

  private generateCandleBackwards(timestamp: Date): DemoCandle {
    const { normalRange, bigJumpChance, bigJumpRange } =
      this.getVolatilityParams();

    const normalMove = (Math.random() - 0.5) * normalRange;
    const bigJump =
      Math.random() < bigJumpChance ? (Math.random() - 0.5) * bigJumpRange : 0;
    const totalMove = normalMove + bigJump;

    const close = this.roundPrice(this.currentPrice);
    const open = this.roundPrice(close / (1 + totalMove));

    const range = Math.abs(close - open);
    const extraRange = range * (0.1 + Math.random() * 0.4);
    const high = this.roundPrice(Math.max(open, close) + extraRange);
    const low = this.roundPrice(Math.min(open, close) - extraRange);

    const durationFactor = Math.max(1, this.durationSeconds / 3600);
    const baseMin = 10_000 * durationFactor;
    const baseMax = 1_000_000 * durationFactor;
    const volume = Math.floor(baseMin + Math.random() * (baseMax - baseMin));

    this.currentPrice = open;

    return { timestamp, open, high, low, close, volume };
  }

  private roundPrice(price: number): number {
    return Math.round(price * 10) / 10;
  }

  private getVolatilityParams() {
    const tickScaleFactor = Math.sqrt(1 / this.config.ticksPerSecond);
    const jumpChanceScaleFactor = 1 / this.config.ticksPerSecond;

    switch (this.config.volatility) {
      case Volatility.Low:
        return {
          normalRange: 0.02,
          bigJumpChance: 0.03 * jumpChanceScaleFactor,
          bigJumpRange: 0.1,
          tickRange: 0.003 * tickScaleFactor,
        };
      case Volatility.High:
        return {
          normalRange: 0.08,
          bigJumpChance: 0.08 * jumpChanceScaleFactor,
          bigJumpRange: 0.3,
          tickRange: 0.012 * tickScaleFactor,
        };
      default:
        return {
          normalRange: 0.04,
          bigJumpChance: 0.05 * jumpChanceScaleFactor,
          bigJumpRange: 0.2,
          tickRange: 0.006 * tickScaleFactor,
        };
    }
  }

  private truncateToCandle(timestamp: Date): Date {
    const local = new Date(timestamp.getTime() + this.timezoneOffsetMs);

    if (this.candleDurationMs === 2_592_000_000) {
      const truncated = new Date(
        Date.UTC(local.getUTCFullYear(), local.getUTCMonth(), 1, 0, 0, 0, 0),
      );
      return new Date(truncated.getTime() - this.timezoneOffsetMs);
    }

    if (this.candleDurationMs === 604_800_000) {
      const day = local.getUTCDay();
      const daysToSubtract = day === 0 ? 6 : day - 1;
      const truncated = new Date(local.getTime() - daysToSubtract * 86_400_000);
      truncated.setUTCHours(0, 0, 0, 0);
      return new Date(truncated.getTime() - this.timezoneOffsetMs);
    }

    const localMs = timestamp.getTime() + this.timezoneOffsetMs;
    const truncatedMs =
      Math.floor(localMs / this.candleDurationMs) * this.candleDurationMs;
    return new Date(truncatedMs - this.timezoneOffsetMs);
  }

  private previousCandleTimestamp(timestamp: Date): Date {
    let previous = new Date(timestamp.getTime() - this.candleDurationMs);
    const isIntraday = this.candleDurationMs < 86_400_000;

    if (isIntraday) {
      while (!this.isMarketOpen(previous)) {
        previous = new Date(previous.getTime() - this.candleDurationMs);
      }
    }

    return previous;
  }

  private isMarketOpen(timestamp: Date): boolean {
    const local = new Date(timestamp.getTime() + this.timezoneOffsetMs);

    const hour = local.getUTCHours();
    const minute = local.getUTCMinutes();

    if (hour < this.MARKET_OPEN_HOUR) return false;
    if (hour === this.MARKET_OPEN_HOUR && minute < this.MARKET_OPEN_MINUTE) {
      return false;
    }

    if (hour > this.MARKET_CLOSE_HOUR) return false;
    if (hour === this.MARKET_CLOSE_HOUR && minute > this.MARKET_CLOSE_MINUTE) {
      return false;
    }

    return true;
  }
}

export async function generateDemoCandles(
  count: number,
  config: DemoDataSimulatorConfig = {},
): Promise<DemoCandle[]> {
  const simulator = new DemoDataSimulator(config);
  return simulator.generateHistoricalCandles(count);
}
