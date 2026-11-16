import { useEffect, useState } from 'react';
import {
  Activity,
  CheckCircle2,
  Code2,
  Download,
  Layers,
  ShieldCheck,
} from 'lucide-react';
import type { ProjectFileEntry, ProjectSummary } from './types/project';
import OverviewView from './components/OverviewView';
import CodeExplorerView from './components/CodeExplorerView';
import StrategySpecView from './components/StrategySpecView';
import PerformanceTerminalView from './components/PerformanceTerminalView';
import ValidationReportView from './components/ValidationReportView';

type NavTab = 'overview' | 'explorer' | 'strategies' | 'terminal' | 'validation';

const NAV_ITEMS: Array<{ id: NavTab; label: string; icon: typeof Layers }> = [
  { id: 'overview', label: 'Architecture', icon: Layers },
  { id: 'explorer', label: 'MQL5 Source', icon: Code2 },
  { id: 'strategies', label: 'Strategies & Inputs', icon: ShieldCheck },
  { id: 'terminal', label: 'CSV Terminal', icon: Activity },
  { id: 'validation', label: 'Testing & Report', icon: CheckCircle2 },
];

export default function App() {
  const [activeTab, setActiveTab] = useState<NavTab>('overview');
  const [files, setFiles] = useState<ProjectFileEntry[]>([]);
  const [summary, setSummary] = useState<ProjectSummary | null>(null);

  useEffect(() => {
    fetch('/api/project/tree')
      .then((r) => r.json())
      .then((data: { files: ProjectFileEntry[] }) => setFiles(data.files ?? []))
      .catch(() => {});

    fetch('/api/project/summary')
      .then((r) => r.json())
      .then((data: ProjectSummary) => setSummary(data))
      .catch(() => {});
  }, []);

  const breadcrumbLabel =
    NAV_ITEMS.find((item) => item.id === activeTab)?.label ?? 'Architecture';

  const shortModeLabel = summary
    ? summary.defaultMode.replace(/^EA_MODE_/, '')
    : 'Loading...';

  return (
    <div className="min-h-screen bg-[#0B1120] text-slate-100 flex flex-col lg:flex-row">
      {/* Left Workspace Sidebar */}
      <aside className="w-full shrink-0 border-b border-slate-800 bg-[#0F172A] lg:w-64 lg:border-b-0 lg:border-r">
        <div className="flex h-14 items-center justify-between border-b border-slate-800 px-5">
          <span className="font-display text-base font-bold tracking-tight text-slate-100 whitespace-nowrap">
            {summary?.eaName ?? 'AdvancedScalpingEA'}
          </span>
          {summary && (
            <span className="font-mono text-[11px] text-sky-400 tabular-nums">
              v{summary.version}
            </span>
          )}
        </div>

        <nav className="flex overflow-x-auto p-3 gap-1 lg:flex-col lg:overflow-visible">
          {NAV_ITEMS.map((item) => {
            const Icon = item.icon;
            const active = activeTab === item.id;
            return (
              <button
                key={item.id}
                type="button"
                onClick={() => setActiveTab(item.id)}
                className={`flex items-center gap-2.5 rounded-lg px-3 py-2.5 text-xs font-medium transition-colors whitespace-nowrap shrink-0 ${
                  active
                    ? 'bg-sky-600/15 text-sky-300 border border-sky-500/30'
                    : 'text-slate-400 hover:bg-slate-800/60 hover:text-slate-200 border border-transparent'
                }`}
              >
                <Icon className="h-4 w-4 shrink-0" />
                <span>{item.label}</span>
              </button>
            );
          })}
        </nav>

        <div className="hidden lg:block px-5 pt-4 mt-4 border-t border-slate-800/80 text-xs text-slate-500 space-y-2">
          <p className="font-medium text-slate-300">Read-Only Companion</p>
          <p className="leading-relaxed">
            Default EA Mode:{' '}
            <span
              className={`font-mono ${
                summary?.liveTradingDefault ? 'text-emerald-400' : 'text-amber-400'
              }`}
            >
              {shortModeLabel}
            </span>
            {summary && (
              <>
                {' '}
                ·{' '}
                {summary.liveTradingDefault
                  ? 'Trading enabled out-of-the-box.'
                  : 'Execution gated by inputs.'}
              </>
            )}
          </p>
        </div>
      </aside>

      {/* Main Content Area */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Top Bar Contract: Breadcrumb on left, 1 primary CTA on right */}
        <header className="flex h-14 items-center justify-between gap-8 border-b border-slate-800 bg-[#0F172A]/80 px-6 shrink-0">
          <div className="flex items-center gap-2 text-xs text-slate-400 truncate">
            <span className="text-slate-500">{summary?.eaName ?? 'AdvancedScalpingEA'}</span>
            <span aria-hidden="true">/</span>
            <span className="font-medium text-slate-200 truncate">{breadcrumbLabel}</span>
          </div>

          <a
            href="/api/project/download-zip"
            download="AdvancedScalpingEA_MT5.zip"
            className="inline-flex items-center gap-2 rounded-lg bg-sky-600 px-4 py-2 text-xs font-medium text-white transition-colors hover:bg-sky-500 whitespace-nowrap shrink-0"
          >
            <Download className="h-3.5 w-3.5" />
            <span>Download MQL5 ZIP</span>
          </a>
        </header>

        <main className="flex-1 p-6 lg:p-8 max-w-7xl w-full mx-auto">
          {activeTab === 'overview' && (
            <OverviewView summary={summary} onNavigate={setActiveTab} />
          )}
          {activeTab === 'explorer' && <CodeExplorerView files={files} />}
          {activeTab === 'strategies' && <StrategySpecView summary={summary} />}
          {activeTab === 'terminal' && (
            <PerformanceTerminalView csvSchemas={summary?.csvSchemas ?? []} />
          )}
          {activeTab === 'validation' && <ValidationReportView summary={summary} />}
        </main>
      </div>
    </div>
  );
}
