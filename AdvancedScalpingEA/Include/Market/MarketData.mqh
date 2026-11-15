//+------------------------------------------------------------------+
//|                                                   MarketData.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        OHLCV, Quote & Multi-Timeframe Data Engine|
//+------------------------------------------------------------------+
#ifndef __ASEA_MARKET_MARKETDATA_MQH__
#define __ASEA_MARKET_MARKETDATA_MQH__

#include "../Core/Types.mqh"
#include "../Core/Diagnostics.mqh"
#include "SymbolIntelligence.mqh"

class CMarketData
{
private:
   string          m_symbol;
   ENUM_TIMEFRAMES m_primaryTF;
   CDiagnostics   *m_diag;
   CSymbolIntelligence *m_symIntel;

   ENUM_TIMEFRAMES m_supportedTFs[EA_MAX_TF_SLOTS];
   bool            m_tfAvailable[EA_MAX_TF_SLOTS];

   double          m_spreadHistory[];
   int             m_spreadCap;
   int             m_spreadCount;
   int             m_spreadHead;

   SMarketSnapshot m_snapshot;
   datetime        m_lastClosedBarTime;

   void RecordSpread(const double spreadPts)
   {
      if(m_spreadCap <= 0) return;
      m_spreadHistory[m_spreadHead] = spreadPts;
      m_spreadHead = (m_spreadHead + 1) % m_spreadCap;
      if(m_spreadCount < m_spreadCap)
         m_spreadCount++;
   }

   double ComputeAverageSpread() const
   {
      if(m_spreadCount <= 0) return m_snapshot.spreadPoints;
      double sum = 0.0;
      for(int i = 0; i < m_spreadCount; i++)
         sum += m_spreadHistory[i];
      return sum / (double)m_spreadCount;
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
      m_lastClosedBarTime = 0;
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
      m_lastClosedBarTime = 0;

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

      return Update();
   }

   bool Update()
   {
      MqlTick tick;
      if(!SymbolInfoTick(m_symbol, tick))
      {
         if(m_diag != NULL)
            m_diag.Log(LOG_WARN, "MarketData", StringFormat("SymbolInfoTick failed for %s (err=%d)", m_symbol, GetLastError()), "tick_fail", 30);
         m_snapshot.dataReady = false;
         return false;
      }

      SSymbolProfile prof = m_symIntel.GetProfile();
      if(prof.point <= 0.0 || tick.bid <= 0.0 || tick.ask <= 0.0 || tick.ask < tick.bid)
      {
         m_snapshot.dataReady = false;
         return false;
      }

      double spreadPts = (tick.ask - tick.bid) / prof.point;
      RecordSpread(spreadPts);
      double avgSpread = ComputeAverageSpread();

      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int copied = CopyRates(m_symbol, m_primaryTF, 0, 3, rates);
      if(copied < 2)
      {
         if(m_diag != NULL)
            m_diag.Log(LOG_WARN, "MarketData", StringFormat("Insufficient OHLC bars on %s %s (copied=%d)", m_symbol, EnumToString(m_primaryTF), copied), "bars_low", 30);
         m_snapshot.dataReady = false;
         return false;
      }

      m_snapshot.symbol          = m_symbol;
      m_snapshot.timeframe       = m_primaryTF;
      m_snapshot.tickTime        = tick.time;
      m_snapshot.barTime         = rates[0].time;
      m_snapshot.bid             = tick.bid;
      m_snapshot.ask             = tick.ask;
      m_snapshot.lastPrice       = (tick.last > 0.0) ? tick.last : (tick.bid + tick.ask) * 0.5;
      m_snapshot.midPrice        = (tick.bid + tick.ask) * 0.5;
      m_snapshot.spreadPoints    = spreadPts;
      m_snapshot.avgSpreadPoints = (avgSpread > 0.0) ? avgSpread : spreadPts;
      m_snapshot.spreadRatio     = (m_snapshot.avgSpreadPoints > 0.0) ? (spreadPts / m_snapshot.avgSpreadPoints) : 1.0;

      // Completed bar [1] for non-repainting OHLC statistics
      m_snapshot.open       = rates[1].open;
      m_snapshot.high       = rates[1].high;
      m_snapshot.low        = rates[1].low;
      m_snapshot.close      = rates[1].close;
      m_snapshot.tickVolume = rates[1].tick_volume;
      m_snapshot.realVolume = rates[1].real_volume;
      m_snapshot.barRange   = rates[1].high - rates[1].low;
      m_snapshot.priceChange = rates[1].close - rates[1].open;
      m_snapshot.priceChangePct = (rates[1].open > 0.0) ? ((m_snapshot.priceChange / rates[1].open) * 100.0) : 0.0;
      m_snapshot.dataReady  = true;

      return true;
   }

   bool IsNewClosedBar()
   {
      if(!m_snapshot.dataReady) return false;
      datetime curBar = iTime(m_symbol, m_primaryTF, 0);
      if(curBar > 0 && curBar != m_lastClosedBarTime)
      {
         m_lastClosedBarTime = curBar;
         return true;
      }
      return false;
   }

   bool CopyClosedRates(const ENUM_TIMEFRAMES tf, const int count, MqlRates &outRates[]) const
   {
      if(count <= 0) return false;
      ArraySetAsSeries(outRates, true);
      int available = Bars(m_symbol, tf);
      if(available < count + 2)
         return false;
      // Start at shift=1 so shift=0 in outRates is always the last COMPLETED bar (prevents look-ahead bias)
      int copied = CopyRates(m_symbol, tf, 1, count, outRates);
      return (copied == count);
   }

   bool HasSufficientHistory(const ENUM_TIMEFRAMES tf, const int minBars) const
   {
      return (Bars(m_symbol, tf) >= minBars);
   }

   SMarketSnapshot GetSnapshot() const { return m_snapshot; }
};

#endif // __ASEA_MARKET_MARKETDATA_MQH__
