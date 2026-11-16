import type {
  RejectedSignalRow,
  RiskEventRow,
  SessionSummaryRow,
  StrategyPerformanceRow,
  StrategySignalRow,
  TradeHistoryRow,
  UploadedCsvDataset,
} from '../types/project';

function splitCsvLines(text: string): string[][] {
  return text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0)
    .map((line) => line.split(',').map((cell) => cell.trim()));
}

function toNum(v: string | undefined): number {
  if (!v) return 0;
  const n = Number(v);
  return Number.isFinite(n) ? n : 0;
}

function buildHeaderMap(header: string[]): Map<string, number> {
  const map = new Map<string, number>();
  header.forEach((col, idx) => {
    map.set(col.toLowerCase().trim(), idx);
  });
  return map;
}

function getStr(row: string[], colMap: Map<string, number>, name: string, fallback = ''): string {
  const idx = colMap.get(name);
  if (idx === undefined || idx < 0 || idx >= row.length) return fallback;
  return row[idx] ?? fallback;
}

function getNum(row: string[], colMap: Map<string, number>, name: string, fallback = 0): number {
  const idx = colMap.get(name);
  if (idx === undefined || idx < 0 || idx >= row.length) return fallback;
  return toNum(row[idx]);
}

export async function parseMt5CsvFiles(fileList: FileList | File[]): Promise<UploadedCsvDataset> {
  const files = Array.from(fileList);
  const dataset: UploadedCsvDataset = {
    loadedFiles: [],
    trades: [],
    signals: [],
    rejectedSignals: [],
    riskEvents: [],
    strategySnapshots: [],
    sessionSummaries: [],
    genericTables: [],
  };

  for (const file of files) {
    const lower = file.name.toLowerCase();
    const content = await file.text();
    const rows = splitCsvLines(content);
    if (rows.length < 2) continue;

    const rawHeader = rows[0];
    const header = rawHeader.map((h) => h.toLowerCase());
    const colMap = buildHeaderMap(header);
    const dataRows = rows.slice(1);
    dataset.loadedFiles.push(file.name);
    dataset.genericTables.push({
      filename: file.name,
      columns: rawHeader,
      rows: dataRows,
    });

    if (lower.includes('trade_history') || (header.includes('ticket') && header.includes('net_pnl'))) {
      for (const r of dataRows) {
        dataset.trades.push({
          timestamp: getStr(r, colMap, 'timestamp', r[0] ?? ''),
          ticket: getStr(r, colMap, 'ticket', r[1] ?? ''),
          signalId: getStr(r, colMap, 'signal_id', ''),
          symbol: getStr(r, colMap, 'symbol', ''),
          timeframe: getStr(r, colMap, 'timeframe', ''),
          strategy: getStr(r, colMap, 'strategy', ''),
          direction: getStr(r, colMap, 'direction', ''),
          volume: getNum(r, colMap, 'volume'),
          entryPrice: getNum(r, colMap, 'entry_price'),
          sl: getNum(r, colMap, 'sl'),
          tp: getNum(r, colMap, 'tp'),
          slippagePts: getNum(r, colMap, 'slippage_pts'),
          executionCost: getNum(r, colMap, 'execution_cost'),
          score: getNum(r, colMap, 'score'),
          regime: getStr(r, colMap, 'regime', ''),
          status: getStr(r, colMap, 'status', ''),
          exitReason: getStr(r, colMap, 'exit_reason', ''),
          netPnL: getNum(r, colMap, 'net_pnl'),
          mfeMoney: getNum(r, colMap, 'mfe_money'),
          maeMoney: getNum(r, colMap, 'mae_money'),
          holdSeconds: getNum(r, colMap, 'hold_seconds'),
          splitTag: getStr(r, colMap, 'split_tag', 'IN_SAMPLE'),
        });
      }
    } else if (lower.includes('rejected_signals') || header.includes('rejection_code')) {
      for (const r of dataRows) {
        dataset.rejectedSignals.push({
          timestamp: getStr(r, colMap, 'timestamp', r[0] ?? ''),
          symbol: getStr(r, colMap, 'symbol', ''),
          timeframe: getStr(r, colMap, 'timeframe', ''),
          strategy: getStr(r, colMap, 'strategy', ''),
          direction: getStr(r, colMap, 'direction', ''),
          score: getNum(r, colMap, 'score'),
          regime: getStr(r, colMap, 'regime', ''),
          rejectionCode: getStr(r, colMap, 'rejection_code', ''),
          rejectionReason: getStr(r, colMap, 'rejection_reason', ''),
        });
      }
    } else if (lower.includes('strategy_signals') || header.includes('signal_id')) {
      for (const r of dataRows) {
        dataset.signals.push({
          timestamp: getStr(r, colMap, 'timestamp', r[0] ?? ''),
          signalId: getStr(r, colMap, 'signal_id', ''),
          symbol: getStr(r, colMap, 'symbol', ''),
          timeframe: getStr(r, colMap, 'timeframe', ''),
          strategy: getStr(r, colMap, 'strategy', ''),
          direction: getStr(r, colMap, 'direction', ''),
          score: getNum(r, colMap, 'score'),
          validatedScore: getStr(r, colMap, 'validated_score', '0') === '1',
          band: getStr(r, colMap, 'band', ''),
          regime: getStr(r, colMap, 'regime', ''),
          entryPrice: getNum(r, colMap, 'entry_price'),
          sl: getNum(r, colMap, 'sl'),
          tp: getNum(r, colMap, 'tp'),
          estCost: getNum(r, colMap, 'est_cost'),
          netExpectancy: getNum(r, colMap, 'net_expectancy'),
          rrRatio: getNum(r, colMap, 'rr_ratio'),
          rationale: getStr(r, colMap, 'rationale', ''),
          splitTag: getStr(r, colMap, 'split_tag', 'IN_SAMPLE'),
        });
      }
    } else if (lower.includes('risk_events') || header.includes('event_type')) {
      for (const r of dataRows) {
        dataset.riskEvents.push({
          timestamp: getStr(r, colMap, 'timestamp', r[0] ?? ''),
          symbol: getStr(r, colMap, 'symbol', ''),
          eventType: getStr(r, colMap, 'event_type', ''),
          statusLabel: getStr(r, colMap, 'status_label', ''),
          dailyPnL: getNum(r, colMap, 'daily_pnl'),
          weeklyPnL: getNum(r, colMap, 'weekly_pnl'),
          balanceDdPct: getNum(r, colMap, 'balance_dd_pct'),
          equityDdPct: getNum(r, colMap, 'equity_dd_pct'),
          openRiskPct: getNum(r, colMap, 'open_risk_pct'),
          topCurrency: getStr(r, colMap, 'top_currency', ''),
          maxCcyLots: getNum(r, colMap, 'max_ccy_lots'),
          consecutiveLosses: getNum(r, colMap, 'consecutive_losses'),
          details: getStr(r, colMap, 'details', ''),
        });
      }
    } else if (lower.includes('strategy_performance') || header.includes('suitability')) {
      for (const r of dataRows) {
        dataset.strategySnapshots.push({
          timestamp: getStr(r, colMap, 'timestamp', r[0] ?? ''),
          symbol: getStr(r, colMap, 'symbol', ''),
          strategy: getStr(r, colMap, 'strategy', ''),
          enabled: getStr(r, colMap, 'enabled', '0') === '1',
          suitability: getStr(r, colMap, 'suitability', ''),
          totalTrades: getNum(r, colMap, 'total_trades'),
          wins: getNum(r, colMap, 'wins'),
          losses: getNum(r, colMap, 'losses'),
          winRatePct: getNum(r, colMap, 'win_rate_pct'),
          netProfit: getNum(r, colMap, 'net_profit'),
          profitFactor: getNum(r, colMap, 'profit_factor'),
          expectedValue: getNum(r, colMap, 'expected_value'),
          maxDdMoney: getNum(r, colMap, 'max_dd_money'),
          avgHoldSec: getNum(r, colMap, 'avg_hold_sec'),
          sufficientSample: getStr(r, colMap, 'sufficient_sample', '0') === '1',
          deteriorationWarn: getStr(r, colMap, 'deterioration_warn', '0') === '1',
        });
      }
    } else if (lower.includes('session_summary') || header.includes('sharpe')) {
      for (const r of dataRows) {
        dataset.sessionSummaries.push({
          timestamp: getStr(r, colMap, 'timestamp', r[0] ?? ''),
          symbol: getStr(r, colMap, 'symbol', ''),
          balance: getNum(r, colMap, 'balance'),
          equity: getNum(r, colMap, 'equity'),
          floatingPnL: getNum(r, colMap, 'floating_pnl'),
          realizedNetPnL: getNum(r, colMap, 'realized_net_pnl'),
          commissions: getNum(r, colMap, 'commissions'),
          swaps: getNum(r, colMap, 'swaps'),
          totalTrades: getNum(r, colMap, 'total_trades'),
          winRatePct: getNum(r, colMap, 'win_rate_pct'),
          profitFactor: getNum(r, colMap, 'profit_factor'),
          maxDdPct: getNum(r, colMap, 'max_dd_pct'),
          avgMfe: getNum(r, colMap, 'avg_mfe'),
          avgMae: getNum(r, colMap, 'avg_mae'),
          sharpe: getNum(r, colMap, 'sharpe'),
          sortino: getNum(r, colMap, 'sortino'),
          observations: getNum(r, colMap, 'observations'),
          signalsGen: getNum(r, colMap, 'signals_gen'),
          signalsAcc: getNum(r, colMap, 'signals_acc'),
          signalsRej: getNum(r, colMap, 'signals_rej'),
        });
      }
    }
  }

  return dataset;
}

