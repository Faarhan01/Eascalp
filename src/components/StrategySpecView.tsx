import { useMemo, useState } from 'react';
import { Search } from 'lucide-react';
import type { ParsedInputParam } from '../types/project';

interface StrategySpecViewProps {
  inputs: ParsedInputParam[];
}

const STRATEGIES = [
  {
    id: 1,
    name: 'Trend Pullback',
    module: 'TrendPullback.mqh',
    regimes: 'Strong/Weak Bull or Bear Trend',
    logic: 'Aligned EMA(9/21/55) stack, ADX >= 18, pullback into EMA21/structure zone, Stochastic turn + RSI confirmation.',
    filters: 'Blocks counter-trend entries opposing Higher Timeframe bias.',
  },
  {
    id: 2,
    name: 'Momentum Scalping',
    module: 'MomentumScalping.mqh',
    regimes: 'Trends & Volatility Expansion',
    logic: 'MACD histogram alignment, ROC threshold, directional DI dominance, RSI momentum zone, and positive tick micro-bias.',
    filters: 'Rejects entries when strong MTF conflicts are active.',
  },
  {
    id: 3,
    name: 'Breakout Scalping',
    module: 'BreakoutScalping.mqh',
    regimes: 'All non-unstable, non-low-vol regimes',
    logic: 'Confirmed closed-bar BOS, range breakout, or chart pattern neckline break with candle body >= 0.45x ATR.',
    filters: 'Requires ATR ratio >= 1.05 or tick activity >= 1.15x to filter fakeouts.',
  },
  {
    id: 4,
    name: 'Reversal Scalping',
    module: 'ReversalScalping.mqh',
    regimes: 'Non-unstable regimes (blocks fading strong trends)',
    logic: 'CHoCH / liquidity sweep / S&R rejection + context-validated reversal candle + RSI/CCI/BB extreme.',
    filters: 'Explicitly blocked against Strong Bull/Bear runaway trends.',
  },
  {
    id: 5,
    name: 'Range Scalping',
    module: 'RangeScalping.mqh',
    regimes: 'Sideways, Consolidation, Low Volatility, Contraction',
    logic: 'Mean reversion at confirmed range/Bollinger boundaries with oversold/overbought Stochastic & RSI.',
    filters: 'Strictly disabled whenever ADX > 22 or trending regimes are active.',
  },
  {
    id: 6,
    name: 'Volatility Expansion',
    module: 'VolatilityExpansion.mqh',
    regimes: 'Volatility Expansion, High Vol, Strong Trends',
    logic: 'ATR ratio >= 1.25 expansion breaking outer Bollinger Band with impulse body >= 0.55x ATR and tick surge.',
    filters: 'Requires MACD histogram and tick micro-trend alignment.',
  },
  {
    id: 7,
    name: 'Micro-Momentum',
    module: 'MicroMomentum.mqh',
    regimes: 'Active non-unstable, non-low-vol markets',
    logic: 'Consecutive tick directional runs + tick velocity (pts/sec) + positive acceleration + EMA fast alignment.',
    filters: 'Enforces spread-to-ATR cost ceiling (<= 18%) and spread-spike lockout.',
  },
];

const SCORING_COMPONENTS = [
  { name: 'Market Direction (EMA Stack)', weight: '10 pts' },
  { name: 'Market Structure & BOS/CHoCH', weight: '12 pts' },
  { name: 'Trend Strength (ADX / Range Fit)', weight: '10 pts' },
  { name: 'Momentum (MACD / RSI / ROC)', weight: '10 pts' },
  { name: 'Volatility Regime Suitability', weight: '8 pts' },
  { name: 'Candlestick Context Confirmation', weight: '8 pts' },
  { name: 'Chart Pattern Alignment', weight: '8 pts' },
  { name: 'Multi-Timeframe Agreement', weight: '12 pts' },
  { name: 'Tick Velocity & Micro-Bias', weight: '8 pts' },
  { name: 'Spread Cost Ratio', weight: '6 pts' },
  { name: 'Strategy Historical PF (Sample-Gated)', weight: '4 pts' },
  { name: 'Regime Suitability Match', weight: '4 pts' },
];

