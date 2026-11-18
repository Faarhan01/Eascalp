//+------------------------------------------------------------------+
//|                                              IndicatorEngine.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.9.0 Cached Volatility & Momentum Suite |
//+------------------------------------------------------------------+
#ifndef __ASEA_INDICATORS_INDICATORENGINE_MQH__
#define __ASEA_INDICATORS_INDICATORENGINE_MQH__

#include "../Core/Types.mqh"
#include "../Core/Diagnostics.mqh"
#include "../Market/MarketData.mqh"

struct SIndicatorConfig
{
   int    emaFastPeriod;
   int    emaMedPeriod;
   int    emaSlowPeriod;
   int    smaTrendPeriod;
   int    rsiPeriod;
   int    macdFast;
   int    macdSlow;
   int    macdSignal;
   int    atrPeriod;
   int    atrShortPeriod;
   int    atrBaselineBars;
   int    adxPeriod;
   int    bbPeriod;
   double bbDeviation;
   int    stochK;
   int    stochD;
   int    stochSlow;
   int    cciPeriod;
   int    wprPeriod;
   double sarStep;
   double sarMax;
   int    momPeriod;
   int    rocPeriod;
   bool   enableVWAP;

   void ResetDefaults()
   {
      emaFastPeriod   = 9;
      emaMedPeriod    = 21;
      emaSlowPeriod   = 55;
      smaTrendPeriod  = 200;
      rsiPeriod       = 14;
      macdFast        = 12;
      macdSlow        = 26;
      macdSignal      = 9;
      atrPeriod       = 14;
      atrShortPeriod  = 5;
      atrBaselineBars = 40;
      adxPeriod       = 14;
      bbPeriod        = 20;
      bbDeviation     = 2.0;
      stochK          = 14;
      stochD          = 3;
      stochSlow       = 3;
      cciPeriod       = 14;
      wprPeriod       = 14;
      sarStep         = 0.02;
      sarMax          = 0.20;
      momPeriod       = 14;
      rocPeriod       = 10;
      enableVWAP      = true;
   }
};

class CIndicatorEngine
{
private:
   string           m_symbol;
   ENUM_TIMEFRAMES  m_tf;
   SIndicatorConfig m_cfg;
   CDiagnostics    *m_diag;
   SIndicatorValues m_values;
   datetime         m_lastUpdatedBar;

   int m_hEmaFast, m_hEmaMed, m_hEmaSlow, m_hSmaTrend;
   int m_hRsi, m_hMacd, m_hAtr, m_hAtrShort, m_hAdx, m_hBands;
   int m_hStoch, m_hCci, m_hWpr, m_hSar, m_hMom;

   bool ReadBufferShift(const int handle, const int bufferNum, const int shift, double &outVal) const
   {
      outVal = 0.0;
      if(handle == INVALID_HANDLE) return false;
      if(BarsCalculated(handle) <= shift + 2) return false;
      double buf[];
      if(CopyBuffer(handle, bufferNum, shift, 1, buf) != 1) return false;
      if(!MathIsValidNumber(buf[0]) || buf[0] == EMPTY_VALUE) return false;
      outVal = buf[0];
      return true;
   }

