import { useState } from 'react';
import {
  Activity,
  ArrowRight,
  BarChart3,
  Check,
  Compass,
  Download,
  Layers,
  Lock,
  ShieldCheck,
  Sliders,
  Terminal,
} from 'lucide-react';
import heroQuantImg from '../assets/images/hero_quant_execution_1794981579954.jpg';

interface LandingPageViewProps {
  onOpenTerminal: () => void;
}

const ASSET_PROFILES = [
  {
    code: 'FX',
    name: 'Forex Majors, Crosses & Exotics',
    detail:
      'Auto-detects 4/5-digit FX pricing, dynamic spread caps relative to ATR, and shared-currency net lot caps across correlated pairs.',
  },
  {
    code: 'IDX',
    name: 'Step Index & 24/7 Synthetics',
    detail:
      'Recognizes Step Index and continuous synthetic instruments, disables weekend closeouts, and enables rolling midnight VWAP continuity.',
  },
  {
    code: 'XAU',
    name: 'Metals & Energy CFDs',
    detail:
      'Scales stop multipliers, slippage tolerances, and minimum expectancy buffers for higher tick volatility and wide liquidity bursts.',
  },
  {
    code: 'EQ',
    name: 'Equities, Indices & Crypto CFDs',
    detail:
      'Calibrates bar normalization, tick-velocity floors, empirically learned wick ratios, and margin safety buffers across stocks, indices, and 24/7 crypto CFDs.',
  },
];

const STRATEGIES = [
  {
    id: '01',
    name: 'Trend Pullback',
    regimes: 'Strong & Established Trends',
    detail:
      'Enforces HTF alignment, ADX >= 20, value-zone swing positioning, and H1 wall clearance—arming the Entry Sniper for EMA value pullbacks instead of chasing extended bars.',
  },
  {
    id: '02',
    name: 'Momentum Scalping',
    regimes: 'Trend & Vol Expansion',
    detail:
      'Captures ADX-confirmed directional launches near fast EMA structure with RVOL >= 0.95, clear headroom to H1/S/R walls, and live pullback trigger optimization.',
  },
  {
    id: '03',
    name: 'Breakout Scalping',
    regimes: 'Consolidation & Early Trend',
    detail:
      'Validates fresh structural BOS and Donchian breaks with RVOL >= 1.10 and structural clearance while arming retest entries on overextended breakout impulses.',
  },
  {
    id: '04',
    name: 'Reversal Scalping',
    regimes: 'Exhaustion & Reversal Regimes',
    detail:
      'Requires graph discount/premium extremes (swing position, Donchian extremum, or Session VWAP Z-Score stretch) plus divergence or rejection candles.',
  },
  {
    id: '05',
    name: 'Range Scalping',
    regimes: 'Sideways & Wide Ranges',
    detail:
      'Buys exclusively in the lower discount third and sells in the upper premium third across >= 2-touch boundaries with strict opposing-HTF locks and >= 1.55R room.',
  },
  {
    id: '06',
    name: 'Volatility Expansion',
    regimes: 'Squeeze-to-Expansion Breaks',
    detail:
      'Triggers out of Bollinger compression inside controlled [1.15..2.35] volatility bounds with clear H1/S/R headroom and pullback retest arming.',
  },
  {
    id: '07',
    name: 'Micro-Momentum',
    regimes: 'High-Velocity Tick Bursts (Opt-In)',
    detail:
      'Optional burst engine (disabled by default for fee preservation) requiring >= 7 directional ticks, rising ADX, value-zone clearance, and tight <= 12% ATR spread.',
  },
  {
    id: '08',
    name: 'Liquidity Sweep',
    regimes: 'Stop-Hunt & Reversal Regimes',
    detail:
      'Detects >= 44% rejection wicks sweeping outer swing/PDH/PDL liquidity pools near graph extremes with empirical sweep-depth stop protection.',
  },
  {
    id: '09',
    name: 'VWAP Reversion',
    regimes: 'Ranges & Overstretched Pullbacks',
    detail:
      'Fades statistical Session VWAP Z-Score extremes (>= 1.25 sigma) aligned with discount/premium swing zones back toward fair value with >= 1.55R room.',
  },
  {
    id: '10',
    name: 'EMA Ribbon Cont.',
    regimes: 'Established & Strong Trends',
    detail:
      'Enters EMA 9/21/55/SMA200 continuation thrusts on rising ADX with H1 wall clearance, anti-chase limits, and automatic pullback trigger refinement.',
  },
];

