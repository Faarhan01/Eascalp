//+------------------------------------------------------------------+
//|                                           AdvancedScalpingEA.mq5 |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.0.0 Intelligent Multi-Market Scalper   |
//+------------------------------------------------------------------+
#property copyright "AdvancedScalpingEA Quantitative Systems"
#property link      "https://www.mql5.com"
#property version   "2.20"
#property description "v2.2.0 Multi-Symbol Scalping EA: Universal Symbol Auto-Profiler, Multi-Strategy Consensus, Structural SL/TP, Progressive Chandelier Trailing, 17 Regimes, Portfolio Risk & Read-Only Dashboard."

#include "../Include/Core/Types.mqh"
#include "../Include/Core/EAController.mqh"
#include "../Include/Dashboard/DashboardManager.mqh"

//--- 1. General Settings
input group "=== 1. General Settings ==="
input ENUM_EA_OPERATING_MODE InpOperatingMode    = EA_MODE_LIVE_TRADING; // Operating Mode (Ready-to-Trade Live/Demo)
input bool   InpAllowLiveTrading                 = true;                  // Allow Live Real-Account Orders
input bool   InpConfirmLiveRiskAcknowledgement     = true;                  // Confirm Real-Account Risk Acknowledgement
input long   InpMagicNumber                      = 510299;                // Unique EA Magic Number
input string InpConfigLabel                      = "ReadyToTrade_v2.2";   // Configuration Label for Logs

//--- 2. Symbol Settings
input group "=== 2. Symbol Settings ==="
input string InpSymbolOverride                   = "";                    // Primary Symbol Override (Empty = Chart Symbol)
input string InpMultiSymbolList                  = "";                    // Additional Symbols (Comma-Separated, Max 8 Total)
input double InpFallbackCommissionPerLot         = 0.0;                   // Fallback Round-Turn Commission/Lot (If Broker History Empty)

//--- 3. Market Data
input group "=== 3. Market Data ==="
input int    InpSpreadAvgWindow                  = 120;                   // Spread Moving Average Window (Ticks)
input int    InpTickWindowSize                   = 64;                    // Tick Velocity Ring Buffer Size

//--- 4. Timeframes & MTF Weights
input group "=== 4. Timeframes & MTF Weights ==="
input ENUM_TIMEFRAMES InpPrimaryTimeframe        = PERIOD_CURRENT;        // Primary Scalping Timeframe
input ENUM_TIMEFRAMES InpIntermediateTimeframe   = PERIOD_M15;            // Intermediate Structure Timeframe
input ENUM_TIMEFRAMES InpHigherTimeframe         = PERIOD_H1;             // Higher Trend Direction Timeframe
input double InpMtfWeightHTF                     = 0.45;                  // Higher Timeframe Weight
input double InpMtfWeightITF                     = 0.35;                  // Intermediate Timeframe Weight
input double InpMtfWeightLTF                     = 0.20;                  // Lower Timeframe Weight

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

//--- 10. Signal Scoring & Expectancy
input group "=== 10. Signal Scoring & Expectancy ==="
input double InpMinSignalScore                   = 48.0;                  // Minimum Signal Score (0 - 100)
input double InpMinRewardRiskRatio               = 1.05;                  // Minimum Structural Reward:Risk Ratio
input double InpMinTpToCostRatio                 = 1.5;                   // Minimum TP Value / Total Execution Cost
input double InpEstimatedSlippagePoints          = 2.0;                   // Baseline Pre-Fill Slippage Floor (Points)
input bool   InpRequireViableExpectancy          = true;                  // Require Economically Viable Expectancy

//--- 11. Trade Validation
input group "=== 11. Trade Validation ==="
input double InpMaxSpreadPoints                  = 0.0;                   // Maximum Allowed Spread (Points, 0 = Auto-Adaptive)
input double InpMaxSpreadRatio                   = 2.50;                  // Maximum Spread Expansion Ratio
input double InpMaxSpreadAtrPct                  = 32.0;                  // Maximum Spread as % of ATR
input double InpMaxVolatilityRatio               = 3.20;                  // Maximum ATR Volatility Ratio
input double InpMinVolatilityRatio               = 0.30;                  // Minimum ATR Volatility Ratio
input int    InpMinRequiredBars                  = 50;                    // Minimum Historical Bars Required
input bool   InpRequireMtfNoStrongConflict       = false;                 // Block Trades on Strong MTF Conflict

