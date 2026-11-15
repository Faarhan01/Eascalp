import type {
  RejectedSignalRow,
  RiskEventRow,
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

export async function parseMt5CsvFiles(fileList: FileList | File[]): Promise<UploadedCsvDataset> {
  const files = Array.from(fileList);
  const dataset: UploadedCsvDataset = {
    loadedFiles: [],
    trades: [],
    signals: [],
    rejectedSignals: [],
    riskEvents: [],
  };

  for (const file of files) {
    const lower = file.name.toLowerCase();
    const content = await file.text();
    const rows = splitCsvLines(content);
    if (rows.length < 2) continue;

    const header = rows[0].map((h) => h.toLowerCase());
    const dataRows = rows.slice(1);
    dataset.loadedFiles.push(file.name);

    if (lower.includes('trade_history') || (header.includes('ticket') && header.includes('net_pnl'))) {
      for (const r of dataRows) {
        dataset.trades.push({
          timestamp: r[0] ?? '',
          ticket: r[1] ?? '',
          symbol: r[2] ?? '',
          timeframe: r[3] ?? '',
          strategy: r[4] ?? '',
          direction: r[5] ?? '',
          volume: toNum(r[6]),
          entryPrice: toNum(r[7]),
          sl: toNum(r[8]),
          tp: toNum(r[9]),
          slippagePts: toNum(r[10]),
          score: toNum(r[11]),
          regime: r[12] ?? '',
          status: r[13] ?? '',
          netPnL: toNum(r[14]),
          holdSeconds: toNum(r[15]),
          splitTag: r[16] ?? 'IN_SAMPLE',
        });
      }
    } else if (lower.includes('rejected_signals') || header.includes('rejection_code')) {
      for (const r of dataRows) {
        dataset.rejectedSignals.push({
          timestamp: r[0] ?? '',
          symbol: r[1] ?? '',
          timeframe: r[2] ?? '',
          strategy: r[3] ?? '',
          direction: r[4] ?? '',
          score: toNum(r[5]),
          regime: r[6] ?? '',
          rejectionCode: r[7] ?? '',
          rejectionReason: r[8] ?? '',
        });
      }
    } else if (lower.includes('strategy_signals') || header.includes('signal_id')) {
      for (const r of dataRows) {
        dataset.signals.push({
          timestamp: r[0] ?? '',
          signalId: r[1] ?? '',
          symbol: r[2] ?? '',
          timeframe: r[3] ?? '',
          strategy: r[4] ?? '',
          direction: r[5] ?? '',
          score: toNum(r[6]),
          band: r[7] ?? '',
          regime: r[8] ?? '',
          entryPrice: toNum(r[9]),
          rationale: r[12] ?? '',
          splitTag: r[15] ?? 'IN_SAMPLE',
        });
      }
    } else if (lower.includes('risk_events') || header.includes('event_type')) {
      for (const r of dataRows) {
        dataset.riskEvents.push({
          timestamp: r[0] ?? '',
          symbol: r[1] ?? '',
          eventType: r[2] ?? '',
          statusLabel: r[3] ?? '',
          dailyPnL: toNum(r[4]),
          weeklyPnL: toNum(r[5]),
          balanceDdPct: toNum(r[6]),
          equityDdPct: toNum(r[7]),
          openRiskPct: toNum(r[8]),
          consecutiveLosses: toNum(r[9]),
          details: r[10] ?? '',
        });
      }
    }
  }

  return dataset;
}

export interface ComputedCsvMetrics {
  closedTrades: number;
  winningTrades: number;
  losingTrades: number;
  winRatePct: number;
  netProfit: number;
  grossProfit: number;
  grossLoss: number;
  profitFactor: number;
  expectedValue: number;
  maxDrawdownMoney: number;
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
}

export function computeCsvMetrics(dataset: UploadedCsvDataset): ComputedCsvMetrics {
  const closed = dataset.trades.filter((t) => t.status.toUpperCase() === 'CLOSED');
  let wins = 0;
  let losses = 0;
  let grossProfit = 0;
  let grossLoss = 0;
  let cumPnL = 0;
  let peak = 0;
  let maxDD = 0;
  const equitySeries: number[] = [0];
  const drawdownSeries: number[] = [0];

  const stratMap = new Map<string, { trades: number; wins: number; gp: number; gl: number; net: number }>();

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

  return {
    closedTrades: closedCount,
    winningTrades: wins,
    losingTrades: losses,
    winRatePct: closedCount > 0 ? (wins / closedCount) * 100 : 0,
    netProfit,
    grossProfit,
    grossLoss,
    profitFactor: grossLoss > 0 ? grossProfit / grossLoss : grossProfit > 0 ? 9.99 : 0,
    expectedValue: closedCount > 0 ? netProfit / closedCount : 0,
    maxDrawdownMoney: maxDD,
    equitySeries,
    drawdownSeries,
    strategyBreakdown,
    rejectionBreakdown,
  };
}
