//+------------------------------------------------------------------+
//|                                                   MarketData.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.9.0 Cached Multi-Timeframe Data Engine |
//+------------------------------------------------------------------+
#ifndef __ASEA_MARKET_MARKETDATA_MQH__
#define __ASEA_MARKET_MARKETDATA_MQH__

#include "../Core/Types.mqh"
#include "../Core/Diagnostics.mqh"
#include "SymbolIntelligence.mqh"

class CMarketData
{
private:
   string               m_symbol;
   ENUM_TIMEFRAMES      m_primaryTF;
   CDiagnostics        *m_diag;
   CSymbolIntelligence *m_symIntel;

   ENUM_TIMEFRAMES m_supportedTFs[EA_MAX_TF_SLOTS];
   bool            m_tfAvailable[EA_MAX_TF_SLOTS];

   double          m_spreadHistory[];
   int             m_spreadCap;
   int             m_spreadCount;
   int             m_spreadHead;
   double          m_spreadSum;
   int             m_spreadOps;

   SMarketSnapshot m_snapshot;
   datetime        m_lastClosedBarTime;
   MqlRates        m_cachedClosedBar;
   datetime        m_cachedBarStamp;

   void RecordSpread(const double spreadPts)
   {
      if(m_spreadCap <= 0) return;
      if(m_spreadCount >= m_spreadCap)
         m_spreadSum -= m_spreadHistory[m_spreadHead];
      else
         m_spreadCount++;

      m_spreadHistory[m_spreadHead] = spreadPts;
      m_spreadSum += spreadPts;
      m_spreadHead = (m_spreadHead + 1) % m_spreadCap;

      // Periodic exact resync prevents long-run floating-point accumulation drift
      if(++m_spreadOps >= 4096)
      {
         m_spreadOps = 0;
         double exactSum = 0.0;
         for(int i = 0; i < m_spreadCount; i++)
            exactSum += m_spreadHistory[i];
         m_spreadSum = exactSum;
      }
   }

   double ComputeAverageSpread() const
   {
      if(m_spreadCount <= 0) return m_snapshot.spreadPoints;
      double avg = m_spreadSum / (double)m_spreadCount;
      return (avg > 0.0) ? avg : m_snapshot.spreadPoints;
   }

public:
   CMarketData()
   {
      m_symbol = "";
      m_primaryTF = PERIOD_M5;
      m_diag = NULL;
      m_symIntel = NULL;
      m_spreadCap = 120;
      m_spreadCount = 0;
      m_spreadHead = 0;
      m_spreadSum = 0.0;
      m_spreadOps = 0;
      m_lastClosedBarTime = 0;
      m_cachedBarStamp = 0;
      m_snapshot.Reset();
   }

   bool Initialize(const string symbol, const ENUM_TIMEFRAMES primaryTF, const int spreadAvgWindow,
                   CSymbolIntelligence *symIntel, CDiagnostics *diag)
   {
      m_symbol = symbol;
      m_primaryTF = primaryTF;
      m_symIntel = symIntel;
      m_diag = diag;
      m_spreadCap = MathMax(10, MathMin(500, spreadAvgWindow));
      ArrayResize(m_spreadHistory, m_spreadCap);
      ArrayInitialize(m_spreadHistory, 0.0);
      m_spreadCount = 0;
      m_spreadHead = 0;
      m_spreadSum = 0.0;
      m_spreadOps = 0;
      m_lastClosedBarTime = 0;
      m_cachedBarStamp = 0;

      m_supportedTFs[0]  = PERIOD_M1;
      m_supportedTFs[1]  = PERIOD_M2;
      m_supportedTFs[2]  = PERIOD_M3;
      m_supportedTFs[3]  = PERIOD_M4;
      m_supportedTFs[4]  = PERIOD_M5;
      m_supportedTFs[5]  = PERIOD_M6;
      m_supportedTFs[6]  = PERIOD_M10;
      m_supportedTFs[7]  = PERIOD_M12;
      m_supportedTFs[8]  = PERIOD_M15;
      m_supportedTFs[9]  = PERIOD_M20;
      m_supportedTFs[10] = PERIOD_M30;
      m_supportedTFs[11] = PERIOD_H1;
      m_supportedTFs[12] = PERIOD_H2;
      m_supportedTFs[13] = PERIOD_H4;

      for(int i = 0; i < EA_MAX_TF_SLOTS; i++)
         m_tfAvailable[i] = (Bars(m_symbol, m_supportedTFs[i]) >= 30);

      // Seed spread moving average from recent terminal ticks so initial spreadRatio is calibrated immediately
      double initPt = (m_symIntel != NULL) ? m_symIntel.GetPoint() : 0.0;
      if(initPt > 0.0)
      {
         MqlTick seedTicks[];
         int copied = CopyTicks(m_symbol, seedTicks, COPY_TICKS_INFO, 0, MathMin(m_spreadCap, 120));
         if(copied > 0)
         {
            for(int tIdx = 0; tIdx < copied; tIdx++)
            {
               if(seedTicks[tIdx].bid > 0.0 && seedTicks[tIdx].ask >= seedTicks[tIdx].bid)
               {
                  double sPts = (seedTicks[tIdx].ask - seedTicks[tIdx].bid) / initPt;
                  if(sPts >= 0.0 && MathIsValidNumber(sPts))
                     RecordSpread(sPts);
               }
            }
         }
      }

      return Update();
   }

