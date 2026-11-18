import { useState } from 'react';
import { ArrowLeft, Download } from 'lucide-react';
import LandingPageView from './components/LandingPageView';
import PerformanceTerminalView from './components/PerformanceTerminalView';

type ActivePage = 'landing' | 'terminal';

export default function App() {
  const [activePage, setActivePage] = useState<ActivePage>('landing');

  function navigateToSection(sectionId: string) {
    if (activePage !== 'landing') {
      setActivePage('landing');
      window.setTimeout(() => {
        const el = document.getElementById(sectionId);
        if (el) el.scrollIntoView({ behavior: 'smooth' });
      }, 60);
      return;
    }
    const el = document.getElementById(sectionId);
    if (el) el.scrollIntoView({ behavior: 'smooth' });
  }

  return (
    <div className="min-h-screen bg-[#0B1120] text-slate-100 flex flex-col">
      {/* 3-Zone Top Bar: Wordmark (Left) · 4 Single-Line Links (Center) · Single Primary CTA (Right) */}
      <header className="sticky top-0 z-30 h-16 border-b border-slate-800 bg-[#0B1120]/95 backdrop-blur shrink-0">
        <div className="mx-auto flex h-full max-w-7xl items-center justify-between gap-4 px-6">
          <button
            type="button"
            onClick={() => {
              setActivePage('landing');
              window.scrollTo({ top: 0, behavior: 'smooth' });
            }}
            className="flex items-center gap-2.5 text-left shrink-0"
          >
            <span className="inline-flex h-7 w-7 items-center justify-center border border-sky-500/50 bg-sky-500/10 font-mono text-xs font-bold text-sky-400">
              AQ
            </span>
            <span className="font-display text-base font-bold tracking-tight text-slate-100 whitespace-nowrap">
              AdvancedScalpingEA
            </span>
          </button>

          <nav className="hidden md:flex items-center gap-7 text-sm">
            <button
              type="button"
              onClick={() => navigateToSection('architecture')}
              className="text-slate-300 hover:text-white transition-colors whitespace-nowrap shrink-0"
            >
              Architecture
            </button>
            <button
              type="button"
              onClick={() => navigateToSection('strategies')}
              className="text-slate-300 hover:text-white transition-colors whitespace-nowrap shrink-0"
            >
              Strategies
            </button>
            <button
              type="button"
              onClick={() => navigateToSection('execution-risk')}
              className="text-slate-300 hover:text-white transition-colors whitespace-nowrap shrink-0"
            >
              Execution &amp; Risk
            </button>
            <button
              type="button"
              onClick={() => {
                setActivePage('terminal');
                window.scrollTo({ top: 0, behavior: 'smooth' });
              }}
              className={`transition-colors whitespace-nowrap shrink-0 ${
                activePage === 'terminal'
                  ? 'text-sky-400 font-medium'
                  : 'text-slate-300 hover:text-white'
              }`}
            >
              CSV Terminal
            </button>
          </nav>

          <a
            href="/api/project/download-zip"
            download="AdvancedScalpingEA_MT5.zip"
            className="inline-flex items-center gap-2 bg-sky-500 px-4 py-2 text-xs font-semibold text-slate-950 transition-colors hover:bg-sky-400 whitespace-nowrap shrink-0"
          >
            <Download className="h-3.5 w-3.5" />
            <span>Download EA</span>
          </a>
        </div>
      </header>

      <main className="flex-1 w-full">
        {activePage === 'landing' ? (
          <LandingPageView
            onOpenTerminal={() => {
              setActivePage('terminal');
              window.scrollTo({ top: 0, behavior: 'smooth' });
            }}
          />
        ) : (
          <div className="mx-auto max-w-7xl px-6 py-8 space-y-6">
            <div className="flex items-center justify-between border-b border-slate-800 pb-4">
              <div>
                <h1 className="font-display text-xl font-bold text-slate-100">
                  MT5 CSV Performance Terminal
                </h1>
                <p className="text-xs text-slate-400 mt-1">
                  Offline analyzer for trade_history.csv, signals, rejections, risk events, and session summaries.
                </p>
              </div>
              <button
                type="button"
                onClick={() => setActivePage('landing')}
                className="inline-flex items-center gap-2 border border-slate-700 bg-slate-900 px-3.5 py-2 text-xs font-medium text-slate-200 hover:border-slate-500 hover:text-white transition-colors whitespace-nowrap shrink-0"
              >
                <ArrowLeft className="h-3.5 w-3.5" />
                <span>Back to Overview</span>
              </button>
            </div>
            <PerformanceTerminalView />
          </div>
        )}
      </main>
    </div>
  );
}
