//+------------------------------------------------------------------+
//|                                               MultiTimeframe.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        Multi-Timeframe Alignment & Conflict Check|
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

   ENUM_SIGNAL_DIRECTION EvaluateTFBias(const int hFast, const int hSlow, const int hExtra, const bool isAdx) const
   {
      if(hFast == INVALID_HANDLE || hSlow == INVALID_HANDLE)
         return SIGNAL_NONE;

      double fast[2], slow[2], extra[2];
      ArraySetAsSeries(fast, true);
      ArraySetAsSeries(slow, true);
      ArraySetAsSeries(extra, true);

      // Copy shift=1 (completed bar) to eliminate repainting
      if(CopyBuffer(hFast, 0, 1, 2, fast) < 2 || CopyBuffer(hSlow, 0, 1, 2, slow) < 2)
         return SIGNAL_NONE;

      bool risingFast  = (fast[0] > fast[1]);
      bool fallingFast = (fast[0] < fast[1]);

      if(isAdx && hExtra != INVALID_HANDLE)
      {
         double plusDI[1], minusDI[1];
         if(CopyBuffer(hExtra, 0, 1, 1, extra) >= 1 &&
            CopyBuffer(hExtra, 1, 1, 1, plusDI) >= 1 &&
            CopyBuffer(hExtra, 2, 1, 1, minusDI) >= 1)
         {
            if(fast[0] > slow[0] && risingFast && plusDI[0] >= minusDI[0] && extra[0] >= 16.0)
               return SIGNAL_BUY;
            if(fast[0] < slow[0] && fallingFast && minusDI[0] >= plusDI[0] && extra[0] >= 16.0)
               return SIGNAL_SELL;
         }
      }
      else if(hExtra != INVALID_HANDLE)
      {
         if(CopyBuffer(hExtra, 0, 1, 1, extra) >= 1)
         {
            if(fast[0] > slow[0] && extra[0] > 51.0) return SIGNAL_BUY;
            if(fast[0] < slow[0] && extra[0] < 49.0) return SIGNAL_SELL;
         }
      }

      if(fast[0] > slow[0] && risingFast)  return SIGNAL_BUY;
      if(fast[0] < slow[0] && fallingFast) return SIGNAL_SELL;
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

   bool Initialize(const string symbol, const ENUM_TIMEFRAMES higherTF, const ENUM_TIMEFRAMES interTF,
                   const ENUM_TIMEFRAMES lowerTF, CDiagnostics *diag)
   {
      Release();
      m_symbol = symbol;
      m_higherTF = higherTF;
      m_intermediateTF = interTF;
      m_lowerTF = lowerTF;
      m_diag = diag;

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
            m_diag.Log(LOG_WARN, "MultiTimeframe", "One or more MTF indicator handles failed to create; degraded mode active.");
         return false;
      }
      return true;
   }

   bool Evaluate(const CMarketData &data, const SIndicatorValues &lowerInd, const STickMetrics &ticks)
   {
      m_analysis.Reset();
      m_analysis.higherTF       = m_higherTF;
      m_analysis.intermediateTF = m_intermediateTF;
      m_analysis.lowerTF        = m_lowerTF;

      if(!lowerInd.isReady)
         return false;

      if(data.HasSufficientHistory(m_higherTF, 60))
         m_analysis.higherBias = EvaluateTFBias(m_hEmaFastHigh, m_hEmaSlowHigh, m_hAdxHigh, true);

      if(data.HasSufficientHistory(m_intermediateTF, 60))
         m_analysis.intermediateBias = EvaluateTFBias(m_hEmaFastMid, m_hEmaSlowMid, m_hRsiMid, false);

      // Lower TF bias from primary indicator engine
      if(lowerInd.emaFast > lowerInd.emaSlow && lowerInd.macdHist >= 0.0)
         m_analysis.lowerBias = SIGNAL_BUY;
      else if(lowerInd.emaFast < lowerInd.emaSlow && lowerInd.macdHist <= 0.0)
         m_analysis.lowerBias = SIGNAL_SELL;
      else
         m_analysis.lowerBias = SIGNAL_NONE;

      // Calculate agreement score (0..100) and conflict detection
      int sum = (int)m_analysis.higherBias + (int)m_analysis.intermediateBias + (int)m_analysis.lowerBias;
      if(sum == 3)
      {
         m_analysis.alignedBullish = true;
         m_analysis.agreementScore = (ticks.microTrendBias >= 0.0) ? 100.0 : 88.0;
      }
      else if(sum == -3)
      {
         m_analysis.alignedBearish = true;
         m_analysis.agreementScore = (ticks.microTrendBias <= 0.0) ? 100.0 : 88.0;
      }
      else if(MathAbs(sum) == 2)
      {
         m_analysis.agreementScore = 72.0;
         if(sum > 0) m_analysis.alignedBullish = true;
         else        m_analysis.alignedBearish = true;
      }
      else
      {
         m_analysis.agreementScore = 35.0;
      }

      // Strong conflict: Higher TF and Intermediate TF explicitly oppose each other, or Lower TF strongly opposes Higher TF
      if((m_analysis.higherBias == SIGNAL_BUY && m_analysis.intermediateBias == SIGNAL_SELL) ||
         (m_analysis.higherBias == SIGNAL_SELL && m_analysis.intermediateBias == SIGNAL_BUY))
      {
         m_analysis.hasStrongConflict = true;
         m_analysis.conflictReason = StringFormat("HTF (%s) opposes ITF (%s)", EnumToString(m_higherTF), EnumToString(m_intermediateTF));
         m_analysis.agreementScore = MathMin(m_analysis.agreementScore, 25.0);
      }
      else if((m_analysis.higherBias == SIGNAL_BUY && m_analysis.lowerBias == SIGNAL_SELL) ||
              (m_analysis.higherBias == SIGNAL_SELL && m_analysis.lowerBias == SIGNAL_BUY))
      {
         m_analysis.hasStrongConflict = true;
         m_analysis.conflictReason = StringFormat("LTF (%s) opposes HTF (%s)", EnumToString(m_lowerTF), EnumToString(m_higherTF));
         m_analysis.agreementScore = MathMin(m_analysis.agreementScore, 40.0);
      }

      m_analysis.isReady = true;
      return true;
   }

   SMTFAnalysis GetAnalysis() const { return m_analysis; }
};

#endif // __ASEA_MARKET_MULTITIMEFRAME_MQH__
