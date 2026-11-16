# Development Report — AdvancedScalpingEA v2.3.0

## 1. Major v2.3.0 Profitability, Universal Symbol & Compiler Upgrades Summary
1. **Resolved Static-Array MQL5 Warnings & Fixed Inverted MTF Slope Detection (`MultiTimeframe.mqh`)**:
   - Converted `fast`, `slow`, `extra`, `plusDI`, and `minusDI` from fixed-size static arrays (`[2]`/`[1]`) to dynamic arrays paired with `ArraySetAsSeries(..., true)`. This eliminates all 3 MetaEditor 5 `"cannot be used for static allocated array"` warnings at lines 41–43 and fixes a subtle bug where non-series `CopyBuffer` indexing previously inverted rising/falling EMA slope detection.
2. **Zero-Preset Built-In Self-Tuning & Expanded Universal Symbol Support (`Types.mqh`, `SymbolIntelligence.mqh`, `SymbolContext.mqh`, `EAController.mqh`)**:
   - Eliminated external `.set` preset dependency: `SAdaptiveAssetProfile` + `SymbolIntelligence::GetAdaptiveAssetProfile()` automatically adapts SL/TP ATR multipliers, BE trigger, partial-close trigger & fraction, Chandelier trailing start/step, ADX trend thresholds, volatility/spread limits, `minSignalScore`, `minTpToCostRatio`, and `lossCooldownBars` for any attached symbol (`InpAutoAdaptBySymbol = true`).
   - Added first-class **Step Index** detection (`isStepIndex`) and Deriv/Broker Synthetic Burst detection (`isSyntheticBurst` for Crash/Boom/Volatility/Jump/1HZ/R_ indices) plus unseparated suffix stripping (`EURUSDm`, `EURUSDc`, `XAUUSDpro`, `EURUSDraw`, etc.) and `SYMBOL_CURRENCY_BASE`/`PROFIT` classification so any Forex major, cross, or exotic pair works out of the box.
   - Added a 48-bar rolling VWAP fallback in `IndicatorEngine::ComputeSessionVWAP()` when daily UTC bars `< 8` to prevent noisy resets after `00:00` on 24/7 Step Index, Synthetics, and Crypto charts.
3. **Expectancy, Win-Rate & Risk-Reward Upgrades Across All 7 Strategies & Position Management**:
   - Defaulted `InpEvaluateOnNewBarOnly = true` (closed-bar signal integrity), raised `InpMinSignalScore = 60.0`, `InpMinRewardRiskRatio = 1.30`, `InpMinTpToCostRatio = 2.20`, `InpRequireMtfNoStrongConflict = true`, `InpDefaultSlAtrMult = 1.60`, and `InpDefaultTpAtrMult = 2.80`.
   - Removed counter-HTF trend bypasses in `TrendPullback`, replaced raw `% ROC` threshold with ATR-normalized `priceDisplacementAtr >= 0.60` in `MomentumScalping` (fixing scale mismatch on indices/Step Index/JPY/exotics), tightened `BreakoutScalping`, `ReversalScalping`, `RangeScalping`, `VolatilityExpansion`, and `MicroMomentum` (eliminating `0.85x` SL shrinkage).
   - Fixed premature position cutting in `PositionManagement.mqh`: disabled `InpEnableMomentumExit = false` by default, tightened CHoCH exit to require multi-factor EMA + MACD + profit/HTF confirmation, enforced `effBeTrigger >= MathMax(effAtr * effBeTrigMult, initSlDist * 1.00)` (>= 1.0R Break-Even), delayed partial take-profit to `1.90 ATR` (`40%`), and anchored Chandelier trailing at `2.00 ATR` start / `1.00 ATR` step.
   - Added earlier statistical + per-regime benching inside `StrategySelection.mqh` so persistently losing strategies in the active regime are automatically sidelined.

## 2. Environment & Compilation Verification Scope
- All MQL5 modules (`AdvancedScalpingEA.mq5` and 39 `.mqh` headers) and documentation files were statically audited for balanced scopes, zero static-array warnings, `ArraySetAsSeries` correctness, clean `#include` graphs, include guards, zero `ZeroMemory()` calls on string/dynamic-array structs, zero `%.*f` specifiers, zero simulated/mocked execution paths, and strict read-only dashboard isolation.
- **Important Limitation**: MetaEditor 5 (`metaeditor64.exe`) and MetaTrader 5 terminal are Windows binaries not installed in this Linux cloud container. Compile `AdvancedScalpingEA/Experts/AdvancedScalpingEA.mq5` in local MetaEditor 5 and run real-tick Strategy Tester validation following `TESTING_AND_VALIDATION.md`.

## 3. Operational Notes
1. **Zero Presets Required**: Attach `AdvancedScalpingEA` directly to any Forex, Metal, Index, Energy, Crypto, Synthetic, or Step Index chart—no `.set` files are needed (`InpAutoAdaptBySymbol = true`).
2. **Commission Detection**: `SymbolIntelligence.mqh` inspects real `DEAL_COMMISSION` history per symbol and honors `InpFallbackCommissionPerLot` (default `0.0`) prior to closed history.
3. **Controlled Non-Mutating Adaptation**: `AdaptiveLearning.mqh` generates Stage 2–3 findings and recommendations without mutating live risk caps.
