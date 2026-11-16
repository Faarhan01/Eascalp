import { useMemo, useState } from 'react';
import { Search } from 'lucide-react';
import type { ProjectSummary } from '../types/project';

interface StrategySpecViewProps {
  summary: ProjectSummary | null;
}

export default function StrategySpecView({ summary }: StrategySpecViewProps) {
  const [query, setQuery] = useState('');
  const [groupFilter, setGroupFilter] = useState('ALL');

  const inputs = summary?.inputs ?? [];
  const strategies = summary?.strategies ?? [];
  const scoringComponents = summary?.scoringComponents ?? [];
  const totalScorePoints = scoringComponents.reduce((acc, c) => acc + c.maxPoints, 0);

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
          All strategy specifications, scoring weights, and EA inputs below are parsed directly from{' '}
          <span className="font-mono text-slate-300">Include/Strategies/*.mqh</span>,{' '}
          <span className="font-mono text-slate-300">Include/Core/Types.mqh</span>, and{' '}
          <span className="font-mono text-slate-300">Experts/AdvancedScalpingEA.mq5</span>.
        </p>
      </div>

      {/* Live Parsed Strategies Table */}
      <div className="rounded-lg border border-slate-800 bg-slate-900/60 overflow-hidden">
        <div className="border-b border-slate-800 px-5 py-3.5">
          <h2 className="font-display text-sm font-semibold text-slate-100">
            Independent Scalping Strategy Engines ({strategies.length})
          </h2>
        </div>
        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs">
            <thead className="border-b border-slate-800 bg-slate-950/60 text-slate-400">
              <tr>
                <th className="px-4 py-3 font-medium">#</th>
                <th className="px-4 py-3 font-medium">Strategy</th>
                <th className="px-4 py-3 font-medium">Suitable Regimes</th>
                <th className="px-4 py-3 font-medium">Conditional Regimes</th>
                <th className="px-4 py-3 font-medium">Calibrated Thresholds &amp; Hooks</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-800/70">
              {strategies.map((s) => (
                <tr key={s.enumKey || s.id} className="hover:bg-slate-800/30">
                  <td className="px-4 py-3 font-mono text-slate-500 tabular-nums align-top">{s.id}</td>
                  <td className="px-4 py-3 align-top">
                    <p className="font-medium text-slate-200 whitespace-nowrap">{s.name}</p>
                    <p className="font-mono text-[11px] text-sky-400">{s.module}</p>
                  </td>
                  <td className="px-4 py-3 text-slate-300 leading-relaxed align-top">
                    {s.suitableRegimes.length > 0 ? s.suitableRegimes.join(', ') : '—'}
                  </td>
                  <td className="px-4 py-3 text-slate-400 leading-relaxed align-top">
                    {s.conditionalRegimes.length > 0 ? s.conditionalRegimes.join(', ') : '—'}
                  </td>
                  <td className="px-4 py-3 font-mono text-[11px] text-slate-300 leading-relaxed align-top">
                    <div>
                      {s.defaults.length > 0
                        ? s.defaults.map((d) => `${d.key}=${d.value}`).join(' · ')
                        : 'Base ATR risk defaults'}
                    </div>
                    <div className="mt-1 font-sans text-slate-500">
                      {s.hasCustomExit ? 'Includes custom ShouldExitPosition() hook' : 'Managed exits'}
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Live Parsed Scoring Breakdown */}
      <div className="rounded-lg border border-slate-800 bg-slate-900/60 p-5">
        <div className="flex flex-col gap-1 sm:flex-row sm:items-center sm:justify-between">
          <h2 className="font-display text-sm font-semibold text-slate-100">
            {scoringComponents.length}-Component Signal Scoring Matrix (0–{totalScorePoints} Scale)
          </h2>
          <span className="font-mono text-xs text-emerald-400 tabular-nums">
            Default Threshold: {summary ? summary.defaultMinScore.toFixed(1) : '—'} / {totalScorePoints}
          </span>
        </div>
        <p className="mt-1 text-xs text-slate-400">
          Parsed directly from <span className="font-mono text-slate-300">struct SScoreBreakdown</span> in{' '}
          <span className="font-mono text-slate-300">Types.mqh</span>. Weights sum to {totalScorePoints} points.
        </p>
        <div className="mt-4 grid gap-2.5 sm:grid-cols-2 lg:grid-cols-5">
          {scoringComponents.map((comp) => (
            <div
              key={comp.field}
              className="flex items-center justify-between gap-2 rounded-md border border-slate-800/80 bg-slate-950/50 px-3 py-2.5 text-xs"
            >
              <span className="text-slate-300">{comp.label}</span>
              <span className="font-mono font-medium text-sky-400 tabular-nums shrink-0">
                {comp.maxPoints} pts
              </span>
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
                  {g === 'ALL' ? `All ${Math.max(0, groups.length - 1)} Input Groups` : g}
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