export interface ComputedCsvMetrics {
  closedTrades: number;
  partialCloses: number;
  winningTrades: number;
  losingTrades: number;
  winRatePct: number;
  netProfit: number;
  grossProfit: number;
  grossLoss: number;
  profitFactor: number;
  expectedValue: number;
  maxDrawdownMoney: number;
  totalExecutionCost: number;
  avgMfeMoney: number;
  avgMaeMoney: number;
  equitySeries: number[];
  drawdownSeries: number[];
  strategyBreakdown: Array<{
    strategy: string;
    trades: number;
    wins: number;
    winRatePct: number;
    netProfit: number;
    profitFactor: number;
  }>;
  rejectionBreakdown: Array<{
    code: string;
    count: number;
  }>;
  latestSession: SessionSummaryRow | null;
}

export function computeCsvMetrics(dataset: UploadedCsvDataset): ComputedCsvMetrics {
  const closed = dataset.trades.filter((t) => {
    const st = t.status.toUpperCase();
    return st === 'CLOSED' || st === 'PARTIAL_CLOSE';
  });
  const fullClosed = dataset.trades.filter((t) => t.status.toUpperCase() === 'CLOSED');
  const partialCloses = dataset.trades.filter((t) => t.status.toUpperCase() === 'PARTIAL_CLOSE').length;

  let wins = 0;
  let losses = 0;
  let grossProfit = 0;
  let grossLoss = 0;
  let cumPnL = 0;
  let peak = 0;
  let maxDD = 0;
  let totalExecutionCost = 0;
  let sumMfe = 0;
  let sumMae = 0;
  let mfeCount = 0;
  const equitySeries: number[] = [0];
  const drawdownSeries: number[] = [0];

  const stratMap = new Map<string, { trades: number; wins: number; gp: number; gl: number; net: number }>();

  for (const t of dataset.trades) {
    totalExecutionCost += t.executionCost;
  }

  for (const t of closed) {
    if (t.netPnL >= 0) {
      wins++;
      grossProfit += t.netPnL;
    } else {
      losses++;
      grossLoss += Math.abs(t.netPnL);
    }
    cumPnL += t.netPnL;
    if (cumPnL > peak) peak = cumPnL;
    const dd = peak - cumPnL;
    if (dd > maxDD) maxDD = dd;
    equitySeries.push(cumPnL);
    drawdownSeries.push(dd);

    if (t.mfeMoney > 0 || t.maeMoney > 0) {
      sumMfe += t.mfeMoney;
      sumMae += t.maeMoney;
      mfeCount++;
    }

    const prev = stratMap.get(t.strategy) ?? { trades: 0, wins: 0, gp: 0, gl: 0, net: 0 };
    prev.trades++;
    if (t.netPnL >= 0) {
      prev.wins++;
      prev.gp += t.netPnL;
    } else {
      prev.gl += Math.abs(t.netPnL);
    }
    prev.net += t.netPnL;
    stratMap.set(t.strategy, prev);
  }

  const rejMap = new Map<string, number>();
  for (const r of dataset.rejectedSignals) {
    rejMap.set(r.rejectionCode, (rejMap.get(r.rejectionCode) ?? 0) + 1);
  }

  const strategyBreakdown = Array.from(stratMap.entries())
    .map(([strategy, s]) => ({
      strategy,
      trades: s.trades,
      wins: s.wins,
      winRatePct: s.trades > 0 ? (s.wins / s.trades) * 100 : 0,
      netProfit: s.net,
      profitFactor: s.gl > 0 ? s.gp / s.gl : s.gp > 0 ? 9.99 : 0,
    }))
    .sort((a, b) => b.netProfit - a.netProfit);

  const rejectionBreakdown = Array.from(rejMap.entries())
    .map(([code, count]) => ({ code, count }))
    .sort((a, b) => b.count - a.count);

  const closedCount = closed.length;
  const netProfit = grossProfit - grossLoss;
  const latestSession =
    dataset.sessionSummaries.length > 0
      ? dataset.sessionSummaries[dataset.sessionSummaries.length - 1]
      : null;

  return {
    closedTrades: fullClosed.length > 0 ? fullClosed.length : closedCount,
    partialCloses,
    winningTrades: wins,
    losingTrades: losses,
    winRatePct: closedCount > 0 ? (wins / closedCount) * 100 : 0,
    netProfit,
    grossProfit,
    grossLoss,
    profitFactor: grossLoss > 0 ? grossProfit / grossLoss : grossProfit > 0 ? 9.99 : 0,
    expectedValue: closedCount > 0 ? netProfit / closedCount : 0,
    maxDrawdownMoney: maxDD,
    totalExecutionCost,
    avgMfeMoney: mfeCount > 0 ? sumMfe / mfeCount : 0,
    avgMaeMoney: mfeCount > 0 ? sumMae / mfeCount : 0,
    equitySeries,
    drawdownSeries,
    strategyBreakdown,
    rejectionBreakdown,
    latestSession,
  };
}
