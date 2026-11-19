//+------------------------------------------------------------------+
//|                                                 EAController.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v3.1.0 Multi-Symbol Sniper Orchestrator   |
//+------------------------------------------------------------------+
#ifndef __ASEA_CORE_EACONTROLLER_MQH__
#define __ASEA_CORE_EACONTROLLER_MQH__

#include "Types.mqh"
#include "Diagnostics.mqh"
#include "StateManager.mqh"
#include "SymbolContext.mqh"
#include "../Strategies/StrategyBase.mqh"
#include "../Strategies/TrendPullback.mqh"
#include "../Strategies/MomentumScalping.mqh"
#include "../Strategies/BreakoutScalping.mqh"
#include "../Strategies/ReversalScalping.mqh"
#include "../Strategies/RangeScalping.mqh"
#include "../Strategies/VolatilityExpansion.mqh"
#include "../Strategies/MicroMomentum.mqh"
#include "../Strategies/LiquiditySweepScalping.mqh"
#include "../Strategies/VwapMeanReversion.mqh"
#include "../Strategies/EmaRibbonContinuation.mqh"
#include "../Trading/ExpectancyEngine.mqh"
#include "../Trading/SignalScoring.mqh"
#include "../Trading/TradeValidation.mqh"
#include "../Trading/RiskManagement.mqh"
#include "../Trading/TradeExecution.mqh"
#include "../Trading/PositionManagement.mqh"
#include "../Intelligence/StrategySelection.mqh"
#include "../Intelligence/AdaptiveLearning.mqh"
#include "../Intelligence/HistoricalResearch.mqh"
#include "../Analytics/PerformanceAnalytics.mqh"
#include "../Analytics/CSVLogger.mqh"

struct SEAConfig
{
   ENUM_EA_OPERATING_MODE operatingMode;
   bool   allowLiveTrading;
   bool   confirmLiveRiskAck;
   long   magicNumber;
   string configLabel;
   bool   autoAdaptBySymbol;
   ENUM_ASSET_CLASS_OVERRIDE assetClassOverride;
   bool   autoTuneFromHistory;

   string symbolOverride;
   string multiSymbolList;
   int    spreadAvgWindow;
   int    tickWindowSize;
   double fallbackCommPerLot;

   bool            autoScaleMtfToChart;
   ENUM_TIMEFRAMES primaryTF;
   ENUM_TIMEFRAMES intermediateTF;
   ENUM_TIMEFRAMES higherTF;
   double mtfWeightHtf;
   double mtfWeightItf;
   double mtfWeightLtf;

   SIndicatorConfig indCfg;

   int    swingStrength;
   int    structureLookback;
   double zoneAtrMult;
   double adxStrongThresh;
   double adxWeakThresh;
   double volHighRatio;
   double volLowRatio;
   double spreadUnstableRatio;

   double dojiBodyMaxRatio;
   double pinWickMinRatio;
   int    patternLookback;
   double patternTolAtrMult;

   bool   enableTrendPullback;
   bool   enableMomentumScalp;
   bool   enableBreakoutScalp;
   bool   enableReversalScalp;
   bool   enableRangeScalp;
   bool   enableVolExpansion;
   bool   enableMicroMomentum;
   bool   enableLiquiditySweep;
   bool   enableVwapReversion;
   bool   enableEmaRibbon;
   double defaultSlAtrMult;
   double defaultTpAtrMult;
   bool   snapTpBeforeMajorWalls;
   double minBreakoutRvol;
   bool   evaluateOnNewBarOnly;
   bool   enableExtremumEntrySniper;
   int    extremumSniperWaitBars;
   double extremumPullbackMinAtr;

   SExpectancyConfig expCfg;
   SValidationConfig valCfg;

   SRiskConfig riskCfg;
   int    maxSlippagePoints;
   int    maxOrderRetries;

   SPosMgmtConfig posCfg;

   int    lossCooldownBars;
   int    maxTradesPerHour;
   int    maxDailyTrades;
   bool   autoSelectBestStrategy;
   int    minStrategySampleSize;
   bool   enableAdaptiveEvaluation;
   double deteriorationPfFloor;
   int    walkForwardDays;
   double oosSplitRatio;

   bool   enableCSVExports;
   int    csvBatchSize;
   ENUM_LOG_SEVERITY logLevel;
   bool   logToFile;
   bool   printToJournal;

   void ResetDefaults()
   {
      operatingMode = EA_MODE_LIVE_TRADING;
      allowLiveTrading = true;
      confirmLiveRiskAck = true;
      magicNumber = 510299;
      configLabel = "AutoAdaptive_v3.1";
      autoAdaptBySymbol = true;
      assetClassOverride = ASSET_OVERRIDE_AUTO;
      autoTuneFromHistory = true;
      symbolOverride = "";
      multiSymbolList = "";
      spreadAvgWindow = 120;
      tickWindowSize = 64;
      fallbackCommPerLot = 0.0;
      autoScaleMtfToChart = true;
      primaryTF = PERIOD_M5;
      intermediateTF = PERIOD_M15;
      higherTF = PERIOD_H1;
      mtfWeightHtf = 0.45;
      mtfWeightItf = 0.35;
      mtfWeightLtf = 0.20;
      indCfg.ResetDefaults();
      swingStrength = 3;
      structureLookback = 120;
      zoneAtrMult = 0.35;
      adxStrongThresh = 26.0;
      adxWeakThresh = 18.0;
      volHighRatio = 1.45;
      volLowRatio = 0.70;
      spreadUnstableRatio = 2.60;
      dojiBodyMaxRatio = 0.12;
      pinWickMinRatio = 2.0;
      patternLookback = 100;
      patternTolAtrMult = 0.45;
      enableTrendPullback = true;
      enableMomentumScalp = true;
      enableBreakoutScalp = true;
      enableReversalScalp = true;
      enableRangeScalp = true;
      enableVolExpansion = true;
      enableMicroMomentum = false;
      enableLiquiditySweep = true;
      enableVwapReversion = true;
      enableEmaRibbon = true;
      defaultSlAtrMult = 1.65;
      defaultTpAtrMult = 3.20;
      snapTpBeforeMajorWalls = true;
      minBreakoutRvol = 1.10;
      evaluateOnNewBarOnly = true;
      enableExtremumEntrySniper = true;
      extremumSniperWaitBars = 2;
      extremumPullbackMinAtr = 0.20;
      expCfg.ResetDefaults();
      valCfg.ResetDefaults();
      riskCfg.ResetDefaults();
      maxSlippagePoints = 25;
      maxOrderRetries = 2;
      posCfg.ResetDefaults();
      lossCooldownBars = 4;
      maxTradesPerHour = 2;
      maxDailyTrades = 8;
      autoSelectBestStrategy = false;
      minStrategySampleSize = 15;
      enableAdaptiveEvaluation = true;
      deteriorationPfFloor = 0.92;
      walkForwardDays = 14;
      oosSplitRatio = 0.30;
      enableCSVExports = true;
      csvBatchSize = 12;
      logLevel = LOG_INFO;
      logToFile = true;
      printToJournal = true;
   }
};

struct SPendingEntryCandidate
{
   int                ctxIdx;
   STradeSignal       sig;
   double             lots;
   datetime           barTime;
   datetime           tickTime;
   ENUM_MARKET_REGIME regime;
   bool               sameBarRej;
};

struct SArmedEntrySniper
{
   bool               active;
   int                ctxIdx;
   string             sym;
   STradeSignal       sig;
   double             targetPrice;
   double             maxChasePrice;
   datetime           armedBarTime;
   int                barsElapsed;
   ENUM_MARKET_REGIME regime;
   string             statusText;

   void Reset(const string status = "Scanning")
   {
      active = false;
      ctxIdx = -1;
      sym = "";
      sig.Reset();
      targetPrice = 0.0;
      maxChasePrice = 0.0;
      armedBarTime = 0;
      barsElapsed = 0;
      regime = REGIME_UNKNOWN;
      statusText = status;
   }
};

class CEAController
{
private:
   SEAConfig m_cfg;
   string    m_primarySymbol;
   bool      m_initialized;
   bool      m_isTester;
   bool      m_isVisualTester;
   datetime  m_lastAnalysisTime;
   datetime  m_lastPerfSnapshotTime;
   datetime  m_lastLearningEvalTime;
   datetime  m_lastSnapshotTime;
   datetime  m_lastRiskUpdateTime;
   int       m_lastKnownPositionsTotal;

   CDiagnostics         m_diag;
   CStateManager        m_stateMgr;

   CSymbolContext       m_contexts[EA_MAX_SYMBOLS];
   int                  m_symbolCount;
   string               m_monitoredSummary;

   CStrategyTrendPullback          m_stratPullback;
   CStrategyMomentumScalping       m_stratMomentum;
   CStrategyBreakoutScalping       m_stratBreakout;
   CStrategyReversalScalping       m_stratReversal;
   CStrategyRangeScalping          m_stratRange;
   CStrategyVolatilityExpansion    m_stratVolExp;
   CStrategyMicroMomentum          m_stratMicro;
   CStrategyLiquiditySweepScalping m_stratLiqSweep;
   CStrategyVwapMeanReversion      m_stratVwapRev;
   CStrategyEmaRibbonContinuation  m_stratEmaRibbon;
   CStrategyBase                  *m_strategies[];

   CExpectancyEngine    m_expectancy;
   CSignalScoring       m_scoring;
   CTradeValidation     m_validation;
   CRiskManagement      m_risk;
   CTradeExecution      m_execution;
   CPositionManagement  m_posMgmt;
   CStrategySelection   m_selector;
   CAdaptiveLearning    m_learning;
   CHistoricalResearch  m_research;
   CPerformanceAnalytics m_perfAnalytics;
   CCSVLogger           m_csv;

   SDashboardSnapshot   m_snapshot;
   STradeSignal         m_lastBestSignal;
   SValidationResult    m_lastValidation;

   string               m_cdSymbols[EA_MAX_SYMBOLS];
   int                  m_cdBarsLeft[EA_MAX_SYMBOLS];