const EXECUTION_PILLARS = [
  {
    icon: Sliders,
    title: 'Symbol DNA, 24h Liquidity & H1 Wall Gates',
    detail:
      'Classifies each instrument empirically over 240 bars (Trending, Mean-Reverting, or Breakout-Sweep), skips dead-liquidity hours automatically, and blocks trades into H1/S/R walls.',
  },
  {
    icon: ShieldCheck,
    title: 'Live Pullback Extremum Entry Sniper',
    detail:
      'Instead of market-chasing extended bars, extended setups arm the tick-level Entry Sniper for up to 2 bars to enter on optimal EMA/retest pullbacks while guarding SL & runaway bounds.',
  },
  {
    icon: Lock,
    title: 'Non-Clipping >= 1.05R BE & Wide Trail',
    detail:
      'Lets winners run to 3.20x ATR targets with sweep-resistant SL adaptation, delayed 1.65x ATR Break-Even (>= 1.05R), and 2.40x ATR Chandelier structure trailing.',
  },
];

const INSTALL_STEPS = [
  {
    step: '01',
    title: 'Download & Extract Package',
    detail:
      'Download the complete AdvancedScalpingEA MQL5 archive and copy the folder into your MetaTrader 5 MQL5/Experts directory.',
  },
  {
    step: '02',
    title: 'Compile in MetaEditor 5',
    detail:
      'Open Experts/AdvancedScalpingEA.mq5 in MetaEditor 5 and compile to generate your native .ex5 binary with zero external DLLs or .set files.',
  },
  {
    step: '03',
    title: 'Attach & Inspect Analytics',
    detail:
      'Attach directly to any symbol or Strategy Tester session (live-ready defaults enabled), then drop exported logs into the CSV Terminal.',
  },
];

