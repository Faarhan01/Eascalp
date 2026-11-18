//+------------------------------------------------------------------+
//|                                               MultiTimeframe.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.9.0 Weighted MTF Context Engine        |
//+------------------------------------------------------------------+
#ifndef __ASEA_MARKET_MULTITIMEFRAME_MQH__
#define __ASEA_MARKET_MULTITIMEFRAME_MQH__

#include "../Core/Types.mqh"
#include "../Core/Diagnostics.mqh"
#include "MarketData.mqh"

class CMultiTimeframe
{
private:
   string          m_symbol;
   ENUM_TIMEFRAMES m_higherTF;
   ENUM_TIMEFRAMES m_intermediateTF;
   ENUM_TIMEFRAMES m_lowerTF;
   int             m_hEmaFastHigh, m_hEmaSlowHigh, m_hAdxHigh;
   int             m_hEmaFastMid, m_hEmaSlowMid, m_hRsiMid;
   CDiagnostics   *m_diag;
   SMTFAnalysis    m_analysis;
   datetime        m_lastHtfBar;
   datetime        m_lastItfBar;
   datetime        m_lastLtfEvalBar;
   int             m_lastStructBias;
   bool            m_htfInitDone;
   bool            m_itfInitDone;
   bool            m_ltfEvalDone;
   ENUM_SIGNAL_DIRECTION m_cachedHtfBias;
   ENUM_SIGNAL_DIRECTION m_cachedItfBias;

   double          m_weightHTF;
   double          m_weightITF;
   double          m_weightLTF;

   ENUM_SIGNAL_DIRECTION EvaluateTFBias(const ENUM_TIMEFRAMES tf, const int hFast, const int hSlow, const int hExtra, const bool isAdx, bool &outDataOk) const
   {
      outDataOk = false;
      if(hFast == INVALID_HANDLE || hSlow == INVALID_HANDLE)
         return SIGNAL_NONE;

      double fast[], slow[], extra[], cls[];
      ArraySetAsSeries(fast, true);
      ArraySetAsSeries(slow, true);
      ArraySetAsSeries(extra, true);
      ArraySetAsSeries(cls, true);

      if(CopyBuffer(hFast, 0, 1, 2, fast) < 2 || CopyBuffer(hSlow, 0, 1, 2, slow) < 2 ||
         CopyClose(m_symbol, tf, 1, 1, cls) < 1)
         return SIGNAL_NONE;

      bool risingFast  = (fast[0] > fast[1]);
      bool fallingFast = (fast[0] < fast[1]);
      bool bullPriceOk = (cls[0] > slow[0]);
      bool bearPriceOk = (cls[0] < slow[0]);

      if(isAdx && hExtra != INVALID_HANDLE)
      {
         double plusDI[], minusDI[];
         ArraySetAsSeries(plusDI, true);
         ArraySetAsSeries(minusDI, true);
         if(CopyBuffer(hExtra, 0, 1, 1, extra) >= 1 &&
            CopyBuffer(hExtra, 1, 1, 1, plusDI) >= 1 &&
            CopyBuffer(hExtra, 2, 1, 1, minusDI) >= 1)
         {
            outDataOk = true;
            if(fast[0] > slow[0] && risingFast && bullPriceOk && plusDI[0] >= minusDI[0] + 1.5 && extra[0] >= 16.0)
               return SIGNAL_BUY;
            if(fast[0] < slow[0] && fallingFast && bearPriceOk && minusDI[0] >= plusDI[0] + 1.5 && extra[0] >= 16.0)
               return SIGNAL_SELL;
         }
         return SIGNAL_NONE;
      }
      else if(hExtra != INVALID_HANDLE)
      {
         if(CopyBuffer(hExtra, 0, 1, 1, extra) >= 1)
         {
            outDataOk = true;
            if(fast[0] > slow[0] && risingFast && bullPriceOk && extra[0] > 51.0)  return SIGNAL_BUY;
            if(fast[0] < slow[0] && fallingFast && bearPriceOk && extra[0] < 49.0) return SIGNAL_SELL;
         }
         return SIGNAL_NONE;
      }

      outDataOk = true;
      if(fast[0] > slow[0] && risingFast && bullPriceOk)  return SIGNAL_BUY;
      if(fast[0] < slow[0] && fallingFast && bearPriceOk) return SIGNAL_SELL;
      return SIGNAL_NONE;
   }

public:
   CMultiTimeframe()
   {
      m_symbol = "";
      m_higherTF = PERIOD_H1;
      m_intermediateTF = PERIOD_M15;
      m_lowerTF = PERIOD_M5;
      m_hEmaFastHigh = INVALID_HANDLE; m_hEmaSlowHigh = INVALID_HANDLE; m_hAdxHigh = INVALID_HANDLE;
      m_hEmaFastMid  = INVALID_HANDLE; m_hEmaSlowMid  = INVALID_HANDLE; m_hRsiMid  = INVALID_HANDLE;
      m_diag = NULL;
      m_lastHtfBar = 0; m_lastItfBar = 0; m_lastLtfEvalBar = 0; m_lastStructBias = 0;
      m_htfInitDone = false; m_itfInitDone = false; m_ltfEvalDone = false;
      m_cachedHtfBias = SIGNAL_NONE; m_cachedItfBias = SIGNAL_NONE;
      m_weightHTF = 0.45; m_weightITF = 0.35; m_weightLTF = 0.20;
      m_analysis.Reset();
   }