   bool ComputeSessionVWAP(const CMarketData &data, const bool hasRealVol, double &outVwap) const
   {
      outVwap = 0.0;
      MqlRates rates[];
      if(!data.CopyAvailableClosedRates(m_tf, 5, 96, rates))
         return false;

      MqlDateTime curDt;
      TimeToStruct(rates[0].time, curDt);

      double sumPV = 0.0, sumV = 0.0;
      int total = ArraySize(rates);
      int sessionBars = 0;
      for(int i = 0; i < total; i++)
      {
         MqlDateTime dt;
         TimeToStruct(rates[i].time, dt);
         if(dt.day_of_year != curDt.day_of_year || dt.year != curDt.year)
            break;
         double vol = hasRealVol && rates[i].real_volume > 0 ? (double)rates[i].real_volume : (double)rates[i].tick_volume;
         if(vol <= 0.0) continue;
         double typical = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
         sumPV += typical * vol;
         sumV  += vol;
         sessionBars++;
      }

      // Rolling 48-bar fallback right after midnight UTC on 24/7 synthetics (e.g. Step Index / Crypto)
      if(sessionBars < 8)
      {
         sumPV = 0.0; sumV = 0.0;
         int rollN = MathMin(48, total);
         for(int i = 0; i < rollN; i++)
         {
            double vol = hasRealVol && rates[i].real_volume > 0 ? (double)rates[i].real_volume : (double)rates[i].tick_volume;
            if(vol <= 0.0) continue;
            double typical = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
            sumPV += typical * vol;
            sumV  += vol;
         }
      }

      if(sumV <= 0.0) return false;
      outVwap = sumPV / sumV;
      return true;
   }

public:
   CIndicatorEngine()
   {
      m_symbol = "";
      m_tf = PERIOD_M5;
      m_cfg.ResetDefaults();
      m_diag = NULL;
      m_lastUpdatedBar = 0;
      m_values.Reset();
      m_hEmaFast = INVALID_HANDLE; m_hEmaMed = INVALID_HANDLE; m_hEmaSlow = INVALID_HANDLE; m_hSmaTrend = INVALID_HANDLE;
      m_hRsi = INVALID_HANDLE; m_hMacd = INVALID_HANDLE; m_hAtr = INVALID_HANDLE; m_hAtrShort = INVALID_HANDLE;
      m_hAdx = INVALID_HANDLE; m_hBands = INVALID_HANDLE;
      m_hStoch = INVALID_HANDLE; m_hCci = INVALID_HANDLE; m_hWpr = INVALID_HANDLE; m_hSar = INVALID_HANDLE; m_hMom = INVALID_HANDLE;
   }

   ~CIndicatorEngine()
   {
      Release();
   }

   void Release()
   {
      int handles[15];
      handles[0]  = m_hEmaFast;  handles[1]  = m_hEmaMed;  handles[2]  = m_hEmaSlow; handles[3]  = m_hSmaTrend;
      handles[4]  = m_hRsi;      handles[5]  = m_hMacd;    handles[6]  = m_hAtr;     handles[7]  = m_hAtrShort;
      handles[8]  = m_hAdx;      handles[9]  = m_hBands;   handles[10] = m_hStoch;   handles[11] = m_hCci;
      handles[12] = m_hWpr;      handles[13] = m_hSar;     handles[14] = m_hMom;

      for(int i = 0; i < 15; i++)
      {
         if(handles[i] != INVALID_HANDLE)
            IndicatorRelease(handles[i]);
      }
      m_hEmaFast = INVALID_HANDLE; m_hEmaMed = INVALID_HANDLE; m_hEmaSlow = INVALID_HANDLE; m_hSmaTrend = INVALID_HANDLE;
      m_hRsi = INVALID_HANDLE; m_hMacd = INVALID_HANDLE; m_hAtr = INVALID_HANDLE; m_hAtrShort = INVALID_HANDLE;
      m_hAdx = INVALID_HANDLE; m_hBands = INVALID_HANDLE;
      m_hStoch = INVALID_HANDLE; m_hCci = INVALID_HANDLE; m_hWpr = INVALID_HANDLE; m_hSar = INVALID_HANDLE; m_hMom = INVALID_HANDLE;
   }

