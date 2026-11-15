//+------------------------------------------------------------------+
//|                                                 EAController.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        Central Orchestration & Lifecycle Manager |
//+------------------------------------------------------------------+
#ifndef __ASEA_CORE_EACONTROLLER_MQH__
#define __ASEA_CORE_EACONTROLLER_MQH__

#include "Types.mqh"
#include "Diagnostics.mqh"
#include "StateManager.mqh"
#include "../Market/SymbolIntelligence.mqh"
#include "../Market/MarketData.mqh"
#include "../Market/TickAnalysis.mqh"
#include "../Market/MarketStructure.mqh"
#include "../Market/MarketRegime.mqh"
#include "../Market/MultiTimeframe.mqh"
#include "../Indicators/IndicatorEngine.mqh"
#include "../Indicators/CandlestickRecognition.mqh"
#include "../Indicators/PatternRecognition.mqh"
#include "../Strategies/StrategyBase.mqh"
#include "../Strategies/TrendPullback.mqh"
#include "../Strategies/MomentumScalping.mqh"
#include "../Strategies/BreakoutScalping.mqh"
#include "../Strategies/ReversalScalping.mqh"
#include "../Strategies/RangeScalping.mqh"
#include "../Strategies/VolatilityExpansion.mqh"
#include "../Strategies/MicroMomentum.mqh"
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
   // 1. General
   ENUM_EA_OPERATING_MODE operatingMode;
   bool   allowLiveTrading;
   bool   confirmLiveRiskAck;
   long   magicNumber;
   string configLabel;

   // 2. Symbol & Market Data
   string symbolOverride;
   int    spreadAvgWindow;
   int    tickWindowSize;

   // 4. Timeframes
   ENUM_TIMEFRAMES primaryTF;
   ENUM_TIMEFRAMES intermediateTF;
   ENUM_TIMEFRAMES higherTF;

   // 5. Indicators
   SIndicatorConfig indCfg;

   // 6. Structure & Regime
   int    swingStrength;
   int    structureLookback;
   double zoneAtrMult;
   double adxStrongThresh;
   double adxWeakThresh;
   double volHighRatio;
   double volLowRatio;
   double spreadUnstableRatio;

   // 7 & 8. Candlestick & Chart Patterns
   double dojiBodyMaxRatio;
   double pinWickMinRatio;
   int    patternLookback;
   double patternTolAtrMult;

   // 9. Strategies
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

   // 10 & 11. Scoring & Validation
   SValidationConfig valCfg;

   // 12. Risk Management
   SRiskConfig riskCfg;
   int    maxSlippagePoints;
   int    maxOrderRetries;

   // 13. Position Management
   SPosMgmtConfig posCfg;

   // 15. Learning & Research
   bool   autoSelectBestStrategy;
   int    minStrategySampleSize;
   bool   enableAdaptiveEvaluation;
   double deteriorationPfFloor;
   int    walkForwardDays;
   double oosSplitRatio;

   // 16 & 18. CSV & Diagnostics
   bool   enableCSVExports;
   int    csvBatchSize;
   ENUM_LOG_SEVERITY logLevel;
   bool   logToFile;
   bool   printToJournal;

   void ResetDefaults()
   {
      operatingMode = EA_MODE_RESEARCH_ONLY;
      allowLiveTrading = false;
      confirmLiveRiskAck = false;
      magicNumber = 510299;
      configLabel = "Default_Research_v1";
      symbolOverride = "";
      spreadAvgWindow = 120;
      tickWindowSize = 64;
      primaryTF = PERIOD_M5;
      intermediateTF = PERIOD_M15;
      higherTF = PERIOD_H1;
      indCfg.ResetDefaults();
      swingStrength = 3;
      structureLookback = 120;
      zoneAtrMult = 0.35;
      adxStrongThresh = 28.0;
      adxWeakThresh = 18.0;
      volHighRatio = 1.45;
      volLowRatio = 0.70;
      spreadUnstableRatio = 2.20;
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
      defaultSlAtrMult = 1.5;
      defaultTpAtrMult = 2.2;
      evaluateOnNewBarOnly = false;
      valCfg.ResetDefaults();
      riskCfg.ResetDefaults();
      maxSlippagePoints = 25;
      maxOrderRetries = 2;
      posCfg.ResetDefaults();
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
   string    m_symbol;
   bool      m_initialized;
   datetime  m_lastAnalysisTime;
   datetime  m_lastBarObsLogged;
   datetime  m_lastPerfSnapshotTime;

   // Core & Market
   CDiagnostics         m_diag;
   CStateManager        m_stateMgr;
   CSymbolIntelligence  m_symIntel;
   CMarketData          m_marketData;
   CTickAnalysis        m_tickAnalysis;
   CIndicatorEngine     m_indEngine;
   CMarketStructure     m_structure;
   CMarketRegime        m_regime;
   CMultiTimeframe      m_mtf;
   CCandlestickRecognition m_candles;
   CPatternRecognition  m_patterns;

   // 7 Independent Strategies
   CStrategyTrendPullback       m_stratPullback;
   CStrategyMomentumScalping    m_stratMomentum;
   CStrategyBreakoutScalping    m_stratBreakout;
   CStrategyReversalScalping    m_stratReversal;
   CStrategyRangeScalping       m_stratRange;
   CStrategyVolatilityExpansion m_stratVolExp;
   CStrategyMicroMomentum       m_stratMicro;
   CStrategyBase               *m_strategies[];

   // Trading, Risk, Intelligence, Analytics
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

   // Latest read-only snapshot cache
   SDashboardSnapshot   m_snapshot;
   STradeSignal         m_lastBestSignal;
   SValidationResult    m_lastValidation;

   void SyncDealHistoryAndResearch()
   {
      double closedPnL = 0.0;
      string closedSym = "";
      ENUM_STRATEGY_ID closedStrat = STRAT_TREND_PULLBACK;
      long closedHold = 0;

      SSymbolProfile prof = m_symIntel.GetProfile();
      int count = m_perfAnalytics.SyncDealHistory(m_strategies, EA_MAX_STRATEGIES, prof.isSynthetic24x7,
                                                  closedPnL, closedSym, closedStrat, closedHold);
      if(count > 0)
      {
         m_risk.RecordClosedTradePnL(closedPnL);
         m_research.RecordTradePnL(closedPnL);
         SResearchFoldInfo fold = m_research.GetFoldTag(TimeCurrent());
         m_csv.LogTradeExecutionOrClose(closedSym, m_cfg.primaryTF, 0, StrategyIdToName(closedStrat),
                                        SIGNAL_NONE, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                                        m_regime.GetState().regime, "CLOSED", closedPnL, closedHold, fold.splitTag);
      }
   }

   void PersistCurrentState(const bool force = false)
   {
      SPersistedState st;
      st.Reset();
      st.magicNumber = m_cfg.magicNumber;
      st.symbol      = m_symbol;
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
      st.lastBarProcessed     = m_lastBarObsLogged;

      SIntelligenceSummary intel = m_learning.GetSummary();
      st.observationsCount   = intel.observationsCollected;
      st.patternsCount       = intel.patternsDetected;
      st.regimesCount        = intel.regimesAnalyzed;
      st.signalsGenerated    = intel.signalsGenerated;
      st.signalsAccepted     = intel.signalsAccepted;
      st.signalsRejected     = intel.signalsRejected;
      st.lastValidatedConfig = intel.lastValidatedConfig;
      st.lastValidationTime  = intel.lastValidationTime;

      m_stateMgr.SaveState(st, force);
   }

public:
   CEAController()
   {
      m_cfg.ResetDefaults();
      m_symbol = "";
      m_initialized = false;
      m_lastAnalysisTime = 0;
      m_lastBarObsLogged = 0;
      m_lastPerfSnapshotTime = 0;
      m_snapshot.Reset();
      m_lastBestSignal.Reset();
      m_lastValidation.Reset();

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
      m_symbol = (m_cfg.symbolOverride != "") ? m_cfg.symbolOverride : _Symbol;
      if(m_cfg.primaryTF == PERIOD_CURRENT) m_cfg.primaryTF = (ENUM_TIMEFRAMES)_Period;

      // Enforce Research/Demo default safety: live mode strictly blocked unless BOTH ack flags are true
      if(m_cfg.operatingMode == EA_MODE_LIVE_TRADING && (!m_cfg.allowLiveTrading || !m_cfg.confirmLiveRiskAck))
      {
         m_cfg.operatingMode = EA_MODE_RESEARCH_ONLY;
      }

      m_diag.Initialize(m_symbol, m_cfg.magicNumber, m_cfg.logLevel, m_cfg.logToFile, m_cfg.printToJournal);
      m_diag.Log(LOG_INFO, "EAController", StringFormat("Initializing %s v%s on %s %s in %s mode",
                                                        EA_PROJECT_NAME, EA_PROJECT_VERSION, m_symbol,
                                                        EnumToString(m_cfg.primaryTF), OperatingModeToString(m_cfg.operatingMode)));

      m_stateMgr.Initialize(m_symbol, m_cfg.magicNumber, GetPointer(m_diag));

      if(!m_symIntel.Initialize(m_symbol, m_cfg.primaryTF, GetPointer(m_diag)))
      {
         m_diag.Log(LOG_ERROR, "EAController", "SymbolIntelligence initialization failed.");
         return false;
      }

      m_marketData.Initialize(m_symbol, m_cfg.primaryTF, m_cfg.spreadAvgWindow, GetPointer(m_symIntel), GetPointer(m_diag));
      m_tickAnalysis.Initialize(m_symbol, m_cfg.tickWindowSize, GetPointer(m_symIntel));
      m_indEngine.Initialize(m_symbol, m_cfg.primaryTF, m_cfg.indCfg, GetPointer(m_diag));
      m_structure.Configure(m_cfg.swingStrength, m_cfg.structureLookback, m_cfg.zoneAtrMult);
      m_regime.Configure(m_cfg.adxStrongThresh, m_cfg.adxWeakThresh, m_cfg.volHighRatio, m_cfg.volLowRatio, m_cfg.spreadUnstableRatio);
      m_mtf.Initialize(m_symbol, m_cfg.higherTF, m_cfg.intermediateTF, m_cfg.primaryTF, GetPointer(m_diag));
      m_candles.Configure(m_cfg.dojiBodyMaxRatio, m_cfg.pinWickMinRatio);
      m_patterns.Configure(m_cfg.patternLookback, m_cfg.swingStrength, m_cfg.patternTolAtrMult);

      // Configure 7 independent strategies
      m_stratPullback.Configure(m_cfg.enableTrendPullback, m_cfg.defaultSlAtrMult, m_cfg.defaultTpAtrMult, m_cfg.minStrategySampleSize, 18.0, 0.65);
      m_stratMomentum.Configure(m_cfg.enableMomentumScalp, m_cfg.defaultSlAtrMult, m_cfg.defaultTpAtrMult, m_cfg.minStrategySampleSize, 0.03);
      m_stratBreakout.Configure(m_cfg.enableBreakoutScalp, m_cfg.defaultSlAtrMult, m_cfg.defaultTpAtrMult * 1.1, m_cfg.minStrategySampleSize, 0.45);
      m_stratReversal.Configure(m_cfg.enableReversalScalp, m_cfg.defaultSlAtrMult, m_cfg.defaultTpAtrMult, m_cfg.minStrategySampleSize, 32.0, 68.0);
      m_stratRange.Configure(m_cfg.enableRangeScalp, m_cfg.defaultSlAtrMult * 0.9, m_cfg.defaultTpAtrMult * 0.85, m_cfg.minStrategySampleSize, 22.0);
      m_stratVolExp.Configure(m_cfg.enableVolExpansion, m_cfg.defaultSlAtrMult * 1.1, m_cfg.defaultTpAtrMult * 1.2, m_cfg.minStrategySampleSize, 1.25);
      m_stratMicro.Configure(m_cfg.enableMicroMomentum, m_cfg.defaultSlAtrMult * 0.85, m_cfg.defaultTpAtrMult * 0.8, m_cfg.minStrategySampleSize, 4, 2.0, 18.0);

      m_scoring.Configure(m_cfg.valCfg.minSignalScore);
      m_validation.Configure(m_cfg.valCfg);
      m_risk.Initialize(m_cfg.magicNumber, m_cfg.riskCfg, GetPointer(m_diag));
      m_execution.Initialize(m_cfg.magicNumber, m_cfg.maxSlippagePoints, m_cfg.maxOrderRetries, GetPointer(m_diag));
      m_posMgmt.Initialize(m_cfg.magicNumber, m_cfg.posCfg, GetPointer(m_diag));
      m_selector.Configure(m_cfg.minStrategySampleSize, m_cfg.autoSelectBestStrategy, 1.05);
      m_learning.Initialize(m_cfg.enableAdaptiveEvaluation, m_cfg.minStrategySampleSize, m_cfg.deteriorationPfFloor, GetPointer(m_diag));
      m_research.Initialize(m_cfg.walkForwardDays, m_cfg.oosSplitRatio);
      m_perfAnalytics.Initialize(m_cfg.magicNumber);
      m_csv.Initialize(m_cfg.enableCSVExports, m_cfg.csvBatchSize, GetPointer(m_diag));

      // Attempt restart recovery
      SPersistedState restored;
      if(m_stateMgr.LoadState(restored) && restored.magicNumber == m_cfg.magicNumber && restored.symbol == m_symbol)
      {
         m_risk.RestoreAnchors(restored.dayAnchor, restored.weekAnchor, restored.dayStartBalance, restored.weekStartBalance,
                               restored.peakBalance, restored.peakEquity, restored.maxDrawdownPct,
                               restored.consecutiveLosses, restored.maxConsecutiveLosses,
                               restored.lockoutActive, restored.lockoutReason);
         m_learning.RestoreCounts(restored.observationsCount, restored.patternsCount, restored.regimesCount,
                                  restored.signalsGenerated, restored.signalsAccepted, restored.signalsRejected,
                                  restored.lastValidatedConfig, restored.lastValidationTime);
         m_lastBarObsLogged = restored.lastBarProcessed;
      }

      // Reconstruct EA-owned positions and historical deals
      m_posMgmt.RefreshOwnedPositions(m_symIntel);
      SyncDealHistoryAndResearch();

      m_csv.LogConfiguration(m_symbol, m_cfg.primaryTF, m_cfg.operatingMode, m_cfg.riskCfg.riskPerTradePct,
                             m_cfg.valCfg.minSignalScore, m_cfg.valCfg.maxSpreadPoints, m_cfg.configLabel);

      m_initialized = true;
      UpdateSnapshot();
      return true;
   }

   void Shutdown()
   {
      if(!m_initialized) return;
      m_csv.LogSessionSummary(m_symbol, m_perfAnalytics.GetMetrics(), m_learning.GetSummary());
      m_csv.FlushAll(true);
      PersistCurrentState(true);
      m_indEngine.Release();
      m_mtf.Release();
      m_diag.Log(LOG_INFO, "EAController", "EA controller shut down cleanly.");
      m_initialized = false;
   }

   void ProcessTick()
   {
      if(!m_initialized) return;

      // 1. Update Symbol & Market Data + Tick Analysis
      m_symIntel.Refresh(m_cfg.primaryTF);
      if(!m_marketData.Update())
      {
         UpdateSnapshot();
         return;
      }

      SMarketSnapshot market = m_marketData.GetSnapshot();
      m_tickAnalysis.OnTickUpdate(market);
      bool isNewBar = m_marketData.IsNewClosedBar();

      // 2. Refresh EA-owned positions & Risk status (always active even if entries are locked out)
      m_posMgmt.RefreshOwnedPositions(m_symIntel);
      SManagedPosition curPositions[];
      int posCount = m_posMgmt.GetManagedPositions(curPositions);
      m_risk.Update(m_symbol, curPositions, posCount);
      m_perfAnalytics.UpdateLiveAccountState(curPositions, posCount);

      // 3. Indicators, Structure, Patterns, Regime, Multi-Timeframe
      SSymbolProfile prof = m_symIntel.GetProfile();
      m_indEngine.Update(m_marketData, prof.hasRealVolume);
      SIndicatorValues ind = m_indEngine.GetValues();
      STickMetrics ticks = m_tickAnalysis.GetMetrics();

      if(ind.isReady)
      {
         m_structure.Analyze(m_marketData, m_cfg.primaryTF, ind.atr);
         m_candles.Analyze(m_marketData, m_cfg.primaryTF, ind, m_structure.GetState());
         m_patterns.Analyze(m_marketData, m_cfg.primaryTF, ind.atr);
         m_regime.Classify(m_marketData, m_cfg.primaryTF, ind, m_structure.GetState(), ticks);
         m_mtf.Evaluate(m_marketData, ind, ticks);
      }

      SRegimeState regime = m_regime.GetState();
      SStructureState structure = m_structure.GetState();
      SCandleSignal candle = m_candles.GetSignal();
      SChartPatternSignal pattern = m_patterns.GetSignal();
      SMTFAnalysis mtf = m_mtf.GetAnalysis();

      // 4. Manage existing EA-owned positions (protective stops & exits remain active under lockout)
      m_posMgmt.ManageActivePositions(m_symbol, market, ind, structure, m_lastBestSignal, m_symIntel, m_execution);

      // Log bar observations once per closed bar
      if(isNewBar && market.barTime != m_lastBarObsLogged && ind.isReady)
      {
         m_lastBarObsLogged = market.barTime;
         m_learning.RecordObservation((candle.pattern != CANDLE_NONE || pattern.pattern != PATTERN_NONE), true);
         m_csv.LogObservation(market, ind, regime, structure);
         m_csv.LogTickAnalysis(m_symbol, market.tickTime, ticks);
         m_csv.LogRegime(m_symbol, m_cfg.primaryTF, market.tickTime, regime);
         m_csv.LogPatterns(m_symbol, m_cfg.primaryTF, market.tickTime, candle, pattern);
      }

      // 5. Strategy Selection & Signal Evaluation
      if(!m_cfg.evaluateOnNewBarOnly || isNewBar)
      {
         int bestStratIdx = -1;
         m_selector.EvaluateAll(m_strategies, EA_MAX_STRATEGIES, regime.regime, bestStratIdx);

         SAnalysisContext ctx;
         ctx.symbolProfile = prof;
         ctx.market = market;
         ctx.ticks = ticks;
         ctx.ind = ind;
         ctx.structure = structure;
         ctx.candle = candle;
         ctx.chartPattern = pattern;
         ctx.regime = regime;
         ctx.mtf = mtf;

         STradeSignal topSignal;
         topSignal.Reset();
         double topScore = -1.0;

         for(int i = 0; i < EA_MAX_STRATEGIES; i++)
         {
            if(m_strategies[i] == NULL || !m_strategies[i].IsEnabled())
               continue;
            if(!m_selector.IsStrategyPermittedBySelector(m_strategies[i], i, bestStratIdx))
               continue;

            STradeSignal cand;
            string rejReason = "";
            if(m_strategies[i].Evaluate(ctx, cand, rejReason))
            {
               m_strategies[i].RecordSignalGenerated();
               bool suitable = m_strategies[i].IsSuitableForRegime(regime.regime);
               m_scoring.ScoreSignal(cand, ctx, m_strategies[i].GetStats(), suitable);

               if(cand.compositeScore > topScore)
               {
                  topScore = cand.compositeScore;
                  topSignal = cand;
               }
            }
         }

         if(topSignal.isValid)
         {
            m_lastBestSignal = topSignal;
            SRiskStatus rk = m_risk.GetStatus();
            string volReason = "";
            double lots = m_risk.CalculateFixedFractionalVolume(topSignal, m_symIntel, volReason);

            bool execEnabled = (m_cfg.operatingMode == EA_MODE_DEMO_EXECUTION || m_cfg.operatingMode == EA_MODE_LIVE_TRADING);
            m_lastValidation = m_validation.Validate(topSignal, prof, market, regime, mtf, rk, m_symIntel, lots, execEnabled);

            int sIdx = (int)topSignal.strategyId;
            if(m_lastValidation.passed && !m_execution.IsDuplicateBarExecution(market.barTime))
            {
               SResearchFoldInfo fold = m_research.GetFoldTag(market.tickTime);
               m_learning.RecordSignalDecision(true);
               if(sIdx >= 0 && sIdx < EA_MAX_STRATEGIES) m_strategies[sIdx].RecordSignalAccepted();
               m_csv.LogAcceptedSignal(topSignal, fold.splitTag);

               if(m_cfg.operatingMode != EA_MODE_RESEARCH_ONLY)
               {
                  SExecutionResult exRes = m_execution.Execute(topSignal, lots, m_symIntel, m_cfg.operatingMode,
                                                               m_cfg.allowLiveTrading, m_cfg.confirmLiveRiskAck, market.barTime);
                  if(exRes.executed)
                  {
                     m_csv.LogTradeExecutionOrClose(m_symbol, m_cfg.primaryTF, exRes.positionTicket, topSignal.strategyName,
                                                    topSignal.direction, exRes.filledVolume, exRes.filledPrice,
                                                    topSignal.stopLoss, topSignal.takeProfit, exRes.slippagePoints,
                                                    topSignal.compositeScore, regime.regime, exRes.retcodeDesc, 0.0, 0, fold.splitTag);
                  }
               }
            }
            else if(!m_lastValidation.passed)
            {
               m_learning.RecordSignalDecision(false);
               if(sIdx >= 0 && sIdx < EA_MAX_STRATEGIES) m_strategies[sIdx].RecordSignalRejected();
               if(isNewBar)
               {
                  m_csv.LogRejectedSignal(m_symbol, m_cfg.primaryTF, topSignal.strategyName, topSignal.direction,
                                          topSignal.compositeScore, regime.regime,
                                          m_lastValidation.rejectionCode, m_lastValidation.rejectionReason);
               }
            }
         }
      }

      // 6. Adaptive Learning evaluation & periodic CSV flush / state persistence
      SLearningProposal prop;
      if(m_learning.EvaluateStrategies(m_strategies, EA_MAX_STRATEGIES, regime.regime, prop))
         m_csv.LogLearningProposal(prop);

      datetime now = TimeCurrent();
      if((now - m_lastPerfSnapshotTime) >= 300)
      {
         m_lastPerfSnapshotTime = now;
         for(int i = 0; i < EA_MAX_STRATEGIES; i++)
            m_csv.LogStrategyPerformanceSnapshot(m_symbol, m_strategies[i].GetStats());
         if(m_risk.GetStatus().lockoutActive)
            m_csv.LogRiskEvent(m_symbol, "LOCKOUT_STATUS", m_risk.GetStatus(), m_risk.GetStatus().lockoutReason);
      }

      m_csv.FlushAll(false);
      PersistCurrentState(false);
      m_lastAnalysisTime = now;
      UpdateSnapshot();
   }

   void OnTradeTransactionEvent()
   {
      if(!m_initialized) return;
      m_posMgmt.RefreshOwnedPositions(m_symIntel);
      SyncDealHistoryAndResearch();
      PersistCurrentState(true);
      UpdateSnapshot();
   }

   void UpdateSnapshot()
   {
      m_snapshot.eaName    = EA_PROJECT_NAME;
      m_snapshot.eaVersion = EA_PROJECT_VERSION;
      m_snapshot.symbol    = m_symbol;
      m_snapshot.timeframe = m_cfg.primaryTF;
      m_snapshot.operatingMode = m_cfg.operatingMode;
      m_snapshot.terminalConnected    = (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
      m_snapshot.tradeAllowedTerminal = (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
      m_snapshot.initialized          = m_initialized;
      m_snapshot.lastAnalysisTime     = m_lastAnalysisTime;
      m_snapshot.operationalStatus    = m_risk.GetStatus().lockoutActive ? "Risk Lockout Active" :
                                        (m_cfg.operatingMode == EA_MODE_RESEARCH_ONLY ? "Research Observing" : "Active");
      m_snapshot.activeStrategyName   = m_lastBestSignal.isValid ? m_lastBestSignal.strategyName : "Scanning (7 Strategies)";

      m_snapshot.symbolProfile  = m_symIntel.GetProfile();
      m_snapshot.market         = m_marketData.GetSnapshot();
      m_snapshot.ticks          = m_tickAnalysis.GetMetrics();
      m_snapshot.indicators     = m_indEngine.GetValues();
      m_snapshot.structure      = m_structure.GetState();
      m_snapshot.candle         = m_candles.GetSignal();
      m_snapshot.chartPattern   = m_patterns.GetSignal();
      m_snapshot.regime         = m_regime.GetState();
      m_snapshot.mtf            = m_mtf.GetAnalysis();
      m_snapshot.lastSignal     = m_lastBestSignal;
      m_snapshot.lastValidation = m_lastValidation;
      m_snapshot.risk           = m_risk.GetStatus();
      m_snapshot.account        = m_perfAnalytics.GetMetrics();
      m_snapshot.intelligence   = m_learning.GetSummary();

      for(int i = 0; i < EA_MAX_STRATEGIES; i++)
         m_snapshot.strategyStats[i] = m_strategies[i].GetStats();
   }

   // Strictly read-only getters for the decoupled Dashboard
   void GetReadOnlyDashboardData(SDashboardSnapshot &outSnap, SManagedPosition &outPos[], int &outPosCount,
                                 double &outEq[], double &outBal[], double &outDD[]) const
   {
      outSnap = m_snapshot;
      outPosCount = m_posMgmt.GetManagedPositions(outPos);
      m_perfAnalytics.GetCurveData(outEq, outBal, outDD);
   }
};

#endif // __ASEA_CORE_EACONTROLLER_MQH__
