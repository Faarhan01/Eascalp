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
      'Measures real swing retracement depth into fast/medium EMA structure with momentum recovery, candle close conviction, and VWAP alignment.',
  },
  {
    id: '02',
    name: 'Momentum Scalping',
    regimes: 'Trend & Vol Expansion',
    detail:
      'Captures ADX-confirmed directional expansion only when ROC and ATR displacement align without overextension beyond 1.85x ATR.',
  },
  {
    id: '03',
    name: 'Breakout Scalping',
    regimes: 'Consolidation & Early Trend',
    detail:
      'Validates structural BOS, Donchian breaks, and retests with full candle body conviction while blocking entries straight into multi-touch S/R walls.',
  },
  {
    id: '04',
    name: 'Reversal Scalping',
    regimes: 'Exhaustion & Reversal Regimes',
    detail:
      'Strict whitelist of authentic reversal candles paired with divergence, CHoCH, or liquidity sweeps plus runaway-ADX protection.',
  },
  {
    id: '05',
    name: 'Range Scalping',
    regimes: 'Sideways & Wide Ranges',
    detail:
      'Operates exclusively under low ADX and low efficiency ratio with weighted multi-timeframe conflict locks and positive boundary headroom.',
  },
  {
    id: '06',
    name: 'Volatility Expansion',
    regimes: 'Squeeze-to-Expansion Breaks',
    detail:
      'Triggers out of Bollinger compression on expanding ATR impulse bars with tick velocity confirmation and strict close-near-extreme checks.',
  },
  {
    id: '07',
    name: 'Micro-Momentum',
    regimes: 'High-Velocity Tick Bursts',
    detail:
      'Inspects spread-cost-validated tick bursts with MACD, RSI room-to-run, and full EMA alignment across fast execution windows.',
  },
  {
    id: '08',
    name: 'Liquidity Sweep',
    regimes: 'Stop-Hunt & Reversal Regimes',
    detail:
      'Detects stop-hunt wicks beneath swing support or above swing resistance pools that snap closed inside structure with rejection momentum.',
  },
  {
    id: '09',
    name: 'VWAP Reversion',
    regimes: 'Ranges & Overstretched Pullbacks',
    detail:
      'Fades statistical price extremes beyond outer Bollinger bands and Session VWAP deviation back toward institutional fair value.',
  },
  {
    id: '10',
    name: 'EMA Ribbon Cont.',
    regimes: 'Established & Strong Trends',
    detail:
      'Enters high-conviction continuation thrusts when EMA 9/21/55/SMA200 fan in hierarchy after compression pauses with strong HTF alignment.',
  },
];

const EXECUTION_PILLARS = [
  {
    icon: Sliders,
    title: 'Structural TP Snap & 0–100 Scoring',
    detail:
      'Evaluates structure, institutional PDH/PDL levels, RVOL, VWAP, and snaps TP cleanly before multi-touch S/R walls with recency-adaptive expectancy.',
  },
  {
    icon: ShieldCheck,
    title: 'Vol-Adjusted Sizing & Giveback Guard',
    detail:
      'Scales fixed-fractional lots by score, volatility spikes, and loss streaks alongside intraday peak-profit giveback protection and transient-safe execution.',
  },
  {
    icon: Lock,
    title: '>=1.0R BE & Hold-Aware Trail',
    detail:
      'Partial closes arm cost-covered BE immediately while structure-swing and Chandelier trailing progressively tighten past 70% of max holding time.',
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
              MetaTrader 5 Native MQL5 Engine · v2.9.0
            </div>

            <h1 className="font-display text-4xl sm:text-5xl font-bold tracking-tight text-slate-50 leading-[1.08]">
              Precision Multi-Asset Scalping Without Preset Files.
            </h1>

            <p className="text-base sm:text-lg text-slate-300 leading-relaxed max-w-xl">
              AdvancedScalpingEA profiles contract specs and historical market DNA across Forex, Step Index,
              Synthetics, Metals, Indices, Equities, and Crypto—routing every bar through 10 regime-gated strategies.
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
                  <p className="font-mono text-[11px] uppercase tracking-wider text-slate-400">Default Mode</p>
                  <p className="font-mono text-xs font-medium text-emerald-400 mt-0.5">Live &amp; Tester Ready</p>
                </div>
                <div className="px-4 py-3">
                  <p className="font-mono text-[11px] uppercase tracking-wider text-slate-400">Risk Model</p>
                  <p className="font-mono text-xs font-medium text-slate-100 mt-0.5">Fixed-Fractional</p>
                </div>
                <div className="px-4 py-3">
                  <p className="font-mono text-[11px] uppercase tracking-wider text-slate-400">BE Floor</p>
                  <p className="font-mono text-xs font-medium text-slate-100 mt-0.5">Strict &gt;= 1.0R</p>
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
              On initialization, the symbol profiler reads point size, tick value, broker stops levels, fill policies,
              ATR baseline, and 24/7 synthetic behavior directly from the terminal—eliminating brittle preset maintenance.
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
            <span className="font-mono">MQL5 Native v2.9.0</span>
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
