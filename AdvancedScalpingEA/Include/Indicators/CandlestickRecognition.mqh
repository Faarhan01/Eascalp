//+------------------------------------------------------------------+
//|                                       CandlestickRecognition.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.9.0 Context-Aware Price Action Engine  |
//+------------------------------------------------------------------+
#ifndef __ASEA_INDICATORS_CANDLESTICKRECOGNITION_MQH__
#define __ASEA_INDICATORS_CANDLESTICKRECOGNITION_MQH__

#include "../Core/Types.mqh"
#include "../Market/MarketData.mqh"

class CCandlestickRecognition
{
private:
   double        m_dojiBodyMaxRatio;
   double        m_pinWickMinRatio;
   SCandleSignal m_signal;
   datetime      m_lastAnalyzedBar;

public:
   CCandlestickRecognition()
   {
      m_dojiBodyMaxRatio = 0.12;
      m_pinWickMinRatio  = 2.0;
      m_lastAnalyzedBar  = 0;
      m_signal.Reset();
   }

   void Configure(const double dojiMaxBodyRatio, const double pinWickMinRatio)
   {
      m_dojiBodyMaxRatio = MathMax(0.03, MathMin(0.25, dojiMaxBodyRatio));
      m_pinWickMinRatio  = MathMax(1.5, MathMin(4.0, pinWickMinRatio));
   }