//--- 12. Risk Management
input group "=== 12. Risk Management ==="
input double InpRiskPerTradePct                  = 1.00;                  // Fixed-Fractional Risk Per Trade (%)
input double InpMaxRiskPerTradePct               = 2.00;                  // Hard Max Risk Per Trade (%)
input double InpMaxPortfolioOpenRiskPct          = 5.00;                  // Hard Max Portfolio Open Risk (%)
input double InpMaxDailyLossPct                  = 2.50;                  // Maximum Daily Loss (%)
input double InpMaxWeeklyLossPct                 = 6.00;                  // Maximum Weekly Loss (%)
input double InpMaxAccountDrawdownPct            = 10.00;                 // Maximum Account Drawdown (%)
input int    InpMaxConsecutiveLosses             = 5;                     // Maximum Consecutive Losses Before Lockout
input int    InpMaxOpenPositionsTotal            = 4;                     // Max Open Positions (Total Portfolio)
input int    InpMaxOpenPositionsPerSymbol        = 2;                     // Max Open Positions (Per Symbol)
input double InpMaxAggregateLots                 = 5.0;                   // Max Aggregate Open Lots
input double InpMaxSymbolLots                    = 2.0;                   // Max Symbol Open Lots
input double InpMaxCurrencyExposureLots          = 2.5;                   // Max Shared Currency Net Exposure (Lots)
input double InpMinFreeMarginLevelPct            = 150.0;                 // Minimum Margin Level (%)
input bool   InpAllowMinLotFallback              = true;                  // Permit Minimum Broker Lot Fallback on Small Balances
input double InpMaxMinLotRiskPct                 = 3.00;                  // Max Risk Ceiling (%) for Min-Lot Fallback
input int    InpMaxSlippagePoints                = 25;                    // Max Allowed Order Slippage (Points)
input bool   InpEmergencyStopNewEntries          = false;                 // Emergency Lockout (Block New Entries)

//--- 13. Position Management
input group "=== 13. Position Management ==="
input bool   InpEnableBreakEven                  = true;                  // Enable Cost-Covering Break-Even Protection
input double InpBreakEvenTriggerAtr              = 1.0;                   // Break-Even Trigger (x ATR)
input double InpBreakEvenLockAtr                 = 0.15;                  // Break-Even Lock Offset (x ATR)
input bool   InpEnablePartialClose               = true;                  // Enable Partial Take-Profit Scaling
input double InpPartialCloseTriggerAtr           = 1.25;                  // Partial Close Profit Trigger (x ATR)
input double InpPartialCloseFraction             = 0.50;                  // Partial Close Volume Fraction (0.20 - 0.75)
input bool   InpEnableTrailingStop               = true;                  // Enable ATR Trailing Stop
input bool   InpUseProgressiveTrail              = true;                  // Compress Trail Multiplier in Extended Profit
input bool   InpUseChandelierTrail               = true;                  // Anchor Trail from Peak Favorable Excursion
input double InpTrailingStartAtr                 = 1.4;                   // Trailing Start Profit (x ATR)
input double InpTrailingStepAtr                  = 0.9;                   // Trailing Stop Distance (x ATR)
input bool   InpEnableStrategyExit               = true;                  // Enable Strategy-Specific Early Exit Hook
input bool   InpEnableStructureExit              = true;                  // Exit on Momentum-Confirmed CHoCH Reversal
input bool   InpEnableMomentumExit               = true;                  // Exit on Momentum Deterioration
input bool   InpEnableMaxHoldExit                = true;                  // Exit at Max Holding Duration
input int    InpMaxHoldingMinutes                = 120;                   // Max Holding Duration (Minutes)
input bool   InpCloseBeforeWeekend               = false;                 // Close Open Non-24x7 Positions Late Friday
input int    InpFridayCloseHour                  = 21;                    // Friday Pre-Weekend Close Hour (Server Time)