   datetime             m_lastClosedStratBar[EA_MAX_SYMBOLS];
   datetime             m_lastMicroEvalTime[EA_MAX_SYMBOLS];
   datetime             m_lastRejBarTime[EA_MAX_SYMBOLS];
   int                  m_lastRejStrat[EA_MAX_SYMBOLS];
   int                  m_lastRejDir[EA_MAX_SYMBOLS];
   string               m_lastRejCode[EA_MAX_SYMBOLS];
   SArmedEntrySniper    m_snipers[EA_MAX_SYMBOLS];

   datetime             m_execTimes[64];
   int                  m_execTimeCount;

   datetime GetDayStart(const datetime t) const
   {
      if(t <= 0) return 0;
      MqlDateTime dt;
      TimeToStruct(t, dt);
      dt.hour = 0; dt.min = 0; dt.sec = 0;
      return StructToTime(dt);
   }

   void RecordExecutionTimestamp(const datetime t)
   {
      datetime stamp = (t > 0) ? t : SafeCurrentTime();
      if(m_execTimeCount < 64)
         m_execTimes[m_execTimeCount++] = stamp;
      else
      {
         for(int i = 1; i < 64; i++)
            m_execTimes[i - 1] = m_execTimes[i];
         m_execTimes[63] = stamp;
      }
   }

