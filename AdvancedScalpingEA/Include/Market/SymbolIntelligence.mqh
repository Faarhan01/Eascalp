//+------------------------------------------------------------------+
//|                                           SymbolIntelligence.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        Dynamic Broker & Instrument Inspection    |
//+------------------------------------------------------------------+
#ifndef __ASEA_MARKET_SYMBOLINTELLIGENCE_MQH__
#define __ASEA_MARKET_SYMBOLINTELLIGENCE_MQH__

#include "../Core/Types.mqh"
#include "../Core/Diagnostics.mqh"

class CSymbolIntelligence
{
private:
   SSymbolProfile m_profile;
   CDiagnostics  *m_diag;

   string ExtractCoreName(const string sym, string &outPrefix, string &outSuffix) const
   {
      outPrefix = "";
      outSuffix = "";
      string upper = sym;
      StringToUpper(upper);

      // Common broker suffixes (.m, .raw, .pro, _i, +, #, .ecn, etc.)
      int dotPos = StringFind(sym, ".");
      int usPos  = StringFind(sym, "_");
      int hashPos = StringFind(sym, "#");
      int plusPos = StringFind(sym, "+");

      int cutPos = -1;
      if(dotPos > 2) cutPos = dotPos;
      else if(usPos > 2 && StringFind(upper, "INDEX") < 0 && StringFind(upper, "VOLATILITY") < 0) cutPos = usPos;
      else if(hashPos > 2) cutPos = hashPos;
      else if(plusPos > 2) cutPos = plusPos;

      string clean = sym;
      if(cutPos > 0)
      {
         outSuffix = StringSubstr(sym, cutPos);
         clean = StringSubstr(sym, 0, cutPos);
      }

      // Check single-char lowercase prefix like "mEURUSD" or "iUS500"
      if(StringLen(clean) >= 7)
      {
         ushort c0 = StringGetCharacter(clean, 0);
         ushort c1 = StringGetCharacter(clean, 1);
         if(c0 >= 'a' && c0 <= 'z' && c1 >= 'A' && c1 <= 'Z')
         {
            outPrefix = StringSubstr(clean, 0, 1);
            clean = StringSubstr(clean, 1);
         }
      }
      return clean;
   }

