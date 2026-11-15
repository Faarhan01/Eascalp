//+------------------------------------------------------------------+
//|                                              MarketStructure.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        Swing Points, S/R Zones, BOS, CHoCH & Liq |
//+------------------------------------------------------------------+
#ifndef __ASEA_MARKET_MARKETSTRUCTURE_MQH__
#define __ASEA_MARKET_MARKETSTRUCTURE_MQH__

#include "../Core/Types.mqh"
#include "MarketData.mqh"

class CMarketStructure
{
private:
   int             m_swingStrength;
   int             m_lookbackBars;
   double          m_zoneAtrMult;
   SStructureState m_state;

   bool IsSwingHigh(const MqlRates &rates[], const int idx, const int total, const int strength) const
   {
      if(idx < strength || idx + strength >= total) return false;
      double val = rates[idx].high;
      for(int k = 1; k <= strength; k++)
      {
         if(rates[idx - k].high >= val || rates[idx + k].high > val)
            return false;
      }
      return true;
   }

   bool IsSwingLow(const MqlRates &rates[], const int idx, const int total, const int strength) const
   {
      if(idx < strength || idx + strength >= total) return false;
      double val = rates[idx].low;
      for(int k = 1; k <= strength; k++)
      {
         if(rates[idx - k].low <= val || rates[idx + k].low < val)
            return false;
      }
      return true;
   }

public:
   CMarketStructure()
   {
      m_swingStrength = 3;
      m_lookbackBars = 120;
      m_zoneAtrMult = 0.35;
      m_state.Reset();
   }

   void Configure(const int swingStrength, const int lookbackBars, const double zoneAtrMult)
   {
      m_swingStrength = MathMax(2, MathMin(10, swingStrength));
      m_lookbackBars  = MathMax(40, MathMin(300, lookbackBars));
      m_zoneAtrMult   = MathMax(0.1, MathMin(2.0, zoneAtrMult));
   }

