//+------------------------------------------------------------------+
//|                                                SymbolContext.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.9.0 Isolated Per-Symbol Analysis Unit  |
//+------------------------------------------------------------------+
#ifndef __ASEA_CORE_SYMBOLCONTEXT_MQH__
#define __ASEA_CORE_SYMBOLCONTEXT_MQH__

#include "Types.mqh"
#include "Diagnostics.mqh"
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

class CSymbolContext
{
private:
   string               m_symbol;
   ENUM_TIMEFRAMES      m_primaryTF;
   bool                 m_initialized;
   bool                 m_autoAdaptBySymbol;
   datetime             m_lastBarObsLogged;
   datetime             m_lastSymRefresh;
   datetime             m_lastFullSyncBar;
   bool                 m_profileDirty;
   bool                 m_lastUnstableSynced;
   double               m_lastAtr;
   int                  m_histCalibBarsSince;

   CSymbolIntelligence  m_symIntel;
   CMarketData          m_marketData;
   CTickAnalysis        m_tickAnalysis;
   CIndicatorEngine     m_indEngine;
   CMarketStructure     m_structure;
   CMarketRegime        m_regime;
   CMultiTimeframe      m_mtf;
   CCandlestickRecognition m_candles;
   CPatternRecognition  m_patterns;

   SAnalysisContext     m_ctx;
   STradeSignal         m_lastSignal;
   SValidationResult    m_lastValidation;

public:
   CSymbolContext()
   {
      m_symbol = "";
      m_primaryTF = PERIOD_M5;
      m_initialized = false;
      m_autoAdaptBySymbol = true;
      m_lastBarObsLogged = 0;
      m_lastSymRefresh = 0;
      m_lastFullSyncBar = 0;
      m_profileDirty = true;
      m_lastUnstableSynced = false;
      m_lastAtr = 0.0;
      m_histCalibBarsSince = 0;
      m_ctx.Reset();
      m_lastSignal.Reset();
      m_lastValidation.Reset();
   }

   ~CSymbolContext()
   {
      Release();
   }

   void Release()
   {
      m_indEngine.Release();
      m_mtf.Release();
      m_initialized = false;
   }

   bool Initialize(const string symbol, const ENUM_TIMEFRAMES primaryTF, const ENUM_TIMEFRAMES interTF,
                   const ENUM_TIMEFRAMES higherTF, const int spreadAvgWindow, const int tickWindowSize,
                   const double fallbackCommPerLot, const SIndicatorConfig &indCfg,
                   const int swingStrength, const int structureLookback, const double zoneAtrMult,
                   const double adxStrong, const double adxWeak, const double volHigh, const double volLow,
                   const double spreadUnstable, const double dojiBodyMax, const double pinWickMin,
                   const int patternLookback, const double patternTolAtr,
                   const double wHtf, const double wItf, const double wLtf,
                   const bool autoAdaptBySymbol, CDiagnostics *diag,
                   const ENUM_ASSET_CLASS_OVERRIDE assetOverride = ASSET_OVERRIDE_AUTO,
                   const bool autoTuneFromHistory = true)
   {
      Release();
      m_symbol = symbol;
      m_primaryTF = primaryTF;
      m_autoAdaptBySymbol = autoAdaptBySymbol;
      m_lastBarObsLogged = 0;
      m_lastSymRefresh = 0;
      m_lastFullSyncBar = 0;
      m_profileDirty = true;
      m_lastUnstableSynced = false;
      m_lastAtr = 0.0;
      m_histCalibBarsSince = 0;
      m_ctx.Reset();
      m_lastSignal.Reset();
      m_lastValidation.Reset();

      if(!m_symIntel.Initialize(m_symbol, m_primaryTF, fallbackCommPerLot, diag, assetOverride, autoTuneFromHistory))
         return false;

      SAdaptiveAssetProfile ap = m_symIntel.GetAdaptiveAssetProfile();
      double effAdxStrong = m_autoAdaptBySymbol ? ap.adxStrongThresh : adxStrong;
      double effAdxWeak   = m_autoAdaptBySymbol ? ap.adxWeakThresh   : adxWeak;
      double effVolHigh   = m_autoAdaptBySymbol ? ap.volHighRatio    : volHigh;
      double effVolLow    = m_autoAdaptBySymbol ? ap.volLowRatio     : volLow;
      double effSprUnst   = m_autoAdaptBySymbol ? ap.spreadUnstableRatio : spreadUnstable;

      m_marketData.Initialize(m_symbol, m_primaryTF, spreadAvgWindow, GetPointer(m_symIntel), diag);
      m_tickAnalysis.Initialize(m_symbol, tickWindowSize, GetPointer(m_symIntel));
      m_indEngine.Initialize(m_symbol, m_primaryTF, indCfg, diag);
      m_structure.Configure(swingStrength, structureLookback, zoneAtrMult);
      m_regime.Configure(effAdxStrong, effAdxWeak, effVolHigh, effVolLow, effSprUnst);
      m_mtf.ConfigureWeights(wHtf, wItf, wLtf);
      m_mtf.Initialize(m_symbol, higherTF, interTF, m_primaryTF, diag);
      m_candles.Configure(dojiBodyMax, pinWickMin);
      m_patterns.Configure(patternLookback, swingStrength, patternTolAtr);

      // Seed empirical microstructure & Step Index detection immediately if bars are already cached
      MqlRates initRates[];
      if(m_marketData.CopyAvailableClosedRates(m_primaryTF, 20, 50, initRates))
      {
         int nInit = ArraySize(initRates);
         double trSum = 0.0;
         int trCount = MathMin(20, nInit - 1);
         for(int b = 0; b < trCount; b++)
         {
            double prevClose = initRates[b + 1].close;
            double tr = MathMax(initRates[b].high - initRates[b].low,
                                MathMax(MathAbs(initRates[b].high - prevClose), MathAbs(initRates[b].low - prevClose)));
            trSum += tr;
         }
         double initAtr = (trCount > 0) ? (trSum / (double)trCount) : 0.0;
         if(initAtr > 0.0)
         {
            m_lastAtr = initAtr;
            SMarketSnapshot initSnap = m_marketData.GetSnapshot();
            m_symIntel.UpdateDynamicBaselines(initAtr, initSnap.avgSpreadPoints);
            m_symIntel.CalibrateFromHistory(initRates, nInit, initAtr);
            if(m_autoAdaptBySymbol)
            {
               SAdaptiveAssetProfile apCal = m_symIntel.GetAdaptiveAssetProfile();
               m_regime.Configure(apCal.adxStrongThresh, apCal.adxWeakThresh,
                                  apCal.volHighRatio, apCal.volLowRatio, apCal.spreadUnstableRatio);
            }
         }
      }

      m_initialized = true;
      return true;
   }

