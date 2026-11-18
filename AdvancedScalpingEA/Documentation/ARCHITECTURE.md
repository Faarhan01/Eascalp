# AdvancedScalpingEA v2.9.0 — System Architecture

## 1. Design Philosophy & Isolation Guarantees
AdvancedScalpingEA v2.9.0 is engineered as a modular, high-throughput MetaTrader 5 quantitative multi-market scalping Expert Advisor across **43 native MQL5 source files** (`1` main EA + `42` include modules) requiring **zero external `.set` preset files**. Its core architectural guarantees are:

1. **Ready-to-Trade Execution Across Live, Demo & Strategy Tester**: `InpOperatingMode` defaults to `EA_MODE_LIVE_TRADING`, `InpAllowLiveTrading = true`, and `InpConfirmLiveRiskAcknowledgement = true`. `TradeValidation.mqh` enforces `TERMINAL_TRADE_ALLOWED` in live/demo accounts while evaluating `MQL_TRADE_ALLOWED` in Strategy Tester (`MQL_TESTER`) so backtests and live sessions execute cleanly out of the box.
2. **Zero-Preset Universal Symbol Auto-Profiler & Market DNA (`SymbolIntelligence.mqh`, `SymbolContext.mqh`)**: Automatically classifies Forex Majors, Minors/Crosses, Exotics (with prefix/suffix stripping such as `pro_EURUSD`, `EURUSDm`, `XAUUSDpro`), Metals, Energies, Stock Indices, Equities (`ASSET_EQUITY`), Crypto CFDs (`ASSET_CRYPTO`), Step Index (`ASSET_SYNTHETIC` with quantized step detection), and Volatility/Crash-Boom/Jump synthetics via symbol tokens, `SYMBOL_CURRENCY_BASE`/`PROFIT`, `SYMBOL_PATH`, `SYMBOL_SECTOR`, and `SYMBOL_TRADE_CALC_MODE`. `SymbolContext::Initialize()` immediately seeds empirical history calibration (`CalibrateFromHistory`) from cached bars and `MarketData::Initialize()` seeds spread baselines from recent terminal ticks so `StepIndex`, wick ratios, spike-bar ratios, and friction profiles are ready on tick 0.
3. **Strict Read-Only Dashboard & Non-Visual Tester Acceleration**: `CDashboardManager` accepts only `const SDashboardSnapshot`, `const SManagedPosition[]`, and analytics arrays across 6 interactive tabs (`Overview`, `Market`, `Strategies`, `Positions/Risk`, `Charts`, `Intelligence`) and 5 chart modes, skipping UI rendering completely in non-visual Strategy Tester runs (`MQL_TESTER && !MQL_VISUAL_MODE`).
4. **Zero Look-Ahead / Zero Repainting**: Indicators (`IndicatorEngine.mqh`, `MultiTimeframe.mqh` using dynamic `ArraySetAsSeries(..., true)` buffers), market structure (`MarketStructure.mqh` including PDH/PDL levels), candlestick formations (`CandlestickRecognition.mqh`), and geometric chart patterns (`PatternRecognition.mqh`) evaluate completed bars (`shift >= 1`) exclusively, with closed-bar strategy evaluation enabled by default (`InpEvaluateOnNewBarOnly = true`).
5. **Magic-Isolated, Netting-Safe & Low-Latency Tick Execution**: `CPositionManagement`, `CPerformanceAnalytics`, and `CEAController` filter `PositionsTotal()` and `HistoryDealsTotal()` strictly by `m_magic` using an $O(1)$-amortized incremental `DEAL_ENTRY_IN` ledger, an $O(1)$ running spread sum, intra-bar closed-bar caching across `SymbolContext`/`MultiTimeframe`/`MarketRegime`, zero-copy scalar getters, and an idle-tick fast path that bypasses heavy context copying when flat between bars.

## 2. Module Dependency Layers (v2.9.0 — 43 Files)
- **Experts (`1`)**: `AdvancedScalpingEA.mq5` (143 validated inputs across 18 groups, `OnInit`/`OnDeinit`/`OnTick`/`OnTimer`/`OnTradeTransaction`/`OnChartEvent`).
- **Core (`5`)**:
  - `Types.mqh`: Shared enums (18 `ENUM_MARKET_REGIME` states, 10 `ENUM_STRATEGY_ID`, 11 `ENUM_ASSET_CLASS`), `SafeCurrentTime()`, and telemetry snapshots.
  - `Diagnostics.mqh`: Cooldown-throttled file & Experts journal logging.
  - `StateManager.mqh`: Schema v2 crash/restart state persistence (`MQL5/Files/AdvancedScalpingEA/State/`).
  - `SymbolContext.mqh`: Per-symbol analysis orchestrator supporting up to `8` concurrent symbols with startup empirical calibration.
  - `EAController.mqh`: Multi-symbol priority queue, consensus-before-conflict signal resolver, hourly/daily frequency caps, post-loss cooldowns, live-price anti-chase guard, and shutdown analytics reporting.
- **Market (`6`)**: `SymbolIntelligence.mqh`, `MarketData.mqh`, `TickAnalysis.mqh`, `MarketStructure.mqh`, `MarketRegime.mqh`, `MultiTimeframe.mqh`.
- **Indicators (`3`)**: `IndicatorEngine.mqh` (EMA 9/21/55, SMA 200, RSI, MACD, ATR short/main/baseline, ADX, Bollinger, Donchian, Stoch, CCI, WPR, PSAR, ROC, RVOL, Session VWAP with 48-bar 24/7 rolling fallback, divergence & exhaustion), `CandlestickRecognition.mqh`, `PatternRecognition.mqh`.
- **Strategies (`11`)**: `StrategyBase.mqh` (with `SnapTpBeforeMajorWalls` S/R & PDH/PDL snapping) plus 10 independent strategies:
  1. `TrendPullback.mqh`
  2. `MomentumScalping.mqh` (ATR%-scaled ROC floor)
  3. `BreakoutScalping.mqh`
  4. `ReversalScalping.mqh`
  5. `RangeScalping.mqh`
  6. `VolatilityExpansion.mqh`
  7. `MicroMomentum.mqh`
  8. `LiquiditySweepScalping.mqh` (PDH/PDL + swing sweep rejection with snapback close polarity check)
  9. `VwapMeanReversion.mqh`
  10. `EmaRibbonContinuation.mqh`
- **Trading (`6`)**: `ExpectancyEngine.mqh`, `SignalScoring.mqh`, `TradeValidation.mqh`, `RiskManagement.mqh` (fractional risk, score/volatility/loss-streak scaling, intraday profit giveback guard, currency net-lot caps), `TradeExecution.mqh` (IOC/FOK/RETURN fallback + retry on transient codes), `PositionManagement.mqh` (cost-covered >= 1.0R BE, partial closes, progressive Chandelier & structure trailing, hold-time tightening).
- **Intelligence (`3`)**: `StrategySelection.mqh`, `AdaptiveLearning.mqh` (5-stage non-mutating research + MC DD95 & segmented session telemetry), `HistoricalResearch.mqh` (walk-forward OOS tagging, score bands, deterministic Monte Carlo DD95).
- **Analytics (`3`)**: `Statistics.mqh`, `PerformanceAnalytics.mqh` (Netting multi-fill `DEAL_ENTRY_IN` accounting + `GetSegmentedSummary()`), `CSVLogger.mqh` (12 buffered CSV exports).
- **Dashboard (`5`)**: `DashboardComponents.mqh`, `DashboardLayout.mqh`, `DashboardCharts.mqh`, `DashboardStatistics.mqh`, `DashboardManager.mqh`.
