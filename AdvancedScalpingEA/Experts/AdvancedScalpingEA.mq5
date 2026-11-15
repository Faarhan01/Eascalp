//+------------------------------------------------------------------+
//|                                           AdvancedScalpingEA.mq5 |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        Research & Multi-Strategy Scalping Engine |
//+------------------------------------------------------------------+
#property copyright "AdvancedScalpingEA Quantitative Systems"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Multi-Market MT5 Scalping EA with 7 Independent Strategies, Independent Risk Engine, and Strictly Read-Only Dashboard."

#include "../Include/Core/Types.mqh"
#include "../Include/Core/EAController.mqh"
#include "../Include/Dashboard/DashboardManager.mqh"

//--- 1. General Settings
input group "=== 1. General Settings ==="
input ENUM_EA_OPERATING_MODE InpOperatingMode    = EA_MODE_RESEARCH_ONLY; // Operating Mode (Default: Research Only)
input bool   InpAllowLiveTrading                 = false;                 // Allow Live Real-Account Orders (Disabled by Default)
input bool   InpConfirmLiveRiskAcknowledgement     = false;                 // Confirm Real-Account Risk Acknowledgement
input long   InpMagicNumber                      = 510299;                // Unique EA Magic Number
input string InpConfigLabel                      = "Research_Baseline_v1";// Configuration Label for Logs

//--- 2. Symbol Settings
input group "=== 2. Symbol Settings ==="
input string InpSymbolOverride                   = "";                    // Symbol Override (Empty = Chart Symbol)

//--- 3. Market Data
input group "=== 3. Market Data ==="
input int    InpSpreadAvgWindow                  = 120;                   // Spread Moving Average Window (Ticks)
input int    InpTickWindowSize                   = 64;                    // Tick Velocity Ring Buffer Size

//--- 4. Timeframes
input group "=== 4. Timeframes ==="
input ENUM_TIMEFRAMES InpPrimaryTimeframe        = PERIOD_CURRENT;        // Primary Scalping Timeframe
input ENUM_TIMEFRAMES InpIntermediateTimeframe   = PERIOD_M15;            // Intermediate Structure Timeframe
input ENUM_TIMEFRAMES InpHigherTimeframe         = PERIOD_H1;             // Higher Trend Direction Timeframe

//--- 5. Technical Indicators
input group "=== 5. Technical Indicators ==="
input int    InpEmaFastPeriod                    = 9;                     // Fast EMA Period
input int    InpEmaMedPeriod                     = 21;                    // Medium EMA Period
input int    InpEmaSlowPeriod                    = 55;                    // Slow EMA Period
input int    InpSmaTrendPeriod                   = 200;                   // Baseline SMA Period
input int    InpRsiPeriod                        = 14;                    // RSI Period
input int    InpMacdFast                         = 12;                    // MACD Fast EMA
input int    InpMacdSlow                         = 26;                    // MACD Slow EMA
input int    InpMacdSignal                       = 9;                     // MACD Signal Period
input int    InpAtrPeriod                        = 14;                    // ATR Period
input int    InpAdxPeriod                        = 14;                    // ADX Period
input int    InpBandsPeriod                      = 20;                    // Bollinger Bands Period
input double InpBandsDeviation                   = 2.0;                   // Bollinger Bands Deviation
input bool   InpEnableVWAP                       = true;                  // Compute Session VWAP

//--- 6. Market Structure
input group "=== 6. Market Structure ==="
input int    InpSwingStrength                    = 3;                     // Swing Pivot Strength (Bars Left/Right)
input int    InpStructureLookback                = 120;                   // Structure Lookback (Closed Bars)
input double InpZoneAtrMult                      = 0.35;                  // S/R Zone Tolerance (x ATR)
input double InpAdxStrongThreshold               = 28.0;                  // Strong Trend ADX Threshold
input double InpAdxWeakThreshold                 = 18.0;                  // Weak Trend ADX Threshold

//--- 7. Candlestick Recognition
input group "=== 7. Candlestick Recognition ==="
input double InpDojiBodyMaxRatio                 = 0.12;                  // Doji Max Body/Range Ratio
input double InpPinWickMinRatio                  = 2.0;                   // Pin Bar / Hammer Min Wick/Body Ratio

