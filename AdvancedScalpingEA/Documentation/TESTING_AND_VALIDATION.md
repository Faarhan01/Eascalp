# Testing, Validation & Strategy Tester Protocol

## 1. MT5 Strategy Tester Configuration
- **Modeling Mode**: Always select **"Every tick based on real ticks"** whenever broker tick history is available. Use M1 OHLC only for initial coarse sanity checks.
- **Operating Mode**: Test with `InpOperatingMode = EA_MODE_DEMO_EXECUTION` inside the Strategy Tester so virtual tester orders exercise `CTradeExecution`, `CPositionManagement`, `CRiskManagement`, and `CPerformanceAnalytics` end-to-end.
- **Multi-Market Matrix**: Run independent validation across:
  - Forex Majors (`EURUSD`, `USDJPY`) — M1, M5, M15
  - Forex Crosses/Exotics (`GBPJPY`, `EURTRY`) — M5, M15
  - Metals (`XAUUSD`, `XAGUSD`) — M5, M15
  - Indices (`US500`, `NAS100`, `GER40`) — M5
  - Synthetics (`Volatility 75 Index`, `Step Index`, where supported) — M1, M5

## 2. Out-of-Sample & Walk-Forward Validation
1. **In-Sample / Out-of-Sample Split**: Reserve at least 30% of unseen chronological data (`InpOosSplitRatio = 0.30`). Never tune parameters on the OOS holdout.
2. **Walk-Forward Windows**: Use rolling `InpWalkForwardDays` folds. Each CSV signal and trade row includes `split_tag` (`IN_SAMPLE` vs `OUT_OF_SAMPLE`) for external Python/R verification.
3. **Strategy Comparison Against No-Trade Baseline**: Compare each of the 7 strategies individually (`InpEnable... = true` one at a time) against a zero-trade baseline and combined mode.
4. **Robustness Sweeps**: Perturb key thresholds (`InpMinSignalScore +/- 5`, `InpDefaultSlAtrMult +/- 0.2`, `InpRiskPerTradePct`) and verify smooth performance degradation rather than fragile parameter cliffs.
5. **Monte Carlo Sequence Stress**: Use `HistoricalResearch::RunMonteCarloDrawdown95` and the CSV exports to evaluate 95th-percentile drawdown under trade-order shuffling and realistic spread/slippage shocks.

## 3. Verification Checklist Before Demo Deployment
- Confirm compilation in MetaEditor 5 with 0 errors.
- Confirm `ObjectsDeleteAll(0, "ASEA_RO_")` cleans up every chart object on EA removal.
- Confirm dashboard page tabs switch views without altering `SEAConfig` or triggering orders.
- Confirm CSV files populate in `MQL5/Files/AdvancedScalpingEA/Exports/`.
- Test restart recovery by closing and reopening MT5 with an open EA position and confirming state continuity.