   ENUM_ASSET_CLASS ClassifySymbol(const string sym, const string core, const string baseCcy, const string profitCcy) const
   {
      string u = core;
      StringToUpper(u);
      string fullU = sym;
      StringToUpper(fullU);

      // Synthetic / Volatility / Step indices
      if(StringFind(fullU, "VOLATILITY") >= 0 || StringFind(fullU, "STEP") >= 0 ||
         StringFind(fullU, "CRASH") >= 0 || StringFind(fullU, "BOOM") >= 0 ||
         StringFind(fullU, "JUMP") >= 0 || StringFind(fullU, "RANGE BREAK") >= 0 ||
         StringFind(fullU, "R_10") >= 0 || StringFind(fullU, "R_25") >= 0 ||
         StringFind(fullU, "R_50") >= 0 || StringFind(fullU, "R_75") >= 0 ||
         StringFind(fullU, "R_100") >= 0 || StringFind(fullU, "V75") >= 0 ||
         StringFind(fullU, "V100") >= 0 || StringFind(fullU, "DEX") >= 0)
         return ASSET_SYNTHETIC;

      // Metals
      if(StringFind(u, "XAU") >= 0 || StringFind(u, "GOLD") >= 0 ||
         StringFind(u, "XAG") >= 0 || StringFind(u, "SILVER") >= 0 ||
         StringFind(u, "XPT") >= 0 || StringFind(u, "XPD") >= 0 ||
         StringFind(u, "COPPER") >= 0)
         return ASSET_METAL;

      // Energy
      if(StringFind(u, "WTI") >= 0 || StringFind(u, "BRENT") >= 0 ||
         StringFind(u, "USOIL") >= 0 || StringFind(u, "UKOIL") >= 0 ||
         StringFind(u, "XTI") >= 0 || StringFind(u, "XBR") >= 0 ||
         StringFind(u, "NGAS") >= 0 || StringFind(u, "NATGAS") >= 0)
         return ASSET_ENERGY;

      // Crypto
      if(StringFind(u, "BTC") >= 0 || StringFind(u, "ETH") >= 0 ||
         StringFind(u, "SOL") >= 0 || StringFind(u, "XRP") >= 0 ||
         StringFind(u, "LTC") >= 0)
         return ASSET_CRYPTO;

      // Stock Indices
      if(StringFind(u, "US30") >= 0 || StringFind(u, "US500") >= 0 || StringFind(u, "SPX") >= 0 ||
         StringFind(u, "NAS100") >= 0 || StringFind(u, "USTEC") >= 0 || StringFind(u, "NDX") >= 0 ||
         StringFind(u, "DAX") >= 0 || StringFind(u, "DE40") >= 0 || StringFind(u, "GER40") >= 0 ||
         StringFind(u, "UK100") >= 0 || StringFind(u, "FTSE") >= 0 || StringFind(u, "JP225") >= 0 ||
         StringFind(u, "AUS200") >= 0 || StringFind(u, "FR40") >= 0 || StringFind(u, "US2000") >= 0)
         return ASSET_INDEX;

      // Forex classification
      string majors[8] = {"USD", "EUR", "GBP", "JPY", "CHF", "CAD", "AUD", "NZD"};
      bool baseMajor = false;
      bool quoteMajor = false;

      if(StringLen(u) == 6)
      {
         string b = StringSubstr(u, 0, 3);
         string q = StringSubstr(u, 3, 3);
         for(int i = 0; i < 8; i++)
         {
            if(b == majors[i]) baseMajor = true;
            if(q == majors[i]) quoteMajor = true;
         }
         if(baseMajor && quoteMajor)
         {
            if(b == "USD" || q == "USD")
            {
               if((b == "EUR" && q == "USD") || (b == "GBP" && q == "USD") ||
                  (b == "USD" && q == "JPY") || (b == "USD" && q == "CHF") ||
                  (b == "USD" && q == "CAD") || (b == "AUD" && q == "USD") ||
                  (b == "NZD" && q == "USD"))
                  return ASSET_FOREX_MAJOR;
            }
            return ASSET_FOREX_MINOR;
         }
         if(baseMajor || quoteMajor)
            return ASSET_FOREX_EXOTIC;
      }

      long calcMode = SymbolInfoInteger(sym, SYMBOL_TRADE_CALC_MODE);
      if(calcMode == SYMBOL_CALC_MODE_FOREX || calcMode == SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE)
         return (baseCcy == "USD" || profitCcy == "USD") ? ASSET_FOREX_MINOR : ASSET_FOREX_EXOTIC;
      if(calcMode == SYMBOL_CALC_MODE_CFD || calcMode == SYMBOL_CALC_MODE_CFDINDEX || calcMode == SYMBOL_CALC_MODE_CFDLEVERAGE)
         return ASSET_CFD;

      return ASSET_CFD;
   }

   int CalculateStepDigits(const double step) const
   {
      if(step <= 0.0) return 2;
      double v = step;
      int digits = 0;
      while(digits < 8 && MathAbs(v - MathRound(v)) > 1e-8)
      {
         v *= 10.0;
         digits++;
      }
      return digits;
   }