   bool UpdateAnalysis(const bool refreshSymSpecs, bool &outIsNewBar)
   {
      outIsNewBar = false;
      if(!m_initialized) return false;

      datetime now = SafeCurrentTime();
      const int baseRefreshSec = (MQLInfoInteger(MQL_TESTER) != 0) ? 1800 : 300;
      const int symRefreshSec  = !m_symIntel.IsSessionOpenNow() ? MathMin(baseRefreshSec, 30) : baseRefreshSec;
      if(refreshSymSpecs || m_lastSymRefresh == 0 || (now - m_lastSymRefresh) >= symRefreshSec)
      {
         m_symIntel.Refresh(m_primaryTF);
         m_lastSymRefresh = now;
         m_profileDirty = true;
      }

      if(!m_marketData.Update(m_lastAtr))
      {
         m_ctx.market = m_marketData.GetSnapshot();
         return false;
      }

      // Copy live market snapshot ONCE into m_ctx.market and pass by reference to TickAnalysis
      m_ctx.market = m_marketData.GetSnapshot();
      m_tickAnalysis.OnTickUpdate(m_ctx.market);
      m_ctx.ticks = m_tickAnalysis.GetMetrics();

      outIsNewBar = m_marketData.IsNewClosedBar();
      datetime curBarT = m_ctx.market.barTime;
      bool needFullSync = (m_profileDirty || outIsNewBar || curBarT != m_lastFullSyncBar);

      if(outIsNewBar)
         m_symIntel.RefreshAvailableBars(m_primaryTF);

      m_indEngine.Update(m_marketData, m_symIntel.HasRealVolume());

      if(needFullSync)
      {
         SIndicatorValues ind = m_indEngine.GetValues();
         if(ind.isReady && ind.atr > 0.0)
         {
            m_lastAtr = ind.atr;
            m_symIntel.UpdateDynamicBaselines(ind.atrBaseline, m_ctx.market.avgSpreadPoints);
            if(outIsNewBar) m_histCalibBarsSince++;
            if(!m_symIntel.IsEmpiricalProfileReady() || m_histCalibBarsSince >= 20)
            {
               MqlRates histRates[];
               if(m_marketData.CopyAvailableClosedRates(m_primaryTF, 20, 50, histRates))
               {
                  bool prevStep = m_symIntel.IsStepIndex();
                  m_symIntel.CalibrateFromHistory(histRates, ArraySize(histRates), ind.atr);
                  m_histCalibBarsSince = 0;
                  if(m_autoAdaptBySymbol && (prevStep != m_symIntel.IsStepIndex() || m_symIntel.IsEmpiricalProfileReady()))
                  {
                     SAdaptiveAssetProfile apNow = m_symIntel.GetAdaptiveAssetProfile();
                     m_regime.Configure(apNow.adxStrongThresh, apNow.adxWeakThresh,
                                        apNow.volHighRatio, apNow.volLowRatio, apNow.spreadUnstableRatio);
                  }
               }
            }
            m_structure.Analyze(m_marketData, m_primaryTF, ind.atr);
            m_candles.Analyze(m_marketData, m_primaryTF, ind, m_structure.GetState());
            m_patterns.Analyze(m_marketData, m_primaryTF, ind.atr);
            double pt = m_symIntel.GetPoint();
            double pipSz = m_symIntel.GetPipSize();
            double pipPts = (pt > 0.0 && pipSz > 0.0) ? MathMax(1.0, pipSz / pt) : 1.0;
            m_regime.Classify(m_marketData, m_primaryTF, ind, m_structure.GetState(), m_ctx.ticks, pipPts);
            m_mtf.Evaluate(m_marketData, ind, m_structure.GetState());

            m_ctx.symbolProfile = m_symIntel.GetProfile();
            m_ctx.assetProfile  = m_symIntel.GetAdaptiveAssetProfile();
            m_ctx.ind           = ind;
            m_ctx.structure     = m_structure.GetState();
            m_ctx.candle        = m_candles.GetSignal();
            m_ctx.chartPattern  = m_patterns.GetSignal();
            m_ctx.regime        = m_regime.GetState();
            m_ctx.mtf           = m_mtf.GetAnalysis();
            m_lastFullSyncBar   = curBarT;
            m_profileDirty      = false;
            m_lastUnstableSynced = m_ctx.regime.isUnstable;
         }
         else
         {
            m_ctx.symbolProfile = m_symIntel.GetProfile();
            m_ctx.assetProfile  = m_symIntel.GetAdaptiveAssetProfile();
            m_ctx.ind           = ind;
         }
      }
      else if(m_ctx.ind.isReady)
      {
         // Intra-bar lightweight overlay update: only touch regime/mtf if overlay toggled or MTF wasn't ready
         double pt = m_symIntel.GetPoint();
         double pipSz = m_symIntel.GetPipSize();
         double pipPts = (pt > 0.0 && pipSz > 0.0) ? MathMax(1.0, pipSz / pt) : 1.0;
         m_regime.Classify(m_marketData, m_primaryTF, m_ctx.ind, m_ctx.structure, m_ctx.ticks, pipPts);
         if(m_regime.IsUnstable() != m_lastUnstableSynced)
         {
            m_ctx.regime = m_regime.GetState();
            m_lastUnstableSynced = m_ctx.regime.isUnstable;
         }
         if(!m_ctx.mtf.isReady)
         {
            if(m_mtf.Evaluate(m_marketData, m_ctx.ind, m_ctx.structure))
               m_ctx.mtf = m_mtf.GetAnalysis();
         }
      }
      return true;
   }