//--- 8. Chart Patterns
input group "=== 8. Chart Patterns ==="
input int    InpPatternLookback                  = 100;                   // Chart Pattern Lookback Bars
input double InpPatternTolAtrMult                = 0.45;                  // Geometric Pattern Tolerance (x ATR)

//--- 9. Scalping Strategies
input group "=== 9. Scalping Strategies ==="
input bool   InpEnableTrendPullback              = true;                  // Strategy 1: Trend Pullback
input bool   InpEnableMomentumScalp              = true;                  // Strategy 2: Momentum Scalping
input bool   InpEnableBreakoutScalp              = true;                  // Strategy 3: Breakout Scalping
input bool   InpEnableReversalScalp              = true;                  // Strategy 4: Reversal Scalping
input bool   InpEnableRangeScalp                 = true;                  // Strategy 5: Range Scalping
input bool   InpEnableVolExpansion               = true;                  // Strategy 6: Volatility Expansion
input bool   InpEnableMicroMomentum              = true;                  // Strategy 7: Micro-Momentum
input double InpDefaultSlAtrMult                 = 1.5;                   // Default Stop-Loss (x ATR)
input double InpDefaultTpAtrMult                 = 2.2;                   // Default Take-Profit (x ATR)
input bool   InpEvaluateOnNewBarOnly             = false;                 // Evaluate Entries Only on New Closed Bar

//--- 10. Signal Scoring
input group "=== 10. Signal Scoring ==="
input double InpMinSignalScore                   = 62.0;                  // Minimum Signal Score (0 - 100)

//--- 11. Trade Validation
input group "=== 11. Trade Validation ==="
input double InpMaxSpreadPoints                  = 60.0;                  // Maximum Allowed Spread (Points)
input double InpMaxSpreadRatio                   = 1.85;                  // Maximum Spread Expansion Ratio
input double InpMaxVolatilityRatio               = 2.60;                  // Maximum ATR Volatility Ratio
input double InpMinVolatilityRatio               = 0.45;                  // Minimum ATR Volatility Ratio
input int    InpMinRequiredBars                  = 100;                   // Minimum Historical Bars Required
input bool   InpRequireMtfNoStrongConflict       = true;                  // Block Trades on Strong MTF Conflict

//--- 12. Risk Management
input group "=== 12. Risk Management ==="
input double InpRiskPerTradePct                  = 0.50;                  // Fixed-Fractional Risk Per Trade (%)
input double InpMaxRiskPerTradePct               = 1.00;                  // Hard Max Risk Per Trade (%)
input double InpMaxDailyLossPct                  = 2.00;                  // Maximum Daily Loss (%)
input double InpMaxWeeklyLossPct                 = 5.00;                  // Maximum Weekly Loss (%)
input double InpMaxAccountDrawdownPct            = 10.00;                 // Maximum Account Drawdown (%)
input int    InpMaxConsecutiveLosses             = 5;                     // Maximum Consecutive Losses Before Lockout
input int    InpMaxOpenPositionsTotal            = 3;                     // Max Open Positions (Total EA)
input int    InpMaxOpenPositionsPerSymbol        = 2;                     // Max Open Positions (Current Symbol)
input double InpMaxAggregateLots                 = 5.0;                   // Max Aggregate Open Lots
input double InpMaxSymbolLots                    = 2.0;                   // Max Symbol Open Lots
input double InpMinFreeMarginLevelPct            = 200.0;                 // Minimum Margin Level (%)
input int    InpMaxSlippagePoints                = 25;                    // Max Allowed Order Slippage (Points)
input bool   InpEmergencyStopNewEntries          = false;                 // Emergency Lockout (Block New Entries)

//--- 13. Position Management
input group "=== 13. Position Management ==="
input bool   InpEnableBreakEven                  = true;                  // Enable Break-Even Stop Protection
input double InpBreakEvenTriggerAtr              = 1.0;                   // Break-Even Trigger (x ATR)
input double InpBreakEvenLockAtr                 = 0.15;                  // Break-Even Lock Offset (x ATR)
input bool   InpEnableTrailingStop               = true;                  // Enable ATR Trailing Stop
input double InpTrailingStartAtr                 = 1.4;                   // Trailing Start Profit (x ATR)
input double InpTrailingStepAtr                  = 0.9;                   // Trailing Stop Distance (x ATR)
input bool   InpEnableStructureExit              = true;                  // Exit on Structural CHoCH Reversal
input bool   InpEnableMomentumExit               = true;                  // Exit on Momentum Deterioration
input bool   InpEnableMaxHoldExit                = true;                  // Exit at Max Holding Duration
input int    InpMaxHoldingMinutes                = 120;                   // Max Holding Duration (Minutes)