   bool Analyze(const CMarketData &data, const ENUM_TIMEFRAMES tf, const double atr)
   {
      MqlRates rates[];
      if(!data.CopyClosedRates(tf, m_lookbackBars, rates))
      {
         m_state.isReady = false;
         m_state.summary = "Insufficient history";
         return false;
      }

      int total = ArraySize(rates);
      if(total < m_swingStrength * 4)
      {
         m_state.isReady = false;
         return false;
      }

      double swingHighs[10];
      datetime swingHighTimes[10];
      int shCount = 0;

      double swingLows[10];
      datetime swingLowTimes[10];
      int slCount = 0;

      // rates[0] is the most recently CLOSED bar (no look-ahead)
      for(int i = m_swingStrength; i < total - m_swingStrength; i++)
      {
         if(shCount < 10 && IsSwingHigh(rates, i, total, m_swingStrength))
         {
            swingHighs[shCount] = rates[i].high;
            swingHighTimes[shCount] = rates[i].time;
            shCount++;
         }
         if(slCount < 10 && IsSwingLow(rates, i, total, m_swingStrength))
         {
            swingLows[slCount] = rates[i].low;
            swingLowTimes[slCount] = rates[i].time;
            slCount++;
         }
         if(shCount >= 10 && slCount >= 10) break;
      }

      if(shCount < 2 || slCount < 2)
      {
         m_state.isReady = false;
         m_state.summary = "Awaiting confirmed swings";
         return false;
      }

      m_state.lastSwingHigh     = swingHighs[0];
      m_state.prevSwingHigh     = swingHighs[1];
      m_state.lastSwingHighTime = swingHighTimes[0];
      m_state.lastSwingLow      = swingLows[0];
      m_state.prevSwingLow      = swingLows[1];
      m_state.lastSwingLowTime  = swingLowTimes[0];

      m_state.hasHH = (m_state.lastSwingHigh > m_state.prevSwingHigh);
      m_state.hasLH = (m_state.lastSwingHigh < m_state.prevSwingHigh);
      m_state.hasHL = (m_state.lastSwingLow  > m_state.prevSwingLow);
      m_state.hasLL = (m_state.lastSwingLow  < m_state.prevSwingLow);

      // Compute nearest support / resistance and recent 24-bar range boundaries
      double rHigh = rates[1].high;
      double rLow  = rates[1].low;
      int rangeBars = MathMin(24, total - 1);
      for(int i = 1; i <= rangeBars; i++)
      {
         if(rates[i].high > rHigh) rHigh = rates[i].high;
         if(rates[i].low  < rLow)  rLow  = rates[i].low;
      }
      m_state.rangeHigh = rHigh;
      m_state.rangeLow  = rLow;

      double lastClose = rates[0].close;
      double prevClose = rates[1].close;
      double effAtr = (atr > 0.0) ? atr : MathMax(1e-6, (rHigh - rLow) * 0.1);
      double zoneTol = effAtr * m_zoneAtrMult;

      // Nearest S/R from confirmed swings relative to current closed price
      double bestSup = 0.0, bestRes = 0.0;
      double minSupDist = 1e18, minResDist = 1e18;
      for(int i = 0; i < slCount; i++)
      {
         if(swingLows[i] <= lastClose && (lastClose - swingLows[i]) < minSupDist)
         {
            minSupDist = lastClose - swingLows[i];
            bestSup = swingLows[i];
         }
      }
      for(int i = 0; i < shCount; i++)
      {
         if(swingHighs[i] >= lastClose && (swingHighs[i] - lastClose) < minResDist)
         {
            minResDist = swingHighs[i] - lastClose;
            bestRes = swingHighs[i];
         }
      }
      m_state.nearestSupport    = (bestSup > 0.0) ? bestSup : m_state.lastSwingLow;
      m_state.nearestResistance = (bestRes > 0.0) ? bestRes : m_state.lastSwingHigh;

      // Bias and events (BOS / CHoCH / Liquidity Sweep / Rejection / Breakout)
      m_state.lastEvent = STRUCT_NONE;
      m_state.structureBias = 0;
      m_state.trendContinuation = false;
      m_state.trendExhaustion = false;

      if(m_state.hasHH && m_state.hasHL)
      {
         m_state.structureBias = 1;
         m_state.trendContinuation = true;
      }
      else if(m_state.hasLH && m_state.hasLL)
      {
         m_state.structureBias = -1;
         m_state.trendContinuation = true;
      }

      // Consolidation detection: narrow range relative to ATR and mixed swings
      double rangeSpan = m_state.rangeHigh - m_state.rangeLow;
      m_state.inConsolidation = (rangeSpan < effAtr * 4.5 && !(m_state.hasHH && m_state.hasHL) && !(m_state.hasLH && m_state.hasLL));

      // Break of Structure (BOS) & Change of Character (CHoCH)
      if(lastClose > m_state.lastSwingHigh && prevClose <= m_state.lastSwingHigh)
      {
         if(m_state.hasLH && m_state.hasLL)
            m_state.lastEvent = STRUCT_CHOCH_BULL;
         else
            m_state.lastEvent = STRUCT_BOS_BULL;
         m_state.structureBias = 1;
      }
      else if(lastClose < m_state.lastSwingLow && prevClose >= m_state.lastSwingLow)
      {
         if(m_state.hasHH && m_state.hasHL)
            m_state.lastEvent = STRUCT_CHOCH_BEAR;
         else
            m_state.lastEvent = STRUCT_BOS_BEAR;
         m_state.structureBias = -1;
      }
      // Objective Liquidity Sweep: wick pierces confirmed swing high/low, but bar closes back inside
      else if(rates[0].high > m_state.lastSwingHigh && lastClose < m_state.lastSwingHigh - zoneTol * 0.25)
      {
         m_state.lastEvent = STRUCT_LIQ_SWEEP_HIGH;
         m_state.trendExhaustion = (m_state.hasHH);
      }
      else if(rates[0].low < m_state.lastSwingLow && lastClose > m_state.lastSwingLow + zoneTol * 0.25)
      {
         m_state.lastEvent = STRUCT_LIQ_SWEEP_LOW;
         m_state.trendExhaustion = (m_state.hasLL);
      }
      else if(lastClose > m_state.rangeHigh && prevClose <= m_state.rangeHigh)
      {
         m_state.lastEvent = STRUCT_BREAKOUT_UP;
      }
      else if(lastClose < m_state.rangeLow && prevClose >= m_state.rangeLow)
      {
         m_state.lastEvent = STRUCT_BREAKOUT_DOWN;
      }
      else if(MathAbs(rates[0].high - m_state.nearestResistance) <= zoneTol && rates[0].close < rates[0].open)
      {
         m_state.lastEvent = STRUCT_REJECTION_HIGH;
      }
      else if(MathAbs(rates[0].low - m_state.nearestSupport) <= zoneTol && rates[0].close > rates[0].open)
      {
         m_state.lastEvent = STRUCT_REJECTION_LOW;
      }

      string biasStr = (m_state.structureBias > 0) ? "Bullish (HH/HL)" : ((m_state.structureBias < 0) ? "Bearish (LH/LL)" : "Neutral/Mixed");
      if(m_state.inConsolidation) biasStr += " [Consolidating]";
      m_state.summary = biasStr;
      m_state.isReady = true;
      return true;
   }

   SStructureState GetState() const { return m_state; }
};

#endif // __ASEA_MARKET_MARKETSTRUCTURE_MQH__
