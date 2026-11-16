# Development Report — AdvancedScalpingEA v2.2.0

## 1. Major v2.2.0 Upgrades Summary
1. **100% Authentic Execution & Analytics (Zero Simulated Fills or Fabricated Data)**:
   - Removed simulated paper-trade fill branch (`EA_MODE_DEMO_PAPER`, `isPaperTrade`, `m_paperTicketSeq`, and `PAPER_FILLED`) across `Types.mqh`, `TradeExecution.mqh`, and `EAController.mqh`. Every signal executes either via authentic broker/Strategy Tester order routing (`EA_MODE_DEMO_EXECUTION` / `EA_MODE_LIVE_TRADING`) or is logged strictly as research observation (`EA_MODE_RESEARCH_ONLY`).
   - Removed the hardcoded `65.0` fallback score in `PerformanceAnalytics::ParseScore()` (`-1.0` sentinel when un-tagged so unknown historical trades never distort `HistoricalResearch` / `PerformanceAnalytics` score-band curves).
2. **Universal Multi-Symbol Auto-Recognition (`SymbolIntelligence.mqh`, `TickAnalysis.mqh`, `MarketRegime.mqh`, `TradeValidation.mqh`, `TradeExecution.mqh`)**:
   - Upgraded `SymbolIntelligence::ClassifySymbol()` and `ExtractCoreName()` using expanded Forex/Metal/Energy/Index/Crypto/Synthetic tokens, broker tier prefix stripping (`#`, `$`, `@`, `pro_`, `ecn_`, `raw_`), and native MT5 `SYMBOL_SECTOR` / `SYMBOL_TRADE_CALC_MODE`.
   - Replaced raw-point spread, velocity, and instability floors across `SymbolIntelligence`, `TickAnalysis`, `MarketRegime`, and `MicroMomentum` with `pipSize / point`-normalized thresholds and ATR-scaled caps so 0-digit through 5-digit instruments size and filter accurately.
   - Anchored `NormalizeVolume()` to `volumeMin`, prioritized direction-aware `OrderCalcProfit()` across risk/expectancy calculations (`RiskManagement`, `ExpectancyEngine`, `PositionManagement`), tracked rolling real measured fill slippage per symbol (`RecordMeasuredSlippage()`), and enforced `preferredFilling` + dynamic slippage + `freezeLevelPoints` guards in `ClosePosition()` / `ModifyPositionStops()`.
3. **Signal Precision, Consensus & Entry Quality (`StrategyBase.mqh`, All 7 Strategies, `SignalScoring.mqh`, `EAController.mqh`)**:
   - Added structural stop-loss anchoring (`ComputeStructuralSLDist()`) and min-stop + freeze-level TP validation across all 7 strategies, plus multi-touch opposing S/R clearance and session VWAP scoring inside `SignalScoring`.
   - Applied `ApplyMultiStrategyConsensus()`, opposing-signal chop rejection (`OPPOSING_SIGNAL_CONFLICT`), per-symbol post-loss cooldown (`InpLossCooldownBars = 2`), lazy `SERIES_SYNCHRONIZED` multi-symbol history verification, and live-quote anti-chase & SL invalidation guards (`LIVE_PRICE_EXTENDED`, `LIVE_PRICE_PAST_SL`).
4. **Drawdown Containment, Cost-Covering 1R Break-Even & Progressive Chandelier Trailing (`RiskManagement.mqh`, `PositionManagement.mqh`)**:
   - Added smooth anti-Martingale equity drawdown (`0.75x`/`0.55x`/`0.35x`) and losing-streak (`0.75x`/`0.55x`/`0.40x`) lot scaling plus margin-safe proportional clamping (72% free-margin budget) before order submission.
   - Upgraded `PositionManagement.mqh` with closed-ticket track pruning (`PruneClosedTracks()`), restart-safe partial-close & un-splittable min-lot protection, cost-covering + 1R risk-based Break-Even (`MathMin(ATR trigger, 1.02*initSL)`), progressive tiered Chandelier trailing (`InpUseChandelierTrail`, `InpUseProgressiveTrail`), momentum-confirmed CHoCH exits, and optional Friday pre-weekend close protection (`InpCloseBeforeWeekend`).

## 2. Environment & Compilation Verification Scope
- All MQL5 modules, `.set` presets, and documentation files were statically audited for balanced scopes, clean `#include` graphs, include guards, zero `ZeroMemory()` calls on string/dynamic-array structs, zero `%.*f` specifiers, zero simulated/mocked execution paths, and strict read-only dashboard isolation.
- **Important Limitation**: MetaEditor 5 (`metaeditor64.exe`) and MetaTrader 5 terminal are Windows binaries not installed in this Linux cloud container. Compile `AdvancedScalpingEA/Experts/AdvancedScalpingEA.mq5` in local MetaEditor 5 and run real-tick Strategy Tester validation following `TESTING_AND_VALIDATION.md`.

## 3. Operational Notes
1. **Intra-Portfolio Multi-Symbol Tick Timing**: In MT5 Strategy Tester, `OnTick()` fires for the primary chart symbol; secondary symbols in `InpMultiSymbolList` update synchronously on each primary tick via `SymbolInfoTick()` / `CopyRates()`, depending on broker history availability.
2. **Commission Detection**: `SymbolIntelligence.mqh` inspects real `DEAL_COMMISSION` history per symbol and honors `InpFallbackCommissionPerLot` (default `0.0`) prior to closed history.
3. **Controlled Non-Mutating Adaptation**: `AdaptiveLearning.mqh` generates Stage 2–3 findings and recommendations without mutating live risk caps; operators promote validated presets through Stage 4–5 after OOS verification.

