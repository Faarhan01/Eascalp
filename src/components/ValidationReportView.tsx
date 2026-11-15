export default function ValidationReportView() {
  const checklist = [
    {
      item: 'Complete Native MQL5 Modular Codebase',
      status: 'Implemented',
      note: '38 MQL5 source files (.mq5 + .mqh) with verified include graph, include guards, and zero placeholder stubs.',
    },
    {
      item: 'Research & Demo Safety Configuration',
      status: 'Implemented',
      note: 'InpOperatingMode defaults to EA_MODE_RESEARCH_ONLY; live real-money execution requires explicit opt-in via two confirmation flags.',
    },
    {
      item: 'Strictly Read-Only Chart Dashboard',
      status: 'Implemented',
      note: 'CDashboardManager accepts const snapshots only; passive page tabs and CCanvas charts cannot alter trading or risk state.',
    },
    {
      item: 'MetaEditor 5 .ex5 Binary Compilation',
      status: 'Requires Local MT5',
      note: 'MetaEditor 5 (metaeditor64.exe) is a Windows desktop compiler not present in this Linux container; compile Experts/AdvancedScalpingEA.mq5 in MetaEditor 5.',
    },
    {
      item: 'Real-Tick Strategy Tester & Walk-Forward Validation',
      status: 'Requires Local MT5',
      note: 'Execute multi-symbol, multi-timeframe real-tick tests using Presets/ and upload exported CSVs into the Performance Terminal.',
    },
  ];

  const csvExports = [
    'market_observations.csv',
    'tick_analysis.csv',
    'market_regimes.csv',
    'detected_patterns.csv',
    'strategy_signals.csv',
    'rejected_signals.csv',
    'trade_history.csv',
    'strategy_performance.csv',
    'risk_events.csv',
    'learning_history.csv',
    'configuration_history.csv',
    'session_summary.csv',
  ];

  return (
    <div className="space-y-8">
      <div className="border-b border-slate-800 pb-4">
        <h1 className="font-display text-xl font-semibold text-slate-100">
          Testing Protocol, Development Report &amp; Known Limitations
        </h1>
        <p className="mt-1 text-xs text-slate-400">
          Transparent engineering summary of what has been implemented in the MQL5 codebase and what requires execution inside MetaTrader 5.
        </p>
      </div>

      {/* Status Matrix */}
      <div className="rounded-lg border border-slate-800 bg-slate-900/60 overflow-hidden">
        <div className="border-b border-slate-800 px-5 py-3.5">
          <h2 className="font-display text-sm font-semibold text-slate-100">
            Engineering &amp; Validation Status
          </h2>
        </div>
        <div className="divide-y divide-slate-800/70">
          {checklist.map((row) => (
            <div key={row.item} className="grid gap-2 px-5 py-3.5 sm:grid-cols-[240px_140px_1fr] sm:items-center">
              <span className="text-xs font-medium text-slate-200">{row.item}</span>
              <span
                className={`font-mono text-xs ${
                  row.status === 'Implemented' ? 'text-emerald-400' : 'text-amber-400'
                }`}
              >
                {row.status}
              </span>
              <span className="text-xs leading-relaxed text-slate-400">{row.note}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Strategy Tester Protocol */}
      <div className="grid gap-6 lg:grid-cols-2">
        <div className="rounded-lg border border-slate-800 bg-slate-900/60 p-5 space-y-3">
          <h2 className="font-display text-sm font-semibold text-slate-100">
            MT5 Strategy Tester Validation Protocol
          </h2>
          <ul className="space-y-2.5 text-xs leading-relaxed text-slate-400">
            <li>
              <span className="font-medium text-slate-200">1. Real-Tick Modeling:</span> Select &ldquo;Every tick based on real ticks&rdquo; with realistic broker spread and commission settings.
            </li>
            <li>
              <span className="font-medium text-slate-200">2. Independent Strategy Isolation:</span> Enable one strategy input at a time (<span className="font-mono text-slate-300">InpEnableTrendPullback</span>, etc.) and compare against a no-trade baseline.
            </li>
            <li>
              <span className="font-medium text-slate-200">3. Out-of-Sample &amp; Walk-Forward Splits:</span> Reserve 30% unseen data (<span className="font-mono text-slate-300">InpOosSplitRatio = 0.30</span>); CSV outputs automatically tag <span className="font-mono text-slate-300">IN_SAMPLE</span> vs <span className="font-mono text-slate-300">OUT_OF_SAMPLE</span> folds.
            </li>
            <li>
              <span className="font-medium text-slate-200">4. Monte Carlo &amp; Robustness Sweeps:</span> Perturb score thresholds (+/- 5 pts) and SL/TP ATR multipliers (+/- 0.2x) to verify stability without curve-fitting.
            </li>
          </ul>
        </div>

        <div className="rounded-lg border border-slate-800 bg-slate-900/60 p-5 space-y-3">
          <h2 className="font-display text-sm font-semibold text-slate-100">
            12 Structured CSV Research Datasets
          </h2>
          <p className="text-xs text-slate-400">
            Buffered writes prevent tick-level disk thrashing and format cleanly for Python, R, Excel, or the Performance Terminal tab.
          </p>
          <div className="grid grid-cols-2 gap-2 pt-1">
            {csvExports.map((file) => (
              <div
                key={file}
                className="rounded border border-slate-800/80 bg-slate-950/60 px-2.5 py-1.5 font-mono text-[11px] text-slate-300"
              >
                {file}
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
