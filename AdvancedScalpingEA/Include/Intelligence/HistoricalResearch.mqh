//+------------------------------------------------------------------+
//|                                           HistoricalResearch.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v3.0.0 OOS, Walk-Forward, MC & ScoreBands |
//+------------------------------------------------------------------+
#ifndef __ASEA_INTELLIGENCE_HISTORICALRESEARCH_MQH__
#define __ASEA_INTELLIGENCE_HISTORICALRESEARCH_MQH__

#include "../Core/Types.mqh"

struct SResearchFoldInfo
{
   string   splitTag;      // "IN_SAMPLE" or "OUT_OF_SAMPLE"
   int      foldIndex;
   datetime splitBoundary;
};

class CHistoricalResearch
{
private:
   datetime m_sessionStart;
   int      m_walkForwardDays;
   double   m_oosSplitRatio;
   double   m_tradePnLs[];
   int      m_tradeCount;

   // Score-band historical validation (<60, 60-74, 75+)
   int      m_bandTrades[3];
   int      m_bandWins[3];
   double   m_bandNetPnL[3];

   // Cached Monte Carlo result & pre-allocated work arrays
   double   m_mcSamples[];
   double   m_mcShuffled[];
   int      m_cachedMcTradeCount;
   int      m_cachedMcIters;
   double   m_cachedMcMedDD;
   double   m_cachedMcP95DD;

public:
   CHistoricalResearch()
   {
      m_sessionStart = 0;
      m_walkForwardDays = 14;
      m_oosSplitRatio = 0.30;
      m_tradeCount = 0;
      m_cachedMcTradeCount = -1;
      m_cachedMcIters = 0;
      m_cachedMcMedDD = 0.0;
      m_cachedMcP95DD = 0.0;
      ArrayResize(m_tradePnLs, 0);
      ArrayResize(m_mcSamples, 0);
      ArrayResize(m_mcShuffled, 0);
      ArrayInitialize(m_bandTrades, 0);
      ArrayInitialize(m_bandWins, 0);
      ArrayInitialize(m_bandNetPnL, 0.0);
   }

   void Initialize(const int walkForwardDays, const double oosRatio)
   {
      m_sessionStart = SafeCurrentTime();
      m_walkForwardDays = MathMax(3, walkForwardDays);
      m_oosSplitRatio = MathMax(0.10, MathMin(0.50, oosRatio));
      m_tradeCount = 0;
      m_cachedMcTradeCount = -1;
      m_cachedMcIters = 0;
      m_cachedMcMedDD = 0.0;
      m_cachedMcP95DD = 0.0;
      ArrayResize(m_tradePnLs, 0);
      ArrayInitialize(m_bandTrades, 0);
      ArrayInitialize(m_bandWins, 0);
      ArrayInitialize(m_bandNetPnL, 0.0);
   }

   void RecordTradeOutcome(const double pnl, const double signalScore)
   {
      int idx = m_tradeCount;
      if(idx >= ArraySize(m_tradePnLs))
         ArrayResize(m_tradePnLs, idx + 64);
      m_tradePnLs[idx] = pnl;
      m_tradeCount++;
      m_cachedMcTradeCount = -1; // Invalidate cached Monte Carlo quantiles

      if(signalScore >= 0.0)
      {
         int b = (signalScore >= 75.0) ? 2 : ((signalScore >= 60.0) ? 1 : 0);
         m_bandTrades[b]++;
         m_bandNetPnL[b] += pnl;
         if(pnl >= 0.0) m_bandWins[b]++;
      }
   }

   string GetScoreBandSummary() const
   {
      return StringFormat("Score<60:%d(%.0f) | 60-74:%d(%.0f) | 75+:%d(%.0f)",
                          m_bandTrades[0], m_bandNetPnL[0],
                          m_bandTrades[1], m_bandNetPnL[1],
                          m_bandTrades[2], m_bandNetPnL[2]);
   }

   SResearchFoldInfo GetFoldTag(const datetime t) const
   {
      SResearchFoldInfo info;
      info.splitBoundary = m_sessionStart;
      if(m_sessionStart <= 0 || t <= m_sessionStart)
      {
         info.foldIndex = 0;
         info.splitTag = "IN_SAMPLE";
         return info;
      }
      long elapsedDays = (long)(t - m_sessionStart) / 86400;
      info.foldIndex = (int)(elapsedDays / m_walkForwardDays);
      long dayInFold = elapsedDays % m_walkForwardDays;
      long isDays = (long)MathRound((double)m_walkForwardDays * (1.0 - m_oosSplitRatio));
      info.splitTag = (dayInFold >= isDays) ? "OUT_OF_SAMPLE" : "IN_SAMPLE";
      return info;
   }

   bool RunMonteCarloDrawdown95(const int iterations, double &outMedianMaxDD, double &outP95MaxDD)
   {
      outMedianMaxDD = 0.0;
      outP95MaxDD = 0.0;
      if(m_tradeCount < 15) return false;

      int iters = MathMax(50, MathMin(500, iterations));
      if(m_cachedMcTradeCount == m_tradeCount && m_cachedMcIters == iters)
      {
         outMedianMaxDD = m_cachedMcMedDD;
         outP95MaxDD = m_cachedMcP95DD;
         return true;
      }

      if(ArraySize(m_mcSamples) != iters)
         ArrayResize(m_mcSamples, iters);
      if(ArraySize(m_mcShuffled) < m_tradeCount)
         ArrayResize(m_mcShuffled, m_tradeCount);

      uint rng = 2463534242U;
      for(int it = 0; it < iters; it++)
      {
         for(int i = 0; i < m_tradeCount; i++) m_mcShuffled[i] = m_tradePnLs[i];
         for(int i = m_tradeCount - 1; i > 0; i--)
         {
            rng ^= (rng << 13);
            rng ^= (rng >> 17);
            rng ^= (rng << 5);
            int j = (int)(rng % (uint)(i + 1));
            double tmp = m_mcShuffled[i];
            m_mcShuffled[i] = m_mcShuffled[j];
            m_mcShuffled[j] = tmp;
         }

         double eq = 0.0, peak = 0.0, maxDD = 0.0;
         for(int i = 0; i < m_tradeCount; i++)
         {
            eq += m_mcShuffled[i];
            if(eq > peak) peak = eq;
            double dd = peak - eq;
            if(dd > maxDD) maxDD = dd;
         }
         m_mcSamples[it] = maxDD;
      }

      ArraySort(m_mcSamples);
      m_cachedMcMedDD = m_mcSamples[iters / 2];
      int p95Idx = (int)MathMin(iters - 1, MathFloor(0.95 * iters));
      m_cachedMcP95DD = m_mcSamples[p95Idx];
      m_cachedMcTradeCount = m_tradeCount;
      m_cachedMcIters = iters;

      outMedianMaxDD = m_cachedMcMedDD;
      outP95MaxDD = m_cachedMcP95DD;
      return true;
   }

   int GetSampleCount() const { return m_tradeCount; }
};

#endif // __ASEA_INTELLIGENCE_HISTORICALRESEARCH_MQH__