export default function LandingPageView({ onOpenTerminal }: LandingPageViewProps) {
  const [imgError, setImgError] = useState(false);

  return (
    <div className="bg-[#0B1120] text-slate-100">
      {/* 1. HERO SECTION */}
      <section className="relative overflow-hidden border-b border-slate-800/90">
        <div className="mx-auto max-w-7xl px-6 py-16 lg:py-24 grid grid-cols-1 lg:grid-cols-12 gap-12 items-center">
          <div className="lg:col-span-6 space-y-6">
            <div className="border-l-2 border-sky-400 pl-3 font-mono text-xs uppercase tracking-widest text-sky-400">
              MetaTrader 5 Native MQL5 Engine · v3.1.0
            </div>

            <h1 className="font-display text-4xl sm:text-5xl font-bold tracking-tight text-slate-50 leading-[1.08]">
              Precision Multi-Asset Scalping Tuned to Every Chart&apos;s DNA.
            </h1>

            <p className="text-base sm:text-lg text-slate-300 leading-relaxed max-w-xl">
              AdvancedScalpingEA profiles contract specs, 240-bar empirical personality, and 24-hour liquidity curves
              on any symbol—waiting at discount/premium graph extremes with a live pullback Entry Sniper.
            </p>

            <div className="flex flex-wrap items-center gap-4 pt-2">
              <a
                href="/api/project/download-zip"
                download="AdvancedScalpingEA_MT5.zip"
                className="inline-flex items-center gap-2.5 bg-sky-500 px-5 py-3 text-sm font-semibold text-slate-950 transition-colors hover:bg-sky-400 whitespace-nowrap"
              >
                <Download className="h-4 w-4" />
                <span>Download MQL5 Package</span>
              </a>

              <button
                type="button"
                onClick={onOpenTerminal}
                className="inline-flex items-center gap-2 border border-slate-700 bg-slate-900/80 px-5 py-3 text-sm font-medium text-slate-200 transition-colors hover:border-slate-500 hover:text-white whitespace-nowrap"
              >
                <Terminal className="h-4 w-4 text-sky-400" />
                <span>Open CSV Terminal</span>
                <ArrowRight className="h-4 w-4" />
              </button>
            </div>

            <div className="grid grid-cols-3 gap-6 border-t border-slate-800 pt-6">
              <div>
                <p className="font-mono text-xl font-semibold text-slate-50 tabular-nums">10</p>
                <p className="text-xs text-slate-400 mt-1">Regime-Gated Strategies</p>
              </div>
              <div>
                <p className="font-mono text-xl font-semibold text-slate-50 tabular-nums">18</p>
                <p className="text-xs text-slate-400 mt-1">Classified Market Regimes</p>
              </div>
              <div>
                <p className="font-mono text-xl font-semibold text-slate-50 tabular-nums">0</p>
                <p className="text-xs text-slate-400 mt-1">Required .SET Presets</p>
              </div>
            </div>
          </div>

          <div className="lg:col-span-6">
            <div className="border border-slate-800 bg-[#0F172A] overflow-hidden">
              <div className="aspect-video w-full bg-slate-950 relative overflow-hidden">
                {!imgError ? (
                  <img
                    src={heroQuantImg}
                    alt="Algorithmic market microstructure depth contour visualization"
                    referrerPolicy="no-referrer"
                    onError={() => setImgError(true)}
                    className="h-full w-full object-cover object-center"
                  />
                ) : (
                  <div className="flex h-full w-full items-center justify-center bg-slate-950 text-xs font-mono text-slate-500">
                    QUANTITATIVE EXECUTION ENGINE TOPOLOGY
                  </div>
                )}
              </div>

              <div className="grid grid-cols-2 sm:grid-cols-4 divide-y sm:divide-y-0 sm:divide-x divide-slate-800 border-t border-slate-800 bg-[#0F172A]">
                <div className="px-4 py-3">
                  <p className="font-mono text-[11px] uppercase tracking-wider text-slate-400">Expectancy Floor</p>
                  <p className="font-mono text-xs font-medium text-emerald-400 mt-0.5">&gt;= 1.55R / 2.6x Cost</p>
                </div>
                <div className="px-4 py-3">
                  <p className="font-mono text-[11px] uppercase tracking-wider text-slate-400">Risk Model</p>
                  <p className="font-mono text-xs font-medium text-slate-100 mt-0.5">Fixed-Fractional</p>
                </div>
                <div className="px-4 py-3">
                  <p className="font-mono text-[11px] uppercase tracking-wider text-slate-400">BE / Trail</p>
                  <p className="font-mono text-xs font-medium text-slate-100 mt-0.5">1.65 / 2.40 ATR</p>
                </div>
                <div className="px-4 py-3">
                  <p className="font-mono text-[11px] uppercase tracking-wider text-slate-400">Telemetry</p>
                  <p className="font-mono text-xs font-medium text-slate-100 mt-0.5">12 CSV Exports</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* 2. AUTO-ADAPTIVE ARCHITECTURE SECTION */}
      <section id="architecture" className="border-b border-slate-800/90 py-16 lg:py-20">
        <div className="mx-auto max-w-7xl px-6">
          <div className="max-w-2xl space-y-3 mb-12">
            <div className="border-l-2 border-sky-400 pl-3 font-mono text-xs uppercase tracking-widest text-sky-400">
              Universal Symbol Intelligence
            </div>
            <h2 className="font-display text-2xl sm:text-3xl font-bold tracking-tight text-slate-50">
              Attach to Any Chart. Zero Manual Configuration Files.
            </h2>
            <p className="text-sm sm:text-base text-slate-400 leading-relaxed">
              On initialization, the symbol profiler inspects point size, tick value, stops levels, fill policies,
              240-bar breakout follow-through, mean-reversion tendency, stop-hunt sweep depth, and 24-hour liquidity
              curves directly from the terminal—eliminating manual preset maintenance.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5">
            {ASSET_PROFILES.map((item) => (
              <div
                key={item.code}
                className="border border-slate-800 bg-[#0F172A] p-6 flex flex-col justify-between transition-colors hover:border-slate-700"
              >
                <div>
                  <div className="flex items-center justify-between mb-4">
                    <span className="border border-slate-700 bg-slate-950 px-2.5 py-1 font-mono text-xs font-semibold text-sky-400">
                      {item.code}
                    </span>
                    <Compass className="h-4 w-4 text-slate-500" />
                  </div>
                  <h3 className="font-display text-base font-semibold text-slate-100 mb-2">{item.name}</h3>
                  <p className="text-sm text-slate-400 leading-relaxed">{item.detail}</p>
                </div>
                <div className="mt-6 pt-4 border-t border-slate-800/80 flex items-center gap-2 font-mono text-xs text-emerald-400">
                  <Check className="h-3.5 w-3.5" />
                  <span>Auto-Adapted at OnInit</span>
                </div>
              </div>
            ))}
          </div>
        </div>
      </section>

      {/* 3. TEN REGIME-GATED STRATEGIES */}
      <section id="strategies" className="border-b border-slate-800/90 py-16 lg:py-20 bg-[#0D1426]">
        <div className="mx-auto max-w-7xl px-6">
          <div className="flex flex-col md:flex-row md:items-end justify-between gap-6 mb-12">
            <div className="max-w-2xl space-y-3">
              <div className="border-l-2 border-emerald-400 pl-3 font-mono text-xs uppercase tracking-widest text-emerald-400">
                10 Independent Strategy Engines
              </div>
              <h2 className="font-display text-2xl sm:text-3xl font-bold tracking-tight text-slate-50">
                Only Eligible Strategies Trade Current Structure.
              </h2>
            </div>
            <p className="text-sm text-slate-400 max-w-md">
              Each setup requires regime suitability, structural confirmation, candle close conviction, and higher-timeframe
              alignment before entering the consensus scorer.
            </p>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
            {STRATEGIES.map((s) => (
              <div
                key={s.id}
                className="border border-slate-800 bg-[#0F172A] p-6 transition-colors hover:border-slate-700"
              >
                <div className="flex items-center justify-between border-b border-slate-800 pb-3 mb-4">
                  <span className="font-mono text-xs font-semibold text-sky-400">{s.id}</span>
                  <span className="font-mono text-[11px] uppercase tracking-wider text-slate-400">{s.regimes}</span>
                </div>
                <h3 className="font-display text-lg font-semibold text-slate-100 mb-2">{s.name}</h3>
                <p className="text-sm text-slate-400 leading-relaxed">{s.detail}</p>
              </div>
            ))}

            {/* Architectural Bento Card balancing the 3-column strategy grid */}
            <div className="border border-sky-500/30 bg-[#0B172A] p-6 md:col-span-2 flex flex-col justify-between">
              <div>
                <div className="flex items-center justify-between border-b border-slate-800 pb-3 mb-4">
                  <span className="font-mono text-xs font-semibold text-emerald-400">SELECTIVE BENCHING</span>
                  <Layers className="h-4 w-4 text-sky-400" />
                </div>
                <h3 className="font-display text-lg font-semibold text-slate-100 mb-2">
                  Real-Time Strategy &amp; Regime Expectancy Filter
                </h3>
                <p className="text-sm text-slate-300 leading-relaxed max-w-2xl">
                  The strategy selector tracks live profit factor, negative expected value, and per-regime win-rates,
                  automatically benching underperforming strategies or unfavorable regime buckets until market behavior recovers.
                </p>
              </div>
              <div className="mt-6 flex flex-wrap gap-6 pt-4 border-t border-slate-800/80 font-mono text-xs text-slate-300">
                <span>PF Floor Auto-Benching</span>
                <span className="text-slate-600">·</span>
                <span>HTF + ITF + LTF Weighted Consensus</span>
                <span className="text-slate-600">·</span>
                <span>Round-Turn Commission Included</span>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* 4. EXECUTION, SCORING & RISK ARCHITECTURE */}
      <section id="execution-risk" className="border-b border-slate-800/90 py-16 lg:py-20">
        <div className="mx-auto max-w-7xl px-6">
          <div className="max-w-2xl space-y-3 mb-12">
            <div className="border-l-2 border-sky-400 pl-3 font-mono text-xs uppercase tracking-widest text-sky-400">
              Capital &amp; Execution Discipline
            </div>
            <h2 className="font-display text-2xl sm:text-3xl font-bold tracking-tight text-slate-50">
              Built to Protect Equity Before Seeking Yield.
            </h2>
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
            {EXECUTION_PILLARS.map((pillar) => {
              const Icon = pillar.icon;
              return (
                <div key={pillar.title} className="border border-slate-800 bg-[#0F172A] p-7 space-y-4">
                  <div className="inline-flex h-10 w-10 items-center justify-center border border-slate-700 bg-slate-950 text-sky-400">
                    <Icon className="h-5 w-5" />
                  </div>
                  <h3 className="font-display text-lg font-semibold text-slate-100">{pillar.title}</h3>
                  <p className="text-sm text-slate-400 leading-relaxed">{pillar.detail}</p>
                </div>
              );
            })}
          </div>
        </div>
      </section>

      {/* 5. INSTALLATION & CSV ANALYTICS WORKFLOW */}
      <section className="py-16 lg:py-20 bg-[#0D1426]">
        <div className="mx-auto max-w-7xl px-6">
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-10 items-start">
            <div className="lg:col-span-5 space-y-4">
              <div className="border-l-2 border-emerald-400 pl-3 font-mono text-xs uppercase tracking-widest text-emerald-400">
                Deployment Workflow
              </div>
              <h2 className="font-display text-2xl sm:text-3xl font-bold tracking-tight text-slate-50">
                From Archive Download to Live Chart in Three Steps.
              </h2>
              <p className="text-sm text-slate-400 leading-relaxed">
                After running live sessions or Strategy Tester backtests in MetaTrader 5, inspect your trade history,
                signal rejections, and drawdown curve inside the built-in browser CSV Performance Terminal.
              </p>
              <div className="pt-2 flex flex-wrap gap-3">
                <a
                  href="/api/project/download-zip"
                  download="AdvancedScalpingEA_MT5.zip"
                  className="inline-flex items-center gap-2 bg-sky-500 px-4 py-2.5 text-xs font-semibold text-slate-950 hover:bg-sky-400 transition-colors"
                >
                  <Download className="h-3.5 w-3.5" />
                  <span>Download ZIP Archive</span>
                </a>
                <button
                  type="button"
                  onClick={onOpenTerminal}
                  className="inline-flex items-center gap-2 border border-slate-700 bg-slate-900 px-4 py-2.5 text-xs font-medium text-slate-200 hover:border-slate-500 hover:text-white transition-colors"
                >
                  <BarChart3 className="h-3.5 w-3.5 text-sky-400" />
                  <span>Launch CSV Analytics</span>
                </button>
              </div>
            </div>

            <div className="lg:col-span-7 grid grid-cols-1 sm:grid-cols-3 gap-4">
              {INSTALL_STEPS.map((st) => (
                <div key={st.step} className="border border-slate-800 bg-[#0F172A] p-5 space-y-3">
                  <div className="flex items-center justify-between">
                    <span className="font-mono text-xs font-semibold text-sky-400">{st.step}</span>
                    <Activity className="h-3.5 w-3.5 text-slate-600" />
                  </div>
                  <h3 className="font-display text-sm font-semibold text-slate-100">{st.title}</h3>
                  <p className="text-xs text-slate-400 leading-relaxed">{st.detail}</p>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>

      {/* FOOTER */}
      <footer className="border-t border-slate-800 bg-[#0B1120] py-8">
        <div className="mx-auto max-w-7xl px-6 flex flex-col sm:flex-row items-center justify-between gap-4 text-xs text-slate-500">
          <div className="flex items-center gap-3">
            <span className="font-display font-semibold text-slate-200">AdvancedScalpingEA</span>
            <span>·</span>
            <span className="font-mono">MQL5 Native v3.1.0</span>
          </div>
          <div className="flex items-center gap-6">
            <button
              type="button"
              onClick={onOpenTerminal}
              className="text-slate-400 hover:text-sky-400 transition-colors"
            >
              CSV Performance Terminal
            </button>
            <a
              href="/api/project/download-zip"
              download="AdvancedScalpingEA_MT5.zip"
              className="text-slate-400 hover:text-sky-400 transition-colors"
            >
              Download MQL5 ZIP
            </a>
          </div>
        </div>
      </footer>
    </div>
  );
}
