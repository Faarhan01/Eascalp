import type { ProjectSummary } from '../types/project';

interface OverviewViewProps {
  summary: ProjectSummary | null;
  onNavigate: (tab: 'explorer' | 'strategies' | 'terminal' | 'validation') => void;
}

export default function OverviewView({ summary, onNavigate }: OverviewViewProps) {
  const shortMode = summary
    ? summary.defaultMode.replace(/^EA_MODE_/, '')
    : '—';

  return (
    <div className="space-y-8">
      <div className="flex flex-col gap-3 border-b border-slate-800 pb-6 lg:flex-row lg:items-end lg:justify-between">
        <div className="max-w-3xl space-y-2">
          <p className="text-xs font-medium text-sky-400">
            MetaTrader 5 Native MQL5 {summary ? `v${summary.version}` : ''} ·{' '}
            {summary?.liveTradingDefault ? 'Ready-to-Trade Configuration' : 'Configurable Execution Mode'}
          </p>
          <h1 className="font-display text-2xl font-semibold tracking-tight text-slate-100 sm:text-3xl">
            {summary?.eaName ?? 'AdvancedScalpingEA'} Architecture &amp; Execution Overview
          </h1>
          <p className="text-sm leading-relaxed text-slate-400">
            Multi-symbol ({summary ? `up to ${summary.maxSymbols}` : '—'} isolated instruments), cost-aware scalping Expert Advisor
            built in native MQL5 with {summary ? summary.maxRegimes : '—'} market regimes, {summary ? summary.strategies.length : '—'} independent strategies,
            pre-trade expectancy filtering, portfolio currency-exposure limits, MFE/MAE telemetry, and {summary ? summary.csvSchemas.length : '—'} CSV research exports.
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

      {/* Key Measured Codebase Metrics (Parsed live from workspace MQL5 files) */}
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-4">
        <div className="rounded-lg border border-slate-800 bg-slate-900/70 p-4">
          <p className="text-xs text-slate-400">MQL5 Source Modules</p>
          <p className="mt-1 font-mono text-2xl font-semibold text-slate-100 tabular-nums">
            {summary ? summary.mqlCount : '—'}
          </p>
          <p className="mt-1 text-xs text-slate-500 tabular-nums">
            {summary ? `${summary.mq5Count} .mq5 Expert · ${summary.mqhCount} .mqh headers` : 'Loading...'}
          </p>
        </div>

        <div className="rounded-lg border border-slate-800 bg-slate-900/70 p-4">
          <p className="text-xs text-slate-400">Verified Lines of Code</p>
          <p className="mt-1 font-mono text-2xl font-semibold text-slate-100 tabular-nums">
            {summary ? summary.totalLines.toLocaleString() : '—'}
          </p>
          <p className="mt-1 text-xs text-slate-500 tabular-nums">
            {summary ? `${summary.presetCount} instrument .set presets` : 'Loading...'}
          </p>
        </div>

        <div className="rounded-lg border border-slate-800 bg-slate-900/70 p-4">
          <p className="text-xs text-slate-400">Validated EA Inputs</p>
          <p className="mt-1 font-mono text-2xl font-semibold text-slate-100 tabular-nums">
            {summary ? summary.inputCount : '—'}
          </p>
          <p className="mt-1 text-xs text-slate-500 tabular-nums">
            {summary ? `${summary.inputGroups.length} parameter groups` : 'Loading...'}
          </p>
        </div>

        <div className="rounded-lg border border-slate-800 bg-slate-900/70 p-4">
          <p className="text-xs text-slate-400">Default Operating Mode</p>
          <p
            className={`mt-1 font-mono text-base font-semibold ${
              summary?.liveTradingDefault ? 'text-emerald-400' : 'text-amber-400'
            }`}
          >
            {shortMode}
          </p>
          <p className="mt-1 text-xs text-slate-500">
            {summary
              ? summary.liveTradingDefault
                ? 'Ready to trade on Live / Demo / Tester'
                : 'Manual execution opt-in active'
              : 'Loading...'}
          </p>
        </div>
      </div>

      {/* Execution & Isolation Invariants + Instrument Presets */}
      <div className="grid gap-6 lg:grid-cols-2">
        <div className="rounded-lg border border-slate-800 bg-slate-900/60 p-5">
          <h2 className="font-display text-base font-semibold text-slate-100">
            Execution Readiness &amp; Capital Safety Invariants
          </h2>
          <dl className="mt-4 divide-y divide-slate-800/80 text-sm">
            <div className="py-2.5 flex items-baseline justify-between gap-4">
              <dt className="text-slate-400">Out-of-the-Box Trading</dt>
              <dd className="font-mono text-xs text-emerald-400 text-right">
                {summary
                  ? `Mode=${shortMode} · Live=${String(summary.allowLiveTrading)} · Ack=${String(summary.confirmLiveRiskAck)}`
                  : '—'}
              </dd>
            </div>
            <div className="py-2.5 flex items-baseline justify-between gap-4">
              <dt className="text-slate-400">Dashboard Authority</dt>
              <dd className="font-mono text-xs text-slate-200 text-right">
                Strictly Read-Only (const SDashboardSnapshot)
              </dd>
            </div>
            <div className="py-2.5 flex items-baseline justify-between gap-4">
              <dt className="text-slate-400">Order Filling &amp; Retries</dt>
              <dd className="font-mono text-xs text-slate-200 text-right">
                Auto-fallback IOC / FOK / RETURN + Hedging &amp; Netting ticket sync
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

        {/* Live Parsed .set Presets */}
        <div className="rounded-lg border border-slate-800 bg-slate-900/60 overflow-hidden">
          <div className="border-b border-slate-800 px-5 py-3.5">
            <h2 className="font-display text-base font-semibold text-slate-100">
              Configured MT5 Presets ({summary ? summary.presets.length : 0})
            </h2>
            <p className="mt-0.5 text-xs text-slate-400">
              Parsed directly from <span className="font-mono text-slate-300">Presets/**/*.set</span> files on disk.
            </p>
          </div>
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs">
              <thead className="border-b border-slate-800 bg-slate-950/60 text-slate-400">
                <tr>
                  <th className="px-4 py-2.5 font-medium">Asset</th>
                  <th className="px-4 py-2.5 font-medium">Preset</th>
                  <th className="px-4 py-2.5 font-medium">Mode</th>
                  <th className="px-4 py-2.5 font-medium text-right">Risk %</th>
                  <th className="px-4 py-2.5 font-medium text-right">Min Score</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-800/70 font-mono tabular-nums">
                {(summary?.presets ?? []).map((p) => (
                  <tr key={p.path} className="hover:bg-slate-800/30">
                    <td className="px-4 py-2 font-sans text-slate-300">{p.assetGroup}</td>
                    <td className="px-4 py-2 text-sky-300">{p.configLabel}</td>
                    <td className="px-4 py-2 text-emerald-400">
                      {p.operatingMode.replace(/^EA_MODE_/, '')}
                    </td>
                    <td className="px-4 py-2 text-right text-slate-200">{p.riskPct}%</td>
                    <td className="px-4 py-2 text-right text-slate-200">{p.minScore}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      {/* Live Workspace Subsystem Breakdown */}
      <div className="rounded-lg border border-slate-800 bg-slate-900/60 overflow-hidden">
        <div className="border-b border-slate-800 px-5 py-4">
          <h2 className="font-display text-base font-semibold text-slate-100">
            Workspace Module Directory Inventory ({summary ? summary.subsystems.length : 0} Subsystems)
          </h2>
          <p className="mt-1 text-xs text-slate-400">
            Enumerated dynamically from <span className="font-mono text-slate-300">AdvancedScalpingEA/</span> with live line counts and file manifests.
          </p>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="border-b border-slate-800 bg-slate-950/60 text-slate-400">
              <tr>
                <th className="px-5 py-3 font-medium">Directory Layer</th>
                <th className="px-5 py-3 font-medium text-right">Files</th>
                <th className="px-5 py-3 font-medium text-right">Lines</th>
                <th className="px-5 py-3 font-medium">Modules</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/70">
              {(summary?.subsystems ?? []).map((sub) => (
                <tr key={sub.category} className="hover:bg-slate-800/30">
                  <td className="px-5 py-3 font-mono font-medium text-slate-200 whitespace-nowrap align-top">
                    {sub.category}
                  </td>
                  <td className="px-5 py-3 font-mono text-right text-slate-300 tabular-nums align-top">
                    {sub.fileCount}
                  </td>
                  <td className="px-5 py-3 font-mono text-right text-slate-300 tabular-nums align-top">
                    {sub.totalLines.toLocaleString()}
                  </td>
                  <td className="px-5 py-3 font-mono text-sky-300 leading-relaxed align-top">
                    {sub.files.join(', ')}
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
          MetaTrader 5 Compilation &amp; Deployment Steps
        </h2>
        <ol className="mt-3 grid gap-4 text-xs leading-relaxed text-slate-400 sm:grid-cols-3">
          <li className="rounded-md border border-slate-800/80 bg-slate-950/50 p-3.5">
            <p className="font-medium text-slate-200">1. Export &amp; Copy to MQL5</p>
            <p className="mt-1">
              Use <span className="text-slate-200">Download MQL5 ZIP</span> in the top bar and extract{' '}
              <span className="font-mono text-slate-300">Experts/</span>,{' '}
              <span className="font-mono text-slate-300">Include/</span>, and{' '}
              <span className="font-mono text-slate-300">Presets/</span> into your MT5 Data Folder (<span className="font-mono text-slate-300">MQL5/</span>).
            </p>
          </li>
          <li className="rounded-md border border-slate-800/80 bg-slate-950/50 p-3.5">
            <p className="font-medium text-slate-200">2. Compile &amp; Enable Algo Trading</p>
            <p className="mt-1">
              Open <span className="font-mono text-slate-300">MQL5/Experts/AdvancedScalpingEA.mq5</span> in MetaEditor 5 and press{' '}
              <span className="font-mono text-slate-300">F7</span>. Attach to chart with MT5 <span className="text-slate-200">Algo Trading</span> enabled.
            </p>
          </li>
          <li className="rounded-md border border-slate-800/80 bg-slate-950/50 p-3.5">
            <p className="font-medium text-slate-200">3. Inspect Live &amp; Tester CSVs</p>
            <p className="mt-1">
              Upload any of the {summary ? summary.csvSchemas.length : 12} CSVs from{' '}
              <span className="font-mono text-slate-300">MQL5/Files/AdvancedScalpingEA/Exports/</span> into the CSV Terminal tab.
            </p>
          </li>
        </ol>
      </div>
    </div>
  );
}
