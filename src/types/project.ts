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

export interface ParsedScoringComponent {
  field: string;
  label: string;
  maxPoints: number;
}

export interface ParsedStrategySpec {
  id: number;
  enumKey: string;
  name: string;
  module: string;
  suitableRegimes: string[];
  conditionalRegimes: string[];
  defaults: Array<{ key: string; value: string }>;
  hasCustomExit: boolean;
}

export interface ParsedCsvSchema {
  index: number;
  filename: string;
  columns: string[];
}

export interface ParsedPresetSpec {
  path: string;
  assetGroup: string;
  name: string;
  configLabel: string;
  operatingMode: string;
  allowLiveTrading: boolean;
  riskPct: string;
  minScore: string;
  maxSpread: string;
  multiSymbolList: string;
}

export interface SubsystemSummary {
  category: string;
  fileCount: number;
  totalLines: number;
  files: string[];
}

export interface ProjectSummary {
  eaName: string;
  version: string;
  defaultMode: string;
  allowLiveTrading: boolean;
  confirmLiveRiskAck: boolean;
  liveTradingDefault: boolean;
  defaultMinScore: number;
  maxRegimes: number;
  maxSymbols: number;
  fileCount: number;
  mqlCount: number;
  mq5Count: number;
  mqhCount: number;
  presetCount: number;
  totalLines: number;
  inputCount: number;
  inputGroups: string[];
  inputs: ParsedInputParam[];
  strategies: ParsedStrategySpec[];
  scoringComponents: ParsedScoringComponent[];
  csvSchemas: ParsedCsvSchema[];
  presets: ParsedPresetSpec[];
  subsystems: SubsystemSummary[];
}

export interface TradeHistoryRow {
  timestamp: string;
  ticket: string;
  signalId: string;
  symbol: string;
  timeframe: string;
  strategy: string;
  direction: string;
  volume: number;
  entryPrice: number;
  sl: number;
  tp: number;
  slippagePts: number;
  executionCost: number;
  score: number;
  regime: string;
  status: string;
  exitReason: string;
  netPnL: number;
  mfeMoney: number;
  maeMoney: number;
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
  validatedScore: boolean;
  band: string;
  regime: string;
  entryPrice: number;
  sl: number;
  tp: number;
  estCost: number;
  netExpectancy: number;
  rrRatio: number;
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
  topCurrency: string;
  maxCcyLots: number;
  consecutiveLosses: number;
  details: string;
}

export interface StrategyPerformanceRow {
  timestamp: string;
  symbol: string;
  strategy: string;
  enabled: boolean;
  suitability: string;
  totalTrades: number;
  wins: number;
  losses: number;
  winRatePct: number;
  netProfit: number;
  profitFactor: number;
  expectedValue: number;
  maxDdMoney: number;
  avgHoldSec: number;
  sufficientSample: boolean;
  deteriorationWarn: boolean;
}

export interface SessionSummaryRow {
  timestamp: string;
  symbol: string;
  balance: number;
  equity: number;
  floatingPnL: number;
  realizedNetPnL: number;
  commissions: number;
  swaps: number;
  totalTrades: number;
  winRatePct: number;
  profitFactor: number;
  maxDdPct: number;
  avgMfe: number;
  avgMae: number;
  sharpe: number;
  sortino: number;
  observations: number;
  signalsGen: number;
  signalsAcc: number;
  signalsRej: number;
}

export interface GenericCsvTable {
  filename: string;
  columns: string[];
  rows: string[][];
}

export interface UploadedCsvDataset {
  loadedFiles: string[];
  trades: TradeHistoryRow[];
  signals: StrategySignalRow[];
  rejectedSignals: RejectedSignalRow[];
  riskEvents: RiskEventRow[];
  strategySnapshots: StrategyPerformanceRow[];
  sessionSummaries: SessionSummaryRow[];
  genericTables: GenericCsvTable[];
}