   bool Analyze(const CMarketData &data, const ENUM_TIMEFRAMES tf, const SIndicatorValues &ind, const SStructureState &structure)
   {
      if(!data.IsDataReady()) return false;
      datetime barT = data.GetBarTime();
      if(barT == m_lastAnalyzedBar)
         return true;

      m_signal.Reset();
      MqlRates r[];
      if(!data.CopyClosedRates(tf, 8, r))
         return false;

      double o0 = r[0].open, h0 = r[0].high, l0 = r[0].low, c0 = r[0].close;
      double o1 = r[1].open, h1 = r[1].high, l1 = r[1].low, c1 = r[1].close;
      double o2 = r[2].open, c2 = r[2].close;

      double range0 = MathMax(1e-9, h0 - l0);
      double body0  = MathAbs(c0 - o0);
      double upper0 = h0 - MathMax(o0, c0);
      double lower0 = MathMin(o0, c0) - l0;
      bool   bull0  = (c0 > o0);
      bool   bear0  = (c0 < o0);

      double body1  = MathAbs(c1 - o1);
      bool   bull1  = (c1 > o1);
      bool   bear1  = (c1 < o1);
      double effAtr = (ind.atr > 0.0) ? ind.atr : range0;

      m_signal.bodyRatio      = body0 / range0;
      m_signal.upperWickRatio = upper0 / range0;
      m_signal.lowerWickRatio = lower0 / range0;
      m_signal.relSizeAtr     = range0 / MathMax(1e-9, effAtr);

      // Consecutive directional candles & inside-bar sequence count
      int dirRun = 0;
      bool targetBull = bull0;
      for(int i = 0; i < 6; i++)
      {
         if((targetBull && r[i].close > r[i].open) || (!targetBull && r[i].close < r[i].open))
            dirRun++;
         else
            break;
      }
      m_signal.consecutiveDirBars = targetBull ? dirRun : -dirRun;

      int ibCount = 0;
      for(int i = 0; i < 4; i++)
      {
         if(r[i].high <= r[i + 1].high && r[i].low >= r[i + 1].low) ibCount++;
         else break;
      }
      m_signal.insideBarCount = ibCount;

      if(range0 < effAtr * 0.30)
      {
         m_signal.pattern = CANDLE_COMPRESSION_BAR;
         m_signal.strength = 0.50;
         m_signal.name = "Compression Candle";
      }
      else if(c2 < o2 && MathAbs(c2 - o2) > effAtr * 0.4 && body1 < MathAbs(c2 - o2) * 0.45 && bull0 && c0 > (o2 + c2) * 0.5)
      {
         m_signal.pattern = CANDLE_MORNING_STAR; m_signal.bias = SIGNAL_BUY; m_signal.strength = 0.90; m_signal.name = "Morning Star";
      }
      else if(c2 > o2 && MathAbs(c2 - o2) > effAtr * 0.4 && body1 < MathAbs(c2 - o2) * 0.45 && bear0 && c0 < (o2 + c2) * 0.5)
      {
         m_signal.pattern = CANDLE_EVENING_STAR; m_signal.bias = SIGNAL_SELL; m_signal.strength = 0.90; m_signal.name = "Evening Star";
      }
      else if(bear1 && bull0 && c0 >= o1 && o0 <= c1 && body0 > body1 * 1.05)
      {
         m_signal.pattern = CANDLE_BULL_ENGULFING; m_signal.bias = SIGNAL_BUY; m_signal.strength = 0.86; m_signal.name = "Bullish Engulfing";
      }
      else if(bull1 && bear0 && c0 <= o1 && o0 >= c1 && body0 > body1 * 1.05)
      {
         m_signal.pattern = CANDLE_BEAR_ENGULFING; m_signal.bias = SIGNAL_SELL; m_signal.strength = 0.86; m_signal.name = "Bearish Engulfing";
      }
      else if(lower0 >= MathMax(body0, effAtr * 0.15) * m_pinWickMinRatio && upper0 <= range0 * 0.22)
      {
         bool atLow = (l0 <= MathMin(l1, r[2].low));
         m_signal.pattern = atLow ? CANDLE_HAMMER : CANDLE_BULL_PINBAR;
         m_signal.bias = SIGNAL_BUY; m_signal.strength = atLow ? 0.84 : 0.72;
         m_signal.name = atLow ? "Hammer Rejection" : "Bullish Pin Bar";
      }
      else if(upper0 >= MathMax(body0, effAtr * 0.15) * m_pinWickMinRatio && lower0 <= range0 * 0.22)
      {
         bool atHigh = (h0 >= MathMax(h1, r[2].high));
         m_signal.pattern = atHigh ? CANDLE_SHOOTING_STAR : CANDLE_BEAR_PINBAR;
         m_signal.bias = SIGNAL_SELL; m_signal.strength = atHigh ? 0.84 : 0.72;
         m_signal.name = atHigh ? "Shooting Star Rejection" : "Bearish Pin Bar";
      }
      else if(h0 > h1 && l0 < l1 && body0 > range0 * 0.50)
      {
         m_signal.pattern = CANDLE_OUTSIDE_BAR;
         m_signal.bias = bull0 ? SIGNAL_BUY : SIGNAL_SELL;
         m_signal.strength = 0.70;
         m_signal.name = bull0 ? "Bullish Outside Bar" : "Bearish Outside Bar";
      }
      else if(ibCount >= 1)
      {
         m_signal.pattern = CANDLE_INSIDE_BAR;
         m_signal.strength = 0.55;
         m_signal.name = (ibCount > 1) ? StringFormat("Inside Bar x%d", ibCount) : "Inside Bar";
      }
      else if(m_signal.relSizeAtr >= 1.45 && m_signal.bodyRatio >= 0.65)
      {
         m_signal.pattern = CANDLE_EXPANSION_BAR;
         m_signal.bias = bull0 ? SIGNAL_BUY : SIGNAL_SELL;
         m_signal.strength = 0.76;
         m_signal.name = bull0 ? "Bullish Expansion Candle" : "Bearish Expansion Candle";
      }
      else if(m_signal.bodyRatio >= 0.68 && m_signal.relSizeAtr >= 0.85)
      {
         m_signal.pattern = CANDLE_MOMENTUM_BAR;
         m_signal.bias = bull0 ? SIGNAL_BUY : SIGNAL_SELL;
         m_signal.strength = 0.68;
         m_signal.name = bull0 ? "Bullish Momentum Candle" : "Bearish Momentum Candle";
      }
      else if(m_signal.bodyRatio <= m_dojiBodyMaxRatio)
      {
         m_signal.pattern = CANDLE_DOJI;
         m_signal.strength = 0.45;
         m_signal.name = "Doji";
      }

      // Context validation against support, resistance, EMA, and market structure
      if(m_signal.pattern != CANDLE_NONE && structure.isReady)
      {
         double tol = effAtr * 0.65;
         if(m_signal.bias == SIGNAL_BUY)
         {
            bool atZone = (MathAbs(l0 - structure.nearestSupport) <= tol) ||
                          (MathAbs(l0 - ind.emaMedium) <= tol) ||
                          (l0 <= ind.bbLower + tol * 0.35);
            m_signal.contextValidated = (atZone && ind.rsi < 70.0 && structure.structureBias >= 0);
            m_signal.contextNote = atZone ? "Anchored at support/EMA21/BB" : "Mid-range candle";
         }
         else if(m_signal.bias == SIGNAL_SELL)
         {
            bool atZone = (MathAbs(h0 - structure.nearestResistance) <= tol) ||
                          (MathAbs(h0 - ind.emaMedium) <= tol) ||
                          (h0 >= ind.bbUpper - tol * 0.35);
            m_signal.contextValidated = (atZone && ind.rsi > 30.0 && structure.structureBias <= 0);
            m_signal.contextNote = atZone ? "Anchored at resistance/EMA21/BB" : "Mid-range candle";
         }
         else
         {
            m_signal.contextValidated = structure.inConsolidation;
            m_signal.contextNote = "Compression / Inside sequence";
         }
      }

      m_lastAnalyzedBar = barT;
      return true;
   }

   SCandleSignal GetSignal() const { return m_signal; }
};

#endif // __ASEA_INDICATORS_CANDLESTICKRECOGNITION_MQH__
