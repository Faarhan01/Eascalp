# Testing, Validation & Strategy Tester Protocol (v2.9.0)

## 1. MT5 Strategy Tester Configuration
- **Zero-Preset Plug-and-Play**: Attach `AdvancedScalpingEA.mq5` (`v2.90`) directly to any symbol and timeframe. With `InpAutoAdaptBySymbol = true`, `SymbolContext::Initialize()` + `SymbolIntelligence::GetAdaptiveAssetProfile()` immediately profile contract specs and cached history DNA (including empirical quantized-step Step Index detection) without loading any `.set` preset files.
- **Modeling Mode**: Always select **"Every tick based on real ticks"** whenever broker tick history is available. Use M1 OHLC only for coarse sanity checks.
- **Operating Mode**: `InpOperatingMode` defaults to `EA_MODE_LIVE_TRADING` with `InpAllowLiveTrading = true` (zero fake execution simulation), placing authentic orders inside MT5 Strategy Tester (`MQL_TESTER`) even if the live terminal Algo Trading toolbar button is disabled. Visual dashboard timers/canvas updates are bypassed in non-visual Strategy Tester for fast execution.
- **Hedging vs. Netting Verification**: Validate both Hedging accounts (scaled positions permitted once existing position reaches Break-Even + 0.85 ATR) and Netting accounts (`PYRAMID_NETTING_BLOCKED` guard + multi-fill `DEAL_ENTRY_IN` commission apportionment in `PerformanceAnalytics`).
- **Multi-Symbol Portfolio Testing**: Set `InpMultiSymbolList` (up to `8` symbols, e.g. `EURUSD,GBPUSD,USDJPY` or `Step Index,Volatility 75 Index`) to verify cross-symbol conviction sorting, shared-currency net lot caps, and per-symbol cooldowns.
- **Universal Multi-Market Matrix**: Test across Forex Majors (`EURUSD`, `USDJPY`, `EURUSDm`), Crosses/Exotics (`GBPJPY`, `EURTRY`), Metals (`XAUUSD`, `XAGUSD`), Indices (`US500`, `NAS100`, `GER40`), Equities, Crypto CFDs (`BTCUSD`, `ETHUSD`), and Synthetics (`Step Index`, `Volatility 75 Index`, `Boom 500 Index`, `Crash 1000 Index`).

## 2. Out-of-Sample, Expectancy & Monte Carlo Validation
1. **In-Sample / Out-of-Sample Split**: Reserve at least 30% of unseen chronological data (`InpOosSplitRatio = 0.30`). Each CSV signal and trade row records `split_tag` (`IN_SAMPLE` vs `OUT_OF_SAMPLE`).
2. **Expectancy & Wall-Snap Cost Stress**: Verify `InpSnapTpBeforeMajorWalls = true` trims obstructed targets cleanly before multi-touch S/R or PDH/PDL barriers while preserving `InpMinRewardRiskRatio` (`1.30`) and `InpMinTpToCostRatio` (`2.20` baseline / per-asset adaptive).
3. **Score-Band Calibration**: Inspect `trade_history.csv` and the Dashboard **Score Bands** chart (`<60`, `60-74`, `75+`) to verify higher-scored consensus setups outperform marginal trades net of commission and slippage.
4. **Shutdown Analytics Report & CSV Pipeline**: Verify the Experts journal prints `AnalyticsReport` (`MC_MedDD`, `MC_P95DD`, `ScoreBands`, best/weak Session & Symbol buckets) on `OnDeinit()` and that all 12 CSV files populate inside `MQL5/Files/AdvancedScalpingEA/Exports/`.

## 3. Verification Checklist
- Open `Experts/AdvancedScalpingEA.mq5` in MetaEditor 5 and compile with **0 errors and 0 warnings**.
- Confirm `ObjectsDeleteAll(0, "ASEA_RO_")` clears all dashboard chart objects upon EA removal.
- Confirm all 6 dashboard tabs and 5 chart modes operate strictly read-only.
- Load exported `.csv` files into the companion **CSV Performance Terminal** to review closed-trade expectancy, rejection breakdown, equity/drawdown curve, and strategy profit factors.
