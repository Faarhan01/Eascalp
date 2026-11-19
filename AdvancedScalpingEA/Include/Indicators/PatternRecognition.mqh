//+------------------------------------------------------------------+
//|                                           PatternRecognition.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v3.1.0 Cached Swing-Based Pattern Engine  |
//+------------------------------------------------------------------+
#ifndef __ASEA_INDICATORS_PATTERNRECOGNITION_MQH__
#define __ASEA_INDICATORS_PATTERNRECOGNITION_MQH__

#include "../Core/Types.mqh"
#include "../Market/MarketData.mqh"

struct SSwingPivot
{
   int      barIndex;
   datetime time;
   double   price;
   bool     isHigh;
};

class CPatternRecognition
{
private:
   int                 m_lookbackBars;
   int                 m_pivotStrength;
   double              m_toleranceAtrMult;
   SChartPatternSignal m_signal;
   datetime            m_lastAnalyzedBar;

   void ExtractSwings(const MqlRates &rates[], const int total, SSwingPivot &highs[], int &hCount,
                      SSwingPivot &lows[], int &lCount) const
   {
      hCount = 0;
      lCount = 0;
      ArrayResize(highs, 12);
      ArrayResize(lows, 12);

      for(int i = m_pivotStrength; i < total - m_pivotStrength; i++)
      {
         bool isH = true, isL = true;
         for(int k = 1; k <= m_pivotStrength; k++)
         {
            if(rates[i - k].high >= rates[i].high || rates[i + k].high > rates[i].high) isH = false;
            if(rates[i - k].low  <= rates[i].low  || rates[i + k].low  < rates[i].low)  isL = false;
         }
         if(isH && hCount < 12)
         {
            highs[hCount].barIndex = i;
            highs[hCount].time     = rates[i].time;
            highs[hCount].price    = rates[i].high;
            highs[hCount].isHigh   = true;
            hCount++;
         }
         if(isL && lCount < 12)
         {
            lows[lCount].barIndex = i;
            lows[lCount].time     = rates[i].time;
            lows[lCount].price    = rates[i].low;
            lows[lCount].isHigh   = false;
            lCount++;
         }
         if(hCount >= 12 && lCount >= 12) break;
      }
   }

public:
   CPatternRecognition()
   {
      m_lookbackBars     = 100;
      m_pivotStrength    = 3;
      m_toleranceAtrMult = 0.45;
      m_lastAnalyzedBar  = 0;
      m_signal.Reset();
   }

   void Configure(const int lookbackBars, const int pivotStrength, const double toleranceAtrMult)
   {
      m_lookbackBars     = MathMax(50, MathMin(240, lookbackBars));
      m_pivotStrength    = MathMax(2, MathMin(6, pivotStrength));
      m_toleranceAtrMult = MathMax(0.15, MathMin(1.2, toleranceAtrMult));
   }