   bool ShouldLogNewBarObservation()
   {
      if(!m_ctx.market.dataReady || !m_ctx.ind.isReady) return false;
      if(m_ctx.market.barTime != m_lastBarObsLogged)
      {
         m_lastBarObsLogged = m_ctx.market.barTime;
         return true;
      }
      return false;
   }

   void SetLastBarLogged(const datetime t)              { m_lastBarObsLogged = t; }
   datetime GetLastBarLogged() const                    { return m_lastBarObsLogged; }
   void RecordFillSlippage(const double slippagePts)    { m_symIntel.RecordMeasuredSlippage(slippagePts); }
   void SetLastDecision(const STradeSignal &s, const SValidationResult &v) { m_lastSignal = s; m_lastValidation = v; }

   string                   GetSymbol() const         { return m_symbol; }
   bool                     IsInitialized() const     { return m_initialized; }
   bool                     IsMarketReady() const     { return m_ctx.market.dataReady; }
   bool                     IsIndReady() const        { return m_ctx.ind.isReady; }
   bool                     IsTicksReady() const      { return m_ctx.ticks.isReady; }
   bool                     IsTickSurge() const       { return m_ctx.ticks.suddenActivitySurge; }
   datetime                 GetBarTime() const        { return m_ctx.market.barTime; }
   datetime                 GetTickTime() const       { return m_ctx.market.tickTime; }
   const CSymbolIntelligence *GetSymbolIntelPtr() const { return GetPointer(m_symIntel); }
   SAnalysisContext         GetContext() const        { return m_ctx; }
   STradeSignal             GetLastSignal() const     { return m_lastSignal; }
   SValidationResult        GetLastValidation() const { return m_lastValidation; }
};

#endif // __ASEA_CORE_SYMBOLCONTEXT_MQH__
