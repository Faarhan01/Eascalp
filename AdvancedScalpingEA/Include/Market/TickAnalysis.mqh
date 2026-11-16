//+------------------------------------------------------------------+
//|                                                 TickAnalysis.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.0.0 Cost-Aware Tick Intelligence       |
//+------------------------------------------------------------------+
#ifndef __ASEA_MARKET_TICKANALYSIS_MQH__
#define __ASEA_MARKET_TICKANALYSIS_MQH__

#include "../Core/Types.mqh"
#include "SymbolIntelligence.mqh"

struct STickSample
{
   long   timeMsc;
   double bid;
   double ask;
   double mid;
   double spreadPoints;
};

class CTickAnalysis
{
private:
   string               m_symbol;
   CSymbolIntelligence *m_symIntel;
   STickSample          m_buffer[];
   int                  m_capacity;
   int                  m_count;
   int                  m_head;
   double               m_prevVelocity;
   double               m_baselineTicksPerSec;
   double               m_avgSpreadPoints;
   STickMetrics         m_metrics;

   int GetIndexFromOldest(const int offsetFromOldest) const
   {
      if(m_count <= 0 || offsetFromOldest < 0 || offsetFromOldest >= m_count)
         return 0;
      int oldest = (m_count < m_capacity) ? 0 : m_head;
      return (oldest + offsetFromOldest) % m_capacity;
   }

public:
   CTickAnalysis()
   {
      m_symbol = "";
      m_symIntel = NULL;
      m_capacity = 64;
      m_count = 0;
      m_head = 0;
      m_prevVelocity = 0.0;
      m_baselineTicksPerSec = 1.0;
      m_avgSpreadPoints = 0.0;
      m_metrics.Reset();
   }

   bool Initialize(const string symbol, const int tickWindow, CSymbolIntelligence *symIntel)
   {
      m_symbol = symbol;
      m_symIntel = symIntel;
      m_capacity = MathMax(16, MathMin(256, tickWindow));
      ArrayResize(m_buffer, m_capacity);
      m_count = 0;
      m_head = 0;
      m_prevVelocity = 0.0;
      m_baselineTicksPerSec = 1.0;
      m_avgSpreadPoints = 0.0;
      m_metrics.Reset();

      MqlTick hist[];
      int copied = CopyTicks(m_symbol, hist, COPY_TICKS_INFO, 0, MathMin(m_capacity, 32));
      if(copied > 0)
      {
         SSymbolProfile prof = m_symIntel.GetProfile();
         double pt = (prof.point > 0.0) ? prof.point : 0.00001;
         for(int i = 0; i < copied; i++)
         {
            if(hist[i].bid <= 0.0 || hist[i].ask <= 0.0) continue;
            STickSample s;
            s.timeMsc = hist[i].time_msc;
            s.bid = hist[i].bid;
            s.ask = hist[i].ask;
            s.mid = (hist[i].bid + hist[i].ask) * 0.5;
            s.spreadPoints = (hist[i].ask - hist[i].bid) / pt;
            PushSample(s);
         }
         ComputeMetrics();
      }
      return true;
   }

   void PushSample(const STickSample &s)
   {
      m_buffer[m_head] = s;
      m_head = (m_head + 1) % m_capacity;
      if(m_count < m_capacity)
         m_count++;
   }

   void OnTickUpdate(const SMarketSnapshot &market)
   {
      if(!market.dataReady || m_symIntel == NULL) return;
      MqlTick t;
      if(!SymbolInfoTick(m_symbol, t)) return;
      if(t.bid <= 0.0 || t.ask <= 0.0) return;

      SSymbolProfile prof = m_symIntel.GetProfile();
      double pt = (prof.point > 0.0) ? prof.point : 0.00001;

      STickSample s;
      s.timeMsc = t.time_msc;
      s.bid = t.bid;
      s.ask = t.ask;
      s.mid = (t.bid + t.ask) * 0.5;
      s.spreadPoints = (t.ask - t.bid) / pt;

      if(m_count > 0)
      {
         int newestIdx = (m_head - 1 + m_capacity) % m_capacity;
         if(m_buffer[newestIdx].timeMsc == s.timeMsc &&
            MathAbs(m_buffer[newestIdx].bid - s.bid) < 1e-12 &&
            MathAbs(m_buffer[newestIdx].ask - s.ask) < 1e-12)
            return;
      }

      PushSample(s);
      m_avgSpreadPoints = market.avgSpreadPoints;
      ComputeMetrics();
   }

