import type { ProjectSummary } from '../types/project';

interface OverviewViewProps {
  summary: ProjectSummary | null;
  onNavigate: (tab: 'explorer' | 'strategies' | 'terminal' | 'validation') => void;
}

const ARCHITECTURE_LAYERS = [
  {
    layer: 'Core Orchestration',
    modules: 'EAController.mqh, StateManager.mqh, Diagnostics.mqh, Types.mqh',
    responsibility:
      'Lifecycle management, INI state recovery on terminal restart, throttled structured logging, and read-only snapshot projection.',
  },
  {
    layer: 'Market & Symbol Intelligence',
    modules: 'SymbolIntelligence.mqh, MarketData.mqh, TickAnalysis.mqh, MarketStructure.mqh, MarketRegime.mqh, MultiTimeframe.mqh',
    responsibility:
      'Dynamic broker prefix/suffix & contract inspection across Forex, Metals, Indices, Energy, CFDs, and Synthetics; 14-timeframe OHLCV; tick velocity; 11 market regimes.',
  },
  {
    layer: 'Indicators & Pattern Engine',
    modules: 'IndicatorEngine.mqh, CandlestickRecognition.mqh, PatternRecognition.mqh',
    responsibility:
      'Non-repainting shift-1 indicator reads (EMA, SMA, RSI, MACD, ATR, ADX, BB, Stoch, CCI, WPR, SAR, Mom, ROC, VWAP), context-validated candles, and swing geometry patterns.',
  },
  {
    layer: '7 Independent Strategies',
    modules: 'TrendPullback, MomentumScalping, BreakoutScalping, ReversalScalping, RangeScalping, VolatilityExpansion, MicroMomentum',
    responsibility:
      'Self-contained entry logic, regime suitability gates, per-strategy trade attribution, and explicit rejection logging.',
  },
  {
    layer: 'Scoring, Validation & Risk',
    modules: 'SignalScoring.mqh, TradeValidation.mqh, RiskManagement.mqh, TradeExecution.mqh, PositionManagement.mqh',
    responsibility:
      '12-component 0-100 scoring, 11-point pre-trade gate, fixed-fractional risk with daily/weekly/DD lockouts, filling-mode execution, and magic-isolated exits.',
  },
  {
    layer: 'Research, CSV & Read-Only UI',
    modules: 'StrategySelection.mqh, AdaptiveLearning.mqh, HistoricalResearch.mqh, PerformanceAnalytics.mqh, CSVLogger.mqh, DashboardManager.mqh',
    responsibility:
      'Sample-gated strategy comparison, non-mutating deterioration warnings, 12 buffered CSV exports, and strictly read-only native MT5 chart UI.',
  },
];

const MARKET_COVERAGE = [
  { group: 'Forex Majors & Minors', specs: 'EURUSD, GBPUSD, USDJPY, crosses · 5/3-digit tick normalization · London/NY/Asian filters' },
  { group: 'Forex Exotics', specs: 'Spread-to-ATR cost gate · Dynamic stop/freeze level buffers · Volatility bounds' },
  { group: 'Metals & Energy', specs: 'XAUUSD, XAGUSD, WTI/Brent · Tick-value loss/lot calculation · Session schedule inspection' },
  { group: 'Stock Indices & CFDs', specs: 'US500, NAS100, GER40 · Contract size & margin estimation · Filling mode auto-selection (IOC/FOK/RETURN)' },
  { group: 'Synthetic & Step Indices', specs: '24/7 continuous session detection · M1-H4 support · Tick velocity & spread-expansion filters' },
];

