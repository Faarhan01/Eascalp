# Testing, Validation & Strategy Tester Protocol (v3.1.0)

## 1. MT5 Strategy Tester Configuration
- **Zero-Preset Plug-and-Play**: Attach `AdvancedScalpingEA.mq5` (`v3.10`) directly to any symbol and timeframe. With `InpAutoAdaptBySymbol = true` and `InpAutoTuneFromHistory = true`, `SymbolContext::Initialize()` immediately profiles contract specs, 240-bar empirical Symbol DNA (Trending, Mean-Reverting, or Breakout-Sweep), empirical quantized Step Index detection, and 24-hour liquidity curves without `.set` files.
- **Modeling Mode**: Always select **"Every tick based on real ticks"** whenever broker tick history is available (essential to accurately test live tick-level Entry Sniper pullback fills).
- **Operating Mode**: `InpOperatingMode` defaults to `EA_MODE_LIVE_TRADING` with `InpAllowLiveTrading = true` (authentic order execution in both live accounts and Strategy Tester). Non-visual tester runs skip canvas dashboard overhead automatically.
- **Universal Multi-Market Matrix**: Test across Forex Majors (`EURUSD`, `USDJPY`, `EURUSDm`), Crosses/Exotics (`GBPJPY`, `EURTRY`), Metals (`XAUUSD`, `XAGUSD`), Indices (`US500`, `NAS100`, `GER40`), Equities, Crypto CFDs (`BTCUSD`, `ETHUSD`), and Synthetics (`Step Index`, `Volatility 75 Index`, `Boom 500 Index`, `Crash 1000 Index`).

## 2. v3.1.0 Functional & Expectancy Verification
1. **Symbol DNA & Empirical Dead-Hour Check**:
   - Inspect Experts journal at `OnInit()` and the Dashboard **Market & Signals** `Symbol DNA` line to verify 240-bar calibration (`DNA=... ER=... BO=... MR=... Swp=...`).
   - With `InpEnableAdaptiveDeadHourFilter = true`, inspect `signal_rejections.csv` to verify low-liquidity/range off-hours below 48% baseline trigger `DEAD_LIQUIDITY_HOUR`.
2. **Graph Extremum, H1 Wall Clearance & Live Entry Sniper**:
   - Verify `InpEnableExtremumEntrySniper = true` (`2` wait bars, `0.20x ATR` min improvement) logs `SNIPER_ARMED_WAIT` on extended setups and executes at improved pullback pricing (`<= targetPrice` for buys, `>= targetPrice` for sells) or expires cleanly after `2` bars.
   - Verify `InpSnapTpBeforeMajorWalls = true` trims obstructed targets cleanly before multi-touch S/R, PDH/PDL, and H1 swing barriers while preserving `1.55` min R:R and `2.60x` min TP-to-cost edge.
3. **Out-of-Sample, Cost Stress & Strategy/Regime Benching**:
   - Reserve >= 30% chronological unseen data (`InpOosSplitRatio = 0.30`, recorded per row as `IN_SAMPLE` vs `OUT_OF_SAMPLE`).
   - Confirm `strategy_metrics.csv` benches negative-EV strategies/regimes cleanly (`8` early / `15` full / `5` regime) and winners reach `1.65x ATR` (`>= 1.05R`) before Break-Even and trail from `2.40x ATR` toward `3.20x ATR` targets.
4. **CSV Performance Terminal Audit**:
   - Open `trade_history.csv` and exported CSVs in the companion browser **CSV Performance Terminal** to audit expectancy, score bands (`<60`, `60-74`, `75+`), drawdown curve, and rejection distributions.

## 3. Pre-Flight Checklist
- Compile `Experts/AdvancedScalpingEA.mq5` (`v3.10`) in MetaEditor 5 with **0 errors and 0 warnings**.
- Confirm `ObjectsDeleteAll(0, "ASEA_RO_")` clears all read-only dashboard objects cleanly upon removal.
- Confirm all 6 dashboard tabs and 5 chart modes operate strictly read-only.
