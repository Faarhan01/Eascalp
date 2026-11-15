//+------------------------------------------------------------------+
//|                                       CandlestickRecognition.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        Context-Validated Candlestick Formations  |
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

public:
   CCandlestickRecognition()
   {
      m_dojiBodyMaxRatio = 0.12;
      m_pinWickMinRatio  = 2.0;
      m_signal.Reset();
   }

   void Configure(const double dojiMaxBodyRatio, const double pinWickMinRatio)
   {
      m_dojiBodyMaxRatio = MathMax(0.03, MathMin(0.25, dojiMaxBodyRatio));
      m_pinWickMinRatio  = MathMax(1.5, MathMin(4.0, pinWickMinRatio));
   }

   bool Analyze(const CMarketData &data, const ENUM_TIMEFRAMES tf, const SIndicatorValues &ind, const SStructureState &structure)
   {
      m_signal.Reset();
      MqlRates r[];
      if(!data.CopyClosedRates(tf, 5, r))
         return false;

      // r[0] = most recent closed bar, r[1] = bar before, r[2] = two bars before
      double o0 = r[0].open, h0 = r[0].high, l0 = r[0].low, c0 = r[0].close;
      double o1 = r[1].open, h1 = r[1].high, l1 = r[1].low, c1 = r[1].close;
      double o2 = r[2].open, c2 = r[2].close;

      double range0 = MathMax(1e-9, h0 - l0);
      double body0  = MathAbs(c0 - o0);
      double upper0 = h0 - MathMax(o0, c0);
      double lower0 = MathMin(o0, c0) - l0;
      bool   bull0  = (c0 > o0);
      bool   bear0  = (c0 < o0);

      double range1 = MathMax(1e-9, h1 - l1);
      double body1  = MathAbs(c1 - o1);
      bool   bull1  = (c1 > o1);
      bool   bear1  = (c1 < o1);

      double effAtr = (ind.atr > 0.0) ? ind.atr : range0;
      if(range0 < effAtr * 0.25)
      {
         m_signal.name = "Micro-Bar (Ignored)";
         return true;
      }

      // 1. Morning Star / Evening Star (3-bar reversal)
      if(c2 < o2 && MathAbs(c2 - o2) > effAtr * 0.4 &&
         body1 < MathAbs(c2 - o2) * 0.45 &&
         bull0 && c0 > (o2 + c2) * 0.5)
      {
         m_signal.pattern  = CANDLE_MORNING_STAR;
         m_signal.bias     = SIGNAL_BUY;
         m_signal.strength = 0.90;
         m_signal.name     = "Morning Star";
      }
      else if(c2 > o2 && MathAbs(c2 - o2) > effAtr * 0.4 &&
              body1 < MathAbs(c2 - o2) * 0.45 &&
              bear0 && c0 < (o2 + c2) * 0.5)
      {
         m_signal.pattern  = CANDLE_EVENING_STAR;
         m_signal.bias     = SIGNAL_SELL;
         m_signal.strength = 0.90;
         m_signal.name     = "Evening Star";
      }
      // 2. Bullish / Bearish Engulfing
      else if(bear1 && bull0 && c0 >= o1 && o0 <= c1 && body0 > body1 * 1.05)
      {
         m_signal.pattern  = CANDLE_BULL_ENGULFING;
         m_signal.bias     = SIGNAL_BUY;
         m_signal.strength = 0.85;
         m_signal.name     = "Bullish Engulfing";
      }
      else if(bull1 && bear0 && c0 <= o1 && o0 >= c1 && body0 > body1 * 1.05)
      {
         m_signal.pattern  = CANDLE_BEAR_ENGULFING;
         m_signal.bias     = SIGNAL_SELL;
         m_signal.strength = 0.85;
         m_signal.name     = "Bearish Engulfing";
      }
      // 3. Hammer / Bullish Pin Bar
      else if(lower0 >= MathMax(body0, effAtr * 0.15) * m_pinWickMinRatio && upper0 <= range0 * 0.22)
      {
         bool atLow = (l0 <= MathMin(l1, r[2].low));
         m_signal.pattern  = atLow ? CANDLE_HAMMER : CANDLE_BULL_PINBAR;
         m_signal.bias     = SIGNAL_BUY;
         m_signal.strength = atLow ? 0.82 : 0.72;
         m_signal.name     = atLow ? "Hammer" : "Bullish Pin Bar";
      }
      // 4. Shooting Star / Bearish Pin Bar
      else if(upper0 >= MathMax(body0, effAtr * 0.15) * m_pinWickMinRatio && lower0 <= range0 * 0.22)
      {
         bool atHigh = (h0 >= MathMax(h1, r[2].high));
         m_signal.pattern  = atHigh ? CANDLE_SHOOTING_STAR : CANDLE_BEAR_PINBAR;
         m_signal.bias     = SIGNAL_SELL;
         m_signal.strength = atHigh ? 0.82 : 0.72;
         m_signal.name     = atHigh ? "Shooting Star" : "Bearish Pin Bar";
      }
      // 5. Outside Bar
      else if(h0 > h1 && l0 < l1 && body0 > range0 * 0.50)
      {
         m_signal.pattern  = CANDLE_OUTSIDE_BAR;
         m_signal.bias     = bull0 ? SIGNAL_BUY : SIGNAL_SELL;
         m_signal.strength = 0.68;
         m_signal.name     = bull0 ? "Bullish Outside Bar" : "Bearish Outside Bar";
      }
      // 6. Inside Bar
      else if(h0 <= h1 && l0 >= l1)
      {
         m_signal.pattern  = CANDLE_INSIDE_BAR;
         m_signal.bias     = SIGNAL_NONE;
         m_signal.strength = 0.50;
         m_signal.name     = "Inside Bar (Compression)";
      }
      // 7. Doji
      else if(body0 <= range0 * m_dojiBodyMaxRatio)
      {
         m_signal.pattern  = CANDLE_DOJI;
         m_signal.bias     = SIGNAL_NONE;
         m_signal.strength = 0.45;
         m_signal.name     = "Doji (Indecision)";
      }

      // Context validation against market structure, S/R, and dynamic levels
      if(m_signal.pattern != CANDLE_NONE && structure.isReady)
      {
         double tol = effAtr * 0.60;
         if(m_signal.bias == SIGNAL_BUY)
         {
            bool nearSup = (MathAbs(l0 - structure.nearestSupport) <= tol) ||
                           (MathAbs(l0 - ind.emaMedium) <= tol) ||
                           (l0 <= ind.bbLower + tol * 0.3);
            bool notOverbought = (ind.rsi < 68.0);
            m_signal.contextValidated = (nearSup && notOverbought);
            m_signal.contextNote = nearSup ? "Confirmed at support/EMA/BB zone" : "Mid-range (unconfirmed S/R)";
         }
         else if(m_signal.bias == SIGNAL_SELL)
         {
            bool nearRes = (MathAbs(h0 - structure.nearestResistance) <= tol) ||
                           (MathAbs(h0 - ind.emaMedium) <= tol) ||
                           (h0 >= ind.bbUpper - tol * 0.3);
            bool notOversold = (ind.rsi > 32.0);
            m_signal.contextValidated = (nearRes && notOversold);
            m_signal.contextNote = nearRes ? "Confirmed at resistance/EMA/BB zone" : "Mid-range (unconfirmed S/R)";
         }
         else
         {
            m_signal.contextValidated = structure.inConsolidation;
            m_signal.contextNote = "Neutral compression/indecision candle";
         }
      }

      return true;
   }

   SCandleSignal GetSignal() const { return m_signal; }
};

#endif // __ASEA_INDICATORS_CANDLESTICKRECOGNITION_MQH__
