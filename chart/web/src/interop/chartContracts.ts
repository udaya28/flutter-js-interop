export type ChartMessageType = 'CHART_READY';

export interface ChartMessage<TPayload = unknown> {
  type: ChartMessageType;
  payload: TPayload;
}

export type ChartTheme = 'light' | 'dark';

export interface CandleDTO {
  time: number; // unix ms
  open: number;
  high: number;
  low: number;
  close: number;
  volume?: number;
}

export interface ChartInitPayload {
  theme: ChartTheme;
  series: CandleDTO[];
  viewport?: ChartViewportPayload;
}

export interface ChartSeriesPayload {
  series: CandleDTO[];
}

export interface ChartPatchPayload {
  upserts: CandleDTO[];
  removals?: number[];
}

export interface ChartThemePayload {
  theme: ChartTheme;
}

export interface ChartViewportPayload {
  startTime: number;
  endTime: number;
}

export interface ChartHoverPayload {
  time: number;
  price: number;
  candle?: CandleDTO;
}