   bool Update(const double currentAtr = 0.0)
   {
      MqlTick tick;
      if(!SymbolInfoTick(m_symbol, tick))
      {
         if(m_diag != NULL)
            m_diag.Log(LOG_WARN, "MarketData", StringFormat("SymbolInfoTick failed for %s", m_symbol), "tick_fail_" + m_symbol, 30);
         m_snapshot.dataReady = false;
         return false;
      }

      double pt = (m_symIntel != NULL) ? m_symIntel.GetPoint() : 0.0;
      if(pt <= 0.0 || tick.bid <= 0.0 || tick.ask <= 0.0 || tick.ask < tick.bid)
      {
         m_snapshot.dataReady = false;
         return false;
      }

      double spreadPts = (tick.ask - tick.bid) / pt;
      RecordSpread(spreadPts);
      double avgSpread = ComputeAverageSpread();

      // Cache closed bar [1] until current bar timestamp advances (reduces CopyRates overhead)
      datetime curBarTime = iTime(m_symbol, m_primaryTF, 0);
      if(curBarTime <= 0)
      {
         m_snapshot.dataReady = false;
         return false;
      }
      if(curBarTime != m_cachedBarStamp)
      {
         MqlRates rates[];
         ArraySetAsSeries(rates, true);
         if(CopyRates(m_symbol, m_primaryTF, 1, 1, rates) != 1)
         {
            m_snapshot.dataReady = false;
            return false;
         }
         m_cachedClosedBar = rates[0];
         m_cachedBarStamp = curBarTime;
      }

      m_snapshot.symbol          = m_symbol;
      m_snapshot.timeframe       = m_primaryTF;
      m_snapshot.tickTime        = tick.time;
      m_snapshot.tickTimeMsc     = tick.time_msc;
      m_snapshot.barTime         = curBarTime;
      m_snapshot.bid             = tick.bid;
      m_snapshot.ask             = tick.ask;
      m_snapshot.lastPrice       = (tick.last > 0.0) ? tick.last : (tick.bid + tick.ask) * 0.5;
      m_snapshot.midPrice        = (tick.bid + tick.ask) * 0.5;
      m_snapshot.spreadPoints    = spreadPts;
      m_snapshot.avgSpreadPoints = (avgSpread > 0.0) ? avgSpread : spreadPts;
      m_snapshot.spreadRatio     = (m_snapshot.avgSpreadPoints > 0.0) ? (spreadPts / m_snapshot.avgSpreadPoints) : 1.0;

      m_snapshot.open       = m_cachedClosedBar.open;
      m_snapshot.high       = m_cachedClosedBar.high;
      m_snapshot.low        = m_cachedClosedBar.low;
      m_snapshot.close      = m_cachedClosedBar.close;
      m_snapshot.tickVolume = m_cachedClosedBar.tick_volume;
      m_snapshot.realVolume = m_cachedClosedBar.real_volume;
      m_snapshot.barRange   = m_cachedClosedBar.high - m_cachedClosedBar.low;
      m_snapshot.priceChange = m_cachedClosedBar.close - m_cachedClosedBar.open;
      m_snapshot.priceChangePct = (m_cachedClosedBar.open > 0.0) ? ((m_snapshot.priceChange / m_cachedClosedBar.open) * 100.0) : 0.0;
      m_snapshot.normalizedBarRangeAtr = (currentAtr > 0.0) ? (m_snapshot.barRange / currentAtr) : 1.0;
      m_snapshot.dataReady  = true;

      return true;
   }

   bool IsNewClosedBar()
   {
      if(!m_snapshot.dataReady) return false;
      if(m_snapshot.barTime > 0 && m_snapshot.barTime != m_lastClosedBarTime)
      {
         m_lastClosedBarTime = m_snapshot.barTime;
         return true;
      }
      return false;
   }

   bool CopyClosedRates(const ENUM_TIMEFRAMES tf, const int count, MqlRates &outRates[]) const
   {
      if(count <= 0) return false;
      ArraySetAsSeries(outRates, true);
      int available = Bars(m_symbol, tf);
      if(available < count + 2) return false;
      return (CopyRates(m_symbol, tf, 1, count, outRates) == count);
   }

   bool CopyAvailableClosedRates(const ENUM_TIMEFRAMES tf, const int minCount, const int maxCount, MqlRates &outRates[]) const
   {
      if(minCount <= 0 || maxCount < minCount) return false;
      ArraySetAsSeries(outRates, true);
      int available = Bars(m_symbol, tf) - 2;
      if(available < minCount) return false;
      int copyN = MathMin(maxCount, available);
      return (CopyRates(m_symbol, tf, 1, copyN, outRates) == copyN);
   }

   bool HasSufficientHistory(const ENUM_TIMEFRAMES tf, const int minBars) const
   {
      if(Bars(m_symbol, tf) < minBars) return false;
      return (SeriesInfoInteger(m_symbol, tf, SERIES_SYNCHRONIZED) != 0 || MQLInfoInteger(MQL_TESTER) != 0);
   }

   bool            IsDataReady() const       { return m_snapshot.dataReady; }
   datetime        GetBarTime() const        { return m_snapshot.barTime; }
   datetime        GetTickTime() const       { return m_snapshot.tickTime; }
   string          GetSymbol() const         { return m_symbol; }
   double          GetSpreadRatio() const    { return m_snapshot.spreadRatio; }
   double          GetSpreadPoints() const   { return m_snapshot.spreadPoints; }
   double          GetAvgSpreadPoints() const{ return m_snapshot.avgSpreadPoints; }
   double          GetClosedClose() const    { return m_snapshot.close; }
   SMarketSnapshot GetSnapshot() const       { return m_snapshot; }
};

#endif // __ASEA_MARKET_MARKETDATA_MQH__
