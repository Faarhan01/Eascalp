//+------------------------------------------------------------------+
//|                                              MarketStructure.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.9.0 Confirmed vs Developing Structure  |
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
   datetime        m_lastAnalyzedBar;

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

   int CountZoneRejections(const MqlRates &rates[], const int barsCheck, const double level,
                           const double tol, const bool isResistance) const
   {
      if(level <= 0.0) return 0;
      int touches = 0;
      for(int i = 0; i < barsCheck; i++)
      {
         double rng = rates[i].high - rates[i].low;
         if(rng <= 0.0) continue;
         if(isResistance)
         {
            double upWick = rates[i].high - MathMax(rates[i].open, rates[i].close);
            if(rates[i].high >= level - tol && rates[i].close < level &&
               (rates[i].close < rates[i].open || upWick >= rng * 0.30))
               touches++;
         }
         else
         {
            double loWick = MathMin(rates[i].open, rates[i].close) - rates[i].low;
            if(rates[i].low <= level + tol && rates[i].close > level &&
               (rates[i].close > rates[i].open || loWick >= rng * 0.30))
               touches++;
         }
      }
      return touches;
   }

public:
   CMarketStructure()
   {
      m_swingStrength = 3;
      m_lookbackBars = 120;
      m_zoneAtrMult = 0.35;
      m_lastAnalyzedBar = 0;
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
      if(!data.IsDataReady()) return false;
      datetime barT = data.GetBarTime();
      if(barT == m_lastAnalyzedBar && m_state.isReady)
         return true; // Cached for current closed bar

      string sym = data.GetSymbol();

      MqlRates rates[];
      if(!data.CopyAvailableClosedRates(tf, 40, m_lookbackBars, rates))
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

      double swingHighs[12];
      datetime swingHighTimes[12];
      int shCount = 0;
      double swingLows[12];
      datetime swingLowTimes[12];
      int slCount = 0;

      // Estimate ATR when caller passes 0 so swing prominence still filters micro-noise
      double estAtr = atr;
      if(estAtr <= 0.0)
      {
         int avgN = MathMin(20, total);
         double sumR = 0.0;
         for(int i = 0; i < avgN; i++) sumR += (rates[i].high - rates[i].low);
         estAtr = (avgN > 0 && sumR > 0.0) ? (sumR / (double)avgN) : 1e-6;
      }
      double minProm = estAtr * 0.40;

      // Pass 1: Prominent structural swing pivots clearing minProm excursion across local window
      for(int i = m_swingStrength; i < total - m_swingStrength; i++)
      {
         if(shCount < 12 && IsSwingHigh(rates, i, total, m_swingStrength))
         {
            double winLow = rates[i].low;
            int wEnd = MathMin(total - 1, i + m_swingStrength + 2);
            int wStart = MathMax(0, i - m_swingStrength - 2);
            for(int j = wStart; j <= wEnd; j++)
               if(rates[j].low < winLow) winLow = rates[j].low;
            if((rates[i].high - winLow) >= minProm)
            {
               swingHighs[shCount] = rates[i].high;
               swingHighTimes[shCount] = rates[i].time;
               shCount++;
            }
         }
         if(slCount < 12 && IsSwingLow(rates, i, total, m_swingStrength))
         {
            double winHigh = rates[i].high;
            int wEnd = MathMin(total - 1, i + m_swingStrength + 2);
            int wStart = MathMax(0, i - m_swingStrength - 2);
            for(int j = wStart; j <= wEnd; j++)
               if(rates[j].high > winHigh) winHigh = rates[j].high;
            if((winHigh - rates[i].low) >= minProm)
            {
               swingLows[slCount] = rates[i].low;
               swingLowTimes[slCount] = rates[i].time;
               slCount++;
            }
         }
         if(shCount >= 12 && slCount >= 12) break;
      }

      // Pass 2: Graceful backfill if quiet range yields < 2 prominent swings
      if(shCount < 2 || slCount < 2)
      {
         shCount = 0;
         slCount = 0;
         for(int i = m_swingStrength; i < total - m_swingStrength; i++)
         {
            if(shCount < 12 && IsSwingHigh(rates, i, total, m_swingStrength))
            {
               swingHighs[shCount] = rates[i].high;
               swingHighTimes[shCount] = rates[i].time;
               shCount++;
            }
            if(slCount < 12 && IsSwingLow(rates, i, total, m_swingStrength))
            {
               swingLows[slCount] = rates[i].low;
               swingLowTimes[slCount] = rates[i].time;
               slCount++;
            }
            if(shCount >= 12 && slCount >= 12) break;
         }
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

      // Developing (unconfirmed) extrema in most recent swingStrength bars
      double devH = rates[0].high, devL = rates[0].low;
      for(int i = 1; i < m_swingStrength; i++)
      {
         if(rates[i].high > devH) devH = rates[i].high;
         if(rates[i].low  < devL) devL = rates[i].low;
      }
      m_state.developingHigh = devH;
      m_state.developingLow  = devL;

      m_state.hasHH = (m_state.lastSwingHigh > m_state.prevSwingHigh);
      m_state.hasLH = (m_state.lastSwingHigh < m_state.prevSwingHigh);
      m_state.hasHL = (m_state.lastSwingLow  > m_state.prevSwingLow);
      m_state.hasLL = (m_state.lastSwingLow  < m_state.prevSwingLow);

      // Consolidation range over bars [1..24] (prior to newest closed bar [0])
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

      // Refresh institutional Previous Day High/Low (PDH/PDL) once per D1 bar
      datetime curDayTime = iTime(sym, PERIOD_D1, 0);
      if(curDayTime > 0 && curDayTime != m_state.prevDayBarTime)
      {
         MqlRates d1Rates[];
         ArraySetAsSeries(d1Rates, true);
         if(CopyRates(sym, PERIOD_D1, 1, 1, d1Rates) == 1)
         {
            m_state.prevDayHigh    = d1Rates[0].high;
            m_state.prevDayLow     = d1Rates[0].low;
            m_state.prevDayBarTime = curDayTime;
         }
      }

      double effAtr = (atr > 0.0) ? atr : MathMax(1e-6, (rHigh - rLow) * 0.1);
      double rangeSpan = m_state.rangeHigh - m_state.rangeLow;
      m_state.rangeWidthAtr = rangeSpan / effAtr;
      double zoneTol = effAtr * m_zoneAtrMult;
      double lastClose = rates[0].close;
      double prevClose = rates[1].close;

      // Nearest S/R strictly below/above close so breakouts never invert anchors
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
      if(bestSup <= 0.0 && m_state.rangeLow < lastClose)
         bestSup = m_state.rangeLow;
      if(bestRes <= 0.0 && m_state.rangeHigh > lastClose)
         bestRes = m_state.rangeHigh;

      m_state.nearestSupport    = bestSup;
      m_state.nearestResistance = bestRes;

      m_state.supportRejectCount    = CountZoneRejections(rates, MathMin(30, total), m_state.nearestSupport, zoneTol, false);
      m_state.resistanceRejectCount = CountZoneRejections(rates, MathMin(30, total), m_state.nearestResistance, zoneTol, true);

      m_state.lastEvent = STRUCT_NONE;
      m_state.structureBias = 0;
      m_state.trendContinuation = false;
      m_state.trendExhaustion = false;
      m_state.structuralReversal = false;
      m_state.failedBreakout = false;
      m_state.breakoutRetest = false;

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

      // Tight vs Wide Consolidation
      bool nonTrend = !(m_state.hasHH && m_state.hasHL) && !(m_state.hasLH && m_state.hasLL);
      m_state.tightConsolidation = (m_state.rangeWidthAtr <= 2.8 && nonTrend);
      m_state.wideConsolidation  = (m_state.rangeWidthAtr > 2.8 && m_state.rangeWidthAtr <= 5.5 && nonTrend);
      m_state.inConsolidation    = (m_state.tightConsolidation || m_state.wideConsolidation);

      // Verify breakout actually occurred recently (bars [2..6]) before classifying a genuine retest
      bool recentBullBreak = false;
      bool recentBearBreak = false;
      int checkEnd = MathMin(6, total - 1);
      for(int b = 2; b <= checkEnd; b++)
      {
         if(rates[b].close <= m_state.lastSwingHigh) recentBullBreak = true;
         if(rates[b].close >= m_state.lastSwingLow)  recentBearBreak = true;
      }

      // Failed breakout detection: bar[1] closed outside swing/range, bar[0] closed back inside
      if(rates[1].close > m_state.lastSwingHigh && lastClose < m_state.lastSwingHigh)
      {
         m_state.lastEvent = STRUCT_FAILED_BREAKOUT_UP;
         m_state.failedBreakout = true;
         m_state.trendExhaustion = m_state.hasHH;
      }
      else if(rates[1].close < m_state.lastSwingLow && lastClose > m_state.lastSwingLow)
      {
         m_state.lastEvent = STRUCT_FAILED_BREAKOUT_DOWN;
         m_state.failedBreakout = true;
         m_state.trendExhaustion = m_state.hasLL;
      }
      // Breakout retest detection: price broke swing recently (within 2-6 bars) and pulled back to kiss level & bounce
      else if(recentBullBreak && lastClose > m_state.lastSwingHigh && rates[0].low <= m_state.lastSwingHigh + zoneTol &&
              rates[0].close > rates[0].open && prevClose > m_state.lastSwingHigh)
      {
         m_state.lastEvent = STRUCT_RETEST_BULL;
         m_state.breakoutRetest = true;
         m_state.structureBias = 1;
      }
      else if(recentBearBreak && lastClose < m_state.lastSwingLow && rates[0].high >= m_state.lastSwingLow - zoneTol &&
              rates[0].close < rates[0].open && prevClose < m_state.lastSwingLow)
      {
         m_state.lastEvent = STRUCT_RETEST_BEAR;
         m_state.breakoutRetest = true;
         m_state.structureBias = -1;
      }
      // BOS / CHoCH
      else if(lastClose > m_state.lastSwingHigh && prevClose <= m_state.lastSwingHigh)
      {
         if(m_state.hasLH && m_state.hasLL)
         {
            m_state.lastEvent = STRUCT_CHOCH_BULL;
            m_state.structuralReversal = true;
         }
         else
            m_state.lastEvent = STRUCT_BOS_BULL;
         m_state.structureBias = 1;
      }
      else if(lastClose < m_state.lastSwingLow && prevClose >= m_state.lastSwingLow)
      {
         if(m_state.hasHH && m_state.hasHL)
         {
            m_state.lastEvent = STRUCT_CHOCH_BEAR;
            m_state.structuralReversal = true;
         }
         else
            m_state.lastEvent = STRUCT_BOS_BEAR;
         m_state.structureBias = -1;
      }
      // Liquidity Sweep
      else if(rates[0].high > m_state.lastSwingHigh && lastClose < m_state.lastSwingHigh - zoneTol * 0.25)
      {
         m_state.lastEvent = STRUCT_LIQ_SWEEP_HIGH;
         m_state.trendExhaustion = m_state.hasHH;
      }
      else if(rates[0].low < m_state.lastSwingLow && lastClose > m_state.lastSwingLow + zoneTol * 0.25)
      {
         m_state.lastEvent = STRUCT_LIQ_SWEEP_LOW;
         m_state.trendExhaustion = m_state.hasLL;
      }
      else if(lastClose > m_state.rangeHigh && prevClose <= m_state.rangeHigh)
      {
         m_state.lastEvent = STRUCT_BREAKOUT_UP;
      }
      else if(lastClose < m_state.rangeLow && prevClose >= m_state.rangeLow)
      {
         m_state.lastEvent = STRUCT_BREAKOUT_DOWN;
      }
      else if(m_state.nearestResistance > lastClose && MathAbs(rates[0].high - m_state.nearestResistance) <= zoneTol && rates[0].close < rates[0].open)
      {
         m_state.lastEvent = STRUCT_REJECTION_HIGH;
      }
      else if(m_state.nearestSupport > 0.0 && m_state.nearestSupport < lastClose && MathAbs(rates[0].low - m_state.nearestSupport) <= zoneTol && rates[0].close > rates[0].open)
      {
         m_state.lastEvent = STRUCT_REJECTION_LOW;
      }

      string biasStr = (m_state.structureBias > 0) ? "Bullish (HH/HL)" : ((m_state.structureBias < 0) ? "Bearish (LH/LL)" : "Neutral/Mixed");
      if(m_state.tightConsolidation) biasStr += " [Tight Range]";
      else if(m_state.wideConsolidation) biasStr += " [Wide Range]";
      m_state.summary = biasStr;
      m_state.isReady = true;
      m_lastAnalyzedBar = barT;
      return true;
   }

   SStructureState GetState() const { return m_state; }
};

#endif // __ASEA_MARKET_MARKETSTRUCTURE_MQH__