   ~CMultiTimeframe()
   {
      Release();
   }

   void Release()
   {
      if(m_hEmaFastHigh != INVALID_HANDLE) { IndicatorRelease(m_hEmaFastHigh); m_hEmaFastHigh = INVALID_HANDLE; }
      if(m_hEmaSlowHigh != INVALID_HANDLE) { IndicatorRelease(m_hEmaSlowHigh); m_hEmaSlowHigh = INVALID_HANDLE; }
      if(m_hAdxHigh     != INVALID_HANDLE) { IndicatorRelease(m_hAdxHigh);     m_hAdxHigh     = INVALID_HANDLE; }
      if(m_hEmaFastMid  != INVALID_HANDLE) { IndicatorRelease(m_hEmaFastMid);  m_hEmaFastMid  = INVALID_HANDLE; }
      if(m_hEmaSlowMid  != INVALID_HANDLE) { IndicatorRelease(m_hEmaSlowMid);  m_hEmaSlowMid  = INVALID_HANDLE; }
      if(m_hRsiMid      != INVALID_HANDLE) { IndicatorRelease(m_hRsiMid);      m_hRsiMid      = INVALID_HANDLE; }
   }

   void ConfigureWeights(const double wHtf, const double wItf, const double wLtf)
   {
      double sum = MathMax(0.01, wHtf + wItf + wLtf);
      m_weightHTF = wHtf / sum;
      m_weightITF = wItf / sum;
      m_weightLTF = wLtf / sum;
   }

   bool Initialize(const string symbol, const ENUM_TIMEFRAMES higherTF, const ENUM_TIMEFRAMES interTF,
                   const ENUM_TIMEFRAMES lowerTF, CDiagnostics *diag)
   {
      Release();
      m_symbol = symbol;
      m_higherTF = higherTF;
      m_intermediateTF = interTF;
      m_lowerTF = lowerTF;
      m_diag = diag;
      m_lastHtfBar = 0; m_lastItfBar = 0; m_lastLtfEvalBar = 0; m_lastStructBias = 0;
      m_htfInitDone = false; m_itfInitDone = false; m_ltfEvalDone = false;
      m_cachedHtfBias = SIGNAL_NONE; m_cachedItfBias = SIGNAL_NONE;

      m_hEmaFastHigh = iMA(m_symbol, m_higherTF, 21, 0, MODE_EMA, PRICE_CLOSE);
      m_hEmaSlowHigh = iMA(m_symbol, m_higherTF, 55, 0, MODE_EMA, PRICE_CLOSE);
      m_hAdxHigh     = iADX(m_symbol, m_higherTF, 14);

      m_hEmaFastMid  = iMA(m_symbol, m_intermediateTF, 21, 0, MODE_EMA, PRICE_CLOSE);
      m_hEmaSlowMid  = iMA(m_symbol, m_intermediateTF, 55, 0, MODE_EMA, PRICE_CLOSE);
      m_hRsiMid      = iRSI(m_symbol, m_intermediateTF, 14, PRICE_CLOSE);

      if(m_hEmaFastHigh == INVALID_HANDLE || m_hEmaSlowHigh == INVALID_HANDLE ||
         m_hEmaFastMid  == INVALID_HANDLE || m_hEmaSlowMid  == INVALID_HANDLE)
      {
         if(m_diag != NULL)
            m_diag.Log(LOG_WARN, "MultiTimeframe", "MTF handle init degraded on " + m_symbol);
         return false;
      }
      return true;
   }

