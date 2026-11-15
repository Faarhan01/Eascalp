//+------------------------------------------------------------------+
//|                                              IndicatorEngine.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        Configurable Multi-Indicator Suite        |
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

   int m_hEmaFast, m_hEmaMed, m_hEmaSlow, m_hSmaTrend;
   int m_hRsi, m_hMacd, m_hAtr, m_hAdx, m_hBands;
   int m_hStoch, m_hCci, m_hWpr, m_hSar, m_hMom;

   bool ReadSingleBuffer(const int handle, const int bufferNum, const int shift, double &outVal) const
   {
      outVal = 0.0;
      if(handle == INVALID_HANDLE) return false;
      if(BarsCalculated(handle) <= shift + 2) return false;
      double buf[1];
      if(CopyBuffer(handle, bufferNum, shift, 1, buf) != 1) return false;
      if(!MathIsValidNumber(buf[0]) || buf[0] == EMPTY_VALUE) return false;
      outVal = buf[0];
      return true;
   }

   bool ComputeSessionVWAP(const CMarketData &data, const bool hasRealVol, double &outVwap) const
   {
      outVwap = 0.0;
      MqlRates rates[];
      if(!data.CopyClosedRates(m_tf, 96, rates))
         return false;

      MqlDateTime curDt;
      TimeToStruct(rates[0].time, curDt);

      double sumPV = 0.0;
      double sumV  = 0.0;
      int total = ArraySize(rates);
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
      m_values.Reset();
      m_hEmaFast = INVALID_HANDLE; m_hEmaMed = INVALID_HANDLE; m_hEmaSlow = INVALID_HANDLE; m_hSmaTrend = INVALID_HANDLE;
      m_hRsi = INVALID_HANDLE; m_hMacd = INVALID_HANDLE; m_hAtr = INVALID_HANDLE; m_hAdx = INVALID_HANDLE; m_hBands = INVALID_HANDLE;
      m_hStoch = INVALID_HANDLE; m_hCci = INVALID_HANDLE; m_hWpr = INVALID_HANDLE; m_hSar = INVALID_HANDLE; m_hMom = INVALID_HANDLE;
   }

   ~CIndicatorEngine()
   {
      Release();
   }

   void Release()
   {
      int handles[14];
      handles[0]  = m_hEmaFast;  handles[1]  = m_hEmaMed;  handles[2]  = m_hEmaSlow; handles[3]  = m_hSmaTrend;
      handles[4]  = m_hRsi;      handles[5]  = m_hMacd;    handles[6]  = m_hAtr;     handles[7]  = m_hAdx;
      handles[8]  = m_hBands;    handles[9]  = m_hStoch;   handles[10] = m_hCci;     handles[11] = m_hWpr;
      handles[12] = m_hSar;      handles[13] = m_hMom;

      for(int i = 0; i < 14; i++)
      {
         if(handles[i] != INVALID_HANDLE)
            IndicatorRelease(handles[i]);
      }
      m_hEmaFast = INVALID_HANDLE; m_hEmaMed = INVALID_HANDLE; m_hEmaSlow = INVALID_HANDLE; m_hSmaTrend = INVALID_HANDLE;
      m_hRsi = INVALID_HANDLE; m_hMacd = INVALID_HANDLE; m_hAtr = INVALID_HANDLE; m_hAdx = INVALID_HANDLE; m_hBands = INVALID_HANDLE;
      m_hStoch = INVALID_HANDLE; m_hCci = INVALID_HANDLE; m_hWpr = INVALID_HANDLE; m_hSar = INVALID_HANDLE; m_hMom = INVALID_HANDLE;
   }

   bool Initialize(const string symbol, const ENUM_TIMEFRAMES tf, const SIndicatorConfig &cfg, CDiagnostics *diag)
   {
      Release();
      m_symbol = symbol;
      m_tf = tf;
      m_cfg = cfg;
      m_diag = diag;
      m_values.Reset();

      m_hEmaFast  = iMA(m_symbol, m_tf, m_cfg.emaFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
      m_hEmaMed   = iMA(m_symbol, m_tf, m_cfg.emaMedPeriod,  0, MODE_EMA, PRICE_CLOSE);
      m_hEmaSlow  = iMA(m_symbol, m_tf, m_cfg.emaSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
      m_hSmaTrend = iMA(m_symbol, m_tf, m_cfg.smaTrendPeriod,0, MODE_SMA, PRICE_CLOSE);
      m_hRsi      = iRSI(m_symbol, m_tf, m_cfg.rsiPeriod, PRICE_CLOSE);
      m_hMacd     = iMACD(m_symbol, m_tf, m_cfg.macdFast, m_cfg.macdSlow, m_cfg.macdSignal, PRICE_CLOSE);
      m_hAtr      = iATR(m_symbol, m_tf, m_cfg.atrPeriod);
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
            m_diag.Log(LOG_ERROR, "IndicatorEngine", StringFormat("Critical indicator handle creation failed on %s %s (err=%d)", m_symbol, EnumToString(m_tf), GetLastError()));
         return false;
      }
      return true;
   }

   bool Update(const CMarketData &data, const bool hasRealVolume)
   {
      m_values.Reset();
      const int shift = 1; // Always read last COMPLETED bar (zero repainting)

      bool ok = true;
      ok &= ReadSingleBuffer(m_hEmaFast,  0, shift, m_values.emaFast);
      ok &= ReadSingleBuffer(m_hEmaMed,   0, shift, m_values.emaMedium);
      ok &= ReadSingleBuffer(m_hEmaSlow,  0, shift, m_values.emaSlow);
      if(!ReadSingleBuffer(m_hSmaTrend, 0, shift, m_values.smaTrend))
         m_values.smaTrend = m_values.emaSlow;

      ok &= ReadSingleBuffer(m_hRsi,      0, shift, m_values.rsi);
      ok &= ReadSingleBuffer(m_hAtr,      0, shift, m_values.atr);
      ok &= ReadSingleBuffer(m_hAdx,      0, shift, m_values.adxMain);
      ok &= ReadSingleBuffer(m_hAdx,      1, shift, m_values.adxPlusDI);
      ok &= ReadSingleBuffer(m_hAdx,      2, shift, m_values.adxMinusDI);
      ok &= ReadSingleBuffer(m_hBands,    0, shift, m_values.bbMiddle);
      ok &= ReadSingleBuffer(m_hBands,    1, shift, m_values.bbUpper);
      ok &= ReadSingleBuffer(m_hBands,    2, shift, m_values.bbLower);

      if(!ok)
      {
         m_values.isReady = false;
         return false;
      }

      ReadSingleBuffer(m_hMacd,  0, shift, m_values.macdMain);
      ReadSingleBuffer(m_hMacd,  1, shift, m_values.macdSignal);
      m_values.macdHist = m_values.macdMain - m_values.macdSignal;

      ReadSingleBuffer(m_hStoch, 0, shift, m_values.stochK);
      ReadSingleBuffer(m_hStoch, 1, shift, m_values.stochD);
      ReadSingleBuffer(m_hCci,   0, shift, m_values.cci);
      ReadSingleBuffer(m_hWpr,   0, shift, m_values.wpr);
      ReadSingleBuffer(m_hSar,   0, shift, m_values.psar);
      ReadSingleBuffer(m_hMom,   0, shift, m_values.momentum);

      // Baseline ATR over N completed bars
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      int bCount = m_cfg.atrBaselineBars;
      if(CopyBuffer(m_hAtr, 0, shift, bCount, atrBuf) == bCount)
      {
         double sum = 0.0;
         for(int i = 0; i < bCount; i++) sum += atrBuf[i];
         m_values.atrBaseline = sum / (double)bCount;
      }
      else
      {
         m_values.atrBaseline = m_values.atr;
      }

      if(m_values.bbMiddle > 0.0)
         m_values.bbWidthPct = ((m_values.bbUpper - m_values.bbLower) / m_values.bbMiddle) * 100.0;

      // Rate of Change over closed bars
      MqlRates rates[];
      if(data.CopyClosedRates(m_tf, m_cfg.rocPeriod + 2, rates))
      {
         double prevClose = rates[m_cfg.rocPeriod].close;
         if(prevClose > 0.0)
            m_values.roc = ((rates[0].close - prevClose) / prevClose) * 100.0;
      }

      if(m_cfg.enableVWAP)
         m_values.vwapAvailable = ComputeSessionVWAP(data, hasRealVolume, m_values.vwap);

      m_values.isReady = true;
      return true;
   }

   SIndicatorValues GetValues() const { return m_values; }
};

#endif // __ASEA_INDICATORS_INDICATORENGINE_MQH__
