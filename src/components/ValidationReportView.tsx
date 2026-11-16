import type { ProjectSummary } from '../types/project';

interface ValidationReportViewProps {
  summary: ProjectSummary | null;
}

export default function ValidationReportView({ summary }: ValidationReportViewProps) {
  const versionLabel = summary ? `v${summary.version}` : '';
  const mqlBreakdown = summary
    ? `${summary.mqlCount} MQL5 source files (${summary.mq5Count} .mq5 + ${summary.mqhCount} .mqh headers), ${summary.maxSymbols}-symbol SymbolContext isolation, ${summary.maxRegimes} regimes, and ${summary.strategies.length} independent strategies.`
    : 'Loading workspace metrics...';

  const checklist = [
    {
      item: `Complete Native MQL5 ${versionLabel} Codebase`,
      status: 'Implemented',
      note: mqlBreakdown,
    },
    {
      item: 'Universal Symbol Intelligence & Execution Fallback',
      status: 'Implemented',
      note: summary
        ? `Default mode ${summary.defaultMode} (AllowLive=${String(summary.allowLiveTrading)}, Ack=${String(summary.confirmLiveRiskAck)}); auto-detects Forex/Metals/Indices/Crypto/Synthetics with adaptive spread caps, 3-mode IOC/FOK/RETURN fallback, and Hedging/Netting resolution.`
        : 'Loading execution settings...',
    },
    {
      item: 'Structural Stops, Anti-Martingale Risk & Chandelier Trailing',
      status: 'Implemented',
      note: 'Anchors SL beyond swing/S/R zones; scales risk by equity DD and losing streaks with margin-safe clamping; manages cost-covering BE, restart-safe partial closes, and progressive Chandelier trailing.',
    },
    {
      item: '5-Stage Controlled Adaptive Learning',
      status: 'Implemented',
      note: 'Separates data collection, edge evaluation, out-of-sample proposal generation, OOS validation gating, and version-tracked activation without silent live self-rewriting.',
    },
    {
      item: 'Strictly Read-Only Chart Dashboard',
      status: 'Implemented',
      note: 'CDashboardManager accepts const snapshots only and derives labels, account currency, Algo status, and sample targets dynamically across 6 tabs and 5 CCanvas charts.',
    },
    {
      item: 'MetaEditor 5 .ex5 Binary Compilation',
      status: 'Requires Local MT5',
      note: 'MetaEditor 5 (metaeditor64.exe) is a Windows desktop compiler not present in this Linux container; compile Experts/AdvancedScalpingEA.mq5 in MetaEditor 5.',
    },
    {
      item: 'Real-Tick Strategy Tester & Live Execution Verification',
      status: 'Requires Local MT5',
      note: `Attach with MT5 Algo Trading enabled or test across the ${summary ? summary.presetCount : '—'} Presets/ files and inspect exported CSVs in the CSV Terminal.`,
    },
  ];

  const csvSchemas = summary?.csvSchemas ?? [];

  return (
    <div className="space-y-8">
      <div className="border-b border-slate-800 pb-4">
        <h1 className="font-display text-xl font-semibold text-slate-100">
          Testing Protocol, Development Report &amp; Diagnostics {versionLabel}
        </h1>
        <p className="mt-1 text-xs text-slate-400">
          Live-parsed engineering summary of the {summary?.eaName ?? 'AdvancedScalpingEA'} MQL5 codebase and local MetaTrader 5 verification steps.
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
            <div key={row.item} className="grid gap-2 px-5 py-3.5 sm:grid-cols-[270px_140px_1fr] sm:items-center">
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

      {/* Strategy Tester Protocol & Dynamic CSV Schemas */}
      <div className="grid gap-6 lg:grid-cols-2">
        <div className="rounded-lg border border-slate-800 bg-slate-900/60 p-5 space-y-3">
          <h2 className="font-display text-sm font-semibold text-slate-100">
            MT5 Strategy Tester &amp; Live Checklist
          </h2>
          <ul className="space-y-2.5 text-xs leading-relaxed text-slate-400">
            <li>
              <span className="font-medium text-slate-200">1. Algo Trading &amp; Mode:</span> Ensure MT5 toolbar <span className="text-slate-200">Algo Trading</span> is enabled. Default <span className="font-mono text-slate-300">InpOperatingMode = EA_MODE_LIVE_TRADING</span> executes on Live, Demo, and Strategy Tester accounts immediately.
            </li>
            <li>
              <span className="font-medium text-slate-200">2. Real-Tick Modeling:</span> Select &ldquo;Every tick based on real ticks&rdquo; with realistic broker spread and slippage settings.
            </li>
            <li>
              <span className="font-medium text-slate-200">3. Out-of-Sample &amp; Score-Band Splits:</span> Reserve unseen data (<span className="font-mono text-slate-300">InpOosSplitRatio</span>); CSV outputs tag <span className="font-mono text-slate-300">IN_SAMPLE</span> vs <span className="font-mono text-slate-300">OUT_OF_SAMPLE</span> folds and score bands.
            </li>
            <li>
              <span className="font-medium text-slate-200">4. Diagnostic Logs:</span> Rejection codes (<span className="font-mono text-slate-300">TERMINAL_AUTO_DISABLED</span>, <span className="font-mono text-slate-300">SPREAD_TOO_WIDE</span>, <span className="font-mono text-slate-300">INSUFFICIENT_MARGIN</span>, <span className="font-mono text-slate-300">OPPOSING_SIGNAL_CONFLICT</span>, etc.) are written to the Experts journal and <span className="font-mono text-slate-300">rejected_signals.csv</span>.
            </li>
          </ul>
        </div>

        <div className="rounded-lg border border-slate-800 bg-slate-900/60 p-5 space-y-3">
          <h2 className="font-display text-sm font-semibold text-slate-100">
            {csvSchemas.length} Structured CSV Research Datasets (Parsed from CSVLogger.mqh)
          </h2>
          <p className="text-xs text-slate-400">
            Buffered writes prevent tick-level disk thrashing and inspect cleanly in the CSV Terminal tab.
          </p>
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 pt-1">
            {csvSchemas.map((schema) => (
              <div
                key={schema.filename}
                className="rounded border border-slate-800/80 bg-slate-950/60 px-2.5 py-1.5"
              >
                <p className="font-mono text-[11px] text-sky-300">{schema.filename}</p>
                <p className="mt-0.5 text-[10px] text-slate-500 tabular-nums">
                  {schema.columns.length} columns
                </p>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