   void RestoreExecutionHistory()
   {
      m_execTimeCount = 0;
      ArrayInitialize(m_execTimes, 0);
      datetime now = SafeCurrentTime();
      if(now <= 0) return;
      datetime day0 = GetDayStart(now);
      datetime fromT = (day0 > 3600) ? (day0 - 3600) : (datetime)0;
      if(!HistorySelect(fromT, now + 60)) return;
      int total = HistoryDealsTotal();
      int startIdx = (total > 64) ? (total - 64) : 0;
      for(int i = startIdx; i < total; i++)
      {
         ulong dtkt = HistoryDealGetTicket(i);
         if(dtkt == 0) continue;
         if(HistoryDealGetInteger(dtkt, DEAL_MAGIC) != m_cfg.magicNumber) continue;
         if(HistoryDealGetInteger(dtkt, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
         datetime dtime = (datetime)HistoryDealGetInteger(dtkt, DEAL_TIME);
         if(dtime > 0) RecordExecutionTimestamp(dtime);
      }
   }

   bool CheckFrequencyCaps(const datetime now, string &outCode, string &outReason) const
   {
      outCode = "";
      outReason = "";
      datetime refNow = (now > 0) ? now : SafeCurrentTime();
      datetime day0 = GetDayStart(refNow);
      int hourCount = 0;
      int dayCount  = 0;

      for(int i = m_execTimeCount - 1; i >= 0; i--)
      {
         datetime ts = m_execTimes[i];
         if(ts <= 0) continue;
         if((refNow - ts) < 3600) hourCount++;
         if(day0 > 0 && ts >= day0) dayCount++;
      }

      if(m_cfg.maxTradesPerHour > 0 && hourCount >= m_cfg.maxTradesPerHour)
      {
         outCode = "HOURLY_TRADE_CAP";
         outReason = StringFormat("Hourly trade frequency cap reached (%d/%d in last 60m).", hourCount, m_cfg.maxTradesPerHour);
         return false;
      }
      if(m_cfg.maxDailyTrades > 0 && dayCount >= m_cfg.maxDailyTrades)
      {
         outCode = "DAILY_TRADE_CAP";
         outReason = StringFormat("Daily trade frequency cap reached (%d/%d today).", dayCount, m_cfg.maxDailyTrades);
         return false;
      }
      return true;
   }

   void TriggerLossCooldown(const string sym, const int cooldownOverride = -1)
   {
      int bars = (cooldownOverride >= 0) ? cooldownOverride : m_cfg.lossCooldownBars;
      if(bars <= 0 || sym == "") return;
      for(int i = 0; i < EA_MAX_SYMBOLS; i++)
      {
         if(m_cdSymbols[i] == sym || m_cdSymbols[i] == "")
         {
            m_cdSymbols[i] = sym;
            m_cdBarsLeft[i] = bars;
            return;
         }
      }
   }

   void TickLossCooldown(const string sym)
   {
      for(int i = 0; i < EA_MAX_SYMBOLS; i++)
      {
         if(m_cdSymbols[i] == sym && m_cdBarsLeft[i] > 0)
         {
            m_cdBarsLeft[i]--;
            return;
         }
      }
   }

   int GetCooldownBars(const string sym) const
   {
      for(int i = 0; i < EA_MAX_SYMBOLS; i++)
      {
         if(m_cdSymbols[i] == sym)
            return m_cdBarsLeft[i];
      }
      return 0;
   }

   void ParseSymbolList(const string primarySym, const string listStr, string &outSyms[], int &outCount) const
   {
      outCount = 0;
      ArrayResize(outSyms, EA_MAX_SYMBOLS);
      outSyms[outCount++] = primarySym;

      if(listStr == "") return;
      string parts[];
      int n = StringSplit(listStr, ',', parts);
      for(int i = 0; i < n && outCount < EA_MAX_SYMBOLS; i++)
      {
         string s = parts[i];
         StringTrimLeft(s);
         StringTrimRight(s);
         if(s == "") continue;
         bool dup = false;
         for(int k = 0; k < outCount; k++)
         {
            if(outSyms[k] == s) { dup = true; break; }
         }
         if(!dup)
            outSyms[outCount++] = s;
      }
      ArrayResize(outSyms, outCount);
   }

   ENUM_TIMEFRAMES NormalizeTimeframe(const ENUM_TIMEFRAMES tf, const ENUM_TIMEFRAMES fallbackTF) const
   {
      int raw = (int)tf;
      if(raw == (int)PERIOD_CURRENT) return (ENUM_TIMEFRAMES)_Period;
      // Repair legacy MQL4 minute integers (e.g. 60 -> PERIOD_H1) that cause MT5 error 4802
      switch(raw)
      {
         case 1:     return PERIOD_M1;
         case 2:     return PERIOD_M2;
         case 3:     return PERIOD_M3;
         case 4:     return PERIOD_M4;
         case 5:     return PERIOD_M5;
         case 6:     return PERIOD_M6;
         case 10:    return PERIOD_M10;
         case 12:    return PERIOD_M12;
         case 15:    return PERIOD_M15;
         case 20:    return PERIOD_M20;
         case 30:    return PERIOD_M30;
         case 60:    return PERIOD_H1;
         case 120:   return PERIOD_H2;
         case 180:   return PERIOD_H3;
         case 240:   return PERIOD_H4;
         case 360:   return PERIOD_H6;
         case 480:   return PERIOD_H8;
         case 720:   return PERIOD_H12;
         case 1440:  return PERIOD_D1;
         case 10080: return PERIOD_W1;
         case 43200: return PERIOD_MN1;
      }
      if(PeriodSeconds(tf) > 0) return tf;
      return fallbackTF;
   }

   ENUM_TIMEFRAMES StepHigherTimeframe(const ENUM_TIMEFRAMES baseTF) const
   {
      int sec = PeriodSeconds(baseTF);
      if(sec < PeriodSeconds(PERIOD_M5))  return PERIOD_M5;
      if(sec < PeriodSeconds(PERIOD_M15)) return PERIOD_M15;
      if(sec < PeriodSeconds(PERIOD_H1))  return PERIOD_H1;
      if(sec < PeriodSeconds(PERIOD_H4))  return PERIOD_H4;
      if(sec < PeriodSeconds(PERIOD_D1))  return PERIOD_D1;
      return PERIOD_W1;
   }

   void AutoScaleHigherTimeframes(const ENUM_TIMEFRAMES pTF, ENUM_TIMEFRAMES &outItf, ENUM_TIMEFRAMES &outHtf) const
   {
      int sec = PeriodSeconds(pTF);
      if(sec <= PeriodSeconds(PERIOD_M1))       { outItf = PERIOD_M5;  outHtf = PERIOD_M15; }
      else if(sec <= PeriodSeconds(PERIOD_M3))  { outItf = PERIOD_M15; outHtf = PERIOD_M30; }
      else if(sec <= PeriodSeconds(PERIOD_M5))  { outItf = PERIOD_M15; outHtf = PERIOD_H1;  }
      else if(sec <= PeriodSeconds(PERIOD_M15)) { outItf = PERIOD_H1;  outHtf = PERIOD_H4;  }
      else if(sec <= PeriodSeconds(PERIOD_M30)) { outItf = PERIOD_H2;  outHtf = PERIOD_H4;  }
      else if(sec <= PeriodSeconds(PERIOD_H1))  { outItf = PERIOD_H4;  outHtf = PERIOD_D1;  }
      else if(sec <= PeriodSeconds(PERIOD_H4))  { outItf = PERIOD_D1;  outHtf = PERIOD_W1;  }
      else                                      { outItf = PERIOD_W1;  outHtf = PERIOD_MN1; }
   }

   void SyncDealHistoryAndResearch(const bool isBootstrap = false)
   {
      SClosedDealEvent events[];
      double totalNewPnL = 0.0;
      SSymbolProfile prof0 = m_contexts[0].GetSymbolIntelPtr().GetProfile();

      int count = m_perfAnalytics.SyncDealHistory(m_strategies, EA_MAX_STRATEGIES, m_posMgmt,
                                                  prof0.isSynthetic24x7, events, totalNewPnL, isBootstrap);
      if(count > 0 && !isBootstrap)
      {
         for(int i = 0; i < count; i++)
         {
            if(!events[i].isPartialClose)
            {
               m_risk.RecordClosedTradePnL(events[i].netPnL);
               if(events[i].netPnL < 0.0)
               {
                  int cdBars = m_cfg.lossCooldownBars;
                  if(m_cfg.autoAdaptBySymbol)
                  {
                     for(int k = 0; k < m_symbolCount; k++)
                     {
                        if(m_contexts[k].GetSymbol() == events[i].symbol)
                        {
                           cdBars = MathMax(m_cfg.lossCooldownBars, m_contexts[k].GetContext().assetProfile.lossCooldownBars);
                           break;
                        }
                     }
                  }
                  int consecL = m_risk.GetStatus().consecutiveLosses;
                  cdBars = MathMin(8, cdBars + MathMax(0, consecL - 1));
                  TriggerLossCooldown(events[i].symbol, cdBars);
               }
               m_research.RecordTradeOutcome(events[i].netPnL, events[i].score);
            }
            SResearchFoldInfo fold = m_research.GetFoldTag(events[i].closeTime);
            m_csv.LogTradeExecutionOrClose(events[i].symbol, m_cfg.primaryTF, events[i].positionTicket,
                                           events[i].signalId, StrategyIdToName(events[i].strategyId),
                                           events[i].direction, events[i].volume, events[i].closePrice,
                                           0.0, 0.0, 0.0, MathAbs(events[i].commission) + MathAbs(events[i].swap),
                                           events[i].score, events[i].entryRegime,
                                           events[i].isPartialClose ? "PARTIAL_CLOSED" : "CLOSED",
                                           events[i].exitReason, events[i].netPnL, events[i].mfeMoney,
                                           events[i].maeMoney, events[i].holdSec, fold.splitTag);
         }
      }
   }

   void PersistCurrentState(const bool force = false)
   {
      SPersistedState st;
      st.Reset();
      st.magicNumber = m_cfg.magicNumber;
      st.symbol      = m_primarySymbol;
      st.dayAnchor   = m_risk.GetDayAnchor();
      st.weekAnchor  = m_risk.GetWeekAnchor();
      st.dayStartBalance  = m_risk.GetDayStartBal();
      st.weekStartBalance = m_risk.GetWeekStartBal();
      st.peakBalance = m_risk.GetPeakBalance();
      st.peakEquity  = m_risk.GetPeakEquity();
      SRiskStatus rk = m_risk.GetStatus();
      st.maxDrawdownPct       = rk.maxHistoricalDrawdownPct;
      st.consecutiveLosses    = rk.consecutiveLosses;
      st.maxConsecutiveLosses = rk.maxConsecutiveLosses;
      st.lockoutActive        = rk.lockoutActive;
      st.lockoutReason        = rk.lockoutReason;
      st.lastBarProcessed     = m_contexts[0].GetLastBarLogged();

      SIntelligenceSummary intel = m_learning.GetSummary();
      st.observationsCount   = intel.observationsCollected;
      st.patternsCount       = intel.patternsDetected;
      st.regimesCount        = intel.regimesAnalyzed;
      st.signalsGenerated    = intel.signalsGenerated;
      st.signalsAccepted     = intel.signalsAccepted;
      st.signalsRejected     = intel.signalsRejected;
      st.lastValidatedConfig = intel.stage4ValidatedConfig;
      st.activeConfigVersion = intel.stage5ActiveConfig;
      st.lastValidationTime  = intel.lastValidationTime;

      m_stateMgr.SaveState(st, force);
   }

public:
   CEAController()
   {
      m_cfg.ResetDefaults();
      m_primarySymbol = "";
      m_initialized = false;
      m_isTester = false;
      m_isVisualTester = false;
      m_lastAnalysisTime = 0;
      m_lastPerfSnapshotTime = 0;
      m_lastLearningEvalTime = 0;
      m_lastSnapshotTime = 0;
      m_lastRiskUpdateTime = 0;
      m_lastKnownPositionsTotal = 0;
      m_symbolCount = 0;
      m_monitoredSummary = "";
      m_snapshot.Reset();
      m_lastBestSignal.Reset();
      m_lastValidation.Reset();
      for(int c = 0; c < EA_MAX_SYMBOLS; c++)
      {
         m_cdSymbols[c] = "";
         m_cdBarsLeft[c] = 0;
         m_lastClosedStratBar[c] = 0;
         m_lastMicroEvalTime[c] = 0;
         m_lastRejBarTime[c] = 0;
         m_lastRejStrat[c] = -1;
         m_lastRejDir[c] = (int)SIGNAL_NONE;
         m_lastRejCode[c] = "";
         m_snipers[c].Reset();
      }

      m_execTimeCount = 0;
      ArrayInitialize(m_execTimes, 0);

      ArrayResize(m_strategies, EA_MAX_STRATEGIES);
      m_strategies[0] = GetPointer(m_stratPullback);
      m_strategies[1] = GetPointer(m_stratMomentum);
      m_strategies[2] = GetPointer(m_stratBreakout);
      m_strategies[3] = GetPointer(m_stratReversal);
      m_strategies[4] = GetPointer(m_stratRange);
      m_strategies[5] = GetPointer(m_stratVolExp);
      m_strategies[6] = GetPointer(m_stratMicro);
      m_strategies[7] = GetPointer(m_stratLiqSweep);
      m_strategies[8] = GetPointer(m_stratVwapRev);
      m_strategies[9] = GetPointer(m_stratEmaRibbon);
   }

   bool Initialize(const SEAConfig &cfg)
   {
      m_cfg = cfg;
      m_cfg.extremumSniperWaitBars = MathMax(0, MathMin(6, m_cfg.extremumSniperWaitBars));
      m_cfg.extremumPullbackMinAtr = MathMax(0.05, MathMin(1.0, m_cfg.extremumPullbackMinAtr));
      m_isTester = (MQLInfoInteger(MQL_TESTER) != 0);
      m_isVisualTester = (MQLInfoInteger(MQL_VISUAL_MODE) != 0);
      m_primarySymbol = (m_cfg.symbolOverride != "") ? m_cfg.symbolOverride : _Symbol;

      ENUM_TIMEFRAMES reqHtf = m_cfg.higherTF;
      ENUM_TIMEFRAMES reqItf = m_cfg.intermediateTF;
      m_cfg.primaryTF      = NormalizeTimeframe(m_cfg.primaryTF, (ENUM_TIMEFRAMES)_Period);
      if(m_cfg.autoScaleMtfToChart)
      {
         AutoScaleHigherTimeframes(m_cfg.primaryTF, m_cfg.intermediateTF, m_cfg.higherTF);
      }
      else
      {
         m_cfg.intermediateTF = NormalizeTimeframe(m_cfg.intermediateTF, PERIOD_M15);
         m_cfg.higherTF       = NormalizeTimeframe(m_cfg.higherTF, PERIOD_H1);
      }
      if(PeriodSeconds(m_cfg.intermediateTF) <= PeriodSeconds(m_cfg.primaryTF))
         m_cfg.intermediateTF = StepHigherTimeframe(m_cfg.primaryTF);
      if(PeriodSeconds(m_cfg.higherTF) <= PeriodSeconds(m_cfg.intermediateTF))
         m_cfg.higherTF = StepHigherTimeframe(m_cfg.intermediateTF);

      m_diag.Initialize(m_primarySymbol, m_cfg.magicNumber, m_cfg.logLevel, m_cfg.logToFile, m_cfg.printToJournal);
      if((int)reqHtf != (int)m_cfg.higherTF || (int)reqItf != (int)m_cfg.intermediateTF)
      {
         m_diag.Log(LOG_INFO, "EAController",
                    StringFormat("Aligned MTF hierarchy -> LTF=%s, ITF=%s, HTF=%s",
                                 EnumToString(m_cfg.primaryTF), EnumToString(m_cfg.intermediateTF), EnumToString(m_cfg.higherTF)));
      }
      m_diag.Log(LOG_INFO, "EAController", StringFormat("Initializing %s v%s on %s %s in %s mode",
                                                        EA_PROJECT_NAME, EA_PROJECT_VERSION, m_primarySymbol,
                                                        EnumToString(m_cfg.primaryTF), OperatingModeToString(m_cfg.operatingMode)));

      m_stateMgr.Initialize(m_primarySymbol, m_cfg.magicNumber, GetPointer(m_diag));

      string syms[];
      int parsedCount = 0;
      ParseSymbolList(m_primarySymbol, m_cfg.multiSymbolList, syms, parsedCount);
      m_symbolCount = 0;
      m_monitoredSummary = "";

      for(int i = 0; i < parsedCount; i++)
      {
         bool ok = m_contexts[m_symbolCount].Initialize(
            syms[i], m_cfg.primaryTF, m_cfg.intermediateTF, m_cfg.higherTF,
            m_cfg.spreadAvgWindow, m_cfg.tickWindowSize, m_cfg.fallbackCommPerLot,
            m_cfg.indCfg, m_cfg.swingStrength, m_cfg.structureLookback, m_cfg.zoneAtrMult,
            m_cfg.adxStrongThresh, m_cfg.adxWeakThresh, m_cfg.volHighRatio, m_cfg.volLowRatio,
            m_cfg.spreadUnstableRatio, m_cfg.dojiBodyMaxRatio, m_cfg.pinWickMinRatio,
            m_cfg.patternLookback, m_cfg.patternTolAtrMult,
            m_cfg.mtfWeightHtf, m_cfg.mtfWeightItf, m_cfg.mtfWeightLtf,
            m_cfg.autoAdaptBySymbol, GetPointer(m_diag),
            m_cfg.assetClassOverride, m_cfg.autoTuneFromHistory
         );
         if(ok)
         {
            if(m_monitoredSummary != "") m_monitoredSummary += ", ";
            m_monitoredSummary += syms[i];
            m_diag.Log(LOG_INFO, "SymbolProfile",
                       StringFormat("%s -> Asset=%s | AutoProfile='%s' | StepIndex=%s | 24x7=%s | Spread=%.1f pts",
                                    syms[i], AssetClassToString(m_contexts[m_symbolCount].GetContext().symbolProfile.assetClass),
                                    m_contexts[m_symbolCount].GetContext().assetProfile.profileName,
                                    m_contexts[m_symbolCount].GetContext().symbolProfile.isStepIndex ? "YES" : "NO",
                                    m_contexts[m_symbolCount].GetContext().symbolProfile.isSynthetic24x7 ? "YES" : "NO",
                                    m_contexts[m_symbolCount].GetContext().symbolProfile.spreadPoints));
            m_symbolCount++;
         }
         else
         {
            m_diag.Log(LOG_WARN, "EAController", "Skipped unavailable symbol in multi-symbol list: " + syms[i]);
         }
      }

      if(m_symbolCount <= 0)
      {
         m_diag.Log(LOG_ERROR, "EAController", "No valid symbol context initialized.");
         return false;
      }

      m_stratPullback.Configure(m_cfg.enableTrendPullback, m_cfg.defaultSlAtrMult, m_cfg.defaultTpAtrMult, m_cfg.minStrategySampleSize, 20.0, 0.50);
      m_stratMomentum.Configure(m_cfg.enableMomentumScalp, m_cfg.defaultSlAtrMult, m_cfg.defaultTpAtrMult, m_cfg.minStrategySampleSize, 0.012);
      m_stratBreakout.Configure(m_cfg.enableBreakoutScalp, m_cfg.defaultSlAtrMult, m_cfg.defaultTpAtrMult * 1.05, m_cfg.minStrategySampleSize, 0.40, m_cfg.minBreakoutRvol);
      m_stratReversal.Configure(m_cfg.enableReversalScalp, m_cfg.defaultSlAtrMult, m_cfg.defaultTpAtrMult, m_cfg.minStrategySampleSize, 30.0, 70.0);
      m_stratRange.Configure(m_cfg.enableRangeScalp, m_cfg.defaultSlAtrMult * 0.95, m_cfg.defaultTpAtrMult * 0.90, m_cfg.minStrategySampleSize, 22.0);
      m_stratVolExp.Configure(m_cfg.enableVolExpansion, m_cfg.defaultSlAtrMult * 1.08, m_cfg.defaultTpAtrMult * 1.15, m_cfg.minStrategySampleSize, 1.15, MathMax(1.15, m_cfg.minBreakoutRvol));
      m_stratMicro.Configure(m_cfg.enableMicroMomentum, m_cfg.defaultSlAtrMult, m_cfg.defaultTpAtrMult, m_cfg.minStrategySampleSize, 7, 1.2, 12.0);
      m_stratLiqSweep.Configure(m_cfg.enableLiquiditySweep, m_cfg.defaultSlAtrMult * 0.92, m_cfg.defaultTpAtrMult * 1.05, m_cfg.minStrategySampleSize, 0.44);
      m_stratVwapRev.Configure(m_cfg.enableVwapReversion, m_cfg.defaultSlAtrMult * 0.95, m_cfg.defaultTpAtrMult * 0.95, m_cfg.minStrategySampleSize, 1.60);
      m_stratEmaRibbon.Configure(m_cfg.enableEmaRibbon, m_cfg.defaultSlAtrMult, m_cfg.defaultTpAtrMult * 1.12, m_cfg.minStrategySampleSize, 21.0, 46.0, MathMax(1.00, m_cfg.minBreakoutRvol));
      for(int i = 0; i < EA_MAX_STRATEGIES; i++)
      {
         if(m_strategies[i] != NULL)
         {
            m_strategies[i].SetAutoAdaptBySymbol(m_cfg.autoAdaptBySymbol);
            m_strategies[i].SetSnapTpBeforeWalls(m_cfg.snapTpBeforeMajorWalls);
         }
      }

      m_expectancy.Configure(m_cfg.expCfg);
      m_scoring.Configure(m_cfg.valCfg.minSignalScore);
      m_validation.Configure(m_cfg.valCfg);
      m_risk.Initialize(m_cfg.magicNumber, m_cfg.riskCfg, GetPointer(m_diag));
      m_execution.Initialize(m_cfg.magicNumber, m_cfg.maxSlippagePoints, m_cfg.maxOrderRetries, GetPointer(m_diag));
      m_posMgmt.Initialize(m_cfg.magicNumber, m_cfg.posCfg, GetPointer(m_diag));
      m_selector.Configure(m_cfg.minStrategySampleSize, m_cfg.autoSelectBestStrategy, 1.05);
      m_learning.Initialize(m_cfg.enableAdaptiveEvaluation, m_cfg.minStrategySampleSize, m_cfg.deteriorationPfFloor, m_cfg.configLabel, GetPointer(m_diag));
      m_research.Initialize(m_cfg.walkForwardDays, m_cfg.oosSplitRatio);
      m_perfAnalytics.Initialize(m_cfg.magicNumber);
      m_csv.Initialize(m_cfg.enableCSVExports, m_cfg.csvBatchSize, GetPointer(m_diag));

      for(int c = 0; c < EA_MAX_SYMBOLS; c++)
      {
         m_cdSymbols[c] = "";
         m_cdBarsLeft[c] = 0;
         m_lastClosedStratBar[c] = 0;
         m_lastMicroEvalTime[c] = 0;
         m_lastRejBarTime[c] = 0;
         m_lastRejStrat[c] = -1;
         m_lastRejDir[c] = (int)SIGNAL_NONE;
         m_lastRejCode[c] = "";
         m_snipers[c].Reset();
      }

      SPersistedState restored;
      if(!m_isTester && m_stateMgr.LoadState(restored) && restored.magicNumber == m_cfg.magicNumber && restored.symbol == m_primarySymbol)
      {
         m_risk.RestoreAnchors(restored.dayAnchor, restored.weekAnchor, restored.dayStartBalance, restored.weekStartBalance,
                               restored.peakBalance, restored.peakEquity, restored.maxDrawdownPct,
                               restored.consecutiveLosses, restored.maxConsecutiveLosses,
                               restored.lockoutActive, restored.lockoutReason);
         m_learning.RestoreCounts(restored.observationsCount, restored.patternsCount, restored.regimesCount,
                                  restored.signalsGenerated, restored.signalsAccepted, restored.signalsRejected,
                                  restored.lastValidatedConfig, restored.lastValidationTime);
         m_contexts[0].SetLastBarLogged(restored.lastBarProcessed);
      }

      m_posMgmt.RefreshOwnedPositions(m_primarySymbol, *(m_contexts[0].GetSymbolIntelPtr()));
      SyncDealHistoryAndResearch(true);
      if(!m_isTester)
         RestoreExecutionHistory();
      m_lastKnownPositionsTotal = PositionsTotal();
      m_lastRiskUpdateTime = 0;

      m_csv.LogConfiguration(m_monitoredSummary, m_cfg.primaryTF, m_cfg.operatingMode, m_cfg.riskCfg.riskPerTradePct,
                             m_cfg.valCfg.minSignalScore, m_cfg.valCfg.maxSpreadPoints, m_cfg.configLabel);

      m_initialized = true;
      UpdateSnapshot();
      return true;
   }

   void Shutdown()
   {
      if(!m_initialized) return;
      SyncDealHistoryAndResearch();

      double mcMed = 0.0, mcP95 = 0.0;
      bool hasMc = m_research.RunMonteCarloDrawdown95(150, mcMed, mcP95);
      string sessSum = "", symSum = "";
      bool hasSeg = m_perfAnalytics.GetSegmentedSummary(sessSum, symSum);
      if(hasMc || hasSeg)
      {
         string mcPart = hasMc ? StringFormat("MC_MedDD=%.2f MC_P95DD=%.2f | ", mcMed, mcP95) : "";
         m_diag.Log(LOG_INFO, "AnalyticsReport",
                    StringFormat("%s%s | Session[%s] | Symbol[%s]",
                                 mcPart, m_research.GetScoreBandSummary(), sessSum, symSum));
      }

      m_csv.LogSessionSummary(m_primarySymbol, m_perfAnalytics.GetMetrics(), m_learning.GetSummary());
      m_csv.FlushAll(true);
      if(!m_isTester)
         PersistCurrentState(true);
      for(int i = 0; i < m_symbolCount; i++)
         m_contexts[i].Release();
      m_diag.Log(LOG_INFO, "EAController", StringFormat("EA controller v%s shut down cleanly.", EA_PROJECT_VERSION));
      m_initialized = false;
   }

   void ProcessTick()
   {
      if(!m_initialized) return;

      int curPosTotal = PositionsTotal();
      if(curPosTotal != m_lastKnownPositionsTotal)
      {
         m_lastKnownPositionsTotal = curPosTotal;
         m_posMgmt.RefreshOwnedPositions(m_primarySymbol, *(m_contexts[0].GetSymbolIntelPtr()));
         SyncDealHistoryAndResearch();
      }
      else if(curPosTotal > 0 || m_posMgmt.GetCount() > 0)
      {
         m_posMgmt.RefreshOwnedPositions(m_primarySymbol, *(m_contexts[0].GetSymbolIntelPtr()));
      }

      SManagedPosition curPositions[];
      int posCount = m_posMgmt.GetCount();
      if(posCount > 0)
         posCount = m_posMgmt.GetManagedPositions(curPositions);
      else
         ArrayResize(curPositions, 0);

      bool anyNewBar = false;
      bool decisionUpdated = false;
      bool posStateDirty = false;
      SPendingEntryCandidate pendingCands[EA_MAX_SYMBOLS];
      int pendingCount = 0;

      for(int sIdxSym = 0; sIdxSym < m_symbolCount; sIdxSym++)
      {
         bool isNewBar = false;
         if(!m_contexts[sIdxSym].UpdateAnalysis(false, isNewBar))
            continue;
         if(isNewBar) anyNewBar = true;

         string sym = m_contexts[sIdxSym].GetSymbol();
         datetime curBarT = m_contexts[sIdxSym].GetBarTime();
         datetime tickNow = m_contexts[sIdxSym].GetTickTime();
         if(tickNow <= 0) tickNow = SafeCurrentTime();
         bool indReady = m_contexts[sIdxSym].IsIndReady();

         if(posStateDirty)
         {
            m_posMgmt.RefreshOwnedPositions(sym, *(m_contexts[sIdxSym].GetSymbolIntelPtr()));
            posCount = m_posMgmt.GetManagedPositions(curPositions);
            posStateDirty = false;
         }

         bool hasSymPos = false;
         for(int p = 0; p < posCount; p++)
         {
            if(curPositions[p].symbol == sym) { hasSymPos = true; break; }
         }

         bool evalBarStrats = (indReady && (isNewBar || m_lastClosedStratBar[sIdxSym] != curBarT));
         bool evalMicro = evalBarStrats || (!m_cfg.evaluateOnNewBarOnly && indReady && m_contexts[sIdxSym].IsTicksReady() &&
                                            ((tickNow - m_lastMicroEvalTime[sIdxSym]) >= 2 || m_contexts[sIdxSym].IsTickSurge()));
         bool hasArmedSniper = m_snipers[sIdxSym].active;

         if(!hasSymPos && !hasArmedSniper && !isNewBar && !evalBarStrats && !evalMicro)
         {
            // Idle intra-bar tick on flat symbol: keep 1 Hz risk heartbeat on primary symbol and skip heavy context copy
            if(sIdxSym == 0 && (tickNow - m_lastRiskUpdateTime) >= 1)
            {
               m_risk.Update(sym, curPositions, posCount);
               m_lastRiskUpdateTime = tickNow;
            }
            continue;
         }

         SAnalysisContext ctx = m_contexts[sIdxSym].GetContext();

         if(hasSymPos || evalBarStrats || evalMicro || (tickNow - m_lastRiskUpdateTime) >= 1)
         {
            m_risk.Update(sym, curPositions, posCount);
            m_lastRiskUpdateTime = tickNow;
         }

         // Manage existing positions on this symbol (always active even under lockout)
         if(hasSymPos)
         {
            int beforeMgmtTotal = PositionsTotal();
            m_posMgmt.ManageSymbolPositions(sym, ctx, m_contexts[sIdxSym].GetLastSignal(),
                                            *(m_contexts[sIdxSym].GetSymbolIntelPtr()),
                                            m_strategies, EA_MAX_STRATEGIES, m_execution, m_cfg.autoAdaptBySymbol);
            if(PositionsTotal() != beforeMgmtTotal)
            {
               m_lastKnownPositionsTotal = PositionsTotal();
               m_posMgmt.RefreshOwnedPositions(sym, *(m_contexts[sIdxSym].GetSymbolIntelPtr()));
               posCount = m_posMgmt.GetManagedPositions(curPositions);
               m_risk.Update(sym, curPositions, posCount);
               m_lastRiskUpdateTime = tickNow;
               posStateDirty = true;
            }
         }

         // Log observations & advance post-loss cooldown once per closed bar per symbol
         if(isNewBar)
         {
            TickLossCooldown(sym);
            if(m_contexts[sIdxSym].ShouldLogNewBarObservation())
            {
               m_learning.RecordObservation((ctx.candle.pattern != CANDLE_NONE || ctx.chartPattern.pattern != PATTERN_NONE), true);
               m_csv.LogObservation(ctx.market, ctx.ind, ctx.regime, ctx.structure);
               m_csv.LogTickAnalysis(sym, ctx.market.tickTime, ctx.ticks);
               m_csv.LogRegime(sym, m_cfg.primaryTF, ctx.market.tickTime, ctx.regime);
               m_csv.LogPatterns(sym, m_cfg.primaryTF, ctx.market.tickTime, ctx.candle, ctx.chartPattern);
            }
         }

         bool inCooldown = (GetCooldownBars(sym) > 0);
         bool sniperTriggeredThisTick = false;

         // Disarm sniper if position opened, symbol enters cooldown, or market becomes unstable
         if(m_snipers[sIdxSym].active && (hasSymPos || inCooldown || ctx.regime.isUnstable))
         {
            m_snipers[sIdxSym].Reset("Disarmed");
            decisionUpdated = true;
         }

         // Manage armed pullback/extremum entry sniper on live ticks
         if(!hasSymPos && !inCooldown && m_snipers[sIdxSym].active)
         {
            if(isNewBar && ctx.market.barTime != m_snipers[sIdxSym].armedBarTime)
               m_snipers[sIdxSym].barsElapsed++;

            if(m_snipers[sIdxSym].barsElapsed > m_cfg.extremumSniperWaitBars)
            {
               m_snipers[sIdxSym].Reset("Expired");
               decisionUpdated = true;
            }
            else if(!m_execution.IsDuplicateBarExecution(sym, ctx.market.barTime))
            {
               MqlTick sniperTick;
               if(SymbolInfoTick(sym, sniperTick) && sniperTick.bid > 0.0 && sniperTick.ask > 0.0)
               {
                  ENUM_SIGNAL_DIRECTION sDir = m_snipers[sIdxSym].sig.direction;
                  bool slHitOrRunaway = false;
                  if(sDir == SIGNAL_BUY)
                     slHitOrRunaway = (sniperTick.bid <= m_snipers[sIdxSym].sig.stopLoss || sniperTick.ask > m_snipers[sIdxSym].maxChasePrice);
                  else if(sDir == SIGNAL_SELL)
                     slHitOrRunaway = (sniperTick.ask >= m_snipers[sIdxSym].sig.stopLoss || sniperTick.bid < m_snipers[sIdxSym].maxChasePrice);

                  if(slHitOrRunaway)
                  {
                     m_snipers[sIdxSym].Reset("Invalidated");
                     decisionUpdated = true;
                  }
                  else
                  {
                     bool hitPullback = (sDir == SIGNAL_BUY && sniperTick.ask <= m_snipers[sIdxSym].targetPrice) ||
                                        (sDir == SIGNAL_SELL && sniperTick.bid >= m_snipers[sIdxSym].targetPrice);
                     if(hitPullback)
                     {
                        string sCapCode = "", sCapReason = "";
                        if(!CheckFrequencyCaps(tickNow, sCapCode, sCapReason))
                        {
                           m_snipers[sIdxSym].Reset("FreqCap");
                           decisionUpdated = true;
                        }
                        else
                        {
                           STradeSignal trigSig = m_snipers[sIdxSym].sig;
                           trigSig.entryPrice = (sDir == SIGNAL_BUY) ? sniperTick.ask : sniperTick.bid;
                           trigSig.timestamp  = tickNow;

                           SRiskStatus rkS = m_risk.GetStatus();
                           string sVolReason = "";
                           double sLots = m_risk.CalculateFixedFractionalVolume(trigSig, *(m_contexts[sIdxSym].GetSymbolIntelPtr()), sVolReason,
                                                                                ctx.regime.volatilityState, ctx.regime.volatilityRatio);
                           int tsId = (int)trigSig.strategyId;
                           SStrategyStats sStStats = (tsId >= 0 && tsId < EA_MAX_STRATEGIES) ? m_strategies[tsId].GetStats() : m_strategies[0].GetStats();
                           double sEvalLots = (sLots > 0.0) ? sLots : ctx.symbolProfile.volumeMin;
                           m_expectancy.Evaluate(trigSig, ctx.market, *(m_contexts[sIdxSym].GetSymbolIntelPtr()), sStStats, sEvalLots, m_cfg.autoAdaptBySymbol);

                           bool sExecEn = (m_cfg.operatingMode == EA_MODE_DEMO_EXECUTION || m_cfg.operatingMode == EA_MODE_LIVE_TRADING);
                           SValidationResult sValRes = m_validation.Validate(trigSig, ctx.symbolProfile, ctx.market, ctx.ind,
                                                                             ctx.regime, ctx.mtf, rkS,
                                                                             *(m_contexts[sIdxSym].GetSymbolIntelPtr()), sLots, sExecEn,
                                                                             m_cfg.autoAdaptBySymbol);

                           m_contexts[sIdxSym].SetLastDecision(trigSig, sValRes);
                           decisionUpdated = true;
                           if(sIdxSym == 0)
                           {
                              m_lastBestSignal = trigSig;
                              m_lastValidation = sValRes;
                           }

                           if(sValRes.passed)
                           {
                              if(pendingCount < EA_MAX_SYMBOLS)
                              {
                                 pendingCands[pendingCount].ctxIdx     = sIdxSym;
                                 pendingCands[pendingCount].sig        = trigSig;
                                 pendingCands[pendingCount].lots       = sLots;
                                 pendingCands[pendingCount].barTime    = ctx.market.barTime;
                                 pendingCands[pendingCount].tickTime   = tickNow;
                                 pendingCands[pendingCount].regime     = m_snipers[sIdxSym].regime;
                                 pendingCands[pendingCount].sameBarRej = false;
                                 pendingCount++;
                              }
                              m_snipers[sIdxSym].Reset("Triggered");
                              sniperTriggeredThisTick = true;
                           }
                           else
                           {
                              bool transientRej = (sValRes.rejectionCode == "SPREAD_TOO_WIDE" ||
                                                   sValRes.rejectionCode == "SPREAD_SPIKE" ||
                                                   sValRes.rejectionCode == "SPREAD_TO_ATR_HIGH");
                              if(!transientRej)
                                 m_snipers[sIdxSym].Reset("Blocked");
                           }
                        }
                     }
                  }
               }
            }
         }

         // Evaluate strategies for this symbol (9 closed-bar strategies run once per bar; MicroMomentum runs throttled intra-bar)
         if(!sniperTriggeredThisTick && !inCooldown && (evalBarStrats || evalMicro) && !m_execution.IsDuplicateBarExecution(sym, ctx.market.barTime))
         {
            if(evalBarStrats)
               m_lastClosedStratBar[sIdxSym] = ctx.market.barTime;
            if(evalMicro)
               m_lastMicroEvalTime[sIdxSym] = tickNow;

            int bestStratIdx = -1;
            m_selector.EvaluateAll(m_strategies, EA_MAX_STRATEGIES, ctx.regime, bestStratIdx, ctx.symbolProfile.symbolPersonality);

            STradeSignal bestBuy, bestSell;
            bestBuy.Reset();
            bestSell.Reset();
            double bestBuyScore = -1.0, bestSellScore = -1.0;
            int buyCount = 0, sellCount = 0;

            for(int i = 0; i < EA_MAX_STRATEGIES; i++)
            {
               if(!evalBarStrats && i != (int)STRAT_MICRO_MOMENTUM)
                  continue;
               if(m_strategies[i] == NULL || !m_strategies[i].IsEnabled())
                  continue;
               if(!m_selector.IsStrategyPermittedBySelector(m_strategies[i], i, bestStratIdx, ctx.regime))
                  continue;

               STradeSignal cand;
               string rejReason = "";
               if(m_strategies[i].Evaluate(ctx, cand, rejReason))
               {
                  ENUM_STRATEGY_SUITABILITY suit = m_strategies[i].GetRegimeSuitability(ctx.regime.regime);
                  m_scoring.ScoreSignal(cand, ctx, m_strategies[i].GetStats(), suit);

                  if(cand.direction == SIGNAL_BUY)
                  {
                     buyCount++;
                     if(cand.compositeScore > bestBuyScore)
                     {
                        bestBuyScore = cand.compositeScore;
                        bestBuy = cand;
                     }
                  }
                  else if(cand.direction == SIGNAL_SELL)
                  {
                     sellCount++;
                     if(cand.compositeScore > bestSellScore)
                     {
                        bestSellScore = cand.compositeScore;
                        bestSell = cand;
                     }
                  }
               }
            }

            double effMinScore = m_cfg.autoAdaptBySymbol
                                 ? MathMax(m_cfg.valCfg.minSignalScore, ctx.assetProfile.minSignalScore)
                                 : m_cfg.valCfg.minSignalScore;

            double rawBuyScore  = bestBuyScore;
            double rawSellScore = bestSellScore;
            if(bestBuy.isValid)
            {
               bool oppStrong = (bestSell.isValid && rawSellScore >= (effMinScore - 4.0));
               m_scoring.ApplyMultiStrategyConsensus(bestBuy, buyCount, oppStrong);
               bestBuyScore = bestBuy.compositeScore;
            }
            if(bestSell.isValid)
            {
               bool oppStrong = (bestBuy.isValid && rawBuyScore >= (effMinScore - 4.0));
               m_scoring.ApplyMultiStrategyConsensus(bestSell, sellCount, oppStrong);
               bestSellScore = bestSell.compositeScore;
            }

            STradeSignal topSignal;
            topSignal.Reset();
            bool chopConflict = false;
            if(bestBuy.isValid && bestSell.isValid &&
               bestBuyScore >= (effMinScore - 4.0) &&
               bestSellScore >= (effMinScore - 4.0) &&
               buyCount == sellCount &&
               MathAbs(bestBuyScore - bestSellScore) <= 5.0)
            {
               chopConflict = true;
               topSignal = (bestBuyScore >= bestSellScore) ? bestBuy : bestSell;
            }
            else if(bestBuy.isValid || bestSell.isValid)
            {
               topSignal = (bestBuyScore >= bestSellScore) ? bestBuy : bestSell;
            }

            if(topSignal.isValid && chopConflict)
            {
               SValidationResult cRes;
               cRes.Reset();
               cRes.rejectionCode = "OPPOSING_SIGNAL_CONFLICT";
               cRes.rejectionReason = StringFormat("Balanced opposing signals BUY (%.1f) vs SELL (%.1f) within 5 pts.", bestBuyScore, bestSellScore);
               m_contexts[sIdxSym].SetLastDecision(topSignal, cRes);
               decisionUpdated = true;
               if(sIdxSym == 0)
               {
                  m_lastBestSignal = topSignal;
                  m_lastValidation = cRes;
               }
               if(m_diag.IsLevelEnabled(LOG_DEBUG))
                  m_diag.Log(LOG_DEBUG, "StrategyConsensus", sym + " " + cRes.rejectionReason, "chop_" + sym, 60);
            }
            else if(topSignal.isValid)
            {
               int sId = (int)topSignal.strategyId;

               // Avoid repeating identical intra-bar MicroMomentum rejections on static blockers within the same bar
               bool sameBarRej = (!evalBarStrats &&
                                  m_lastRejBarTime[sIdxSym] == ctx.market.barTime &&
                                  m_lastRejStrat[sIdxSym] == sId &&
                                  m_lastRejDir[sIdxSym] == (int)topSignal.direction);
               bool allowCandidate = true;
               if(sameBarRej)
               {
                  string prevCode = m_lastRejCode[sIdxSym];
                  allowCandidate = (prevCode == "SPREAD_TOO_WIDE" || prevCode == "SPREAD_SPIKE" ||
                                    prevCode == "SPREAD_TO_ATR_HIGH" || prevCode == "LIVE_PRICE_EXTENDED" ||
                                    prevCode == "LIVE_PRICE_PAST_SL" ||
                                    (prevCode == "LOW_SIGNAL_SCORE" && topSignal.compositeScore >= effMinScore));
               }

               if(allowCandidate && m_snipers[sIdxSym].active)
               {
                  // Do not supersede an armed pullback sniper on the same bar unless a strong opposite signal arrives
                  if(topSignal.direction != m_snipers[sIdxSym].sig.direction && topSignal.compositeScore >= effMinScore)
                     m_snipers[sIdxSym].Reset("Replaced");
                  else if(topSignal.direction == m_snipers[sIdxSym].sig.direction &&
                          !topSignal.requiresPullbackWait &&
                          topSignal.compositeScore >= m_snipers[sIdxSym].sig.compositeScore + 3.0)
                     m_snipers[sIdxSym].Reset("Upgraded");
                  else
                     allowCandidate = false;
               }

               if(allowCandidate)
               {
               // Immediate strong opposite-signal position exit hook before live entry validation
               if(m_cfg.posCfg.enableOppositeSignalExit && posCount > 0 && !ctx.regime.isUnstable &&
                  topSignal.compositeScore >= MathMax(effMinScore, m_cfg.posCfg.oppositeSignalMinScore))
               {
                  if(m_posMgmt.HandleOppositeSignalExit(sym, ctx, topSignal, *(m_contexts[sIdxSym].GetSymbolIntelPtr()), m_execution))
                  {
                     m_lastKnownPositionsTotal = PositionsTotal();
                     m_posMgmt.RefreshOwnedPositions(sym, *(m_contexts[sIdxSym].GetSymbolIntelPtr()));
                     posCount = m_posMgmt.GetManagedPositions(curPositions);
                     m_risk.Update(sym, curPositions, posCount);
                     SyncDealHistoryAndResearch(false);
                     posStateDirty = true;
                  }
               }

               // Live-price anti-chase and structural SL invalidation guard
               MqlTick liveTick;
               bool liveBlocked = false;
               SValidationResult guardRes;
               guardRes.Reset();
               if(SymbolInfoTick(sym, liveTick) && liveTick.bid > 0.0 && liveTick.ask > 0.0)
               {
                  double liveEntry = (topSignal.direction == SIGNAL_BUY) ? liveTick.ask : liveTick.bid;
                  double effAtr = (ctx.ind.isReady && ctx.ind.atr > 0.0) ? ctx.ind.atr : (ctx.market.spreadPoints * ctx.symbolProfile.point * 6.0);
                  double drift = (topSignal.direction == SIGNAL_BUY) ? (liveEntry - ctx.market.close) : (ctx.market.close - liveEntry);

                  if((topSignal.direction == SIGNAL_BUY && liveTick.bid <= topSignal.stopLoss) ||
                     (topSignal.direction == SIGNAL_SELL && liveTick.ask >= topSignal.stopLoss))
                  {
                     liveBlocked = true;
                     guardRes.rejectionCode = "LIVE_PRICE_PAST_SL";
                     guardRes.rejectionReason = "Live quote already breached proposed stop-loss before execution.";
                  }
                  else if(effAtr > 0.0 && drift > effAtr * 0.75)
                  {
                     liveBlocked = true;
                     guardRes.rejectionCode = "LIVE_PRICE_EXTENDED";
                     guardRes.rejectionReason = StringFormat("Live quote extended %.2fx ATR beyond signal bar close.", drift / effAtr);
                  }
                  else
                  {
                     topSignal.entryPrice = liveEntry;
                  }
               }

               // Trade frequency cap guard (hourly & daily trade throttling)
               if(!liveBlocked)
               {
                  string capCode = "", capReason = "";
                  if(!CheckFrequencyCaps(tickNow, capCode, capReason))
                  {
                     liveBlocked = true;
                     guardRes.rejectionCode = capCode;
                     guardRes.rejectionReason = capReason;
                  }
               }

               // Active symbol position conflict & unhedged pyramiding guard
               if(!liveBlocked && posCount > 0)
               {
                  double refAtr = (ctx.ind.isReady && ctx.ind.atr > 0.0) ? ctx.ind.atr : (ctx.market.spreadPoints * ctx.symbolProfile.point * 6.0);
                  for(int p = 0; p < posCount; p++)
                  {
                     if(curPositions[p].symbol != sym) continue;
                     if(curPositions[p].direction != topSignal.direction)
                     {
                        liveBlocked = true;
                        guardRes.rejectionCode = "SYMBOL_OPPOSITE_POS_ACTIVE";
                        guardRes.rejectionReason = "Opposite direction position already open on symbol; avoiding self-hedge/netting conflict.";
                        break;
                     }
                     if(!ctx.symbolProfile.isHedgingAccount)
                     {
                        liveBlocked = true;
                        guardRes.rejectionCode = "PYRAMID_NETTING_BLOCKED";
                        guardRes.rejectionReason = "Netting account averages open entry price on same-direction add-ons; blocking to preserve break-even.";
                        break;
                     }
                     double favMove = (curPositions[p].direction == SIGNAL_BUY)
                                      ? (curPositions[p].currentPrice - curPositions[p].openPrice)
                                      : (curPositions[p].openPrice - curPositions[p].currentPrice);
                     if(!curPositions[p].breakEvenApplied || (refAtr > 0.0 && favMove < refAtr * 0.85))
                     {
                        liveBlocked = true;
                        guardRes.rejectionCode = "PYRAMID_NOT_RISK_FREE";
                        guardRes.rejectionReason = "Existing same-direction position not yet at break-even (+0.85 ATR); preventing loss stacking.";
                        break;
                     }
                  }
               }

               if(liveBlocked)
               {
                  bool dupGuardRej = (sameBarRej && m_lastRejCode[sIdxSym] == guardRes.rejectionCode);
                  m_contexts[sIdxSym].SetLastDecision(topSignal, guardRes);
                  decisionUpdated = true;
                  if(sIdxSym == 0)
                  {
                     m_lastBestSignal = topSignal;
                     m_lastValidation = guardRes;
                  }
                  if(!dupGuardRej)
                  {
                     m_learning.RecordSignalDecision(false);
                     if(sId >= 0 && sId < EA_MAX_STRATEGIES)
                     {
                        m_strategies[sId].RecordSignalGenerated();
                        m_strategies[sId].RecordSignalRejected();
                     }
                     m_lastRejBarTime[sIdxSym] = ctx.market.barTime;
                     m_lastRejStrat[sIdxSym] = sId;
                     m_lastRejDir[sIdxSym] = (int)topSignal.direction;
                     m_lastRejCode[sIdxSym] = guardRes.rejectionCode;
                     if(m_diag.IsLevelEnabled(LOG_DEBUG))
                        m_diag.Log(LOG_DEBUG, "TradeValidation", sym + " " + guardRes.rejectionReason, "guard_" + sym + "_" + guardRes.rejectionCode, 60);
                  }
               }
               else
               {
                  SRiskStatus rk = m_risk.GetStatus();
                  string volReason = "";
                  double lots = m_risk.CalculateFixedFractionalVolume(topSignal, *(m_contexts[sIdxSym].GetSymbolIntelPtr()), volReason,
                                                                      ctx.regime.volatilityState, ctx.regime.volatilityRatio);

                  SStrategyStats stStats = (sId >= 0 && sId < EA_MAX_STRATEGIES) ? m_strategies[sId].GetStats() : m_strategies[0].GetStats();
                  double evalLots = (lots > 0.0) ? lots : ctx.symbolProfile.volumeMin;
                  m_expectancy.Evaluate(topSignal, ctx.market, *(m_contexts[sIdxSym].GetSymbolIntelPtr()), stStats, evalLots, m_cfg.autoAdaptBySymbol);

                  bool execEnabled = (m_cfg.operatingMode == EA_MODE_DEMO_EXECUTION || m_cfg.operatingMode == EA_MODE_LIVE_TRADING);
                  SValidationResult valRes = m_validation.Validate(topSignal, ctx.symbolProfile, ctx.market, ctx.ind,
                                                                   ctx.regime, ctx.mtf, rk,
                                                                   *(m_contexts[sIdxSym].GetSymbolIntelPtr()), lots, execEnabled,
                                                                   m_cfg.autoAdaptBySymbol);

                  m_contexts[sIdxSym].SetLastDecision(topSignal, valRes);
                  decisionUpdated = true;
                  if(sIdxSym == 0)
                  {
                     m_lastBestSignal = topSignal;
                     m_lastValidation = valRes;
                  }

                  if(valRes.passed)
                  {
                     double sniperAtr = (ctx.ind.isReady && ctx.ind.atr > 0.0) ? ctx.ind.atr : (ctx.market.spreadPoints * ctx.symbolProfile.point * 6.0);
                     bool alreadyAtOpt = (topSignal.optimalEntryPrice <= 0.0) ||
                                         (topSignal.direction == SIGNAL_BUY && topSignal.entryPrice <= topSignal.optimalEntryPrice) ||
                                         (topSignal.direction == SIGNAL_SELL && topSignal.entryPrice >= topSignal.optimalEntryPrice);
                     double improveDist = (topSignal.optimalEntryPrice > 0.0) ? MathAbs(topSignal.entryPrice - topSignal.optimalEntryPrice) : 0.0;
                     bool optSafeSideOfSl = (topSignal.direction == SIGNAL_BUY && topSignal.optimalEntryPrice > topSignal.stopLoss) ||
                                            (topSignal.direction == SIGNAL_SELL && topSignal.optimalEntryPrice < topSignal.stopLoss);

                     bool armSniper = (m_cfg.enableExtremumEntrySniper && m_cfg.extremumSniperWaitBars > 0 &&
                                       !hasSymPos && !m_snipers[sIdxSym].active &&
                                       topSignal.requiresPullbackWait && topSignal.optimalEntryPrice > 0.0 &&
                                       !alreadyAtOpt && optSafeSideOfSl &&
                                       sniperAtr > 0.0 && improveDist >= sniperAtr * m_cfg.extremumPullbackMinAtr);

                     if(armSniper)
                     {
                        double normTarget = m_contexts[sIdxSym].GetSymbolIntelPtr().NormalizePrice(topSignal.optimalEntryPrice);
                        m_snipers[sIdxSym].active        = true;
                        m_snipers[sIdxSym].ctxIdx        = sIdxSym;
                        m_snipers[sIdxSym].sym           = sym;
                        m_snipers[sIdxSym].sig           = topSignal;
                        m_snipers[sIdxSym].targetPrice   = (normTarget > 0.0) ? normTarget : topSignal.optimalEntryPrice;
                        m_snipers[sIdxSym].maxChasePrice = (topSignal.direction == SIGNAL_BUY)
                                                           ? (topSignal.entryPrice + sniperAtr * 0.85)
                                                           : (topSignal.entryPrice - sniperAtr * 0.85);
                        m_snipers[sIdxSym].armedBarTime  = ctx.market.barTime;
                        m_snipers[sIdxSym].barsElapsed   = 0;
                        m_snipers[sIdxSym].regime        = ctx.regime.regime;
                        m_snipers[sIdxSym].statusText    = "Armed";

                        SValidationResult armRes;
                        armRes.Reset();
                        armRes.rejectionCode   = "SNIPER_ARMED_WAIT";
                        armRes.rejectionReason = StringFormat("Armed pullback sniper for %s @ %.*f (wait %d bars).",
                                                              DirectionToString(topSignal.direction),
                                                              ctx.symbolProfile.digits,
                                                              m_snipers[sIdxSym].targetPrice,
                                                              m_cfg.extremumSniperWaitBars);
                        m_contexts[sIdxSym].SetLastDecision(topSignal, armRes);
                        if(sIdxSym == 0)
                        {
                           m_lastBestSignal = topSignal;
                           m_lastValidation = armRes;
                        }
                        if(m_diag.IsLevelEnabled(LOG_INFO))
                           m_diag.Log(LOG_INFO, "EntrySniper", sym + " " + armRes.rejectionReason, "sniper_" + sym, 30);
                     }
                     else if(pendingCount < EA_MAX_SYMBOLS)
                     {
                        pendingCands[pendingCount].ctxIdx = sIdxSym;
                        pendingCands[pendingCount].sig = topSignal;
                        pendingCands[pendingCount].lots = lots;
                        pendingCands[pendingCount].barTime = ctx.market.barTime;
                        pendingCands[pendingCount].tickTime = tickNow;
                        pendingCands[pendingCount].regime = ctx.regime.regime;
                        pendingCands[pendingCount].sameBarRej = sameBarRej;
                        pendingCount++;
                     }
                  }
                  else
                  {
                     bool dupValRej = (sameBarRej && m_lastRejCode[sIdxSym] == valRes.rejectionCode);
                     if(!dupValRej)
                     {
                        m_learning.RecordSignalDecision(false);
                        if(sId >= 0 && sId < EA_MAX_STRATEGIES)
                        {
                           m_strategies[sId].RecordSignalGenerated();
                           m_strategies[sId].RecordSignalRejected();
                        }
                        m_lastRejBarTime[sIdxSym] = ctx.market.barTime;
                        m_lastRejStrat[sIdxSym] = sId;
                        m_lastRejDir[sIdxSym] = (int)topSignal.direction;
                        m_lastRejCode[sIdxSym] = valRes.rejectionCode;
                        ENUM_LOG_SEVERITY sev = (valRes.rejectionCode == "TERMINAL_AUTO_DISABLED" || valRes.rejectionCode == "INSUFFICIENT_MARGIN" || valRes.rejectionCode == "RISK_LOCKOUT") ? LOG_WARN : LOG_DEBUG;
                        if(m_diag.IsLevelEnabled(sev))
                           m_diag.Log(sev, "TradeValidation", StringFormat("%s %s (%s) rejected [%s]: %s", sym, topSignal.strategyName, DirectionToString(topSignal.direction), valRes.rejectionCode, valRes.rejectionReason), "rej_" + sym + "_" + valRes.rejectionCode, 60);
                        m_csv.LogRejectedSignal(sym, m_cfg.primaryTF, topSignal.strategyName, topSignal.direction,
                                                topSignal.compositeScore, ctx.regime.regime,
                                                valRes.rejectionCode, valRes.rejectionReason);
                     }
                  }
               }
               }
            }
         }
      }

      // Cross-Symbol Conviction Priority Queue: execute highest-scored signals first across portfolio
      if(pendingCount > 0)
      {
         for(int a = 0; a < pendingCount - 1; a++)
         {
            for(int b = a + 1; b < pendingCount; b++)
            {
               bool swap = (pendingCands[b].sig.compositeScore > pendingCands[a].sig.compositeScore + 1e-6) ||
                           (MathAbs(pendingCands[b].sig.compositeScore - pendingCands[a].sig.compositeScore) <= 1e-6 &&
                            pendingCands[b].sig.expectancy.netExpectancyMoney > pendingCands[a].sig.expectancy.netExpectancyMoney);
               if(swap)
               {
                  SPendingEntryCandidate tmp = pendingCands[a];
                  pendingCands[a] = pendingCands[b];
                  pendingCands[b] = tmp;
               }
            }
         }

         for(int c = 0; c < pendingCount; c++)
         {
            int cIdx = pendingCands[c].ctxIdx;
            string cSym = m_contexts[cIdx].GetSymbol();
            SAnalysisContext cCtx = m_contexts[cIdx].GetContext();
            STradeSignal cSig = pendingCands[c].sig;
            double cLots = pendingCands[c].lots;
            int cStratId = (int)cSig.strategyId;

            if(posStateDirty || c > 0)
            {
               m_posMgmt.RefreshOwnedPositions(cSym, *(m_contexts[cIdx].GetSymbolIntelPtr()));
               posCount = m_posMgmt.GetManagedPositions(curPositions);
               m_risk.Update(cSym, curPositions, posCount);
               posStateDirty = false;

               string cCapCode = "", cCapReason = "";
               if(!CheckFrequencyCaps(pendingCands[c].tickTime, cCapCode, cCapReason))
               {
                  SValidationResult capRes;
                  capRes.Reset();
                  capRes.rejectionCode = cCapCode;
                  capRes.rejectionReason = cCapReason;
                  m_contexts[cIdx].SetLastDecision(cSig, capRes);
                  decisionUpdated = true;
                  if(cIdx == 0) { m_lastBestSignal = cSig; m_lastValidation = capRes; }
                  continue;
               }

               SRiskStatus rkNow = m_risk.GetStatus();
               string vRsn = "";
               cLots = m_risk.CalculateFixedFractionalVolume(cSig, *(m_contexts[cIdx].GetSymbolIntelPtr()), vRsn,
                                                             cCtx.regime.volatilityState, cCtx.regime.volatilityRatio);
               SStrategyStats cStStats = (cStratId >= 0 && cStratId < EA_MAX_STRATEGIES) ? m_strategies[cStratId].GetStats() : m_strategies[0].GetStats();
               double cEvalLots = (cLots > 0.0) ? cLots : cCtx.symbolProfile.volumeMin;
               m_expectancy.Evaluate(cSig, cCtx.market, *(m_contexts[cIdx].GetSymbolIntelPtr()), cStStats, cEvalLots, m_cfg.autoAdaptBySymbol);
               bool cExecEn = (m_cfg.operatingMode == EA_MODE_DEMO_EXECUTION || m_cfg.operatingMode == EA_MODE_LIVE_TRADING);
               SValidationResult cValRes = m_validation.Validate(cSig, cCtx.symbolProfile, cCtx.market, cCtx.ind,
                                                                 cCtx.regime, cCtx.mtf, rkNow,
                                                                 *(m_contexts[cIdx].GetSymbolIntelPtr()), cLots, cExecEn,
                                                                 m_cfg.autoAdaptBySymbol);
               m_contexts[cIdx].SetLastDecision(cSig, cValRes);
               decisionUpdated = true;
               if(cIdx == 0) { m_lastBestSignal = cSig; m_lastValidation = cValRes; }
               if(!cValRes.passed)
               {
                  if(!(pendingCands[c].sameBarRej && m_lastRejCode[cIdx] == cValRes.rejectionCode))
                  {
                     m_learning.RecordSignalDecision(false);
                     if(cStratId >= 0 && cStratId < EA_MAX_STRATEGIES)
                     {
                        m_strategies[cStratId].RecordSignalGenerated();
                        m_strategies[cStratId].RecordSignalRejected();
                     }
                     m_lastRejBarTime[cIdx] = pendingCands[c].barTime;
                     m_lastRejStrat[cIdx] = cStratId;
                     m_lastRejDir[cIdx] = (int)cSig.direction;
                     m_lastRejCode[cIdx] = cValRes.rejectionCode;
                     m_csv.LogRejectedSignal(cSym, m_cfg.primaryTF, cSig.strategyName, cSig.direction,
                                             cSig.compositeScore, cCtx.regime.regime,
                                             cValRes.rejectionCode, cValRes.rejectionReason);
                  }
                  continue;
               }
            }

            SResearchFoldInfo fold = m_research.GetFoldTag(cCtx.market.tickTime);
            m_learning.RecordSignalDecision(true);
            if(cStratId >= 0 && cStratId < EA_MAX_STRATEGIES)
            {
               m_strategies[cStratId].RecordSignalGenerated();
               m_strategies[cStratId].RecordSignalAccepted();
            }
            m_csv.LogAcceptedSignal(cSig, fold.splitTag);

            if(m_cfg.operatingMode != EA_MODE_RESEARCH_ONLY)
            {
               SExecutionResult exRes = m_execution.Execute(cSig, cLots, *(m_contexts[cIdx].GetSymbolIntelPtr()),
                                                            m_cfg.operatingMode, m_cfg.allowLiveTrading,
                                                            m_cfg.confirmLiveRiskAck, pendingCands[c].barTime);
               if(exRes.executed)
               {
                  RecordExecutionTimestamp(exRes.executionTime);
                  m_contexts[cIdx].RecordFillSlippage(exRes.slippagePoints);
                  m_lastKnownPositionsTotal = PositionsTotal();
                  m_posMgmt.RegisterNewEntryMeta(exRes.positionTicket, cSym, cSig.signalId,
                                                 pendingCands[c].regime, exRes.filledVolume, cSig.stopLoss);
                  posStateDirty = true;
                  m_csv.LogTradeExecutionOrClose(cSym, m_cfg.primaryTF, exRes.positionTicket, cSig.signalId,
                                                 cSig.strategyName, cSig.direction, exRes.filledVolume,
                                                 exRes.filledPrice, cSig.stopLoss, cSig.takeProfit,
                                                 exRes.slippagePoints, exRes.estimatedCostMoney,
                                                 cSig.compositeScore, pendingCands[c].regime, exRes.retcodeDesc,
                                                 "OPENED", 0.0, 0.0, 0.0, 0, fold.splitTag);
               }
            }
         }
      }

      if(posStateDirty || (m_symbolCount > 1 && posCount > 0))
      {
         m_posMgmt.RefreshOwnedPositions(m_primarySymbol, *(m_contexts[0].GetSymbolIntelPtr()));
         posCount = m_posMgmt.GetManagedPositions(curPositions);
         m_risk.Update(m_primarySymbol, curPositions, posCount);
      }
      m_perfAnalytics.UpdateLiveAccountState(curPositions, posCount);

      datetime now = SafeCurrentTime();

      // Adaptive Learning 5-stage evaluation (throttled per closed bar or 60s)
      if(anyNewBar || (now - m_lastLearningEvalTime) >= 60)
      {
         m_lastLearningEvalTime = now;
         SAnalysisContext primaryCtx = m_contexts[0].GetContext();
         double mcMed = 0.0, mcP95 = 0.0;
         bool hasMc = m_research.RunMonteCarloDrawdown95(150, mcMed, mcP95);
         string sessSum = "", symSum = "", researchExtras = "";
         if(m_perfAnalytics.GetSegmentedSummary(sessSum, symSum))
            researchExtras = sessSum;
         if(hasMc)
            researchExtras += (researchExtras != "" ? " | " : "") + StringFormat("MC_P95DD=%.2f", mcP95);

         SLearningProposal prop;
         if(m_learning.EvaluateStrategies(m_strategies, EA_MAX_STRATEGIES, primaryCtx.regime.regime,
                                          m_validation.GetFilterStats(), m_perfAnalytics.GetMetrics().totalTrades,
                                          m_research.GetScoreBandSummary(), prop, researchExtras))
         {
            m_csv.LogLearningProposal(prop);
         }
      }

      if((now - m_lastPerfSnapshotTime) >= 300)
      {
         m_lastPerfSnapshotTime = now;
         for(int i = 0; i < EA_MAX_STRATEGIES; i++)
            m_csv.LogStrategyPerformanceSnapshot(m_primarySymbol, m_strategies[i].GetStats());
         if(m_risk.GetStatus().lockoutActive)
            m_csv.LogRiskEvent(m_primarySymbol, "LOCKOUT_STATUS", m_risk.GetStatus(), m_risk.GetStatus().lockoutReason);
      }

      m_csv.FlushAll(false);
      if(!m_isTester)
         PersistCurrentState(false);

      m_lastAnalysisTime = now;
      if((!m_isTester || m_isVisualTester) && (anyNewBar || decisionUpdated || (now - m_lastSnapshotTime) >= 1))
      {
         m_lastSnapshotTime = now;
         UpdateSnapshot();
      }
   }

   void OnTradeTransactionEvent()
   {
      if(!m_initialized) return;
      m_posMgmt.RefreshOwnedPositions(m_primarySymbol, *(m_contexts[0].GetSymbolIntelPtr()));
      SyncDealHistoryAndResearch();
      m_lastKnownPositionsTotal = PositionsTotal();
      if(!m_isTester)
         PersistCurrentState(true);
      if(!m_isTester || m_isVisualTester)
         UpdateSnapshot();
   }

   void UpdateSnapshot()
   {
      if(m_symbolCount <= 0) return;
      SAnalysisContext ctx0 = m_contexts[0].GetContext();

      m_snapshot.eaName                  = EA_PROJECT_NAME;
      m_snapshot.eaVersion               = EA_PROJECT_VERSION;
      m_snapshot.symbol                  = m_primarySymbol;
      m_snapshot.accountCurrency         = AccountInfoString(ACCOUNT_CURRENCY);
      m_snapshot.monitoredSymbolsSummary = m_monitoredSummary;
      m_snapshot.monitoredSymbolCount    = m_symbolCount;
      m_snapshot.timeframe               = m_cfg.primaryTF;
      m_snapshot.operatingMode           = m_cfg.operatingMode;
      m_snapshot.terminalConnected       = (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
      m_snapshot.tradeAllowedTerminal    = m_isTester ? (bool)MQLInfoInteger(MQL_TRADE_ALLOWED) : ((bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && (bool)MQLInfoInteger(MQL_TRADE_ALLOWED));
      m_snapshot.initialized             = m_initialized;
      m_snapshot.lastAnalysisTime        = m_lastAnalysisTime;
      m_snapshot.operationalStatus       = m_risk.GetStatus().lockoutActive ? "Risk Lockout Active" :
                                           (m_cfg.operatingMode == EA_MODE_RESEARCH_ONLY ? "Research Observing" : "Active");
      m_snapshot.activeStrategyName      = m_lastBestSignal.isValid ? m_lastBestSignal.strategyName : "Scanning (10 Strategies)";
      m_snapshot.sniperActive            = m_snipers[0].active;
      m_snapshot.sniperStatus            = m_snipers[0].active ? "Armed" : m_snipers[0].statusText;
      m_snapshot.sniperDirection         = m_snipers[0].active ? m_snipers[0].sig.direction : SIGNAL_NONE;
      m_snapshot.sniperTargetPrice       = m_snipers[0].active ? m_snipers[0].targetPrice : 0.0;
      m_snapshot.sniperBarsLeft          = m_snipers[0].active ? MathMax(0, m_cfg.extremumSniperWaitBars - m_snipers[0].barsElapsed) : 0;

      m_snapshot.symbolProfile  = ctx0.symbolProfile;
      m_snapshot.market         = ctx0.market;
      m_snapshot.ticks          = ctx0.ticks;
      m_snapshot.indicators     = ctx0.ind;
      m_snapshot.structure      = ctx0.structure;
      m_snapshot.candle         = ctx0.candle;
      m_snapshot.chartPattern   = ctx0.chartPattern;
      m_snapshot.regime         = ctx0.regime;
      m_snapshot.mtf            = ctx0.mtf;
      m_snapshot.lastSignal     = m_lastBestSignal;
      m_snapshot.lastValidation = m_lastValidation;
      m_snapshot.risk           = m_risk.GetStatus();
      m_snapshot.account        = m_perfAnalytics.GetMetrics();
      m_snapshot.intelligence   = m_learning.GetSummary();

      for(int i = 0; i < EA_MAX_STRATEGIES; i++)
         m_snapshot.strategyStats[i] = m_strategies[i].GetStats();
   }

   void GetReadOnlyDashboardData(SDashboardSnapshot &outSnap, SManagedPosition &outPos[], int &outPosCount,
                                 double &outEq[], double &outBal[], double &outDD[],
                                 double &outScoreNet[], int &outScoreTrades[],
                                 double &outRegimeNet[], int &outRegimeTrades[]) const
   {
      outSnap = m_snapshot;
      outPosCount = m_posMgmt.GetManagedPositions(outPos);
      m_perfAnalytics.GetCurveData(outEq, outBal, outDD);
      m_perfAnalytics.GetScoreBandMetrics(outScoreNet, outScoreTrades);
      m_perfAnalytics.GetRegimeMetrics(outRegimeNet, outRegimeTrades);
   }
};

#endif // __ASEA_CORE_EACONTROLLER_MQH__