//--- 14. Trading Filters
input group "=== 14. Trading Filters ==="
input int    InpLossCooldownBars                 = 2;                     // Per-Symbol Cooldown Bars After Loss (0 = Off)
input bool   InpEnableSessionFilter              = false;                 // Restrict to Configured Session Hours
input int    InpSessionStartHour                 = 7;                     // Session Start Hour (Server Time)
input int    InpSessionEndHour                   = 21;                    // Session End Hour (Server Time)
input bool   InpAvoidFridayLateHours             = false;                 // Block New Entries Late Friday
input int    InpFridayCutoffHour                 = 21;                    // Friday Cutoff Hour (Server Time)

//--- 15. Learning & Research
input group "=== 15. Learning & Research ==="
input bool   InpAutoSelectBestStrategy           = false;                 // Filter to Top Ranked Strategy (After Min Sample)
input int    InpMinStrategySampleSize            = 20;                    // Minimum Trades Before Strategy Selection
input bool   InpEnableAdaptiveEvaluation         = true;                  // Enable 5-Stage Non-Mutating Research
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

CEAController     g_controller;
CDashboardManager g_dashboard;
bool              g_dashboardRuntimeActive = false;

bool ValidateInputs(string &outErr)
{
   outErr = "";
   if(InpMagicNumber <= 0) { outErr = "InpMagicNumber must be positive."; return false; }
   if(InpEmaFastPeriod < 2 || InpEmaMedPeriod <= InpEmaFastPeriod || InpEmaSlowPeriod <= InpEmaMedPeriod)
   { outErr = "EMA periods must satisfy 2 <= Fast < Medium < Slow."; return false; }
   if(InpMinSignalScore < 20.0 || InpMinSignalScore > 95.0)
   { outErr = "InpMinSignalScore must be between 20 and 95."; return false; }
   if(InpMinRewardRiskRatio < 0.8 || InpMinRewardRiskRatio > 5.0)
   { outErr = "InpMinRewardRiskRatio must be between 0.8 and 5.0."; return false; }
   if(InpMinTpToCostRatio < 1.1)
   { outErr = "InpMinTpToCostRatio must be >= 1.1."; return false; }
   if(InpMaxSpreadPoints < 0.0)
   { outErr = "InpMaxSpreadPoints cannot be negative (use 0 to disable point cap)."; return false; }
   if(InpRiskPerTradePct <= 0.0 || InpRiskPerTradePct > InpMaxRiskPerTradePct || InpMaxRiskPerTradePct > 5.0)
   { outErr = "Risk per trade must satisfy 0 < RiskPerTradePct <= MaxRiskPerTradePct <= 5.0%."; return false; }
   if(InpMaxMinLotRiskPct < InpMaxRiskPerTradePct || InpMaxMinLotRiskPct > 10.0)
   { outErr = "InpMaxMinLotRiskPct must be >= MaxRiskPerTradePct and <= 10.0%."; return false; }
   if(InpMaxPortfolioOpenRiskPct < InpMaxRiskPerTradePct || InpMaxPortfolioOpenRiskPct > 15.0)
   { outErr = "InpMaxPortfolioOpenRiskPct must be >= MaxRiskPerTradePct and <= 15.0%."; return false; }
   if(InpMaxAccountDrawdownPct <= 0.5 || InpMaxAccountDrawdownPct > 50.0)
   { outErr = "InpMaxAccountDrawdownPct must be between 0.5% and 50%."; return false; }
   if(InpMaxOpenPositionsTotal < 1 || InpMaxOpenPositionsPerSymbol < 1)
   { outErr = "Max open positions must be >= 1."; return false; }
   if(InpMtfWeightHTF < 0.0 || InpMtfWeightITF < 0.0 || InpMtfWeightLTF < 0.0 ||
      (InpMtfWeightHTF + InpMtfWeightITF + InpMtfWeightLTF) <= 0.0)
   { outErr = "MTF weights must be non-negative and sum > 0."; return false; }
   if(InpDashboardRefreshSec < 1 || InpDashboardRefreshSec > 60)
   { outErr = "InpDashboardRefreshSec must be between 1 and 60 seconds."; return false; }
   if(InpLossCooldownBars < 0 || InpLossCooldownBars > 20)
   { outErr = "InpLossCooldownBars must be between 0 and 20."; return false; }
   if(InpFridayCloseHour < 0 || InpFridayCloseHour > 23)
   { outErr = "InpFridayCloseHour must be between 0 and 23."; return false; }
   return true;
}

