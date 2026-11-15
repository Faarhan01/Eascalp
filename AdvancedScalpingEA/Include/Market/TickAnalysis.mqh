//+------------------------------------------------------------------+
//|                                                 TickAnalysis.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        Short-Term Tick Velocity & Micro-Momentum |
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
   string              m_symbol;
   CSymbolIntelligence *m_symIntel;
   STickSample         m_buffer[];
   int                 m_capacity;
   int                 m_count;
   int                 m_head;
   double              m_prevVelocity;
   double              m_baselineTicksPerSec;
   double              m_avgSpreadPoints;
   STickMetrics        m_metrics;

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

      // Seed from recent historical ticks if available (no future ticks)
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

      // Avoid duplicate identical tick timestamps & prices
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

      int firstIdx = GetIndexFromOldest(0);
      int lastIdx  = GetIndexFromOldest(m_count - 1);

      double elapsedSec = (double)(m_buffer[lastIdx].timeMsc - m_buffer[firstIdx].timeMsc) / 1000.0;
      if(elapsedSec < 0.1) elapsedSec = 0.1;

      double tps = (double)m_count / elapsedSec;
      m_baselineTicksPerSec = 0.95 * m_baselineTicksPerSec + 0.05 * tps;
      if(m_baselineTicksPerSec < 0.05) m_baselineTicksPerSec = 0.05;

      double netPoints = (m_buffer[lastIdx].mid - m_buffer[firstIdx].mid) / pt;
      double velocity = netPoints / elapsedSec;

      // Recent half-window velocity for acceleration
      int midOffset = m_count / 2;
      int midIdx = GetIndexFromOldest(midOffset);
      double recentSec = (double)(m_buffer[lastIdx].timeMsc - m_buffer[midIdx].timeMsc) / 1000.0;
      if(recentSec < 0.05) recentSec = 0.05;
      double recentVel = ((m_buffer[lastIdx].mid - m_buffer[midIdx].mid) / pt) / recentSec;
      double accel = (recentVel - m_prevVelocity) / recentSec;
      m_prevVelocity = recentVel;

      // Consecutive tick direction from newest backwards
      int upRun = 0, downRun = 0;
      for(int k = m_count - 1; k >= 1; k--)
      {
         int cur = GetIndexFromOldest(k);
         int prv = GetIndexFromOldest(k - 1);
         double d = m_buffer[cur].mid - m_buffer[prv].mid;
         if(d > 0.0)
         {
            if(downRun > 0) break;
            upRun++;
         }
         else if(d < 0.0)
         {
            if(upRun > 0) break;
            downRun++;
         }
      }

      // Micro-trend bias: net up steps vs down steps across window
      int upSteps = 0, downSteps = 0;
      double sumSpread = 0.0;
      for(int k = 1; k < m_count; k++)
      {
         int cur = GetIndexFromOldest(k);
         int prv = GetIndexFromOldest(k - 1);
         double d = m_buffer[cur].mid - m_buffer[prv].mid;
         if(d > 0.0) upSteps++;
         else if(d < 0.0) downSteps++;
         sumSpread += m_buffer[cur].spreadPoints;
      }
      int totalDirSteps = upSteps + downSteps;
      double bias = (totalDirSteps > 0) ? (double)(upSteps - downSteps) / (double)totalDirSteps : 0.0;

      // Bid/ask movement asymmetry
      double bidMove = (m_buffer[lastIdx].bid - m_buffer[midIdx].bid) / pt;
      double askMove = (m_buffer[lastIdx].ask - m_buffer[midIdx].ask) / pt;
      double imbalance = (MathAbs(bidMove) + MathAbs(askMove) > 0.0) ? ((bidMove + askMove) * 0.5) : 0.0;

      double curSpread = m_buffer[lastIdx].spreadPoints;
      double refSpread = (m_avgSpreadPoints > 0.0) ? m_avgSpreadPoints : (sumSpread / MathMax(1, m_count - 1));
      double spreadExp = (refSpread > 0.0) ? (curSpread / refSpread) : 1.0;

      m_metrics.consecutiveUpTicks   = upRun;
      m_metrics.consecutiveDownTicks = downRun;
      m_metrics.ticksPerSecond       = tps;
      m_metrics.priceVelocity        = recentVel;
      m_metrics.priceAcceleration    = accel;
      m_metrics.shortTermMomentum    = netPoints;
      m_metrics.microTrendBias       = bias;
      m_metrics.bidAskImbalance      = imbalance;
      m_metrics.spreadExpansionRatio = spreadExp;
      m_metrics.activityRatio        = tps / m_baselineTicksPerSec;
      m_metrics.spreadSpikeDetected  = (spreadExp >= 1.85);
      m_metrics.suddenMoveDetected   = (MathAbs(recentVel) > 15.0 && m_metrics.activityRatio > 1.5);
      m_metrics.isReady              = true;
   }

   STickMetrics GetMetrics() const { return m_metrics; }
};

#endif // __ASEA_MARKET_TICKANALYSIS_MQH__
