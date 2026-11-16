//+------------------------------------------------------------------+
//|                                                SymbolContext.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.0.0 Isolated Per-Symbol Analysis Unit  |
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
   double               m_lastAtr;

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
      m_lastAtr = 0.0;
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
                   const bool autoAdaptBySymbol, CDiagnostics *diag)
   {
      Release();
      m_symbol = symbol;
      m_primaryTF = primaryTF;
      m_autoAdaptBySymbol = autoAdaptBySymbol;
      m_lastBarObsLogged = 0;
      m_lastSymRefresh = 0;
      m_lastAtr = 0.0;
      m_ctx.Reset();
      m_lastSignal.Reset();
      m_lastValidation.Reset();

      if(!m_symIntel.Initialize(m_symbol, m_primaryTF, fallbackCommPerLot, diag))
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

      m_initialized = true;
      return true;
   }

   bool UpdateAnalysis(const bool refreshSymSpecs, bool &outIsNewBar)
   {
      outIsNewBar = false;
      if(!m_initialized) return false;

      datetime now = TimeCurrent();
      const int baseRefreshSec = (MQLInfoInteger(MQL_TESTER) != 0) ? 1800 : 300;
      const int symRefreshSec  = !m_ctx.symbolProfile.sessionOpenNow ? MathMin(baseRefreshSec, 30) : baseRefreshSec;
      if(refreshSymSpecs || m_lastSymRefresh == 0 || (now - m_lastSymRefresh) >= symRefreshSec)
      {
         m_symIntel.Refresh(m_primaryTF);
         m_lastSymRefresh = now;
      }

      if(!m_marketData.Update(m_lastAtr))
      {
         m_ctx.market = m_marketData.GetSnapshot();
         return false;
      }

      SMarketSnapshot market = m_marketData.GetSnapshot();
      m_tickAnalysis.OnTickUpdate(market);
      outIsNewBar = m_marketData.IsNewClosedBar();
      if(outIsNewBar)
         m_symIntel.RefreshAvailableBars(m_primaryTF);

      SSymbolProfile prof = m_symIntel.GetProfile();
      m_indEngine.Update(m_marketData, prof.hasRealVolume);
      SIndicatorValues ind = m_indEngine.GetValues();
      if(ind.isReady && ind.atr > 0.0)
      {
         m_lastAtr = ind.atr;
         m_symIntel.UpdateDynamicBaselines(ind.atrBaseline, market.avgSpreadPoints);
         prof = m_symIntel.GetProfile();
      }

      STickMetrics ticks = m_tickAnalysis.GetMetrics();
      if(ind.isReady)
      {
         m_structure.Analyze(m_marketData, m_primaryTF, ind.atr);
         m_candles.Analyze(m_marketData, m_primaryTF, ind, m_structure.GetState());
         m_patterns.Analyze(m_marketData, m_primaryTF, ind.atr);
         double pipPts = (prof.point > 0.0 && prof.pipSize > 0.0) ? MathMax(1.0, prof.pipSize / prof.point) : 1.0;
         m_regime.Classify(m_marketData, m_primaryTF, ind, m_structure.GetState(), ticks, pipPts);
         m_mtf.Evaluate(m_marketData, ind, m_structure.GetState());
      }

      m_ctx.symbolProfile = prof;
      m_ctx.assetProfile  = m_symIntel.GetAdaptiveAssetProfile();
      m_ctx.market        = market;
      m_ctx.ticks         = ticks;
      m_ctx.ind           = ind;
      m_ctx.structure     = m_structure.GetState();
      m_ctx.candle        = m_candles.GetSignal();
      m_ctx.chartPattern  = m_patterns.GetSignal();
      m_ctx.regime        = m_regime.GetState();
      m_ctx.mtf           = m_mtf.GetAnalysis();
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
   const CSymbolIntelligence *GetSymbolIntelPtr() const { return GetPointer(m_symIntel); }
   SAnalysisContext         GetContext() const        { return m_ctx; }
   STradeSignal             GetLastSignal() const     { return m_lastSignal; }
   SValidationResult        GetLastValidation() const { return m_lastValidation; }
};

#endif // __ASEA_CORE_SYMBOLCONTEXT_MQH__