export default function StrategySpecView({ inputs }: StrategySpecViewProps) {
  const [query, setQuery] = useState('');
  const [groupFilter, setGroupFilter] = useState('ALL');

  const groups = useMemo(() => {
    const set = new Set<string>();
    for (const p of inputs) set.add(p.group);
    return ['ALL', ...Array.from(set)];
  }, [inputs]);

  const filteredInputs = useMemo(() => {
    const q = query.trim().toLowerCase();
    return inputs.filter((p) => {
      if (groupFilter !== 'ALL' && p.group !== groupFilter) return false;
      if (!q) return true;
      return (
        p.name.toLowerCase().includes(q) ||
        p.comment.toLowerCase().includes(q) ||
        p.group.toLowerCase().includes(q)
      );
    });
  }, [inputs, query, groupFilter]);

  return (
    <div className="space-y-8">
      <div className="border-b border-slate-800 pb-4">
        <h1 className="font-display text-xl font-semibold text-slate-100">
          Scalping Strategies, Signal Scoring &amp; Configuration Inputs
        </h1>
        <p className="mt-1 text-xs text-slate-400">
          Every strategy evaluates opportunities independently, logs acceptance or rejection reasons, and submits candidate signals to the 100-point quantitative scoring and 11-point trade validation gates.
        </p>
      </div>

      {/* 7 Strategies Table */}
      <div className="rounded-lg border border-slate-800 bg-slate-900/60 overflow-hidden">
        <div className="border-b border-slate-800 px-5 py-3.5">
          <h2 className="font-display text-sm font-semibold text-slate-100">
            Seven Independent Scalping Strategy Engines
          </h2>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="border-b border-slate-800 bg-slate-950/60 text-slate-400">
              <tr>
                <th className="px-4 py-3 font-medium">#</th>
                <th className="px-4 py-3 font-medium">Strategy</th>
                <th className="px-4 py-3 font-medium">Permitted Regimes</th>
                <th className="px-4 py-3 font-medium">Entry &amp; Confirmation Logic</th>
                <th className="px-4 py-3 font-medium">Safety / Context Filter</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/70">
              {STRATEGIES.map((s) => (
                <tr key={s.id} className="hover:bg-slate-800/30">
                  <td className="px-4 py-3 font-mono text-slate-500 tabular-nums align-top">{s.id}</td>
                  <td className="px-4 py-3 align-top">
                    <p className="font-medium text-slate-200 whitespace-nowrap">{s.name}</p>
                    <p className="font-mono text-[11px] text-sky-400">{s.module}</p>
                  </td>
                  <td className="px-4 py-3 text-slate-300 align-top">{s.regimes}</td>
                  <td className="px-4 py-3 text-slate-400 leading-relaxed align-top">{s.logic}</td>
                  <td className="px-4 py-3 text-slate-400 leading-relaxed align-top">{s.filters}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* 100-Point Scoring Breakdown */}
      <div className="rounded-lg border border-slate-800 bg-slate-900/60 p-5">
        <div className="flex flex-col gap-1 sm:flex-row sm:items-center sm:justify-between">
          <h2 className="font-display text-sm font-semibold text-slate-100">
            12-Component Signal Scoring Matrix (0–100 Scale)
          </h2>
          <span className="font-mono text-xs text-slate-400">
            Default Execution Threshold: 62.0 / 100
          </span>
        </div>
        <p className="mt-1 text-xs text-slate-400">
          Scores classify conditions into Strong/Moderate/Weak Bullish, Neutral, or Weak/Moderate/Strong Bearish bands and never claim guaranteed win probabilities.
        </p>
        <div className="mt-4 grid gap-2.5 sm:grid-cols-2 lg:grid-cols-3">
          {SCORING_COMPONENTS.map((comp) => (
            <div
              key={comp.name}
              className="flex items-center justify-between rounded-md border border-slate-800/80 bg-slate-950/50 px-3.5 py-2.5 text-xs"
            >
              <span className="text-slate-300">{comp.name}</span>
              <span className="font-mono font-medium text-sky-400 tabular-nums">{comp.weight}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Parsed EA Input Parameters */}
      <div className="rounded-lg border border-slate-800 bg-slate-900/60 overflow-hidden">
        <div className="flex flex-col gap-3 border-b border-slate-800 px-5 py-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h2 className="font-display text-sm font-semibold text-slate-100">
              Validated EA Configuration Inputs ({filteredInputs.length} / {inputs.length})
            </h2>
            <p className="mt-0.5 text-xs text-slate-400">
              Parsed directly from <span className="font-mono text-slate-300">Experts/AdvancedScalpingEA.mq5</span>. Configuration changes occur solely in MT5 EA Inputs, never via the read-only dashboard.
            </p>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <select
              value={groupFilter}
              onChange={(e) => setGroupFilter(e.target.value)}
              className="rounded-lg border border-slate-800 bg-slate-950 px-3 py-1.5 text-xs text-slate-200 focus:border-sky-500 focus:outline-none"
            >
              {groups.map((g) => (
                <option key={g} value={g}>
                  {g === 'ALL' ? 'All 18 Input Groups' : g}
                </option>
              ))}
            </select>
            <div className="relative w-56">
              <Search className="pointer-events-none absolute left-2.5 top-1/2 h-3.5 w-3.5 -translate-y-1/2 text-slate-500" />
              <input
                type="text"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder="Search input name..."
                className="w-full rounded-lg border border-slate-800 bg-slate-950 py-1.5 pl-8 pr-3 text-xs text-slate-200 placeholder-slate-500 focus:border-sky-500 focus:outline-none"
              />
            </div>
          </div>
        </div>

        <div className="max-h-[480px] overflow-auto">
          <table className="w-full text-left text-xs">
            <thead className="sticky top-0 border-b border-slate-800 bg-slate-950 text-slate-400">
              <tr>
                <th className="px-4 py-2.5 font-medium">Category</th>
                <th className="px-4 py-2.5 font-medium">Input Variable</th>
                <th className="px-4 py-2.5 font-medium">Type</th>
                <th className="px-4 py-2.5 font-medium">Default</th>
                <th className="px-4 py-2.5 font-medium">Description</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/60">
              {filteredInputs.map((param) => (
                <tr key={param.name} className="hover:bg-slate-800/30">
                  <td className="px-4 py-2 text-slate-400 whitespace-nowrap">{param.group}</td>
                  <td className="px-4 py-2 font-mono text-sky-300 whitespace-nowrap">{param.name}</td>
                  <td className="px-4 py-2 font-mono text-slate-400 whitespace-nowrap">{param.type}</td>
                  <td className="px-4 py-2 font-mono text-emerald-400 whitespace-nowrap">{param.defaultValue}</td>
                  <td className="px-4 py-2 text-slate-300">{param.comment}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
