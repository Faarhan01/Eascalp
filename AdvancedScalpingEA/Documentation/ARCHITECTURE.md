# AdvancedScalpingEA v3.1.0 — System Architecture

## 1. Design Philosophy & Isolation Guarantees
AdvancedScalpingEA v3.1.0 is engineered as a modular, symbol-aware, positive-expectancy MetaTrader 5 quantitative multi-market scalping Expert Advisor across **43 native MQL5 source files** (`1` main EA + `42` include modules) requiring **zero external `.set` preset files**. Its core architectural guarantees are:

1. **Ready-to-Trade Execution Across Live, Demo & Strategy Tester**: `InpOperatingMode` defaults to `EA_MODE_LIVE_TRADING`, `InpAllowLiveTrading = true`, and `InpConfirmLiveRiskAcknowledgement = true`. `TradeValidation.mqh` enforces `TERMINAL_TRADE_ALLOWED` in live/demo accounts while evaluating `MQL_TRADE_ALLOWED` in Strategy Tester (`MQL_TESTER`).
2. **Zero-Preset Universal Symbol DNA & 24-Hour Empirical Liquidity Profiler (`SymbolIntelligence.mqh`, `SymbolContext.mqh`)**:
   - Automatically classifies Forex Majors, Minors/Crosses, Exotics (stripping broker prefixes/suffixes), Metals, Energies, Stock Indices, Equities (`ASSET_EQUITY`), Crypto CFDs (`ASSET_CRYPTO`), Step Index (`ASSET_SYNTHETIC` with empirical quantized step detection), and Volatility/Crash-Boom/Jump synthetics via symbol tokens, `SYMBOL_CURRENCY_BASE`/`PROFIT`, `SYMBOL_PATH`, `SYMBOL_SECTOR`, and `SYMBOL_TRADE_CALC_MODE`.
   - `CalibrateFromHistory()` inspects up to `240` closed bars on initialization to learn each symbol's true empirical personality (`PERSONALITY_BALANCED`, `PERSONALITY_TRENDING`, `PERSONALITY_MEAN_REVERTING`, `PERSONALITY_BREAKOUT_SWEEP`), breakout follow-through rate, mean-reversion rate, stop-hunt sweep wick overshoot depth (`avgSweepWickAtr`), spike bar ratio, and 24-hour empirical activity ratios (`IsQuietDeadHour(serverHour)` with zero hardcoded broker timezone offsets).
   - Auto-scales Stop-Loss cushion, Take-Profit extension, minimum signal scores, and strategy affinities (`trendAffinity`, `meanRevAffinity`, `sweepAffinity`) for any symbol attached.
3. **Graph Extremum, Value-Zone & H1 Swing Clearance (`MarketStructure.mqh`, `IndicatorEngine.mqh`, `StrategyBase.mqh`, `SignalScoring.mqh`)**:
   - Prunes invalidated broken pivots and computes major swing range (`swingHigh`, `swingLow`, `swingEquilibrium`, `swingRangePos01`), `isDiscountZone` (`<= 0.38`) / `isPremiumZone` (`>= 0.62`), cached 48-bar H1 higher-timeframe swing walls (`htfSwingHigh`, `htfSwingLow`), Session VWAP statistical Z-Score (`vwapZScore`), rising ADX confirmation (`adxRising`), and Donchian extremity (`donchianPos01`).
   - Enforces `HasClearRoomToTarget()` across all 10 strategies so entries never fire straight into multi-touch S/R, PDH/PDL, or H1 swing barriers, and snaps Take-Profit targets cleanly inside major structural walls (`InpSnapTpBeforeMajorWalls = true`).
4. **Live Pullback / Extremum Entry Sniper (`EAController.mqh`, `StrategyBase.mqh`, `AdvancedScalpingEA.mq5`)**:
   - Rather than chasing extended momentum bars at poor prices, extended trend, momentum, breakout, and expansion setups compute an `optimalEntryPrice` via `ComputeOptimalPullbackTrigger()` and arm `SArmedEntrySniper` (`InpEnableExtremumEntrySniper = true`, `InpExtremumSniperWaitBars = 2`, `InpExtremumPullbackMinAtr = 0.20`).
   - While armed, the controller monitors live ticks for up to `2` bars (while guarding SL invalidation and runaway bounds) to fill on the pullback extremum and immediately improve effective R:R.
5. **Strict Negative-EV Strategy/Regime Benching & Non-Clipping Exits**:
   - Retains the positive-expectancy asymmetric geometry (`1.65 ATR` SL, `3.20 ATR` TP, `>= 1.55R` floor, `>= 2.60x` TP-to-cost, `64.0` min score), delayed Break-Even (`1.65 ATR` / `>= 1.05R`), wide Chandelier/structure trailing (`2.40 ATR` start), and real-time personality-weighted `CStrategySelection` benching.
6. **Strict Read-Only Dashboard & Non-Visual Tester Acceleration**: `CDashboardManager` displays live `Symbol DNA`, `Swing / Zone` (`VWAP Z-Score`), and `Entry Sniper` telemetry strictly read-only across 6 tabs and 5 chart modes, bypassing chart rendering in non-visual Strategy Tester runs (`MQL_TESTER && !MQL_VISUAL_MODE`).

## 2. Module Dependency Layers (v3.1.0 — 43 Files)
- **Experts (`1`)**: `AdvancedScalpingEA.mq5` (`v3.10`, validated inputs across 18 groups including Entry Sniper and Adaptive Dead-Hour Liquidity filters).
- **Core (`5`)**: `Types.mqh`, `Diagnostics.mqh`, `StateManager.mqh`, `SymbolContext.mqh`, `EAController.mqh` (orchestrates multi-symbol conviction queue, live `SArmedEntrySniper`, cooldowns, frequency caps, and shutdown analytics).
- **Market (`6`)**: `SymbolIntelligence.mqh`, `MarketData.mqh`, `TickAnalysis.mqh`, `MarketStructure.mqh`, `MarketRegime.mqh`, `MultiTimeframe.mqh`.
- **Indicators (`3`)**: `IndicatorEngine.mqh`, `CandlestickRecognition.mqh`, `PatternRecognition.mqh`.
- **Strategies (`11`)**: `StrategyBase.mqh` (`HasClearRoomToTarget`, HTF swing TP snapping, `ComputeOptimalPullbackTrigger`) + all 10 value-zone & extremum-aware strategy modules (`TrendPullback`, `MomentumScalping`, `BreakoutScalping`, `ReversalScalping`, `RangeScalping`, `VolatilityExpansion`, `MicroMomentum`, `LiquiditySweepScalping`, `VwapMeanReversion`, `EmaRibbonContinuation`).
- **Trading (`6`)**: `ExpectancyEngine.mqh`, `SignalScoring.mqh`, `TradeValidation.mqh`, `RiskManagement.mqh`, `TradeExecution.mqh`, `PositionManagement.mqh`.
- **Intelligence (`3`)**: `StrategySelection.mqh`, `AdaptiveLearning.mqh`, `HistoricalResearch.mqh`.
- **Analytics (`3`)**: `Statistics.mqh`, `PerformanceAnalytics.mqh`, `CSVLogger.mqh`.
- **Dashboard (`5`)**: `DashboardComponents.mqh`, `DashboardLayout.mqh`, `DashboardCharts.mqh`, `DashboardStatistics.mqh`, `DashboardManager.mqh`.