   bool CheckSessionOpenNow(const string sym, bool &out24x7) const
   {
      datetime now = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(now, dt);
      ENUM_DAY_OF_WEEK dow = (ENUM_DAY_OF_WEEK)dt.day_of_week;

      datetime fromTime = 0, toTime = 0;
      int secondsToday = dt.hour * 3600 + dt.min * 60 + dt.sec;
      bool foundOpen = false;
      bool sundayOpen = SymbolInfoSessionTrade(sym, SUNDAY, 0, fromTime, toTime);
      bool satOpen    = SymbolInfoSessionTrade(sym, SATURDAY, 0, fromTime, toTime);
      out24x7 = (sundayOpen && satOpen);

      for(uint idx = 0; idx < 8; idx++)
      {
         if(!SymbolInfoSessionTrade(sym, dow, idx, fromTime, toTime))
            break;
         long fromSec = (long)(fromTime % 86400);
         long toSec   = (long)(toTime % 86400);
         if(toSec == 0 && toTime > fromTime)
            toSec = 86400;
         if(secondsToday >= fromSec && secondsToday <= toSec)
         {
            foundOpen = true;
            break;
         }
      }
      return foundOpen;
   }

public:
   CSymbolIntelligence()
   {
      m_profile.Reset();
      m_diag = NULL;
   }

   bool Initialize(const string symbol, const ENUM_TIMEFRAMES primaryTF, CDiagnostics *diag)
   {
      m_diag = diag;
      m_profile.Reset();
      m_profile.symbol = symbol;

      if(!SymbolSelect(symbol, true))
      {
         if(m_diag != NULL)
            m_diag.Log(LOG_ERROR, "SymbolIntelligence", StringFormat("SymbolSelect failed for %s", symbol));
         return false;
      }

      return Refresh(primaryTF);
   }

