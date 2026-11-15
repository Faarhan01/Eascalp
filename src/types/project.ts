export interface ProjectFileEntry {
  path: string;
  name: string;
  category: string;
  ext: string;
  sizeBytes: number;
  lines: number;
}

export interface ParsedInputParam {
  group: string;
  type: string;
  name: string;
  defaultValue: string;
  comment: string;
}

export interface ProjectSummary {
  eaName: string;
  version: string;
  defaultMode: string;
  liveTradingDefault: boolean;
  fileCount: number;
  mqlCount: number;
  presetCount: number;
  totalLines: number;
  inputCount: number;
  inputs: ParsedInputParam[];
}

export interface TradeHistoryRow {
  timestamp: string;
  ticket: string;
  symbol: string;
  timeframe: string;
  strategy: string;
  direction: string;
  volume: number;
  entryPrice: number;
  sl: number;
  tp: number;
  slippagePts: number;
  score: number;
  regime: string;
  status: string;
  netPnL: number;
  holdSeconds: number;
  splitTag: string;
}

export interface RejectedSignalRow {
  timestamp: string;
  symbol: string;
  timeframe: string;
  strategy: string;
  direction: string;
  score: number;
  regime: string;
  rejectionCode: string;
  rejectionReason: string;
}

export interface StrategySignalRow {
  timestamp: string;
  signalId: string;
  symbol: string;
  timeframe: string;
  strategy: string;
  direction: string;
  score: number;
  band: string;
  regime: string;
  entryPrice: number;
  rationale: string;
  splitTag: string;
}

export interface RiskEventRow {
  timestamp: string;
  symbol: string;
  eventType: string;
  statusLabel: string;
  dailyPnL: number;
  weeklyPnL: number;
  balanceDdPct: number;
  equityDdPct: number;
  openRiskPct: number;
  consecutiveLosses: number;
  details: string;
}

export interface UploadedCsvDataset {
  loadedFiles: string[];
  trades: TradeHistoryRow[];
  signals: StrategySignalRow[];
  rejectedSignals: RejectedSignalRow[];
  riskEvents: RiskEventRow[];
}