   bool Analyze(const CMarketData &data, const ENUM_TIMEFRAMES tf, const double atr)
   {
      if(!data.IsDataReady()) return false;
      datetime barT = data.GetBarTime();
      if(barT == m_lastAnalyzedBar)
         return true;

      m_signal.Reset();
      MqlRates rates[];
      if(!data.CopyAvailableClosedRates(tf, 35, m_lookbackBars, rates))
         return false;

      int total = ArraySize(rates);
      if(total < 35) return false;

      SSwingPivot highs[], lows[];
      int hCount = 0, lCount = 0;
      ExtractSwings(rates, total, highs, hCount, lows, lCount);
      if(hCount < 2 || lCount < 2)
      {
         m_lastAnalyzedBar = barT;
         return true;
      }

      double effAtr = (atr > 0.0) ? atr : MathAbs(highs[0].price - lows[0].price) * 0.25;
      double tol = effAtr * m_toleranceAtrMult;
      double lastClose = rates[0].close;

      double h1 = highs[0].price, h2 = highs[1].price;
      double l1 = lows[0].price,  l2 = lows[1].price;

      if(hCount >= 3 && lCount >= 2 && highs[0].barIndex <= 20)
      {
         double rightS = highs[0].price, head = highs[1].price, leftS = highs[2].price;
         if(head > leftS + tol * 0.5 && head > rightS + tol * 0.5 &&
            MathAbs(leftS - rightS) <= tol * 1.2 &&
            (highs[2].barIndex - highs[0].barIndex) >= 12 && lastClose <= rightS)
         {
            // Measure true neckline trough between right shoulder and left shoulder from bar history
            double leftValley = rates[highs[1].barIndex].low;
            for(int b = highs[1].barIndex; b <= highs[2].barIndex && b < total; b++)
               if(rates[b].low < leftValley) leftValley = rates[b].low;
            double rightValley = rates[highs[0].barIndex].low;
            for(int b = highs[0].barIndex; b <= highs[1].barIndex && b < total; b++)
               if(rates[b].low < rightValley) rightValley = rates[b].low;
            double neckline = MathMin(leftValley, rightValley);
            if((head - neckline) >= effAtr * 1.60)
            {
               m_signal.pattern = PATTERN_HEAD_SHOULDERS; m_signal.bias = SIGNAL_SELL;
               m_signal.breakoutLevel = neckline; m_signal.invalidationLevel = rightS;
               m_signal.confidence = (lastClose <= neckline) ? 0.88 : 0.68;
               m_signal.name = "Head & Shoulders";
               m_signal.note = StringFormat("Neckline %.5f | Right Shoulder %.5f", neckline, rightS);
               m_lastAnalyzedBar = barT;
               return true;
            }
         }
      }
      if(lCount >= 3 && hCount >= 2 && lows[0].barIndex <= 20)
      {
         double rightS = lows[0].price, head = lows[1].price, leftS = lows[2].price;
         if(head < leftS - tol * 0.5 && head < rightS - tol * 0.5 &&
            MathAbs(leftS - rightS) <= tol * 1.2 &&
            (lows[2].barIndex - lows[0].barIndex) >= 12 && lastClose >= rightS)
         {
            // Measure true neckline peak between right shoulder and left shoulder from bar history
            double leftPeak = rates[lows[1].barIndex].high;
            for(int b = lows[1].barIndex; b <= lows[2].barIndex && b < total; b++)
               if(rates[b].high > leftPeak) leftPeak = rates[b].high;
            double rightPeak = rates[lows[0].barIndex].high;
            for(int b = lows[0].barIndex; b <= lows[1].barIndex && b < total; b++)
               if(rates[b].high > rightPeak) rightPeak = rates[b].high;
            double neckline = MathMax(leftPeak, rightPeak);
            if((neckline - head) >= effAtr * 1.60)
            {
               m_signal.pattern = PATTERN_INV_HEAD_SHOULDERS; m_signal.bias = SIGNAL_BUY;
               m_signal.breakoutLevel = neckline; m_signal.invalidationLevel = rightS;
               m_signal.confidence = (lastClose >= neckline) ? 0.88 : 0.68;
               m_signal.name = "Inverse Head & Shoulders";
               m_signal.note = StringFormat("Neckline %.5f | Right Shoulder %.5f", neckline, rightS);
               m_lastAnalyzedBar = barT;
               return true;
            }
         }
      }

      if(highs[0].barIndex <= 20 && MathAbs(h1 - h2) <= tol && (highs[1].barIndex - highs[0].barIndex) >= 6)
      {
         // Scan bars strictly between the two swing highs for genuine intervening valley
         double invLevel = MathMax(h1, h2) + tol * 0.5;
         double valley = rates[highs[0].barIndex].low;
         for(int b = highs[0].barIndex; b <= highs[1].barIndex && b < total; b++)
            if(rates[b].low < valley) valley = rates[b].low;
         if(lastClose <= invLevel && (MathMax(h1, h2) - valley) >= effAtr * 1.5)
         {
            m_signal.pattern = PATTERN_DOUBLE_TOP; m_signal.bias = SIGNAL_SELL;
            m_signal.breakoutLevel = valley; m_signal.invalidationLevel = invLevel;
            m_signal.confidence = (lastClose < valley) ? 0.85 : 0.65;
            m_signal.name = "Double Top";
            m_signal.note = StringFormat("Peaks ~%.5f | Neck %.5f", (h1 + h2) * 0.5, valley);
            m_lastAnalyzedBar = barT;
            return true;
         }
      }
      if(lows[0].barIndex <= 20 && MathAbs(l1 - l2) <= tol && (lows[1].barIndex - lows[0].barIndex) >= 6)
      {
         // Scan bars strictly between the two swing lows for genuine intervening peak
         double invLevel = MathMin(l1, l2) - tol * 0.5;
         double peak = rates[lows[0].barIndex].high;
         for(int b = lows[0].barIndex; b <= lows[1].barIndex && b < total; b++)
            if(rates[b].high > peak) peak = rates[b].high;
         if(lastClose >= invLevel && (peak - MathMin(l1, l2)) >= effAtr * 1.5)
         {
            m_signal.pattern = PATTERN_DOUBLE_BOTTOM; m_signal.bias = SIGNAL_BUY;
            m_signal.breakoutLevel = peak; m_signal.invalidationLevel = invLevel;
            m_signal.confidence = (lastClose > peak) ? 0.85 : 0.65;
            m_signal.name = "Double Bottom";
            m_signal.note = StringFormat("Troughs ~%.5f | Neck %.5f", (l1 + l2) * 0.5, peak);
            m_lastAnalyzedBar = barT;
            return true;
         }
      }

      bool flatTop = (MathAbs(h1 - h2) <= tol * 0.8);
      bool flatBot = (MathAbs(l1 - l2) <= tol * 0.8);
      bool risingTop  = (h1 > h2 + tol * 0.4);
      bool fallingTop = (h1 < h2 - tol * 0.4);
      bool risingBot  = (l1 > l2 + tol * 0.4);
      bool fallingBot = (l1 < l2 - tol * 0.4);

      if(flatTop && risingBot)
      {
         m_signal.pattern = PATTERN_ASC_TRIANGLE; m_signal.bias = SIGNAL_BUY;
         m_signal.breakoutLevel = MathMax(h1, h2); m_signal.invalidationLevel = l1;
         m_signal.confidence = 0.76; m_signal.name = "Ascending Triangle"; m_signal.note = "Flat resistance + higher lows";
      }
      else if(flatBot && fallingTop)
      {
         m_signal.pattern = PATTERN_DESC_TRIANGLE; m_signal.bias = SIGNAL_SELL;
         m_signal.breakoutLevel = MathMin(l1, l2); m_signal.invalidationLevel = h1;
         m_signal.confidence = 0.76; m_signal.name = "Descending Triangle"; m_signal.note = "Flat support + lower highs";
      }
      else if(fallingTop && risingBot)
      {
         bool isPennant = ((h1 - l1) < (h2 - l2) * 0.55 && (highs[1].barIndex - highs[0].barIndex) <= 14);
         m_signal.pattern = isPennant ? PATTERN_PENNANT : PATTERN_SYM_TRIANGLE;
         m_signal.bias = (lastClose >= (h1 + l1) * 0.5) ? SIGNAL_BUY : SIGNAL_SELL;
         m_signal.breakoutLevel = (m_signal.bias == SIGNAL_BUY) ? h1 : l1;
         m_signal.invalidationLevel = (m_signal.bias == SIGNAL_BUY) ? l1 : h1;
         m_signal.confidence = 0.70; m_signal.name = isPennant ? "Pennant" : "Symmetrical Triangle";
         m_signal.note = "Converging volatility boundary";
      }
      else if(risingTop && risingBot)
      {
         bool converging = ((h1 - l1) < (h2 - l2) * 0.80);
         if(converging)
         {
            m_signal.pattern = PATTERN_RISING_WEDGE; m_signal.bias = SIGNAL_SELL;
            m_signal.breakoutLevel = l1; m_signal.invalidationLevel = h1;
            m_signal.confidence = 0.74; m_signal.name = "Rising Wedge"; m_signal.note = "Converging upward channel";
         }
         else
         {
            double priorMove = (total > highs[1].barIndex + 10) ? (rates[highs[1].barIndex + 8].close - l2) : 0.0;
            if(priorMove > effAtr * 2.5)
            {
               m_signal.pattern = PATTERN_BEAR_FLAG; m_signal.bias = SIGNAL_SELL;
               m_signal.breakoutLevel = l1; m_signal.invalidationLevel = h1;
               m_signal.confidence = 0.75; m_signal.name = "Bear Flag"; m_signal.note = "Counter-trend pullback after drop";
            }
            else
            {
               m_signal.pattern = PATTERN_UP_CHANNEL; m_signal.bias = SIGNAL_BUY;
               m_signal.breakoutLevel = h1; m_signal.invalidationLevel = l1;
               m_signal.confidence = 0.66; m_signal.name = "Ascending Channel"; m_signal.note = "Parallel HH/HL";
            }
         }
      }
      else if(fallingTop && fallingBot)
      {
         bool converging = ((h1 - l1) < (h2 - l2) * 0.80);
         if(converging)
         {
            m_signal.pattern = PATTERN_FALLING_WEDGE; m_signal.bias = SIGNAL_BUY;
            m_signal.breakoutLevel = h1; m_signal.invalidationLevel = l1;
            m_signal.confidence = 0.74; m_signal.name = "Falling Wedge"; m_signal.note = "Converging downward channel";
         }
         else
         {
            double priorMove = (total > lows[1].barIndex + 10) ? (h2 - rates[lows[1].barIndex + 8].close) : 0.0;
            if(priorMove > effAtr * 2.5)
            {
               m_signal.pattern = PATTERN_BULL_FLAG; m_signal.bias = SIGNAL_BUY;
               m_signal.breakoutLevel = h1; m_signal.invalidationLevel = l1;
               m_signal.confidence = 0.75; m_signal.name = "Bull Flag"; m_signal.note = "Counter-trend pullback after rally";
            }
            else
            {
               m_signal.pattern = PATTERN_DOWN_CHANNEL; m_signal.bias = SIGNAL_SELL;
               m_signal.breakoutLevel = l1; m_signal.invalidationLevel = h1;
               m_signal.confidence = 0.66; m_signal.name = "Descending Channel"; m_signal.note = "Parallel LH/LL";
            }
         }
      }
      else if(flatTop && flatBot)
      {
         m_signal.pattern = PATTERN_RECTANGLE; m_signal.bias = SIGNAL_NONE;
         m_signal.breakoutLevel = h1; m_signal.invalidationLevel = l1;
         m_signal.confidence = 0.72; m_signal.name = "Rectangle Range"; m_signal.note = "Horizontal range";
      }

      m_lastAnalyzedBar = barT;
      return true;
   }

   SChartPatternSignal GetSignal() const { return m_signal; }
};

#endif // __ASEA_INDICATORS_PATTERNRECOGNITION_MQH__
