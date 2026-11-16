import { Download } from 'lucide-react';
import PerformanceTerminalView from './components/PerformanceTerminalView';

export default function App() {
  return (
    <div className="min-h-screen bg-[#0B1120] text-slate-100 flex flex-col">
      <header className="flex h-14 items-center justify-between gap-6 border-b border-slate-800 bg-[#0F172A]/90 px-6 shrink-0">
        <div className="flex items-center gap-3 truncate">
          <span className="font-display text-base font-bold tracking-tight text-slate-100 whitespace-nowrap">
            AdvancedScalpingEA
          </span>
          <span className="hidden sm:inline text-xs text-slate-400 truncate">
            MT5 CSV Performance Terminal
          </span>
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
        <PerformanceTerminalView />
      </main>
    </div>
  );
}