   bool Refresh(const ENUM_TIMEFRAMES primaryTF)
   {
      string sym = m_profile.symbol;
      if(sym == "") return false;

      string pfx = "", sfx = "";
      m_profile.baseSymbol = ExtractCoreName(sym, pfx, sfx);
      m_profile.prefix = pfx;
      m_profile.suffix = sfx;

      m_profile.currencyBase   = SymbolInfoString(sym, SYMBOL_CURRENCY_BASE);
      m_profile.currencyProfit = SymbolInfoString(sym, SYMBOL_CURRENCY_PROFIT);
      m_profile.currencyMargin = SymbolInfoString(sym, SYMBOL_CURRENCY_MARGIN);
      m_profile.assetClass     = ClassifySymbol(sym, m_profile.baseSymbol, m_profile.currencyBase, m_profile.currencyProfit);

      m_profile.digits          = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      m_profile.point           = SymbolInfoDouble(sym, SYMBOL_POINT);
      m_profile.tickSize        = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
      m_profile.tickValue       = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE);
      m_profile.tickValueProfit = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE_PROFIT);
      m_profile.tickValueLoss   = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_VALUE_LOSS);
      m_profile.contractSize    = SymbolInfoDouble(sym, SYMBOL_TRADE_CONTRACT_SIZE);

      m_profile.volumeMin    = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
      m_profile.volumeMax    = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
      m_profile.volumeStep   = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
      m_profile.volumeDigits = CalculateStepDigits(m_profile.volumeStep);

      m_profile.stopsLevelPoints  = (int)SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
      m_profile.freezeLevelPoints = (int)SymbolInfoInteger(sym, SYMBOL_TRADE_FREEZE_LEVEL);
      m_profile.spreadPoints      = (int)SymbolInfoInteger(sym, SYMBOL_SPREAD);

      m_profile.tradeMode    = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(sym, SYMBOL_TRADE_MODE);
      m_profile.execMode     = (ENUM_SYMBOL_TRADE_EXECUTION)SymbolInfoInteger(sym, SYMBOL_TRADE_EXEMODE);
      m_profile.fillingFlags = (int)SymbolInfoInteger(sym, SYMBOL_FILLING_MODE);

      if((m_profile.fillingFlags & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
         m_profile.preferredFilling = ORDER_FILLING_IOC;
      else if((m_profile.fillingFlags & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
         m_profile.preferredFilling = ORDER_FILLING_FOK;
      else
         m_profile.preferredFilling = ORDER_FILLING_RETURN;

      m_profile.swapLong          = SymbolInfoDouble(sym, SYMBOL_SWAP_LONG);
      m_profile.swapShort         = SymbolInfoDouble(sym, SYMBOL_SWAP_SHORT);
      m_profile.swapMode          = (int)SymbolInfoInteger(sym, SYMBOL_SWAP_MODE);
      m_profile.marginInitial     = SymbolInfoDouble(sym, SYMBOL_MARGIN_INITIAL);
      m_profile.marginMaintenance = SymbolInfoDouble(sym, SYMBOL_MARGIN_MAINTENANCE);

      bool is24x7 = false;
      m_profile.sessionOpenNow  = CheckSessionOpenNow(sym, is24x7);
      m_profile.isSynthetic24x7 = is24x7 || (m_profile.assetClass == ASSET_SYNTHETIC) || (m_profile.assetClass == ASSET_CRYPTO);

      long realVol = iVolume(sym, primaryTF, 1);
      m_profile.hasRealVolume = (realVol > 0);
      m_profile.availableBarsPrimary = Bars(sym, primaryTF);
      m_profile.lastInspected = TimeCurrent();

      m_profile.isValid = (m_profile.point > 0.0 && m_profile.tickSize > 0.0 && m_profile.volumeStep > 0.0 && m_profile.volumeMin > 0.0);

      if(!m_profile.isValid && m_diag != NULL)
         m_diag.Log(LOG_WARN, "SymbolIntelligence", StringFormat("Incomplete symbol spec for %s (point=%.8f, tickSize=%.8f)", sym, m_profile.point, m_profile.tickSize), "sym_spec_warn", 60);

      return m_profile.isValid;
   }

   SSymbolProfile GetProfile() const { return m_profile; }

   double NormalizePrice(const double price) const
   {
      if(m_profile.tickSize > 0.0)
         return NormalizeDouble(MathRound(price / m_profile.tickSize) * m_profile.tickSize, m_profile.digits);
      return NormalizeDouble(price, m_profile.digits);
   }

   double NormalizeVolume(const double lots) const
   {
      if(m_profile.volumeStep <= 0.0)
         return 0.0;
      double clamped = MathMax(m_profile.volumeMin, MathMin(m_profile.volumeMax, lots));
      double steps = MathFloor((clamped + 1e-12) / m_profile.volumeStep);
      double res = NormalizeDouble(steps * m_profile.volumeStep, m_profile.volumeDigits);
      if(res < m_profile.volumeMin) res = 0.0;
      if(res > m_profile.volumeMax) res = m_profile.volumeMax;
      return res;
   }

   double GetMinStopDistancePrice() const
   {
      int effectiveStops = MathMax(m_profile.stopsLevelPoints, m_profile.freezeLevelPoints);
      // Add 2 points buffer for broker spread/tick rounding safety
      return (double)(effectiveStops + 2) * m_profile.point;
   }

   double GetLossPerLotForPriceDistance(const double priceDistance) const
   {
      if(priceDistance <= 0.0 || m_profile.tickSize <= 0.0)
         return 0.0;
      double tv = (m_profile.tickValueLoss > 0.0) ? m_profile.tickValueLoss : m_profile.tickValue;
      if(tv <= 0.0)
         return 0.0;
      return (priceDistance / m_profile.tickSize) * tv;
   }

   bool EstimateMargin(const ENUM_ORDER_TYPE orderType, const double volume, const double price, double &outMargin) const
   {
      outMargin = 0.0;
      if(volume <= 0.0 || price <= 0.0)
         return false;
      return OrderCalcMargin(orderType, m_profile.symbol, volume, price, outMargin);
   }

   bool IsTradingPermittedBySymbol() const
   {
      if(!m_profile.isValid) return false;
      if(m_profile.tradeMode == SYMBOL_TRADE_MODE_DISABLED || m_profile.tradeMode == SYMBOL_TRADE_MODE_CLOSEONLY)
         return false;
      return m_profile.sessionOpenNow || m_profile.isSynthetic24x7;
   }
};

#endif // __ASEA_MARKET_SYMBOLINTELLIGENCE_MQH__
