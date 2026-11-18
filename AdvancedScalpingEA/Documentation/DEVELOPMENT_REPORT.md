# Development Report — AdvancedScalpingEA v2.9.0

## 1. v2.9.0 Full Audit: Hot-Path Performance, Zero-Copy Architecture & Code Hygiene
1. **Intra-Bar Idle-Tick Fast Path & Zero-Copy Hot-Path Getters (`EAController.mqh`, `SymbolContext.mqh`, `SymbolIntelligence.mqh`, `MarketData.mqh`, `Diagnostics.mqh`)**:
   - Eliminated full per-tick `SAnalysisContext` copies (`10` nested structs with `~30` MQL5 `string` members) on flat idle intra-bar ticks when no symbol position is open, no new bar occurred, and intra-bar micro evaluation is inactive (`m_risk.Update` maintains a 1 Hz flat heartbeat).
   - Added lightweight scalar const getters across `SymbolIntelligence`, `MarketData`, `MarketRegime`, and `SymbolContext` (`GetPoint()`, `GetPipSize()`, `IsDataReady()`, `GetBarTime()`, `GetTickTime()`, `IsUnstable()`, `IsTickSurge()`) so intra-bar checks and indicator/candle/pattern modules short-circuit without copying snapshot structs containing strings.
   - Added `m_lastFullSyncBar`, `m_profileDirty`, and `m_lastUnstableSynced` inside `SymbolContext` so static symbol profiles, indicator payloads, market structure, candle, and chart-pattern structs are synced only when a new closed bar arrives or symbol specs refresh.
   - Added `IsLevelEnabled()` log-level gating before hot-path `StringFormat(...)` arguments and fixed `Diagnostics::ShouldThrottle` at 128 keys using a rolling overwrite cursor instead of stalling once full.
2. **$O(1)$ Deal History Ledger, $O(1)$ Spread Window & Cached Analytics (`PerformanceAnalytics.mqh`, `MarketData.mqh`, `TickAnalysis.mqh`, `HistoricalResearch.mqh`, `PositionManagement.mqh`, `CSVLogger.mqh`)**:
   - Replaced the $O(N^2)$ full history deal scan and per-close reverse `DEAL_ENTRY_IN` loop in `PerformanceAnalytics::SyncDealHistory()` with an $O(1)$-amortized incremental cursor (`m_lastScannedDealIdx`) paired with an active open-entry ledger (`SPosEntryAccum`), retaining reverse scanning only as a partial-history fallback.
   - Replaced the $O(N)$ `MarketData::ComputeAverageSpread()` loop with an $O(1)$ running `m_spreadSum` accumulator (periodically resynced every 4096 samples for zero floating-point drift), and added `tickTimeMsc` directly inside `SMarketSnapshot` so `TickAnalysis` eliminates duplicate per-tick `SymbolInfoTick()` calls.
   - Pre-allocated `TickAnalysis` `m_deltas[]` at `Initialize()`, replaced dynamic `deltas[]` resize in `SymbolIntelligence::CalibrateFromHistory()` with fixed stack storage `double deltas[48]`, memoized `HistoricalResearch::RunMonteCarloDrawdown95()` per `(m_tradeCount, iters)` with pre-allocated scratch buffers, and added early `if(!m_enabled) return;` guards across all 12 `CSVLogger::Log*()` writers.
   - Optimized `MultiTimeframe::Evaluate()` with an intra-bar LTF/ITF/HTF + `structureBias` fast-path cache and avoided array/struct churn in `PositionManagement::RefreshOwnedPositions()` / `ManageSymbolPositions()` when no EA positions exist on that symbol.
3. **Prior v2.8.0 Foundation Preserved (`Netting Safety`, `Universal Calibration`, `Risk & Scoring`)**:
1. **MT5 Netting & Multi-Fill Accounting Fixes (`PerformanceAnalytics.mqh`, `EAController.mqh`)**:
   - Fixed `PerformanceAnalytics::SyncDealHistory()` where MT5 Netting partial/scaled entries stopped scanning on the first `DEAL_ENTRY_IN` match, undercounting entry commissions and miscomputing hold duration. The loop now aggregates all `DEAL_ENTRY_IN` deals belonging to `posId`, uses the earliest open timestamp, and apportions entry commission/fee against total open volume.
   - Added `PYRAMID_NETTING_BLOCKED` inside `EAController::ProcessTick()` when `!ctx.symbolProfile.isHedgingAccount` so same-direction add-ons on Netting accounts never shift weighted-average entry price across an already armed Break-Even stop.