   bool Evaluate(const CMarketData &data, const SIndicatorValues &lowerInd, const SStructureState &structure)
   {
      if(!lowerInd.isReady || !data.IsDataReady())
      {
         m_analysis.Reset();
         m_analysis.higherTF       = m_higherTF;
         m_analysis.intermediateTF = m_intermediateTF;
         m_analysis.lowerTF        = m_lowerTF;
         m_ltfEvalDone             = false;
         return false;
      }

      datetime ltfBar = data.GetBarTime();
      datetime htfBar = iTime(m_symbol, m_higherTF, 0);
      datetime itfBar = iTime(m_symbol, m_intermediateTF, 0);

      // Zero-cost intra-bar fast path once HTF, ITF & LTF closed-bar evaluations match current bars
      if(m_analysis.isReady && m_ltfEvalDone && m_htfInitDone && m_itfInitDone &&
         ltfBar == m_lastLtfEvalBar && htfBar == m_lastHtfBar && itfBar == m_lastItfBar &&
         structure.structureBias == m_lastStructBias)
         return true;

      m_analysis.Reset();
      m_analysis.higherTF       = m_higherTF;
      m_analysis.intermediateTF = m_intermediateTF;
      m_analysis.lowerTF        = m_lowerTF;

      // Cached HTF evaluation (only cache once all HTF handles finish calculation)
      if(htfBar > 0 && (htfBar != m_lastHtfBar || !m_htfInitDone))
      {
         bool htfHandlesReady = (BarsCalculated(m_hEmaFastHigh) >= 4 && BarsCalculated(m_hEmaSlowHigh) >= 4 &&
                                 (m_hAdxHigh == INVALID_HANDLE || BarsCalculated(m_hAdxHigh) >= 4));
         if(htfHandlesReady && data.HasSufficientHistory(m_higherTF, 35))
         {
            bool htfDataOk = false;
            ENUM_SIGNAL_DIRECTION b = EvaluateTFBias(m_higherTF, m_hEmaFastHigh, m_hEmaSlowHigh, m_hAdxHigh, true, htfDataOk);
            if(htfDataOk)
            {
               m_cachedHtfBias = b;
               m_lastHtfBar = htfBar;
               m_htfInitDone = true;
            }
         }
      }
      m_analysis.higherBias = m_cachedHtfBias;

      // Cached ITF evaluation
      if(itfBar > 0 && (itfBar != m_lastItfBar || !m_itfInitDone))
      {
         bool itfHandlesReady = (BarsCalculated(m_hEmaFastMid) >= 4 && BarsCalculated(m_hEmaSlowMid) >= 4 &&
                                 (m_hRsiMid == INVALID_HANDLE || BarsCalculated(m_hRsiMid) >= 4));
         if(itfHandlesReady && data.HasSufficientHistory(m_intermediateTF, 35))
         {
            bool itfDataOk = false;
            ENUM_SIGNAL_DIRECTION b = EvaluateTFBias(m_intermediateTF, m_hEmaFastMid, m_hEmaSlowMid, m_hRsiMid, false, itfDataOk);
            if(itfDataOk)
            {
               m_cachedItfBias = b;
               m_lastItfBar = itfBar;
               m_itfInitDone = true;
            }
         }
      }
      m_analysis.intermediateBias = m_cachedItfBias;

      // LTF bias
      if(lowerInd.emaFast > lowerInd.emaSlow && lowerInd.macdHist >= 0.0)
         m_analysis.lowerBias = SIGNAL_BUY;
      else if(lowerInd.emaFast < lowerInd.emaSlow && lowerInd.macdHist <= 0.0)
         m_analysis.lowerBias = SIGNAL_SELL;
      else
         m_analysis.lowerBias = SIGNAL_NONE;

      double wScore = ((double)m_analysis.higherBias * m_weightHTF +
                       (double)m_analysis.intermediateBias * m_weightITF +
                       (double)m_analysis.lowerBias * m_weightLTF) * 100.0;
      m_analysis.weightedScore  = wScore;
      m_analysis.agreementScore = MathAbs(wScore);
      m_analysis.alignedBullish = (wScore >= 40.0);
      m_analysis.alignedBearish = (wScore <= -40.0);

      // Structural contradiction check
      if((m_analysis.higherBias == SIGNAL_BUY && structure.structureBias < 0) ||
         (m_analysis.higherBias == SIGNAL_SELL && structure.structureBias > 0))
      {
         m_analysis.ltfContradictsHtfStructure = true;
      }

      if((m_analysis.higherBias == SIGNAL_BUY && m_analysis.intermediateBias == SIGNAL_SELL) ||
         (m_analysis.higherBias == SIGNAL_SELL && m_analysis.intermediateBias == SIGNAL_BUY))
      {
         m_analysis.hasStrongConflict = true;
         m_analysis.assessment = MTF_CONFLICTING;
         m_analysis.conflictReason = StringFormat("HTF (%s) opposes ITF (%s)", EnumToString(m_higherTF), EnumToString(m_intermediateTF));
         m_analysis.assessmentSummary = "Conflicting: " + m_analysis.conflictReason;
      }
      else if(m_analysis.higherBias == m_analysis.intermediateBias && m_analysis.higherBias != SIGNAL_NONE &&
              m_analysis.lowerBias == m_analysis.higherBias)
      {
         m_analysis.assessment = MTF_STRONG_AGREEMENT;
         m_analysis.assessmentSummary = StringFormat("Strong %s agreement across HTF/ITF/LTF", DirectionToString(m_analysis.higherBias));
      }
      else if(MathAbs(wScore) >= 40.0)
      {
         m_analysis.assessment = MTF_PARTIAL_AGREEMENT;
         m_analysis.assessmentSummary = StringFormat("Partial %s agreement (w=%.0f)", wScore > 0 ? "Bullish" : "Bearish", wScore);
      }
      else
      {
         m_analysis.assessment = MTF_NEUTRAL;
         m_analysis.assessmentSummary = "Neutral / Mixed TF bias";
      }

      m_lastLtfEvalBar = ltfBar;
      m_lastStructBias = structure.structureBias;
      m_ltfEvalDone    = true;
      m_analysis.isReady = true;
      return true;
   }

   SMTFAnalysis GetAnalysis() const { return m_analysis; }
};

#endif // __ASEA_MARKET_MULTITIMEFRAME_MQH__