//--- 14. Trading Filters
input group "=== 14. Trading Filters ==="
input bool   InpEnableSessionFilter              = false;                 // Restrict to Configured Session Hours
input int    InpSessionStartHour                 = 7;                     // Session Start Hour (Server Time)
input int    InpSessionEndHour                   = 21;                    // Session End Hour (Server Time)
input bool   InpAvoidFridayLateHours             = true;                  // Block New Entries Late Friday
input int    InpFridayCutoffHour                 = 20;                    // Friday Cutoff Hour (Server Time)

//--- 15. Learning & Research
input group "=== 15. Learning & Research ==="
input bool   InpAutoSelectBestStrategy           = false;                 // Filter to Top Ranked Strategy (After Min Sample)
input int    InpMinStrategySampleSize            = 20;                    // Minimum Trades Before Strategy Selection
input bool   InpEnableAdaptiveEvaluation         = true;                  // Enable Non-Mutating Performance Research
input double InpDeteriorationPfFloor             = 0.85;                  // Profit Factor Deterioration Warning Floor
input int    InpWalkForwardDays                  = 14;                    // Walk-Forward Fold Window (Days)
input double InpOosSplitRatio                    = 0.30;                  // Out-of-Sample Fold Ratio (0.10 - 0.50)

//--- 16. Performance Analytics & CSV
input group "=== 16. Performance Analytics & CSV ==="
input bool   InpEnableCSVExports                 = true;                  // Export 12 Research & Analytics CSV Files
input int    InpCsvFlushBatchSize                = 12;                    // Buffered Lines Before CSV Disk Flush

//--- 17. Dashboard (Strictly Read-Only)
input group "=== 17. Dashboard (Strictly Read-Only) ==="
input bool   InpShowDashboard                    = true;                  // Render Read-Only Chart Dashboard
input bool   InpDashboardCompactMode             = false;                 // Compact Dashboard Sizing
input int    InpDashboardRefreshSec              = 1;                     // Dashboard Timer Refresh Interval (Seconds)

//--- 18. Diagnostics & Logging
input group "=== 18. Diagnostics & Logging ==="
input ENUM_LOG_SEVERITY InpLogLevel              = LOG_INFO;              // Minimum Diagnostic Log Level
input bool   InpLogToFile                        = true;                  // Write Structured Logs to File
input bool   InpPrintToJournal                   = true;                  // Print Logs to MT5 Experts Journal

//--- Isolated Module Instances
CEAController     g_controller;
CDashboardManager g_dashboard;

bool ValidateInputs(string &outErr)
{
   outErr = "";
   if(InpMagicNumber <= 0) { outErr = "InpMagicNumber must be positive."; return false; }
   if(InpEmaFastPeriod < 2 || InpEmaMedPeriod <= InpEmaFastPeriod || InpEmaSlowPeriod <= InpEmaMedPeriod)
   { outErr = "EMA periods must satisfy 2 <= Fast < Medium < Slow."; return false; }
   if(InpMinSignalScore < 20.0 || InpMinSignalScore > 95.0)
   { outErr = "InpMinSignalScore must be between 20 and 95."; return false; }
   if(InpRiskPerTradePct <= 0.0 || InpRiskPerTradePct > InpMaxRiskPerTradePct || InpMaxRiskPerTradePct > 5.0)
   { outErr = "Risk per trade must satisfy 0 < RiskPerTradePct <= MaxRiskPerTradePct <= 5.0%."; return false; }
   if(InpMaxAccountDrawdownPct <= 0.5 || InpMaxAccountDrawdownPct > 50.0)
   { outErr = "InpMaxAccountDrawdownPct must be between 0.5% and 50%."; return false; }
   if(InpMaxOpenPositionsTotal < 1 || InpMaxOpenPositionsPerSymbol < 1)
   { outErr = "Max open positions must be >= 1."; return false; }
   if(InpDashboardRefreshSec < 1 || InpDashboardRefreshSec > 60)
   { outErr = "InpDashboardRefreshSec must be between 1 and 60 seconds."; return false; }
   return true;
}