   bool Initialize(const string symbol, const ENUM_TIMEFRAMES tf, const SIndicatorConfig &cfg, CDiagnostics *diag)
   {
      Release();
      m_symbol = symbol;
      m_tf = tf;
      m_cfg = cfg;
      m_diag = diag;
      m_lastUpdatedBar = 0;
      m_values.Reset();

      m_hEmaFast  = iMA(m_symbol, m_tf, m_cfg.emaFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
      m_hEmaMed   = iMA(m_symbol, m_tf, m_cfg.emaMedPeriod,  0, MODE_EMA, PRICE_CLOSE);
      m_hEmaSlow  = iMA(m_symbol, m_tf, m_cfg.emaSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
      m_hSmaTrend = iMA(m_symbol, m_tf, m_cfg.smaTrendPeriod,0, MODE_SMA, PRICE_CLOSE);
      m_hRsi      = iRSI(m_symbol, m_tf, m_cfg.rsiPeriod, PRICE_CLOSE);
      m_hMacd     = iMACD(m_symbol, m_tf, m_cfg.macdFast, m_cfg.macdSlow, m_cfg.macdSignal, PRICE_CLOSE);
      m_hAtr      = iATR(m_symbol, m_tf, m_cfg.atrPeriod);
      m_hAtrShort = iATR(m_symbol, m_tf, m_cfg.atrShortPeriod);
      m_hAdx      = iADX(m_symbol, m_tf, m_cfg.adxPeriod);
      m_hBands    = iBands(m_symbol, m_tf, m_cfg.bbPeriod, 0, m_cfg.bbDeviation, PRICE_CLOSE);
      m_hStoch    = iStochastic(m_symbol, m_tf, m_cfg.stochK, m_cfg.stochD, m_cfg.stochSlow, MODE_SMA, STO_LOWHIGH);
      m_hCci      = iCCI(m_symbol, m_tf, m_cfg.cciPeriod, PRICE_TYPICAL);
      m_hWpr      = iWPR(m_symbol, m_tf, m_cfg.wprPeriod);
      m_hSar      = iSAR(m_symbol, m_tf, m_cfg.sarStep, m_cfg.sarMax);
      m_hMom      = iMomentum(m_symbol, m_tf, m_cfg.momPeriod, PRICE_CLOSE);

      if(m_hEmaFast == INVALID_HANDLE || m_hEmaMed == INVALID_HANDLE || m_hEmaSlow == INVALID_HANDLE ||
         m_hRsi == INVALID_HANDLE || m_hAtr == INVALID_HANDLE || m_hAdx == INVALID_HANDLE || m_hBands == INVALID_HANDLE)
      {
         if(m_diag != NULL)
            m_diag.Log(LOG_ERROR, "IndicatorEngine", StringFormat("Indicator handle creation failed on %s %s", m_symbol, EnumToString(m_tf)));
         return false;
      }
      return true;
   }

   bool Update(const CMarketData &data, const bool hasRealVolume)
   {
      if(!data.IsDataReady()) return false;
      datetime barT = data.GetBarTime();

      // Closed-bar caching: skip expensive CopyBuffer calls if closed bar unchanged
      if(barT == m_lastUpdatedBar && m_values.isReady)
         return true;

      m_values.Reset();
      const int shift = 1; // Completed bar only (zero look-ahead)

      bool ok = true;
      ok &= ReadBufferShift(m_hEmaFast, 0, shift, m_values.emaFast);
      ok &= ReadBufferShift(m_hEmaMed,  0, shift, m_values.emaMedium);
      ok &= ReadBufferShift(m_hEmaSlow, 0, shift, m_values.emaSlow);
      if(!ReadBufferShift(m_hSmaTrend, 0, shift, m_values.smaTrend))
         m_values.smaTrend = m_values.emaSlow;

      ok &= ReadBufferShift(m_hRsi,   0, shift, m_values.rsi);
      ReadBufferShift(m_hRsi, 0, shift + 1, m_values.prevRsi);
      ok &= ReadBufferShift(m_hAtr,   0, shift, m_values.atr);
      if(!ReadBufferShift(m_hAtrShort, 0, shift, m_values.atrShort))
         m_values.atrShort = m_values.atr;

      ok &= ReadBufferShift(m_hAdx,   0, shift, m_values.adxMain);
      ok &= ReadBufferShift(m_hAdx,   1, shift, m_values.adxPlusDI);
      ok &= ReadBufferShift(m_hAdx,   2, shift, m_values.adxMinusDI);
      ok &= ReadBufferShift(m_hBands, 0, shift, m_values.bbMiddle);
      ok &= ReadBufferShift(m_hBands, 1, shift, m_values.bbUpper);
      ok &= ReadBufferShift(m_hBands, 2, shift, m_values.bbLower);

      if(!ok)
      {
         m_values.isReady = false;
         return false;
      }

      ReadBufferShift(m_hMacd, 0, shift, m_values.macdMain);
      ReadBufferShift(m_hMacd, 1, shift, m_values.macdSignal);
      m_values.macdHist = m_values.macdMain - m_values.macdSignal;

      double prevMain = 0.0, prevSig = 0.0;
      if(ReadBufferShift(m_hMacd, 0, shift + 1, prevMain) && ReadBufferShift(m_hMacd, 1, shift + 1, prevSig))
         m_values.prevMacdHist = prevMain - prevSig;

      ReadBufferShift(m_hStoch, 0, shift, m_values.stochK);
      ReadBufferShift(m_hStoch, 1, shift, m_values.stochD);
      ReadBufferShift(m_hCci,   0, shift, m_values.cci);
      ReadBufferShift(m_hWpr,   0, shift, m_values.wpr);
      ReadBufferShift(m_hSar,   0, shift, m_values.psar);
      ReadBufferShift(m_hMom,   0, shift, m_values.momentum);

      // Volatility percentile & baseline ATR over 100 completed bars
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      int atrSamples = 100;
      int copiedAtr = CopyBuffer(m_hAtr, 0, shift, atrSamples, atrBuf);
      if(copiedAtr >= m_cfg.atrBaselineBars)
      {
         double sum = 0.0;
         for(int i = 0; i < m_cfg.atrBaselineBars; i++) sum += atrBuf[i];
         m_values.atrBaseline = sum / (double)m_cfg.atrBaselineBars;

         int belowCount = 0;
         for(int i = 0; i < copiedAtr; i++)
         {
            if(atrBuf[i] <= m_values.atr) belowCount++;
         }
         m_values.volatilityPercentile = ((double)belowCount / (double)copiedAtr) * 100.0;
      }
      else
      {
         m_values.atrBaseline = m_values.atr;
         m_values.volatilityPercentile = 50.0;
      }

      m_values.relativeAtr       = (m_values.atrBaseline > 0.0) ? (m_values.atr / m_values.atrBaseline) : 1.0;
      m_values.shortLongVolRatio = (m_values.atrBaseline > 0.0) ? (m_values.atrShort / m_values.atrBaseline) : 1.0;

      if(m_values.bbMiddle > 0.0)
         m_values.bbWidthPct = ((m_values.bbUpper - m_values.bbLower) / m_values.bbMiddle) * 100.0;

      double prevU = 0.0, prevL = 0.0, prevM = 0.0;
      if(ReadBufferShift(m_hBands, 0, shift + 1, prevM) && ReadBufferShift(m_hBands, 1, shift + 1, prevU) &&
         ReadBufferShift(m_hBands, 2, shift + 1, prevL) && prevM > 0.0)
         m_values.prevBbWidthPct = ((prevU - prevL) / prevM) * 100.0;

      // Closed OHLC analysis: ROC, momentum acceleration, rolling StdDev, directional persistence, displacement, divergence
      int histNeed = MathMax(25, m_cfg.rocPeriod + 6);
      MqlRates rates[];
      if(data.CopyClosedRates(m_tf, histNeed, rates))
      {
         double prevC = rates[m_cfg.rocPeriod].close;
         double prevC2 = rates[m_cfg.rocPeriod + 1].close;
         if(prevC > 0.0)  m_values.roc     = ((rates[0].close - prevC) / prevC) * 100.0;
         if(prevC2 > 0.0) m_values.prevRoc = ((rates[1].close - prevC2) / prevC2) * 100.0;
         m_values.momentumAccel = m_values.roc - m_values.prevRoc;

         // 20-bar rolling close StdDev
         int sdN = MathMin(20, ArraySize(rates));
         double sumC = 0.0;
         for(int i = 0; i < sdN; i++) sumC += rates[i].close;
         double meanC = sumC / (double)sdN;
         double varC = 0.0;
         for(int i = 0; i < sdN; i++)
         {
            double d = rates[i].close - meanC;
            varC += d * d;
         }
         m_values.rollingStdDev = MathSqrt(varC / (double)MathMax(1, sdN - 1));

         // 10-bar directional persistence (-1 to +1)
         int bullBars = 0, bearBars = 0;
         int pN = MathMin(10, ArraySize(rates));
         for(int i = 0; i < pN; i++)
         {
            if(rates[i].close > rates[i].open) bullBars++;
            else if(rates[i].close < rates[i].open) bearBars++;
         }
         m_values.directionalPersist = (double)(bullBars - bearBars) / (double)MathMax(1, pN);

         if(m_values.atr > 0.0)
         {
            m_values.priceDisplacementAtr = (rates[0].close - rates[MathMin(10, ArraySize(rates) - 1)].close) / m_values.atr;
            m_values.emaDistanceAtr       = (rates[0].close - m_values.emaMedium) / m_values.atr;
         }

         // Relative Volume (RVOL): closed bar [0] vs 20-bar closed baseline average
         int volBars = MathMin(21, ArraySize(rates));
         if(volBars >= 6)
         {
            double curVol = (hasRealVolume && rates[0].real_volume > 0) ? (double)rates[0].real_volume : (double)rates[0].tick_volume;
            double sumVol = 0.0;
            int cntVol = 0;
            for(int v = 1; v < volBars; v++)
            {
               double bv = (hasRealVolume && rates[v].real_volume > 0) ? (double)rates[v].real_volume : (double)rates[v].tick_volume;
               if(bv > 0.0) { sumVol += bv; cntVol++; }
            }
            if(cntVol >= 5 && sumVol > 0.0 && curVol > 0.0)
               m_values.relativeVolume = MathMax(0.10, MathMin(6.0, curVol / (sumVol / (double)cntVol)));
         }

         // Objective 12-bar RSI divergence check requiring genuine wave separation in bars [2..5]
         double rsiBuf[];
         ArraySetAsSeries(rsiBuf, true);
         if(CopyBuffer(m_hRsi, 0, shift, 16, rsiBuf) == 16)
         {
            double minLowNow = MathMin(rates[0].low, rates[1].low);
            double minLowOld = rates[6].low;
            double minRsiNow = MathMin(rsiBuf[0], rsiBuf[1]);
            double minRsiOld = rsiBuf[6];
            for(int k = 7; k < 14; k++)
            {
               if(rates[k].low < minLowOld) { minLowOld = rates[k].low; minRsiOld = rsiBuf[k]; }
            }
            double midMaxRsi = rsiBuf[2];
            for(int k = 3; k <= 5; k++)
               if(rsiBuf[k] > midMaxRsi) midMaxRsi = rsiBuf[k];
            bool bullWaveSep = (midMaxRsi >= minRsiOld + 3.5 && midMaxRsi >= minRsiNow + 2.0);
            m_values.bullDivergence = (minLowNow < minLowOld && minRsiNow > minRsiOld + 2.5 && bullWaveSep && m_values.rsi < 45.0);

            double maxHighNow = MathMax(rates[0].high, rates[1].high);
            double maxHighOld = rates[6].high;
            double maxRsiNow = MathMax(rsiBuf[0], rsiBuf[1]);
            double maxRsiOld = rsiBuf[6];
            for(int k = 7; k < 14; k++)
            {
               if(rates[k].high > maxHighOld) { maxHighOld = rates[k].high; maxRsiOld = rsiBuf[k]; }
            }
            double midMinRsi = rsiBuf[2];
            for(int k = 3; k <= 5; k++)
               if(rsiBuf[k] < midMinRsi) midMinRsi = rsiBuf[k];
            bool bearWaveSep = (midMinRsi <= maxRsiOld - 3.5 && midMinRsi <= maxRsiNow - 2.0);
            m_values.bearDivergence = (maxHighNow > maxHighOld && maxRsiNow < maxRsiOld - 2.5 && bearWaveSep && m_values.rsi > 55.0);
         }

         // 20-bar prior Donchian channel on completed bars [1..20] (zero look-ahead against bar [0])
         int dcStart = 1;
         int dcEnd   = MathMin(20, ArraySize(rates) - 1);
         if(dcEnd >= dcStart)
         {
            double dcH = rates[dcStart].high;
            double dcL = rates[dcStart].low;
            for(int k = dcStart + 1; k <= dcEnd; k++)
            {
               if(rates[k].high > dcH) dcH = rates[k].high;
               if(rates[k].low  < dcL) dcL = rates[k].low;
            }
            m_values.donchianHigh = dcH;
            m_values.donchianLow  = dcL;
            m_values.donchianMid  = (dcH + dcL) * 0.5;
         }

         // Momentum exhaustion: true overextension (>2.15 ATR + fading MACD + extreme RSI) or active divergence
         bool histFading = (MathAbs(m_values.macdHist) < MathAbs(m_values.prevMacdHist));
         m_values.momentumExhaustion = ((MathAbs(m_values.emaDistanceAtr) > 2.15 && histFading &&
                                         (m_values.rsi >= 72.0 || m_values.rsi <= 28.0)) ||
                                        (m_values.bearDivergence && m_values.emaDistanceAtr > 0.85) ||
                                        (m_values.bullDivergence && m_values.emaDistanceAtr < -0.85));
      }

      if(m_cfg.enableVWAP)
         m_values.vwapAvailable = ComputeSessionVWAP(data, hasRealVolume, m_values.vwap);

      m_values.isReady = true;
      m_lastUpdatedBar = barT;
      return true;
   }

   SIndicatorValues GetValues() const { return m_values; }
};

#endif // __ASEA_INDICATORS_INDICATORENGINE_MQH__
