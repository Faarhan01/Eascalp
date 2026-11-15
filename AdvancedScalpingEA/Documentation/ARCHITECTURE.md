# AdvancedScalpingEA — System Architecture

## 1. Design Philosophy & Isolation Guarantees
AdvancedScalpingEA is engineered as a modular MetaTrader 5 quantitative research and scalping Expert Advisor. Its primary invariants are:
1. **Research & Demo Safety by Default**: `InpOperatingMode` defaults to `EA_MODE_RESEARCH_ONLY` and `InpAllowLiveTrading = false`. Real-money execution requires explicit opt-in via two independent boolean inputs alongside `EA_MODE_LIVE_TRADING`.
2. **Strict Read-Only Dashboard Isolation**: `CDashboardManager` accepts only `const SDashboardSnapshot`, `const SManagedPosition[]`, and curve value arrays. It holds no pointers or references to `CEAController`, `CRiskManagement`, `CTradeExecution`, or any strategy instance.
3. **Zero Look-Ahead / Zero Repainting**: Indicators (`IndicatorEngine.mqh`, `MultiTimeframe.mqh`), market structure (`MarketStructure.mqh`), candlestick formations (`CandlestickRecognition.mqh`), and geometric chart patterns (`PatternRecognition.mqh`) evaluate completed bars (`shift >= 1`) exclusively.
4. **Magic-Number Ownership Isolation**: `CPositionManagement` and `CPerformanceAnalytics` strictly filter `PositionsTotal()` and `HistoryDealsTotal()` by `POSITION_MAGIC == m_magic` and `DEAL_MAGIC == m_magic`, never modifying manual trades or unrelated EAs.

## 2. Module Dependency Layers
- **Core**: `Types.mqh`, `Diagnostics.mqh`, `StateManager.mqh`, `EAController.mqh`
- **Market**: `SymbolIntelligence.mqh`, `MarketData.mqh`, `TickAnalysis.mqh`, `MarketStructure.mqh`, `MarketRegime.mqh`, `MultiTimeframe.mqh`
- **Indicators**: `IndicatorEngine.mqh`, `CandlestickRecognition.mqh`, `PatternRecognition.mqh`
- **Strategies**: `StrategyBase.mqh`, `TrendPullback.mqh`, `MomentumScalping.mqh`, `BreakoutScalping.mqh`, `ReversalScalping.mqh`, `RangeScalping.mqh`, `VolatilityExpansion.mqh`, `MicroMomentum.mqh`
- **Trading**: `SignalScoring.mqh`, `TradeValidation.mqh`, `RiskManagement.mqh`, `TradeExecution.mqh`, `PositionManagement.mqh`
- **Intelligence**: `StrategySelection.mqh`, `AdaptiveLearning.mqh`, `HistoricalResearch.mqh`
- **Analytics**: `Statistics.mqh`, `PerformanceAnalytics.mqh`, `CSVLogger.mqh`
- **Dashboard**: `DashboardComponents.mqh`, `DashboardLayout.mqh`, `DashboardCharts.mqh`, `DashboardStatistics.mqh`, `DashboardManager.mqh`

## 3. State Recovery on Terminal Restart
`CStateManager` persists daily/weekly balance anchors, peak equity/balance, consecutive loss counters, lockout status, and observation counters into `MQL5/Files/AdvancedScalpingEA/State/state_<symbol>_<magic>.ini` using safe text key-value encoding. On startup, `CEAController` restores those anchors and reconciles open positions and historical closed deals directly from MT5 terminal state.
