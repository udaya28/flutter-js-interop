export type ChartMessageType =
  | 'INIT_CHART'
  | 'SET_SERIES'
  | 'PATCH_SERIES'
  | 'SET_THEME'
  | 'SET_VIEWPORT'
  | 'CHART_READY'
  | 'RANGE_SELECTED'
  | 'CANDLE_HOVERED'
  | 'DATA_REQUEST';

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

export interface ChartDataRequestPayload {
  fromTime: number;
  toTime: number;
  reason: 'ZOOM_OUT' | 'SCROLL_BACK' | 'LOAD_INITIAL';
}

export interface ChartFlutterUI {
  update: ((message: ChartMessage) => void) | null;
}
