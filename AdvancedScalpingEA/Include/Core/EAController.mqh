//+------------------------------------------------------------------+
//|                                                 EAController.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.0.0 Multi-Symbol Orchestrator          |
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

   string symbolOverride;
   string multiSymbolList;
   int    spreadAvgWindow;
   int    tickWindowSize;
   double fallbackCommPerLot;

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
   double defaultSlAtrMult;
   double defaultTpAtrMult;
   bool   evaluateOnNewBarOnly;

   SExpectancyConfig expCfg;
   SValidationConfig valCfg;

   SRiskConfig riskCfg;
   int    maxSlippagePoints;
   int    maxOrderRetries;

   SPosMgmtConfig posCfg;

   int    lossCooldownBars;
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
      configLabel = "AutoAdaptive_v2.3";
      autoAdaptBySymbol = true;
      symbolOverride = "";
      multiSymbolList = "";
      spreadAvgWindow = 120;
      tickWindowSize = 64;
      fallbackCommPerLot = 0.0;
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
      adxWeakThresh = 17.0;
      volHighRatio = 1.45;
      volLowRatio = 0.70;
      spreadUnstableRatio = 2.80;
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
      enableMicroMomentum = true;
      defaultSlAtrMult = 1.60;
      defaultTpAtrMult = 2.80;
      evaluateOnNewBarOnly = true;
      expCfg.ResetDefaults();
      valCfg.ResetDefaults();
      riskCfg.ResetDefaults();
      maxSlippagePoints = 25;
      maxOrderRetries = 2;
      posCfg.ResetDefaults();
      lossCooldownBars = 3;
      autoSelectBestStrategy = false;
      minStrategySampleSize = 20;
      enableAdaptiveEvaluation = true;
      deteriorationPfFloor = 0.85;
      walkForwardDays = 14;
      oosSplitRatio = 0.30;
      enableCSVExports = true;
      csvBatchSize = 12;
      logLevel = LOG_INFO;
      logToFile = true;
      printToJournal = true;
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
   int       m_lastKnownPositionsTotal;

   CDiagnostics         m_diag;
   CStateManager        m_stateMgr;

   CSymbolContext       m_contexts[EA_MAX_SYMBOLS];
   int                  m_symbolCount;
   string               m_monitoredSummary;

   CStrategyTrendPullback       m_stratPullback;
   CStrategyMomentumScalping    m_stratMomentum;
   CStrategyBreakoutScalping    m_stratBreakout;
   CStrategyReversalScalping    m_stratReversal;
   CStrategyRangeScalping       m_stratRange;
   CStrategyVolatilityExpansion m_stratVolExp;
   CStrategyMicroMomentum       m_stratMicro;
   CStrategyBase               *m_strategies[];

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

   void SyncDealHistoryAndResearch()
   {
      SClosedDealEvent events[];
      double totalNewPnL = 0.0;
      SSymbolProfile prof0 = m_contexts[0].GetSymbolIntelPtr().GetProfile();

      int count = m_perfAnalytics.SyncDealHistory(m_strategies, EA_MAX_STRATEGIES, m_posMgmt,
                                                  prof0.isSynthetic24x7, events, totalNewPnL);
      if(count > 0)
      {
         for(int i = 0; i < count; i++)
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
               TriggerLossCooldown(events[i].symbol, cdBars);
            }
            m_research.RecordTradeOutcome(events[i].netPnL, events[i].score);
            SResearchFoldInfo fold = m_research.GetFoldTag(events[i].closeTime);
            m_csv.LogTradeExecutionOrClose(events[i].symbol, m_cfg.primaryTF, events[i].positionTicket,
                                           events[i].signalId, StrategyIdToName(events[i].strategyId),
                                           events[i].direction, events[i].volume, events[i].closePrice,
                                           0.0, 0.0, 0.0, MathAbs(events[i].commission) + MathAbs(events[i].swap),
                                           events[i].score, events[i].entryRegime, "CLOSED", events[i].exitReason,
                                           events[i].netPnL, events[i].mfeMoney, events[i].maeMoney,
                                           events[i].holdSec, fold.splitTag);
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
      }

      ArrayResize(m_strategies, EA_MAX_STRATEGIES);
      m_strategies[0] = GetPointer(m_stratPullback);
      m_strategies[1] = GetPointer(m_stratMomentum);
      m_strategies[2] = GetPointer(m_stratBreakout);
      m_strategies[3] = GetPointer(m_stratReversal);
      m_strategies[4] = GetPointer(m_stratRange);
      m_strategies[5] = GetPointer(m_stratVolExp);
      m_strategies[6] = GetPointer(m_stratMicro);
   }

   bool Initialize(const SEAConfig &cfg)
   {
      m_cfg = cfg;
      m_isTester = (MQLInfoInteger(MQL_TESTER) != 0);
      m_isVisualTester = (MQLInfoInteger(MQL_VISUAL_MODE) != 0);
      m_primarySymbol = (m_cfg.symbolOverride != "") ? m_cfg.symbolOverride : _Symbol;

      ENUM_TIMEFRAMES reqHtf = m_cfg.higherTF;
      ENUM_TIMEFRAMES reqItf = m_cfg.intermediateTF;
      m_cfg.primaryTF      = NormalizeTimeframe(m_cfg.primaryTF, (ENUM_TIMEFRAMES)_Period);
      m_cfg.intermediateTF = NormalizeTimeframe(m_cfg.intermediateTF, PERIOD_M15);
      m_cfg.higherTF       = NormalizeTimeframe(m_cfg.higherTF, PERIOD_H1);
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
            m_cfg.autoAdaptBySymbol, GetPointer(m_diag)
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

      m_stratPullback.Configure(m_cfg.enableTrendPullback, m_cfg.defaultSlAtrMult, m_cfg.defaultTpAtrMult, m_cfg.minStrategySampleSize, 18.0, 0.70);
      m_stratMomentum.Configure(m_cfg.enableMomentumScalp, m_cfg.defaultSlAtrMult, m_cfg.defaultTpAtrMult, m_cfg.minStrategySampleSize, 0.015);
      m_stratBreakout.Configure(m_cfg.enableBreakoutScalp, m_cfg.defaultSlAtrMult, m_cfg.defaultTpAtrMult * 1.05, m_cfg.minStrategySampleSize, 0.35);
      m_stratReversal.Configure(m_cfg.enableReversalScalp, m_cfg.defaultSlAtrMult, m_cfg.defaultTpAtrMult, m_cfg.minStrategySampleSize, 32.0, 68.0);
      m_stratRange.Configure(m_cfg.enableRangeScalp, m_cfg.defaultSlAtrMult * 0.95, m_cfg.defaultTpAtrMult * 0.88, m_cfg.minStrategySampleSize, 22.0);
      m_stratVolExp.Configure(m_cfg.enableVolExpansion, m_cfg.defaultSlAtrMult * 1.08, m_cfg.defaultTpAtrMult * 1.15, m_cfg.minStrategySampleSize, 1.15);
      m_stratMicro.Configure(m_cfg.enableMicroMomentum, m_cfg.defaultSlAtrMult, m_cfg.defaultTpAtrMult * 0.95, m_cfg.minStrategySampleSize, 5, 1.0, 20.0);
      for(int i = 0; i < EA_MAX_STRATEGIES; i++)
      {
         if(m_strategies[i] != NULL)
            m_strategies[i].SetAutoAdaptBySymbol(m_cfg.autoAdaptBySymbol);
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
      SyncDealHistoryAndResearch();
      m_lastKnownPositionsTotal = PositionsTotal();

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

      m_posMgmt.RefreshOwnedPositions(m_primarySymbol, *(m_contexts[0].GetSymbolIntelPtr()));
      SManagedPosition curPositions[];
      int posCount = m_posMgmt.GetManagedPositions(curPositions);

      bool anyNewBar = false;
      bool decisionUpdated = false;
      bool posStateDirty = false;

      for(int sIdxSym = 0; sIdxSym < m_symbolCount; sIdxSym++)
      {
         bool isNewBar = false;
         if(!m_contexts[sIdxSym].UpdateAnalysis(false, isNewBar))
            continue;
         if(isNewBar) anyNewBar = true;

         string sym = m_contexts[sIdxSym].GetSymbol();
         SAnalysisContext ctx = m_contexts[sIdxSym].GetContext();

         if(posStateDirty)
         {
            m_posMgmt.RefreshOwnedPositions(sym, *(m_contexts[sIdxSym].GetSymbolIntelPtr()));
            posCount = m_posMgmt.GetManagedPositions(curPositions);
            posStateDirty = false;
         }
         m_risk.Update(sym, curPositions, posCount);

         int beforeMgmtTotal = PositionsTotal();
         // Manage existing positions on this symbol (always active even under lockout)
         m_posMgmt.ManageSymbolPositions(sym, ctx, m_contexts[sIdxSym].GetLastSignal(),
                                         *(m_contexts[sIdxSym].GetSymbolIntelPtr()),
                                         m_strategies, EA_MAX_STRATEGIES, m_execution, m_cfg.autoAdaptBySymbol);
         if(PositionsTotal() != beforeMgmtTotal)
         {
            m_lastKnownPositionsTotal = PositionsTotal();
            m_posMgmt.RefreshOwnedPositions(sym, *(m_contexts[sIdxSym].GetSymbolIntelPtr()));
            posCount = m_posMgmt.GetManagedPositions(curPositions);
            m_risk.Update(sym, curPositions, posCount);
            posStateDirty = true;
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
         datetime tickNow = (ctx.market.tickTime > 0) ? ctx.market.tickTime : TimeCurrent();
         bool evalBarStrats = (ctx.ind.isReady && (isNewBar || m_lastClosedStratBar[sIdxSym] != ctx.market.barTime));
         bool evalMicro = evalBarStrats || (!m_cfg.evaluateOnNewBarOnly && ctx.ind.isReady && ctx.ticks.isReady &&
                                            ((tickNow - m_lastMicroEvalTime[sIdxSym]) >= 2 || ctx.ticks.suddenActivitySurge));

         // Evaluate strategies for this symbol (closed-bar strategies 0..5 run once per bar; MicroMomentum runs throttled intra-bar)
         if(!inCooldown && (evalBarStrats || evalMicro) && !m_execution.IsDuplicateBarExecution(sym, ctx.market.barTime))
         {
            if(evalBarStrats)
               m_lastClosedStratBar[sIdxSym] = ctx.market.barTime;
            if(evalMicro)
               m_lastMicroEvalTime[sIdxSym] = tickNow;

            int bestStratIdx = -1;
            m_selector.EvaluateAll(m_strategies, EA_MAX_STRATEGIES, ctx.regime, bestStratIdx);

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

            STradeSignal topSignal;
            topSignal.Reset();
            bool chopConflict = false;
            if(bestBuy.isValid && bestSell.isValid &&
               bestBuyScore >= (effMinScore - 4.0) &&
               bestSellScore >= (effMinScore - 4.0) &&
               MathAbs(bestBuyScore - bestSellScore) <= 6.0)
            {
               chopConflict = true;
               topSignal = (bestBuyScore >= bestSellScore) ? bestBuy : bestSell;
            }
            else if(bestBuy.isValid || bestSell.isValid)
            {
               if(bestBuyScore >= bestSellScore)
               {
                  topSignal = bestBuy;
                  bool oppWeak = (bestSell.isValid && bestSellScore >= (effMinScore - 4.0));
                  m_scoring.ApplyMultiStrategyConsensus(topSignal, buyCount, oppWeak);
               }
               else
               {
                  topSignal = bestSell;
                  bool oppWeak = (bestBuy.isValid && bestBuyScore >= (effMinScore - 4.0));
                  m_scoring.ApplyMultiStrategyConsensus(topSignal, sellCount, oppWeak);
               }
            }

            if(topSignal.isValid && chopConflict)
            {
               SValidationResult cRes;
               cRes.Reset();
               cRes.rejectionCode = "OPPOSING_SIGNAL_CONFLICT";
               cRes.rejectionReason = StringFormat("Conflicting BUY (%.1f) vs SELL (%.1f) within 6 pts.", bestBuyScore, bestSellScore);
               m_contexts[sIdxSym].SetLastDecision(topSignal, cRes);
               decisionUpdated = true;
               if(sIdxSym == 0)
               {
                  m_lastBestSignal = topSignal;
                  m_lastValidation = cRes;
               }
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
               if(sameBarRej)
               {
                  string prevCode = m_lastRejCode[sIdxSym];
                  bool canRetry = (prevCode == "SPREAD_TOO_WIDE" || prevCode == "SPREAD_SPIKE" ||
                                   prevCode == "SPREAD_TO_ATR_HIGH" || prevCode == "LIVE_PRICE_EXTENDED" ||
                                   prevCode == "LIVE_PRICE_PAST_SL" ||
                                   (prevCode == "LOW_SIGNAL_SCORE" && topSignal.compositeScore >= effMinScore));
                  if(!canRetry)
                     continue;
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
                     m_diag.Log(LOG_DEBUG, "TradeValidation", sym + " " + guardRes.rejectionReason, "guard_" + sym + "_" + guardRes.rejectionCode, 60);
                  }
               }
               else
               {
                  SRiskStatus rk = m_risk.GetStatus();
                  string volReason = "";
                  double lots = m_risk.CalculateFixedFractionalVolume(topSignal, *(m_contexts[sIdxSym].GetSymbolIntelPtr()), volReason);

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
                     SResearchFoldInfo fold = m_research.GetFoldTag(ctx.market.tickTime);
                     m_learning.RecordSignalDecision(true);
                     if(sId >= 0 && sId < EA_MAX_STRATEGIES)
                     {
                        m_strategies[sId].RecordSignalGenerated();
                        m_strategies[sId].RecordSignalAccepted();
                     }
                     m_csv.LogAcceptedSignal(topSignal, fold.splitTag);

                     if(m_cfg.operatingMode != EA_MODE_RESEARCH_ONLY)
                     {
                        SExecutionResult exRes = m_execution.Execute(topSignal, lots, *(m_contexts[sIdxSym].GetSymbolIntelPtr()),
                                                                     m_cfg.operatingMode, m_cfg.allowLiveTrading,
                                                                     m_cfg.confirmLiveRiskAck, ctx.market.barTime);
                        if(exRes.executed)
                        {
                           m_contexts[sIdxSym].RecordFillSlippage(exRes.slippagePoints);
                           m_lastKnownPositionsTotal = PositionsTotal();
                           m_posMgmt.RegisterNewEntryMeta(exRes.positionTicket, sym, topSignal.signalId,
                                                          ctx.regime.regime, exRes.filledVolume, topSignal.stopLoss);
                           posStateDirty = true;
                           m_csv.LogTradeExecutionOrClose(sym, m_cfg.primaryTF, exRes.positionTicket, topSignal.signalId,
                                                          topSignal.strategyName, topSignal.direction, exRes.filledVolume,
                                                          exRes.filledPrice, topSignal.stopLoss, topSignal.takeProfit,
                                                          exRes.slippagePoints, exRes.estimatedCostMoney,
                                                          topSignal.compositeScore, ctx.regime.regime, exRes.retcodeDesc,
                                                          "OPENED", 0.0, 0.0, 0.0, 0, fold.splitTag);
                        }
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

      if(posStateDirty || m_symbolCount > 1)
      {
         m_posMgmt.RefreshOwnedPositions(m_primarySymbol, *(m_contexts[0].GetSymbolIntelPtr()));
         posCount = m_posMgmt.GetManagedPositions(curPositions);
         m_risk.Update(m_primarySymbol, curPositions, posCount);
      }
      m_perfAnalytics.UpdateLiveAccountState(curPositions, posCount);

      datetime now = (TimeCurrent() > 0) ? TimeCurrent() : TimeLocal();

      // Adaptive Learning 5-stage evaluation (throttled per closed bar or 60s)
      if(anyNewBar || (now - m_lastLearningEvalTime) >= 60)
      {
         m_lastLearningEvalTime = now;
         SAnalysisContext primaryCtx = m_contexts[0].GetContext();
         SLearningProposal prop;
         if(m_learning.EvaluateStrategies(m_strategies, EA_MAX_STRATEGIES, primaryCtx.regime.regime,
                                          m_validation.GetFilterStats(), m_perfAnalytics.GetMetrics().totalTrades,
                                          m_research.GetScoreBandSummary(), prop))
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
      m_snapshot.activeStrategyName      = m_lastBestSignal.isValid ? m_lastBestSignal.strategyName : "Scanning (7 Strategies)";

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