export default function OverviewView({ summary, onNavigate }: OverviewViewProps) {
  return (
    <div className="space-y-8">
      <div className="flex flex-col gap-3 border-b border-slate-800 pb-6 lg:flex-row lg:items-end lg:justify-between">
        <div className="max-w-3xl space-y-2">
          <p className="text-xs font-medium text-sky-400">
            MetaTrader 5 Native MQL5 System · Research &amp; Demo Testing Configuration
          </p>
          <h1 className="font-display text-2xl font-semibold tracking-tight text-slate-100 sm:text-3xl">
            AdvancedScalpingEA Architecture &amp; Safety Overview
          </h1>
          <p className="text-sm leading-relaxed text-slate-400">
            Modular multi-market scalping Expert Advisor built in native MQL5 with independent capital preservation,
            non-repainting market analysis, 12-file CSV research telemetry, and a strictly decoupled read-only chart dashboard.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-3 shrink-0">
          <button
            type="button"
            onClick={() => onNavigate('explorer')}
            className="rounded-lg border border-slate-700 bg-slate-900 px-4 py-2 text-xs font-medium text-slate-200 transition-colors hover:border-slate-600 hover:bg-slate-800 whitespace-nowrap shrink-0"
          >
            Inspect MQL5 Source
          </button>
          <button
            type="button"
            onClick={() => onNavigate('terminal')}
            className="rounded-lg bg-sky-600 px-4 py-2 text-xs font-medium text-white transition-colors hover:bg-sky-500 whitespace-nowrap shrink-0"
          >
            Load MT5 CSV Exports
          </button>
        </div>
      </div>

      {/* Key Measured Codebase Metrics (Read directly from workspace files) */}
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <div className="rounded-lg border border-slate-800 bg-slate-900/70 p-4">
          <p className="text-xs text-slate-400">MQL5 Source Modules</p>
          <p className="mt-1 font-mono text-2xl font-semibold text-slate-100 tabular-nums">
            {summary ? summary.mqlCount : '—'}
          </p>
          <p className="mt-1 text-xs text-slate-500">1 .mq5 Expert · {summary ? summary.mqlCount - 1 : '—'} .mqh headers</p>
        </div>

        <div className="rounded-lg border border-slate-800 bg-slate-900/70 p-4">
          <p className="text-xs text-slate-400">Verified Lines of Code</p>
          <p className="mt-1 font-mono text-2xl font-semibold text-slate-100 tabular-nums">
            {summary ? summary.totalLines.toLocaleString() : '—'}
          </p>
          <p className="mt-1 text-xs text-slate-500">{summary ? summary.presetCount : '—'} instrument .set presets</p>
        </div>

        <div className="rounded-lg border border-slate-800 bg-slate-900/70 p-4">
          <p className="text-xs text-slate-400">Validated EA Inputs</p>
          <p className="mt-1 font-mono text-2xl font-semibold text-slate-100 tabular-nums">
            {summary ? summary.inputCount : '—'}
          </p>
          <p className="mt-1 text-xs text-slate-500">18 categorized parameter groups</p>
        </div>

        <div className="rounded-lg border border-slate-800 bg-slate-900/70 p-4">
          <p className="text-xs text-slate-400">Default Operating Mode</p>
          <p className="mt-1 font-mono text-base font-semibold text-emerald-400">
            RESEARCH_ONLY
          </p>
          <p className="mt-1 text-xs text-slate-500">Live trading disabled by default</p>
        </div>
      </div>

      {/* Safety & Isolation Guarantees */}
      <div className="grid gap-6 lg:grid-cols-2">
        <div className="rounded-lg border border-slate-800 bg-slate-900/60 p-5">
          <h2 className="font-display text-base font-semibold text-slate-100">
            Core Engineering &amp; Capital Safety Invariants
          </h2>
          <dl className="mt-4 divide-y divide-slate-800/80 text-sm">
            <div className="py-2.5 flex items-baseline justify-between gap-4">
              <dt className="text-slate-400">Live Trading Safety Gate</dt>
              <dd className="font-mono text-xs text-emerald-400 text-right">
                Blocked unless Mode=LIVE + 2 explicit opt-in flags
              </dd>
            </div>
            <div className="py-2.5 flex items-baseline justify-between gap-4">
              <dt className="text-slate-400">Dashboard Authority</dt>
              <dd className="font-mono text-xs text-slate-200 text-right">
                Strictly Read-Only (const SDashboardSnapshot)
              </dd>
            </div>
            <div className="py-2.5 flex items-baseline justify-between gap-4">
              <dt className="text-slate-400">Position &amp; Deal Ownership</dt>
              <dd className="font-mono text-xs text-slate-200 text-right">
                Filtered strictly by POSITION_MAGIC / DEAL_MAGIC
              </dd>
            </div>
            <div className="py-2.5 flex items-baseline justify-between gap-4">
              <dt className="text-slate-400">Look-Ahead / Repainting Guard</dt>
              <dd className="font-mono text-xs text-slate-200 text-right">
                Completed bars only (shift &gt;= 1)
              </dd>
            </div>
            <div className="py-2.5 flex items-baseline justify-between gap-4">
              <dt className="text-slate-400">Prohibited Sizing Methods</dt>
              <dd className="font-mono text-xs text-amber-400 text-right">
                Zero Martingale, grid, or loss doubling
              </dd>
            </div>
          </dl>
        </div>

        <div className="rounded-lg border border-slate-800 bg-slate-900/60 p-5">
          <h2 className="font-display text-base font-semibold text-slate-100">
            Multi-Market Dynamic Inspection Coverage
          </h2>
          <div className="mt-4 divide-y divide-slate-800/80">
            {MARKET_COVERAGE.map((item) => (
              <div key={item.group} className="py-2.5">
                <p className="text-sm font-medium text-slate-200">{item.group}</p>
                <p className="mt-0.5 text-xs text-slate-400">{item.specs}</p>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Modular Architecture Table */}
      <div className="rounded-lg border border-slate-800 bg-slate-900/60 overflow-hidden">
        <div className="border-b border-slate-800 px-5 py-4">
          <h2 className="font-display text-base font-semibold text-slate-100">
            Modular MQL5 Dependency Architecture
          </h2>
          <p className="mt-1 text-xs text-slate-400">
            Every layer compiles independently with explicit include guards and clean separation between market sensing, strategy evaluation, risk enforcement, and chart presentation.
          </p>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="border-b border-slate-800 bg-slate-950/60 text-xs text-slate-400">
              <tr>
                <th className="px-5 py-3 font-medium">Subsystem Layer</th>
                <th className="px-5 py-3 font-medium">MQL5 Modules</th>
                <th className="px-5 py-3 font-medium">Primary Responsibility</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/70">
              {ARCHITECTURE_LAYERS.map((row) => (
                <tr key={row.layer} className="hover:bg-slate-800/30">
                  <td className="px-5 py-3.5 font-medium text-slate-200 whitespace-nowrap align-top">
                    {row.layer}
                  </td>
                  <td className="px-5 py-3.5 font-mono text-xs text-sky-300 align-top">
                    {row.modules}
                  </td>
                  <td className="px-5 py-3.5 text-xs leading-relaxed text-slate-400 align-top">
                    {row.responsibility}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Deployment Workflow */}
      <div className="rounded-lg border border-slate-800 bg-slate-900/60 p-5">
        <h2 className="font-display text-base font-semibold text-slate-100">
          MetaTrader 5 Compilation &amp; Installation Steps
        </h2>
        <ol className="mt-3 grid gap-4 text-xs leading-relaxed text-slate-400 sm:grid-cols-3">
          <li className="rounded-md border border-slate-800/80 bg-slate-950/50 p-3.5">
            <p className="font-medium text-slate-200">1. Export &amp; Copy to MQL5</p>
            <p className="mt-1">
              Use <span className="text-slate-200">Download MQL5 ZIP</span> in the top bar and extract <span className="font-mono text-slate-300">Experts/</span>, <span className="font-mono text-slate-300">Include/</span>, and <span className="font-mono text-slate-300">Presets/</span> into your MT5 Data Folder (<span className="font-mono text-slate-300">MQL5/</span>).
            </p>
          </li>
          <li className="rounded-md border border-slate-800/80 bg-slate-950/50 p-3.5">
            <p className="font-medium text-slate-200">2. Compile in MetaEditor 5</p>
            <p className="mt-1">
              Open <span className="font-mono text-slate-300">MQL5/Experts/AdvancedScalpingEA.mq5</span> in MetaEditor 5 and press <span className="font-mono text-slate-300">F7</span> to build <span className="font-mono text-slate-300">AdvancedScalpingEA.ex5</span>.
            </p>
          </li>
          <li className="rounded-md border border-slate-800/80 bg-slate-950/50 p-3.5">
            <p className="font-medium text-slate-200">3. Backtest &amp; Analyze CSVs</p>
            <p className="mt-1">
              Run MT5 Strategy Tester on real ticks with <span className="font-mono text-slate-300">EA_MODE_DEMO_EXECUTION</span>, then upload the exported files from <span className="font-mono text-slate-300">MQL5/Files/AdvancedScalpingEA/Exports/</span> here.
            </p>
          </li>
        </ol>
      </div>
    </div>
  );
}