   void ComputeMetrics()
   {
      m_metrics.Reset();
      m_metrics.sampleCount = m_count;
      if(m_count < 6 || m_symIntel == NULL)
      {
         m_metrics.isReady = false;
         return;
      }

      SSymbolProfile prof = m_symIntel.GetProfile();
      double pt = (prof.point > 0.0) ? prof.point : 0.00001;
      double pipPts = (prof.pipSize > 0.0) ? MathMax(1.0, prof.pipSize / pt) : 1.0;

      int firstIdx = GetIndexFromOldest(0);
      int lastIdx  = GetIndexFromOldest(m_count - 1);
      int midIdx   = GetIndexFromOldest(m_count / 2);

      double elapsedSec = MathMax(0.1, (double)(m_buffer[lastIdx].timeMsc - m_buffer[firstIdx].timeMsc) / 1000.0);
      double tps = (double)m_count / elapsedSec;
      m_baselineTicksPerSec = 0.95 * m_baselineTicksPerSec + 0.05 * tps;
      if(m_baselineTicksPerSec < 0.05) m_baselineTicksPerSec = 0.05;

      double netPoints = (m_buffer[lastIdx].mid - m_buffer[firstIdx].mid) / pt;
      double recentSec = MathMax(0.05, (double)(m_buffer[lastIdx].timeMsc - m_buffer[midIdx].timeMsc) / 1000.0);
      double recentVel = ((m_buffer[lastIdx].mid - m_buffer[midIdx].mid) / pt) / recentSec;
      double accel = (recentVel - m_prevVelocity) / recentSec;
      double velThreshold = MathMax(0.20, pipPts * 0.12);
      bool velSlowing = (MathAbs(recentVel) < MathAbs(m_prevVelocity) * 0.75) && (MathAbs(m_prevVelocity) > velThreshold);
      m_prevVelocity = recentVel;

      // Consecutive direction runs
      int upRun = 0, downRun = 0;
      for(int k = m_count - 1; k >= 1; k--)
      {
         int cur = GetIndexFromOldest(k);
         int prv = GetIndexFromOldest(k - 1);
         double d = m_buffer[cur].mid - m_buffer[prv].mid;
         if(d > 0.0) { if(downRun > 0) break; upRun++; }
         else if(d < 0.0) { if(upRun > 0) break; downRun++; }
      }

      // Tick-to-tick deltas for persistence & short-term tick volatility
      double deltas[];
      ArrayResize(deltas, m_count - 1);
      int upSteps = 0, downSteps = 0;
      double sumDelta = 0.0, sumSpread = 0.0;
      for(int k = 1; k < m_count; k++)
      {
         int cur = GetIndexFromOldest(k);
         int prv = GetIndexFromOldest(k - 1);
         double dPts = (m_buffer[cur].mid - m_buffer[prv].mid) / pt;
         deltas[k - 1] = dPts;
         sumDelta += dPts;
         if(dPts > 0.0) upSteps++;
         else if(dPts < 0.0) downSteps++;
         sumSpread += m_buffer[cur].spreadPoints;
      }

      double meanDelta = sumDelta / (double)(m_count - 1);
      double varSum = 0.0;
      for(int k = 0; k < m_count - 1; k++)
      {
         double diff = deltas[k] - meanDelta;
         varSum += diff * diff;
      }
      double tickStdDevPts = MathSqrt(varSum / (double)MathMax(1, m_count - 2));

      int totalDirSteps = upSteps + downSteps;
      double bias = (totalDirSteps > 0) ? (double)(upSteps - downSteps) / (double)totalDirSteps : 0.0;
      double persistence = (totalDirSteps > 0) ? (double)MathMax(upSteps, downSteps) / (double)totalDirSteps : 0.0;

      double bidDelta = (m_buffer[lastIdx].bid - m_buffer[midIdx].bid) / pt;
      double askDelta = (m_buffer[lastIdx].ask - m_buffer[midIdx].ask) / pt;
      double curSpread = m_buffer[lastIdx].spreadPoints;
      double refSpread = (m_avgSpreadPoints > 0.0) ? m_avgSpreadPoints : (sumSpread / MathMax(1, m_count - 1));
      double spreadExp = (refSpread > 0.0) ? (curSpread / refSpread) : 1.0;

      m_metrics.consecutiveUpTicks     = upRun;
      m_metrics.consecutiveDownTicks   = downRun;
      m_metrics.directionalPersistence = persistence;
      m_metrics.ticksPerSecond         = tps;
      m_metrics.priceVelocity          = recentVel;
      m_metrics.priceAcceleration      = accel;
      m_metrics.shortTermDisplacement  = netPoints;
      m_metrics.shortTermVolatilityPts = tickStdDevPts;
      m_metrics.bidDeltaPts            = bidDelta;
      m_metrics.askDeltaPts            = askDelta;
      m_metrics.microTrendBias         = bias;
      m_metrics.spreadExpansionRatio   = spreadExp;
      m_metrics.activityRatio          = tps / m_baselineTicksPerSec;
      m_metrics.spreadSpikeDetected    = ((spreadExp >= 2.80 && curSpread > MathMax(4.0, pipPts * 1.5)) ||
                                          (spreadExp >= 4.00 && curSpread > MathMax(2.0, pipPts * 0.6)));
      m_metrics.suddenActivitySurge    = (m_metrics.activityRatio >= 1.65 && MathAbs(recentVel) > MathMax(0.4, pipPts * 0.20));
      m_metrics.momentumDeteriorating  = velSlowing;

      // Only grant tick edge value if displacement meaningfully clears current spread cost
      m_metrics.tickProvidesNetEdge = (!m_metrics.spreadSpikeDetected &&
                                       MathAbs(netPoints) > curSpread * 1.15 &&
                                       persistence >= 0.54);
      m_metrics.isReady = true;
   }

   STickMetrics GetMetrics() const { return m_metrics; }
};

#endif // __ASEA_MARKET_TICKANALYSIS_MQH__