void RenderDashboardFromSnapshot()
{
   if(!g_dashboardRuntimeActive) return;
   SDashboardSnapshot snap;
   SManagedPosition pos[];
   int posCount = 0;
   double eq[], bal[], dd[], scoreNet[], regNet[];
   int scoreTrades[], regTrades[];
   g_controller.GetReadOnlyDashboardData(snap, pos, posCount, eq, bal, dd, scoreNet, scoreTrades, regNet, regTrades);
   g_dashboard.Render(snap, pos, posCount, eq, bal, dd, scoreNet, scoreTrades, regNet, regTrades);
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
   cfg.multiSymbolList     = InpMultiSymbolList;
   cfg.fallbackCommPerLot  = InpFallbackCommissionPerLot;
   cfg.spreadAvgWindow     = InpSpreadAvgWindow;
   cfg.tickWindowSize      = InpTickWindowSize;
   cfg.primaryTF           = InpPrimaryTimeframe;
   cfg.intermediateTF      = InpIntermediateTimeframe;
   cfg.higherTF            = InpHigherTimeframe;
   cfg.mtfWeightHtf        = InpMtfWeightHTF;
   cfg.mtfWeightItf        = InpMtfWeightITF;
   cfg.mtfWeightLtf        = InpMtfWeightLTF;

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

   cfg.expCfg.minRewardRiskRatio     = InpMinRewardRiskRatio;
   cfg.expCfg.minTpToCostRatio       = InpMinTpToCostRatio;
   cfg.expCfg.estSlippagePoints      = InpEstimatedSlippagePoints;
   cfg.expCfg.minSampleForExpectancy = InpMinStrategySampleSize;

   cfg.valCfg.minSignalScore             = InpMinSignalScore;
   cfg.valCfg.maxSpreadPoints            = InpMaxSpreadPoints;
   cfg.valCfg.maxSpreadRatio             = InpMaxSpreadRatio;
   cfg.valCfg.maxSpreadAtrPct            = InpMaxSpreadAtrPct;
   cfg.valCfg.maxVolatilityRatio         = InpMaxVolatilityRatio;
   cfg.valCfg.minVolatilityRatio         = InpMinVolatilityRatio;
   cfg.valCfg.minRequiredBars            = InpMinRequiredBars;
   cfg.valCfg.requireMtfNoStrongConflict = InpRequireMtfNoStrongConflict;
   cfg.valCfg.requireEconomicallyViableExp = InpRequireViableExpectancy;
   cfg.valCfg.enableSessionFilter        = InpEnableSessionFilter;
   cfg.valCfg.sessionStartHour           = InpSessionStartHour;
   cfg.valCfg.sessionEndHour             = InpSessionEndHour;
   cfg.valCfg.avoidFridayLateHours       = InpAvoidFridayLateHours;
   cfg.valCfg.fridayCutoffHour           = InpFridayCutoffHour;

   cfg.riskCfg.riskPerTradePct           = InpRiskPerTradePct;
   cfg.riskCfg.maxRiskPerTradePct        = InpMaxRiskPerTradePct;
   cfg.riskCfg.maxPortfolioOpenRiskPct   = InpMaxPortfolioOpenRiskPct;
   cfg.riskCfg.maxDailyLossPct           = InpMaxDailyLossPct;
   cfg.riskCfg.maxWeeklyLossPct          = InpMaxWeeklyLossPct;
   cfg.riskCfg.maxAccountDrawdownPct     = InpMaxAccountDrawdownPct;
   cfg.riskCfg.maxConsecutiveLosses      = InpMaxConsecutiveLosses;
   cfg.riskCfg.maxOpenPositionsTotal     = InpMaxOpenPositionsTotal;
   cfg.riskCfg.maxOpenPositionsPerSymbol = InpMaxOpenPositionsPerSymbol;
   cfg.riskCfg.maxAggregateLots          = InpMaxAggregateLots;
   cfg.riskCfg.maxSymbolLots             = InpMaxSymbolLots;
   cfg.riskCfg.maxCurrencyExposureLots   = InpMaxCurrencyExposureLots;
   cfg.riskCfg.minFreeMarginLevelPct     = InpMinFreeMarginLevelPct;
   cfg.riskCfg.allowMinLotFallback       = InpAllowMinLotFallback;
   cfg.riskCfg.maxMinLotRiskPct          = InpMaxMinLotRiskPct;
   cfg.riskCfg.emergencyStopAllNewEntries= InpEmergencyStopNewEntries;
   cfg.maxSlippagePoints                 = InpMaxSlippagePoints;
   cfg.maxOrderRetries                   = 2;

   cfg.posCfg.enableBreakEven            = InpEnableBreakEven;
   cfg.posCfg.breakEvenTriggerAtr        = InpBreakEvenTriggerAtr;
   cfg.posCfg.breakEvenLockAtr           = InpBreakEvenLockAtr;
   cfg.posCfg.enablePartialClose         = InpEnablePartialClose;
   cfg.posCfg.partialCloseTriggerAtr     = InpPartialCloseTriggerAtr;
   cfg.posCfg.partialCloseFraction       = InpPartialCloseFraction;
   cfg.posCfg.enableTrailingStop         = InpEnableTrailingStop;
   cfg.posCfg.useProgressiveTrail        = InpUseProgressiveTrail;
   cfg.posCfg.useChandelierTrail         = InpUseChandelierTrail;
   cfg.posCfg.trailingStartAtr           = InpTrailingStartAtr;
   cfg.posCfg.trailingStepAtr            = InpTrailingStepAtr;
   cfg.posCfg.enableStrategyExit         = InpEnableStrategyExit;
   cfg.posCfg.enableStructureExit        = InpEnableStructureExit;
   cfg.posCfg.enableMomentumExit         = InpEnableMomentumExit;
   cfg.posCfg.enableMaxHoldExit          = InpEnableMaxHoldExit;
   cfg.posCfg.maxHoldingMinutes          = InpMaxHoldingMinutes;
   cfg.posCfg.closeBeforeWeekend         = InpCloseBeforeWeekend;
   cfg.posCfg.fridayCloseHour            = InpFridayCloseHour;

   cfg.lossCooldownBars                  = InpLossCooldownBars;
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

   g_dashboardRuntimeActive = InpShowDashboard && (!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE));
   if(g_dashboardRuntimeActive)
   {
      g_dashboard.Initialize(true, InpDashboardCompactMode);
      EventSetTimer(MathMax(1, InpDashboardRefreshSec));
      RenderDashboardFromSnapshot();
   }

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_dashboardRuntimeActive)
   {
      EventKillTimer();
      g_dashboard.Deinit();
      g_dashboardRuntimeActive = false;
   }
   g_controller.Shutdown();
}

void OnTick()
{
   g_controller.ProcessTick();
}

void OnTimer()
{
   if(g_dashboardRuntimeActive)
      RenderDashboardFromSnapshot();
}

void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD || trans.type == TRADE_TRANSACTION_POSITION)
      g_controller.OnTradeTransactionEvent();
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(!g_dashboardRuntimeActive) return;
   g_dashboard.OnChartEvent(id, sparam);
   if(id == CHARTEVENT_OBJECT_CLICK || id == CHARTEVENT_CHART_CHANGE)
      RenderDashboardFromSnapshot();
}
//+------------------------------------------------------------------+
