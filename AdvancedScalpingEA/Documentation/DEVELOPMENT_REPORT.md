# Development Report — AdvancedScalpingEA v3.1.0

## 1. v3.1.0 Universal Symbol Intelligence, Graph Extremum Filtering & Entry Sniper Upgrade
Following the positive-expectancy overhaul in v3.0.0, v3.1.0 addresses two deeper alpha bottlenecks—blindness to symbol-specific empirical behavior and entering extended candles instead of waiting for graph extremes / pullbacks:

1. **Empirical Symbol DNA & Adaptive 24-Hour Liquidity Profiling (`Types.mqh`, `SymbolIntelligence.mqh`, `SymbolContext.mqh`, `TradeValidation.mqh`)**:
   - Added `ENUM_SYMBOL_PERSONALITY` (`BALANCED`, `TRENDING`, `MEAN_REVERTING`, `BREAKOUT_SWEEP`) computed empirically over up to `240` historical bars via breakout follow-through rate, mean-reversion rate, efficiency ratio, and stop-hunt sweep wick overshoot (`avgSweepWickAtr`).
   - Built a 24-hour empirical server-hour liquidity histogram (`hourlyActivityRatio[24]`, `hourlySampleCount[24]`) so `CTradeValidation` automatically skips dead-liquidity hours (`DEAD_LIQUIDITY_HOUR` when `InpEnableAdaptiveDeadHourFilter = true`) without brittle hardcoded broker timezone offsets.
   - Added empirical sweep-depth SL padding and adaptive personality affinities (`trendAffinity`, `meanRevAffinity`, `sweepAffinity`) wired into `CStrategySelection` (`ComputePersonalityFit`) and `CSignalScoring`.

2. **Full Graph Structure, Discount/Premium Zones & H1 Wall Clearance (`MarketStructure.mqh`, `IndicatorEngine.mqh`, `CandlestickRecognition.mqh`, `PatternRecognition.mqh`, `StrategyBase.mqh`)**:
   - Upgraded `CMarketStructure` to prune invalidated broken pivots, track major swing boundaries (`swingHigh`, `swingLow`, `swingEquilibrium`, `swingRangePos01`, `isDiscountZone`, `isPremiumZone`), and cache 48-bar H1 swing extremes (`htfSwingHigh`, `htfSwingLow`).
   - Added statistical Session VWAP Z-Score (`vwapZScore`), rising ADX detection (`adxRising`), Donchian extremity (`donchianPos01`), ATR-floored candlestick filters (`relSizeAtr >= 0.45`), and pattern recency/invalidation checks (`<= 20` bars).
   - Implemented `HasClearRoomToTarget()` in `StrategyBase.mqh` and wired value-zone/extremum gates + H1/S/R wall clearance across all 10 strategy engines (`TrendPullback`, `EmaRibbonContinuation`, `MomentumScalping`, `BreakoutScalping`, `ReversalScalping`, `RangeScalping`, `VolatilityExpansion`, `MicroMomentum`, `LiquiditySweepScalping`, `VwapMeanReversion`).

3. **Live Pullback / Extremum Entry Sniper (`EAController.mqh`, `AdvancedScalpingEA.mq5`, `DashboardManager.mqh`)**:
   - Added `ComputeOptimalPullbackTrigger()` in `StrategyBase.mqh` and `SArmedEntrySniper` in `CEAController` (`InpEnableExtremumEntrySniper = true`, `InpExtremumSniperWaitBars = 2`, `InpExtremumPullbackMinAtr = 0.20`).
   - Extended momentum/trend/breakout setups automatically arm the tick-level sniper to wait up to `2` bars for a pullback retracement (`optimalEntryPrice`) instead of market-chasing extended closes, disarming safely on SL breach, runaway drift, expiry, cooldown, or strong opposite signals.
   - Added read-only `Symbol DNA`, `Swing / Zone` (`VWAP Z-Score`), and `Entry Sniper` diagnostics to `CDashboardManager`.

## 2. Prior Milestone Foundation Preserved (v2.8.0 – v3.0.0)
- **v3.0.0 Positive-Expectancy Execution**: `1.65x ATR` SL / `3.20x ATR` TP geometry, `>= 1.55R` floor, `>= 2.60x` TP-to-cost edge, non-clipping `>= 1.05R` BE & `2.40 ATR` trailing, unbiased `1.0` cold-start PF prior, negative-EV benching, and pullback-resilient MTF bias.
- **v2.8.0 – v2.9.0 Engineering Core**: Idle-tick fast path, $O(1)$-amortized `PerformanceAnalytics` incremental deal ledger, Netting-safe multi-fill commission handling, startup history calibration, and zero-preset universal symbol initialization.

## 3. Verification Scope
- All `43` MQL5 files (`42` `.mqh` + `1` `.mq5`), include dependencies, brace/parenthesis balance, MQL5 syntax safety rules, and web bundle compilation are verified via automated static checks and Vite/TSX build tools on Linux.
- Compile `AdvancedScalpingEA/Experts/AdvancedScalpingEA.mq5` (`v3.10`) in local MetaEditor 5 on Windows and run "Every tick based on real ticks" validation in MT5 Strategy Tester per `TESTING_AND_VALIDATION.md`.