void RenderDashboardFromSnapshot()
{
   if(!InpShowDashboard) return;
   SDashboardSnapshot snap;
   SManagedPosition pos[];
   int posCount = 0;
   double eq[], bal[], dd[];
   g_controller.GetReadOnlyDashboardData(snap, pos, posCount, eq, bal, dd);
   g_dashboard.Render(snap, pos, posCount, eq, bal, dd);
}

int OnInit()
{
   string err = "";
   if(!ValidateInputs(err))
   {
      Print("[CRITICAL] Input validation failed: ", err);
      return INIT_PARAMETERS_INCORRECT;
   }

   SEAConfig cfg;
   cfg.ResetDefaults();

   cfg.operatingMode       = InpOperatingMode;
   cfg.allowLiveTrading    = InpAllowLiveTrading;
   cfg.confirmLiveRiskAck  = InpConfirmLiveRiskAcknowledgement;
   cfg.magicNumber         = InpMagicNumber;
   cfg.configLabel         = InpConfigLabel;
   cfg.symbolOverride      = InpSymbolOverride;
   cfg.spreadAvgWindow     = InpSpreadAvgWindow;
   cfg.tickWindowSize      = InpTickWindowSize;
   cfg.primaryTF           = InpPrimaryTimeframe;
   cfg.intermediateTF      = InpIntermediateTimeframe;
   cfg.higherTF            = InpHigherTimeframe;

   cfg.indCfg.emaFastPeriod  = InpEmaFastPeriod;
   cfg.indCfg.emaMedPeriod   = InpEmaMedPeriod;
   cfg.indCfg.emaSlowPeriod  = InpEmaSlowPeriod;
   cfg.indCfg.smaTrendPeriod = InpSmaTrendPeriod;
   cfg.indCfg.rsiPeriod      = InpRsiPeriod;
   cfg.indCfg.macdFast       = InpMacdFast;
   cfg.indCfg.macdSlow       = InpMacdSlow;
   cfg.indCfg.macdSignal     = InpMacdSignal;
   cfg.indCfg.atrPeriod      = InpAtrPeriod;
   cfg.indCfg.adxPeriod      = InpAdxPeriod;
   cfg.indCfg.bbPeriod       = InpBandsPeriod;
   cfg.indCfg.bbDeviation    = InpBandsDeviation;
   cfg.indCfg.enableVWAP     = InpEnableVWAP;

   cfg.swingStrength       = InpSwingStrength;
   cfg.structureLookback   = InpStructureLookback;
   cfg.zoneAtrMult         = InpZoneAtrMult;
   cfg.adxStrongThresh     = InpAdxStrongThreshold;
   cfg.adxWeakThresh       = InpAdxWeakThreshold;
   cfg.dojiBodyMaxRatio    = InpDojiBodyMaxRatio;
   cfg.pinWickMinRatio     = InpPinWickMinRatio;
   cfg.patternLookback     = InpPatternLookback;
   cfg.patternTolAtrMult   = InpPatternTolAtrMult;

   cfg.enableTrendPullback = InpEnableTrendPullback;
   cfg.enableMomentumScalp = InpEnableMomentumScalp;
   cfg.enableBreakoutScalp = InpEnableBreakoutScalp;
   cfg.enableReversalScalp = InpEnableReversalScalp;
   cfg.enableRangeScalp    = InpEnableRangeScalp;
   cfg.enableVolExpansion  = InpEnableVolExpansion;
   cfg.enableMicroMomentum = InpEnableMicroMomentum;
   cfg.defaultSlAtrMult    = InpDefaultSlAtrMult;
   cfg.defaultTpAtrMult    = InpDefaultTpAtrMult;
   cfg.evaluateOnNewBarOnly= InpEvaluateOnNewBarOnly;

   cfg.valCfg.minSignalScore             = InpMinSignalScore;
   cfg.valCfg.maxSpreadPoints            = InpMaxSpreadPoints;
   cfg.valCfg.maxSpreadRatio             = InpMaxSpreadRatio;
   cfg.valCfg.maxVolatilityRatio         = InpMaxVolatilityRatio;
   cfg.valCfg.minVolatilityRatio         = InpMinVolatilityRatio;
   cfg.valCfg.minRequiredBars            = InpMinRequiredBars;
   cfg.valCfg.requireMtfNoStrongConflict = InpRequireMtfNoStrongConflict;
   cfg.valCfg.enableSessionFilter        = InpEnableSessionFilter;
   cfg.valCfg.sessionStartHour           = InpSessionStartHour;
   cfg.valCfg.sessionEndHour             = InpSessionEndHour;
   cfg.valCfg.avoidFridayLateHours       = InpAvoidFridayLateHours;
   cfg.valCfg.fridayCutoffHour           = InpFridayCutoffHour;

   cfg.riskCfg.riskPerTradePct           = InpRiskPerTradePct;
   cfg.riskCfg.maxRiskPerTradePct        = InpMaxRiskPerTradePct;
   cfg.riskCfg.maxDailyLossPct           = InpMaxDailyLossPct;
   cfg.riskCfg.maxWeeklyLossPct          = InpMaxWeeklyLossPct;
   cfg.riskCfg.maxAccountDrawdownPct     = InpMaxAccountDrawdownPct;
   cfg.riskCfg.maxConsecutiveLosses      = InpMaxConsecutiveLosses;
   cfg.riskCfg.maxOpenPositionsTotal     = InpMaxOpenPositionsTotal;
   cfg.riskCfg.maxOpenPositionsPerSymbol = InpMaxOpenPositionsPerSymbol;
   cfg.riskCfg.maxAggregateLots          = InpMaxAggregateLots;
   cfg.riskCfg.maxSymbolLots             = InpMaxSymbolLots;
   cfg.riskCfg.minFreeMarginLevelPct     = InpMinFreeMarginLevelPct;
   cfg.riskCfg.emergencyStopAllNewEntries= InpEmergencyStopNewEntries;
   cfg.maxSlippagePoints                 = InpMaxSlippagePoints;

   cfg.posCfg.enableBreakEven            = InpEnableBreakEven;
   cfg.posCfg.breakEvenTriggerAtr        = InpBreakEvenTriggerAtr;
   cfg.posCfg.breakEvenLockAtr           = InpBreakEvenLockAtr;
   cfg.posCfg.enableTrailingStop         = InpEnableTrailingStop;
   cfg.posCfg.trailingStartAtr           = InpTrailingStartAtr;
   cfg.posCfg.trailingStepAtr            = InpTrailingStepAtr;
   cfg.posCfg.enableStructureExit        = InpEnableStructureExit;
   cfg.posCfg.enableMomentumExit         = InpEnableMomentumExit;
   cfg.posCfg.enableMaxHoldExit          = InpEnableMaxHoldExit;
   cfg.posCfg.maxHoldingMinutes          = InpMaxHoldingMinutes;

   cfg.autoSelectBestStrategy            = InpAutoSelectBestStrategy;
   cfg.minStrategySampleSize             = InpMinStrategySampleSize;
   cfg.enableAdaptiveEvaluation          = InpEnableAdaptiveEvaluation;
   cfg.deteriorationPfFloor              = InpDeteriorationPfFloor;
   cfg.walkForwardDays                   = InpWalkForwardDays;
   cfg.oosSplitRatio                     = InpOosSplitRatio;

   cfg.enableCSVExports                  = InpEnableCSVExports;
   cfg.csvBatchSize                      = InpCsvFlushBatchSize;
   cfg.logLevel                          = InpLogLevel;
   cfg.logToFile                         = InpLogToFile;
   cfg.printToJournal                    = InpPrintToJournal;

   if(!g_controller.Initialize(cfg))
      return INIT_FAILED;

   g_dashboard.Initialize(InpShowDashboard, InpDashboardCompactMode);
   EventSetTimer(MathMax(1, InpDashboardRefreshSec));
   RenderDashboardFromSnapshot();

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   g_dashboard.Deinit();
   g_controller.Shutdown();
}

void OnTick()
{
   g_controller.ProcessTick();
}

void OnTimer()
{
   RenderDashboardFromSnapshot();
}

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD || trans.type == TRADE_TRANSACTION_POSITION)
      g_controller.OnTradeTransactionEvent();
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   // Dashboard handles passive presentation navigation only (never touches g_controller)
   g_dashboard.OnChartEvent(id, sparam);
   if(id == CHARTEVENT_OBJECT_CLICK || id == CHARTEVENT_CHART_CHANGE)
      RenderDashboardFromSnapshot();
}
//+------------------------------------------------------------------+