2. **Consensus-Before-Conflict Signal Resolution (`EAController.mqh`)**:
   - Fixed ordering where `chopConflict` compared raw `bestBuyScore` vs `bestSellScore` before `ApplyMultiStrategyConsensus()` ran. Multi-strategy agreement bonuses and weak-opposite penalties now apply first; `OPPOSING_SIGNAL_CONFLICT` triggers only when post-consensus BUY and SELL clusters remain genuinely tied (`buyCount == sellCount` within `5.0` points).
   - Replaced bare mid-loop `continue` inside `sameBarRej` suppression with explicit `allowCandidate` scoping so symbol risk/state progression remains linear and deterministic.
3. **Universal Symbol Calibration at Startup & Strategy Refinements (`SymbolContext.mqh`, `MomentumScalping.mqh`, `LiquiditySweepScalping.mqh`)**:
   - `SymbolContext::Initialize()` now executes an initial `CalibrateFromHistory()` pass whenever `>= 20` closed bars are already cached in MT5, ensuring `StepIndex=YES` empirical quantized-step detection, wick ratios, and regime thresholds are active prior to the first live tick.
   - `MomentumScalping.mqh` now enforces a volatility-proportional ROC floor `MathMax(m_minRocAbs, atrPct * 0.40)` so high-volatility Crypto, Index, and Gold feeds require genuine ATR-relative velocity rather than a static FX-scale percent floor.
   - `LiquiditySweepScalping.mqh` tightens snapback rejection close validation to require same-side bar polarity or a `>= 72%` wick snapback close.
4. **Live Monte Carlo DD95 & Segmented Performance Wiring (`PerformanceAnalytics.mqh`, `AdaptiveLearning.mqh`, `EAController.mqh`, `Types.mqh`)**:
   - Exposed `PerformanceAnalytics::GetSegmentedSummary()` over `m_bySession` and `m_bySymbol` buckets and wired both `HistoricalResearch::RunMonteCarloDrawdown95(150, ...)` and segmented summaries into Stage 2 Adaptive Learning updates and `EAController::Shutdown()` `AnalyticsReport` journal logs.
   - Added centralized `SafeCurrentTime()` in `Types.mqh` across all timestamping and logging subsystems (`Diagnostics`, `StateManager`, `CSVLogger`, `SymbolIntelligence`, `TickAnalysis`, `PositionManagement`, `RiskManagement`, `TradeExecution`, `HistoricalResearch`, `AdaptiveLearning`, `PerformanceAnalytics`, `EAController`) to prevent `1970.01.01` epochs on disconnected terminals.
   - Unified all 43 MQL5 file banners (`v2.8.0`), standardized `__ASEA_<DIR>_<FILE>_MQH__` include guards across Dashboard modules, synchronized `AdvancedScalpingEA.mq5` (`#property version "2.80"`), documentation, and `LandingPageView.tsx` (`v2.8.0`).

## 2. Prior Milestone Foundation Preserved (v2.3.0 – v2.7.0)
- Zero `.set` preset files required (`InpAutoAdaptBySymbol = true`, `EA_MODE_LIVE_TRADING`, ready-to-trade defaults).
- Structural TP wall-snapping ahead of multi-touch S/R & PDH/PDL barriers (`InpSnapTpBeforeMajorWalls = true`).
- Tick-seeded spread baselines, spike-bar auto-calibration, recency-adaptive expectancy weighting, and transient-resilient close retries.
- Clean dynamic arrays + `ArraySetAsSeries(..., true)` in `MultiTimeframe.mqh` with zero MetaEditor static-array warnings.

## 3. Environment & Compilation Scope
- All `43` MQL5 files (`42` `.mqh` + `1` `.mq5`), `143` inputs, include guards, brace/parenthesis balance, `ArraySetAsSeries` safety, and string format specifiers were verified via automated static audits on Linux.
- Because MetaEditor 5 (`metaeditor64.exe`) and MT5 terminal binaries run natively on Windows, compile `AdvancedScalpingEA/Experts/AdvancedScalpingEA.mq5` in local MetaEditor 5 and run real-tick Strategy Tester validation following `TESTING_AND_VALIDATION.md`.
