# Testing, Validation & Strategy Tester Protocol (v2.2.0)

## 1. MT5 Strategy Tester Configuration
- **Modeling Mode**: Always select **"Every tick based on real ticks"** whenever broker tick history is available. Use M1 OHLC only for coarse sanity checks.
- **Operating Mode**: `InpOperatingMode` defaults to `EA_MODE_LIVE_TRADING` with `InpAllowLiveTrading = true` (zero fake execution simulation), placing authentic orders inside MT5 Strategy Tester (`MQL_TESTER`) even if the live terminal Algo Trading toolbar button is disabled. Visual dashboard timers/canvas updates are bypassed in non-visual Strategy Tester for fast execution.
- **Multi-Symbol Testing**: Set `InpMultiSymbolList` (e.g. `EURUSD,GBPUSD,USDJPY`) in MT5 Strategy Tester to exercise multi-symbol context isolation, per-symbol bar deduplication, post-loss cooldowns, and shared currency exposure caps simultaneously.
- **Universal Multi-Market Matrix**: Validate across Forex Majors (`EURUSD`, `USDJPY`), Crosses/Exotics (`GBPJPY`, `EURTRY`), Metals (`XAUUSD`, `XAGUSD`), Indices (`US500`, `NAS100`, `GER40`), Crypto CFDs (`BTCUSD`, `ETHUSD`), and Synthetics (`Volatility 75 Index`, `Step Index`). Default `InpMaxSpreadPoints = 0.0` engages `SymbolIntelligence::GetAutoMaxSpreadPoints()` automatically per asset class and ATR so any symbol can be attached without manual point tuning.

## 2. Out-of-Sample, Cost-Aware & Walk-Forward Validation
1. **In-Sample / Out-of-Sample Split**: Reserve at least 30% of unseen chronological data (`InpOosSplitRatio = 0.30`). Each CSV signal and trade row includes `split_tag` (`IN_SAMPLE` vs `OUT_OF_SAMPLE`).
2. **Expectancy & Cost Stress**: Perturb `InpEstimatedSlippagePoints`, `InpFallbackCommissionPerLot`, and `InpMinTpToCostRatio` to verify strategies survive realistic broker friction.
3. **Score-Band Calibration**: Inspect `trade_history.csv` and the Dashboard **Score Bands** chart (`<60`, `60-74`, `75+`) to verify higher-scored signals outperform lower-scored signals net of costs.
4. **Filter & Consensus Review**: Review `SFilterStats` in Stage 2 Historical Findings and `rejected_signals.csv` (`OPPOSING_SIGNAL_CONFLICT`, `LIVE_PRICE_EXTENDED`, `SPREAD_TOO_WIDE`, `INSUFFICIENT_MARGIN`) to confirm filters protect capital without choking valid setups.
5. **Monte Carlo Sequence Stress**: Run `HistoricalResearch::RunMonteCarloDrawdown95` and inspect MFE/MAE ratios to evaluate 95th-percentile drawdown.

## 3. Verification Checklist
- Confirm compilation in MetaEditor 5 with 0 errors and 0 warnings.
- Confirm `ObjectsDeleteAll(0, "ASEA_RO_")` cleans up every chart object on EA removal.
- Confirm all 5 chart modes (`Equity/Bal`, `Drawdown %`, `Strategies`, `Score Bands`, `Regimes`) and 6 tabs operate strictly read-only.
- Confirm 12 v2.2.0 CSV files populate in `MQL5/Files/AdvancedScalpingEA/Exports/` with `signal_id`, `mfe_money`, `mae_money`, `exit_reason`, `execution_cost`, and `net_expectancy`.

