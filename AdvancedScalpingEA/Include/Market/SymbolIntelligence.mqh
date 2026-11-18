//+------------------------------------------------------------------+
//|                                           SymbolIntelligence.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.9.0 Dynamic Multi-Instrument Profiler  |
//+------------------------------------------------------------------+
#ifndef __ASEA_MARKET_SYMBOLINTELLIGENCE_MQH__
#define __ASEA_MARKET_SYMBOLINTELLIGENCE_MQH__

#include "../Core/Types.mqh"
#include "../Core/Diagnostics.mqh"

class CSymbolIntelligence
{
private:
   SSymbolProfile            m_profile;
   ENUM_ASSET_CLASS_OVERRIDE m_assetOverride;
   bool                      m_autoTuneFromHistory;
   CDiagnostics             *m_diag;
   double                    m_defaultCommissionPerLot;
   bool                      m_commissionChecked;
   bool                      m_commissionDiscovered;
   datetime                  m_lastCommCheck;

   string ExtractCoreName(const string sym, string &outPrefix, string &outSuffix) const
   {
      outPrefix = "";
      outSuffix = "";
      string clean = sym;

      // Strip leading special broker prefix characters (#US30, $SPX, @NDX, etc.)
      if(StringLen(clean) >= 3)
      {
         ushort ch0 = StringGetCharacter(clean, 0);
         if(ch0 == '#' || ch0 == '$' || ch0 == '@')
         {
            outPrefix = StringSubstr(clean, 0, 1);
            clean = StringSubstr(clean, 1);
         }
      }

      // Strip explicit multi-character broker tier prefixes (e.g. pro_EURUSD, ecn-XAUUSD)
      string lowerClean = clean;
      StringToLower(lowerClean);
      string pfxTokens[6] = {"pro_", "ecn_", "raw_", "std_", "pro-", "ecn-"};
      for(int p = 0; p < 6; p++)
      {
         if(StringFind(lowerClean, pfxTokens[p]) == 0 && StringLen(clean) > 6)
         {
            outPrefix += StringSubstr(clean, 0, 4);
            clean = StringSubstr(clean, 4);
            break;
         }
      }

      string upper = clean;
      StringToUpper(upper);

      int dotPos  = StringFind(clean, ".");
      int usPos   = StringFind(clean, "_");
      int hashPos = StringFind(clean, "#");
      int plusPos = StringFind(clean, "+");
      int dashPos = StringFind(clean, "-");

      int cutPos = -1;
      if(dotPos > 2) cutPos = dotPos;
      else if(usPos > 2 && StringFind(upper, "INDEX") < 0 && StringFind(upper, "VOLATILITY") < 0 &&
              StringFind(upper, "R_") != 0 && StringFind(upper, "1HZ") < 0) cutPos = usPos;
      else if(hashPos > 2) cutPos = hashPos;
      else if(plusPos > 2) cutPos = plusPos;
      else if(dashPos > 2 && StringFind(upper, "INDEX") < 0) cutPos = dashPos;

      if(cutPos > 0)
      {
         outSuffix = StringSubstr(clean, cutPos);
         clean = StringSubstr(clean, 0, cutPos);
      }

      if(StringLen(clean) >= 7)
      {
         ushort c0 = StringGetCharacter(clean, 0);
         ushort c1 = StringGetCharacter(clean, 1);
         if(c0 >= 'a' && c0 <= 'z' && c1 >= 'A' && c1 <= 'Z')
         {
            outPrefix += StringSubstr(clean, 0, 1);
            clean = StringSubstr(clean, 1);
         }
      }

      // Strip trailing unseparated broker account suffixes on 6-letter FX/Metal cores (e.g. EURUSDm, GBPUSDc, EURUSDraw, XAUUSDpro)
      if(StringLen(clean) > 6 && StringFind(upper, "INDEX") < 0 && StringFind(upper, "CASH") < 0 &&
         StringFind(upper, "STEP") < 0 && StringFind(upper, "BOOM") < 0 && StringFind(upper, "CRASH") < 0 &&
         StringFind(upper, "JUMP") < 0 && StringFind(upper, "VOL") < 0 && StringFind(upper, "US30") < 0 &&
         StringFind(upper, "US500") < 0 && StringFind(upper, "US100") < 0 && StringFind(upper, "NAS100") < 0)
      {
         string head6 = StringSubstr(clean, 0, 6);
         string head6U = head6;
         StringToUpper(head6U);
         string tail = StringSubstr(clean, 6);
         string tailL = tail;
         StringToLower(tailL);
         bool allAlpha6 = true;
         for(int i = 0; i < 6; i++)
         {
            ushort ch = StringGetCharacter(head6U, i);
            if(ch < 'A' || ch > 'Z') { allAlpha6 = false; break; }
         }
         if(allAlpha6 && (tailL == "m" || tailL == "c" || tailL == "i" || tailL == "r" || tailL == "z" ||
                          tailL == "x" || tailL == "a" || tailL == "b" || tailL == "e" || tailL == "k" ||
                          tailL == "pro" || tailL == "ecn" || tailL == "raw" || tailL == "std" ||
                          tailL == "micro" || tailL == "mini" || tailL == "cent" || tailL == "zero" ||
                          tailL == "vip" || tailL == "prime" || tailL == "plus" || tailL == "fx"))
         {
            outSuffix = tail + outSuffix;
            clean = head6;
         }
      }
      return clean;
   }

   bool IsKnownMajorPair(const string b, const string q) const
   {
      return ((b == "EUR" && q == "USD") || (b == "GBP" && q == "USD") ||
              (b == "USD" && q == "JPY") || (b == "USD" && q == "CHF") ||
              (b == "USD" && q == "CAD") || (b == "AUD" && q == "USD") ||
              (b == "NZD" && q == "USD"));
   }

   bool IsMajorCurrency(const string c) const
   {
      return (c == "USD" || c == "EUR" || c == "GBP" || c == "JPY" ||
              c == "CHF" || c == "CAD" || c == "AUD" || c == "NZD");
   }

   bool IsKnownCurrencyCode(const string c) const
   {
      if(IsMajorCurrency(c)) return true;
      return (c == "CNH" || c == "CNY" || c == "HKD" || c == "SGD" || c == "PLN" ||
              c == "HUF" || c == "CZK" || c == "THB" || c == "INR" || c == "ZAR" ||
              c == "MXN" || c == "TRY" || c == "NOK" || c == "SEK" || c == "DKK" ||
              c == "KRW" || c == "TWD" || c == "BRL" || c == "ILS" || c == "SAR" ||
              c == "AED" || c == "RON" || c == "RUB");
   }

   ENUM_ASSET_CLASS ClassifySymbol(const string sym, const string core, const string baseCcy, const string profitCcy,
                                   bool &outStepIndex, bool &outSyntheticBurst) const
   {
      outStepIndex = false;
      outSyntheticBurst = false;

      string u = core;
      StringToUpper(u);
      string fullU = sym;
      StringToUpper(fullU);
      string pathU = SymbolInfoString(sym, SYMBOL_PATH);
      StringToUpper(pathU);
      string baseU = baseCcy;
      StringToUpper(baseU);
      string profU = profitCcy;
      StringToUpper(profU);

      if(StringFind(fullU, "STEP") >= 0 || StringFind(fullU, "MULTISTEP") >= 0 || StringFind(pathU, "STEP") >= 0)
      {
         outStepIndex = true;
         return ASSET_SYNTHETIC;
      }

      if(StringFind(fullU, "VOLATILITY") >= 0 || StringFind(fullU, "CRASH") >= 0 ||
         StringFind(fullU, "BOOM") >= 0 || StringFind(fullU, "JUMP") >= 0 ||
         StringFind(fullU, "RANGE BREAK") >= 0 || StringFind(fullU, "DRIFT") >= 0 ||
         StringFind(fullU, "1HZ") >= 0 || StringFind(fullU, "DEX") >= 0 ||
         StringFind(fullU, "HYBRID") >= 0 ||
         StringFind(fullU, "R_10") >= 0 || StringFind(fullU, "R_25") >= 0 ||
         StringFind(fullU, "R_50") >= 0 || StringFind(fullU, "R_75") >= 0 ||
         StringFind(fullU, "R_100") >= 0 || StringFind(fullU, "V10") >= 0 ||
         StringFind(fullU, "V25") >= 0 || StringFind(fullU, "V50") >= 0 ||
         StringFind(fullU, "V75") >= 0 || StringFind(fullU, "V100") >= 0 ||
         StringFind(pathU, "SYNTH") >= 0 || StringFind(pathU, "CRASH") >= 0 ||
         StringFind(pathU, "BOOM") >= 0 || StringFind(pathU, "VOLATILITY") >= 0)
      {
         outSyntheticBurst = (StringFind(fullU, "CRASH") >= 0 || StringFind(fullU, "BOOM") >= 0 ||
                              StringFind(fullU, "JUMP") >= 0 || StringFind(fullU, "VOLATILITY") >= 0 ||
                              StringFind(fullU, "1HZ") >= 0 || StringFind(fullU, "R_") >= 0);
         return ASSET_SYNTHETIC;
      }

      if(StringFind(u, "XAU") >= 0 || StringFind(u, "GOLD") >= 0 ||
         StringFind(u, "XAG") >= 0 || StringFind(u, "SILVER") >= 0 ||
         StringFind(u, "XPT") >= 0 || StringFind(u, "XPD") >= 0 ||
         StringFind(u, "XCU") >= 0 || StringFind(u, "COPPER") >= 0 ||
         StringFind(u, "XAL") >= 0 || StringFind(u, "ALUM") >= 0 ||
         StringFind(u, "PLAT") >= 0 || StringFind(u, "PALL") >= 0 ||
         baseU == "XAU" || baseU == "XAG" || baseU == "XPT" || baseU == "XPD" || baseU == "XAL")
         return ASSET_METAL;

      if(StringFind(u, "WTI") >= 0 || StringFind(u, "BRENT") >= 0 || StringFind(u, "BRN") >= 0 ||
         StringFind(u, "USOIL") >= 0 || StringFind(u, "UKOIL") >= 0 ||
         StringFind(u, "CRUDE") >= 0 || StringFind(u, "CL_") >= 0 ||
         StringFind(u, "XTI") >= 0 || StringFind(u, "XBR") >= 0 || StringFind(u, "XNG") >= 0 ||
         StringFind(u, "NGAS") >= 0 || StringFind(u, "NATGAS") >= 0 || StringFind(u, "USO") >= 0)
         return ASSET_ENERGY;

      if(StringFind(u, "BTC") >= 0 || StringFind(u, "ETH") >= 0 ||
         StringFind(u, "SOL") >= 0 || StringFind(u, "XRP") >= 0 ||
         StringFind(u, "LTC") >= 0 || StringFind(u, "ADA") >= 0 ||
         StringFind(u, "DOGE") >= 0 || StringFind(u, "BNB") >= 0 ||
         StringFind(u, "AVAX") >= 0 || StringFind(u, "DOT") >= 0 ||
         StringFind(u, "MATIC") >= 0 || StringFind(u, "LINK") >= 0 ||
         StringFind(u, "TON") >= 0 || StringFind(u, "TRX") >= 0 ||
         StringFind(u, "SUI") >= 0 || StringFind(u, "PEPE") >= 0 ||
         StringFind(u, "APT") >= 0 || StringFind(u, "NEAR") >= 0 ||
         StringFind(u, "ARB") >= 0 || StringFind(u, "XLM") >= 0 ||
         StringFind(u, "UNI") >= 0 || StringFind(u, "ETC") >= 0 ||
         StringFind(u, "ATOM") >= 0 || StringFind(u, "FIL") >= 0 ||
         StringFind(u, "SHIB") >= 0 ||
         StringFind(u, "BCH") >= 0 || baseU == "BTC" || baseU == "ETH" || baseU == "SOL")
         return ASSET_CRYPTO;

      if(StringFind(u, "US30") >= 0 || StringFind(u, "DJ30") >= 0 || StringFind(u, "DJI") >= 0 ||
         StringFind(u, "DOW") >= 0 || StringFind(u, "WS30") >= 0 ||
         StringFind(u, "US500") >= 0 || StringFind(u, "SPX") >= 0 || StringFind(u, "SP500") >= 0 ||
         StringFind(u, "NAS100") >= 0 || StringFind(u, "US100") >= 0 || StringFind(u, "USTEC") >= 0 ||
         StringFind(u, "NQ100") >= 0 || StringFind(u, "NDX") >= 0 || StringFind(u, "DAX") >= 0 ||
         StringFind(u, "DE30") >= 0 || StringFind(u, "DE40") >= 0 ||
         StringFind(u, "GER30") >= 0 || StringFind(u, "GER40") >= 0 ||
         StringFind(u, "UK100") >= 0 || StringFind(u, "FTSE") >= 0 || StringFind(u, "JP225") >= 0 ||
         StringFind(u, "NI225") >= 0 || StringFind(u, "NIKKEI") >= 0 ||
         StringFind(u, "AUS200") >= 0 || StringFind(u, "ASX200") >= 0 ||
         StringFind(u, "FR40") >= 0 || StringFind(u, "CAC") >= 0 ||
         StringFind(u, "EU50") >= 0 || StringFind(u, "STOXX") >= 0 ||
         StringFind(u, "HK50") >= 0 || StringFind(u, "HKG50") >= 0 || StringFind(u, "HSI") >= 0 ||
         StringFind(u, "ES35") >= 0 || StringFind(u, "SPA35") >= 0 ||
         StringFind(u, "IT40") >= 0 || StringFind(u, "MIB") >= 0 ||
         StringFind(u, "NETH25") >= 0 || StringFind(u, "AEX") >= 0 ||
         StringFind(u, "SWI20") >= 0 || StringFind(u, "SMI") >= 0 || StringFind(u, "CH20") >= 0 ||
         StringFind(u, "CN50") >= 0 || StringFind(u, "NIFTY") >= 0 ||
         StringFind(u, "US2000") >= 0 || StringFind(u, "RUSSELL") >= 0 ||
         StringFind(u, "RUT") >= 0 || StringFind(u, "VIX") >= 0 || StringFind(u, "VOLX") >= 0 || StringFind(u, "DXY") >= 0)
         return ASSET_INDEX;

      if(StringLen(u) >= 6)
      {
         string b = StringSubstr(u, 0, 3);
         string q = StringSubstr(u, 3, 3);
         bool baseMajor  = IsMajorCurrency(b);
         bool quoteMajor = IsMajorCurrency(q);
         bool baseKnown  = IsKnownCurrencyCode(b);
         bool quoteKnown = IsKnownCurrencyCode(q);
         if(baseMajor && quoteMajor && StringLen(u) == 6)
            return IsKnownMajorPair(b, q) ? ASSET_FOREX_MAJOR : ASSET_FOREX_MINOR;
         if((baseKnown && quoteKnown) && StringLen(u) == 6)
            return ASSET_FOREX_EXOTIC;
      }

      long sector = SymbolInfoInteger(sym, SYMBOL_SECTOR);
      long calcMode = SymbolInfoInteger(sym, SYMBOL_TRADE_CALC_MODE);
      if(sector == SECTOR_CURRENCY_CRYPTO) return ASSET_CRYPTO;
      if(sector == SECTOR_INDEXES)         return ASSET_INDEX;
      if(sector == SECTOR_COMMODITIES)
      {
         if(StringFind(pathU, "METAL") >= 0)  return ASSET_METAL;
         if(StringFind(pathU, "ENERGY") >= 0 || StringFind(pathU, "OIL") >= 0 || StringFind(pathU, "GAS") >= 0) return ASSET_ENERGY;
      }

      if(calcMode == SYMBOL_CALC_MODE_EXCH_STOCKS || calcMode == SYMBOL_CALC_MODE_EXCH_STOCKS_MOEX ||
         (sector >= SECTOR_BASIC_MATERIALS && sector <= SECTOR_UTILITIES))
         return ASSET_EQUITY;

      if(calcMode == SYMBOL_CALC_MODE_CFDINDEX)
         return ASSET_INDEX;
      if(calcMode == SYMBOL_CALC_MODE_FOREX || calcMode == SYMBOL_CALC_MODE_FOREX_NO_LEVERAGE || sector == SECTOR_CURRENCY)
      {
         if(StringLen(baseU) == 3 && StringLen(profU) == 3)
         {
            if(IsKnownMajorPair(baseU, profU)) return ASSET_FOREX_MAJOR;
            if(IsMajorCurrency(baseU) && IsMajorCurrency(profU)) return ASSET_FOREX_MINOR;
            return ASSET_FOREX_EXOTIC;
         }
         return (baseU == "USD" || profU == "USD") ? ASSET_FOREX_MINOR : ASSET_FOREX_EXOTIC;
      }

      if(StringFind(pathU, "STOCK") >= 0 || StringFind(pathU, "EQUIT") >= 0 || StringFind(pathU, "SHARE") >= 0)
         return ASSET_EQUITY;

      return ASSET_CFD;
   }

   double ComputePipSize(const ENUM_ASSET_CLASS ac, const int digits, const double point, const double tickSize) const
   {
      if(ac == ASSET_FOREX_MAJOR || ac == ASSET_FOREX_MINOR || ac == ASSET_FOREX_EXOTIC)
      {
         if(digits == 5 || digits == 3) return point * 10.0;
         return point;
      }
      return MathMax(point, tickSize);
   }

   double ComputeBaseAutoSpreadFloorPts(const ENUM_ASSET_CLASS ac, const double point, const double pipSize, const double refPrice = 0.0) const
   {
      double pipPts   = (point > 0.0 && pipSize > 0.0) ? MathMax(1.0, pipSize / point) : 1.0;
      double pricePts = (point > 0.0 && refPrice > 0.0) ? (refPrice / point) : 0.0;
      switch(ac)
      {
         case ASSET_FOREX_MAJOR:  return MathMax(12.0, pipPts * 4.5);
         case ASSET_FOREX_MINOR:  return MathMax(20.0, pipPts * 7.5);
         case ASSET_FOREX_EXOTIC: return MathMax(80.0, pipPts * 25.0);
         case ASSET_METAL:        return MathMax(55.0, MathMax(pipPts * 20.0, pricePts * 0.00025));
         case ASSET_INDEX:        return MathMax(80.0, MathMax(pipPts * 35.0, pricePts * 0.00050));
         case ASSET_ENERGY:       return MathMax(55.0, MathMax(pipPts * 20.0, pricePts * 0.00060));
         case ASSET_CRYPTO:       return MathMax(150.0, MathMax(pipPts * 50.0, pricePts * 0.00140));
         case ASSET_SYNTHETIC:    return MathMax(100.0, MathMax(pipPts * 45.0, pricePts * 0.00040));
         case ASSET_EQUITY:       return MathMax(25.0, MathMax(pipPts * 12.0, pricePts * 0.00120));
         default:                 return MathMax(60.0, MathMax(pipPts * 25.0, pricePts * 0.00060));
      }
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
      datetime now = SafeCurrentTime();
      MqlDateTime dt;
      TimeToStruct(now, dt);
      ENUM_DAY_OF_WEEK dow = (ENUM_DAY_OF_WEEK)dt.day_of_week;

      datetime fromTime = 0, toTime = 0;
      int secondsToday = dt.hour * 3600 + dt.min * 60 + dt.sec;
      bool foundOpen = false;
      bool anyRow = false;
      bool sundayOpen = SymbolInfoSessionTrade(sym, SUNDAY, 0, fromTime, toTime);
      bool satOpen    = SymbolInfoSessionTrade(sym, SATURDAY, 0, fromTime, toTime);
      out24x7 = (sundayOpen && satOpen);

      for(uint idx = 0; idx < 8; idx++)
      {
         if(!SymbolInfoSessionTrade(sym, dow, idx, fromTime, toTime))
            break;
         anyRow = true;
         long fromSec = (long)(fromTime % 86400);
         long toSec   = (long)(toTime % 86400);
         if(fromSec == toSec)
         {
            // Brokers frequently encode continuous 24h session as 00:00 -> 00:00
            foundOpen = true;
            break;
         }
         if(toSec == 0 && toTime > fromTime)
            toSec = 86400;

         if(toSec >= fromSec)
         {
            if(secondsToday >= fromSec && secondsToday <= toSec)
            {
               foundOpen = true;
               break;
            }
         }
         else
         {
            // Overnight session wrapping past midnight
            if(secondsToday >= fromSec || secondsToday <= toSec)
            {
               foundOpen = true;
               break;
            }
         }
      }

      if(!anyRow || MQLInfoInteger(MQL_TESTER))
      {
         // Strategy Tester or brokers omitting per-day session rows for active symbols
         ENUM_SYMBOL_TRADE_MODE tm = (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(sym, SYMBOL_TRADE_MODE);
         if(tm != SYMBOL_TRADE_MODE_DISABLED && tm != SYMBOL_TRADE_MODE_CLOSEONLY)
         {
            MqlTick t;
            if(SymbolInfoTick(sym, t) && t.bid > 0.0 && t.ask > 0.0)
               foundOpen = true;
         }
      }
      return foundOpen;
   }

   double EstimateCommissionFromHistory(const string sym)
   {
      datetime now = SafeCurrentTime();
      if(now <= 0) return m_defaultCommissionPerLot;
      if(m_commissionChecked && (m_commissionDiscovered || (now - m_lastCommCheck) < 300))
         return m_profile.estCommissionPerLot;

      datetime fromTime = (now > 86400 * 30) ? (now - 86400 * 30) : (datetime)0;
      m_lastCommCheck = now;
      if(!HistorySelect(fromTime, now))
         return m_defaultCommissionPerLot;

      m_commissionChecked = true;
      int total = HistoryDealsTotal();
      for(int i = total - 1; i >= 0 && i >= total - 50; i--)
      {
         ulong t = HistoryDealGetTicket(i);
         if(HistoryDealGetString(t, DEAL_SYMBOL) != sym) continue;
         long entry = HistoryDealGetInteger(t, DEAL_ENTRY);
         if(entry != DEAL_ENTRY_IN && entry != DEAL_ENTRY_OUT) continue;
         double vol = HistoryDealGetDouble(t, DEAL_VOLUME);
         double comm = MathAbs(HistoryDealGetDouble(t, DEAL_COMMISSION));
         if(vol > 0.0)
         {
            m_commissionDiscovered = true;
            return (comm / vol) * 2.0; // Round-turn commission per lot
         }
      }
      return m_defaultCommissionPerLot;
   }

public:
   CSymbolIntelligence()
   {
      m_profile.Reset();
      m_assetOverride = ASSET_OVERRIDE_AUTO;
      m_autoTuneFromHistory = true;
      m_diag = NULL;
      m_defaultCommissionPerLot = 0.0;
      m_commissionChecked = false;
      m_commissionDiscovered = false;
      m_lastCommCheck = 0;
   }

   bool Initialize(const string symbol, const ENUM_TIMEFRAMES primaryTF, const double fallbackCommPerLot,
                   CDiagnostics *diag, const ENUM_ASSET_CLASS_OVERRIDE assetOverride = ASSET_OVERRIDE_AUTO,
                   const bool autoTuneFromHistory = true)
   {
      m_diag = diag;
      m_assetOverride = assetOverride;
      m_autoTuneFromHistory = autoTuneFromHistory;
      m_defaultCommissionPerLot = MathMax(0.0, fallbackCommPerLot);
      m_commissionChecked = false;
      m_commissionDiscovered = false;
      m_lastCommCheck = 0;
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
      bool isStep = false, isBurst = false;
      m_profile.assetClass     = ClassifySymbol(sym, m_profile.baseSymbol, m_profile.currencyBase, m_profile.currencyProfit, isStep, isBurst);
      if(m_assetOverride != ASSET_OVERRIDE_AUTO)
      {
         m_profile.assetClass = (ENUM_ASSET_CLASS)((int)m_assetOverride);
         string symU = sym;
         StringToUpper(symU);
         if(m_profile.assetClass == ASSET_SYNTHETIC && StringFind(symU, "STEP") >= 0)
            isStep = true;
      }
      if(m_profile.empiricalQuantizedStep && m_profile.assetClass == ASSET_CFD)
      {
         isStep = true;
         m_profile.assetClass = ASSET_SYNTHETIC;
      }
      m_profile.isStepIndex    = isStep;
      m_profile.isSyntheticBurst = isBurst;

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

      long marginMode = AccountInfoInteger(ACCOUNT_MARGIN_MODE);
      m_profile.isHedgingAccount = (marginMode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);

      bool is24x7 = false;
      m_profile.sessionOpenNow  = CheckSessionOpenNow(sym, is24x7);
      m_profile.isSynthetic24x7 = is24x7 || (m_profile.assetClass == ASSET_SYNTHETIC) || (m_profile.assetClass == ASSET_CRYPTO);

      long realVol = iVolume(sym, primaryTF, 1);
      m_profile.hasRealVolume = (realVol > 0);
      m_profile.availableBarsPrimary = Bars(sym, primaryTF);
      m_profile.estCommissionPerLot = EstimateCommissionFromHistory(sym);
      m_profile.lastInspected = SafeCurrentTime();

      double refBid = SymbolInfoDouble(sym, SYMBOL_BID);
      m_profile.pipSize = ComputePipSize(m_profile.assetClass, m_profile.digits, m_profile.point, m_profile.tickSize);
      double baseFloor = ComputeBaseAutoSpreadFloorPts(m_profile.assetClass, m_profile.point, m_profile.pipSize, refBid);
      double initSprFloor = (m_profile.spreadPoints > 0) ? ((double)m_profile.spreadPoints * 2.40) : baseFloor;
      m_profile.autoMaxSpreadPts = MathMax(baseFloor, initSprFloor);
      m_profile.recommendedSlippagePts = (int)MathMax(20.0, MathMin(400.0, (double)m_profile.spreadPoints * 0.8 + 15.0));

      m_profile.isValid = (m_profile.point > 0.0 && m_profile.tickSize > 0.0 && m_profile.volumeStep > 0.0 && m_profile.volumeMin > 0.0);
      return m_profile.isValid;
   }

   void RefreshAvailableBars(const ENUM_TIMEFRAMES primaryTF)
   {
      if(m_profile.symbol == "") return;
      m_profile.availableBarsPrimary = Bars(m_profile.symbol, primaryTF);
   }

   void UpdateDynamicBaselines(const double typicalAtr, const double typicalSpreadPts)
   {
      if(typicalAtr > 0.0) m_profile.typicalAtrPrice = typicalAtr;
      if(typicalSpreadPts > 0.0) m_profile.typicalSpreadPoints = typicalSpreadPts;

      double refBid = SymbolInfoDouble(m_profile.symbol, SYMBOL_BID);
      double baseFloor = ComputeBaseAutoSpreadFloorPts(m_profile.assetClass, m_profile.point, m_profile.pipSize, refBid);
      double atrPtsCap = (typicalAtr > 0.0 && m_profile.point > 0.0) ? ((typicalAtr / m_profile.point) * 0.30) : baseFloor;
      double typSpreadCap = (typicalSpreadPts > 0.0) ? (typicalSpreadPts * 2.40) : baseFloor;
      m_profile.autoMaxSpreadPts = MathMax(baseFloor, MathMax(atrPtsCap, typSpreadCap));
      m_profile.recommendedSlippagePts = (int)MathMax(20.0, MathMin(400.0, typicalSpreadPts * 0.9 + 15.0));

      if(typicalAtr > 0.0 && m_profile.point > 0.0 && typicalSpreadPts > 0.0)
         m_profile.spreadToAtrBaselinePct = ((typicalSpreadPts * m_profile.point) / typicalAtr) * 100.0;
   }

   void CalibrateFromHistory(const MqlRates &rates[], const int count, const double curAtr)
   {
      if(!m_autoTuneFromHistory || count < 20 || curAtr <= 0.0)
         return;

      int n = MathMin(48, count);
      double netMove = MathAbs(rates[0].close - rates[n - 1].close);
      double sumStep = 0.0, sumWick = 0.0, sumRange = 0.0;
      int spikeBars = 0;
      double minStepDelta = 1e12;
      double deltas[48];
      int dCount = 0;

      for(int i = 0; i < n; i++)
      {
         double rng = rates[i].high - rates[i].low;
         double bodyTop = MathMax(rates[i].open, rates[i].close);
         double bodyBot = MathMin(rates[i].open, rates[i].close);
         double wicks = MathMax(0.0, (rates[i].high - bodyTop) + (bodyBot - rates[i].low));
         if(rng > 0.0)
         {
            sumRange += rng;
            sumWick  += wicks;
            if(rng > curAtr * 2.35)
               spikeBars++;
         }
         if(i < n - 1)
         {
            double delta = MathAbs(rates[i].close - rates[i + 1].close);
            sumStep += delta;
            if(delta > m_profile.point * 0.5)
            {
               deltas[dCount++] = delta;
               if(delta < minStepDelta) minStepDelta = delta;
            }
         }
      }

      if(sumStep > 0.0)
         m_profile.empiricalEffRatio = MathMax(0.0, MathMin(1.0, netMove / sumStep));
      if(sumRange > 0.0)
      {
         m_profile.avgWickRatio      = MathMax(0.0, MathMin(0.95, sumWick / sumRange));
         m_profile.medianBarRangeAtr = MathMax(0.25, MathMin(3.0, (sumRange / (double)n) / curAtr));
      }
      m_profile.spikeBarRatio = (n > 0) ? ((double)spikeBars / (double)n) : 0.0;

      // Quantized step detection (identifies Step Index / fixed-step synthetics empirically)
      if(dCount >= 16 && minStepDelta > m_profile.tickSize * 1.5 && minStepDelta < curAtr * 0.75)
      {
         int quantizedMatches = 0;
         for(int i = 0; i < dCount; i++)
         {
            double ratio = deltas[i] / minStepDelta;
            if(MathAbs(ratio - MathRound(ratio)) <= 0.04)
               quantizedMatches++;
         }
         if(((double)quantizedMatches / (double)dCount) >= 0.72)
         {
            m_profile.empiricalQuantizedStep = true;
            m_profile.quantizedStepSize      = minStepDelta;
            m_profile.isStepIndex            = true;
         }
      }

      m_profile.empiricalProfileReady = true;
      m_profile.microstructureSummary = StringFormat("ER=%.2f Wick=%.0f%% Spk=%.0f%% SprATR=%.1f%% Step=%s",
                                                     m_profile.empiricalEffRatio,
                                                     m_profile.avgWickRatio * 100.0,
                                                     m_profile.spikeBarRatio * 100.0,
                                                     m_profile.spreadToAtrBaselinePct,
                                                     m_profile.empiricalQuantizedStep ? "Quantized" : "Continuous");
   }

   void RecordMeasuredSlippage(const double slippagePts)
   {
      if(slippagePts < 0.0 || !MathIsValidNumber(slippagePts)) return;
      if(m_profile.measuredFillCount == 0)
         m_profile.measuredAvgSlippagePts = slippagePts;
      else
         m_profile.measuredAvgSlippagePts = 0.70 * m_profile.measuredAvgSlippagePts + 0.30 * slippagePts;
      m_profile.measuredFillCount++;
   }

   double GetEffectiveSlippagePoints(const double baselineFloorPts, const double curSpreadPts) const
   {
      if(m_profile.measuredFillCount >= 1)
         return MathMax(0.0, m_profile.measuredAvgSlippagePts);
      return MathMax(baselineFloorPts, MathMin(curSpreadPts * 0.15, 25.0));
   }

   double GetAutoMaxSpreadPoints(const double curAtr) const
   {
      double baseFloor = m_profile.autoMaxSpreadPts;
      if(curAtr > 0.0 && m_profile.point > 0.0)
      {
         double atrPtsLimit = (curAtr / m_profile.point) * 0.30;
         return MathMax(baseFloor, atrPtsLimit);
      }
      return baseFloor;
   }

   SSymbolProfile   GetProfile() const               { return m_profile; }
   double           GetPoint() const                 { return m_profile.point; }
   double           GetTickSize() const              { return m_profile.tickSize; }
   double           GetPipSize() const               { return m_profile.pipSize; }
   bool             HasRealVolume() const            { return m_profile.hasRealVolume; }
   bool             IsStepIndex() const              { return m_profile.isStepIndex; }
   bool             IsSynthetic24x7() const          { return m_profile.isSynthetic24x7; }
   bool             IsSessionOpenNow() const         { return m_profile.sessionOpenNow; }
   bool             IsEmpiricalProfileReady() const  { return m_profile.empiricalProfileReady; }
   ENUM_ASSET_CLASS GetAssetClass() const            { return m_profile.assetClass; }

   SAdaptiveAssetProfile GetAdaptiveAssetProfile() const
   {
      SAdaptiveAssetProfile ap;
      ap.ResetDefaults();
      ap.recommendedSlippagePts = MathMax(20, m_profile.recommendedSlippagePts);

      if(m_profile.isStepIndex)
      {
         ap.profileName         = "Step Index (Quantized Synthetic)";
         ap.slAtrMult           = 1.80;
         ap.tpAtrMult           = 3.00;
         ap.beTriggerAtr        = 1.50;
         ap.partialTriggerAtr   = 2.00;
         ap.partialFraction     = 0.40;
         ap.trailStartAtr       = 2.00;
         ap.trailStepAtr        = 1.05;
         ap.adxStrongThresh     = 25.0;
         ap.adxWeakThresh       = 16.0;
         ap.volHighRatio        = 1.55;
         ap.volLowRatio         = 0.65;
         ap.spreadUnstableRatio = 3.00;
         ap.maxSpreadRatio      = 2.80;
         ap.maxSpreadAtrPct     = 30.0;
         ap.maxVolatilityRatio  = 4.00;
         ap.minVolatilityRatio  = 0.25;
         ap.minTpToCostRatio    = 2.20;
         ap.minSignalScore      = 58.0;
         ap.lossCooldownBars    = 2;
         ap.recommendedSlippagePts = MathMax(30, m_profile.recommendedSlippagePts);
         ap.allow24x7Continuous = true;
         ap.tuningNotes         = "24/7 continuous quantized-step profile with wider swing stop room and trend trail";
         return ap;
      }

      switch(m_profile.assetClass)
      {
         case ASSET_FOREX_MAJOR:
            ap.profileName         = "Forex Major";
            ap.slAtrMult           = 1.55;
            ap.tpAtrMult           = 2.75;
            ap.beTriggerAtr        = 1.40;
            ap.partialTriggerAtr   = 1.85;
            ap.partialFraction     = 0.40;
            ap.trailStartAtr       = 1.95;
            ap.trailStepAtr        = 0.95;
            ap.adxStrongThresh     = 26.0;
            ap.adxWeakThresh       = 17.0;
            ap.maxSpreadAtrPct     = 24.0;
            ap.minSignalScore      = 60.0;
            ap.lossCooldownBars    = 3;
            ap.recommendedSlippagePts = MathMax(20, m_profile.recommendedSlippagePts);
            ap.allow24x7Continuous = false;
            ap.tuningNotes         = "Tight spread-cost FX major scaling";
            break;

         case ASSET_FOREX_MINOR:
            ap.profileName         = "Forex Minor / Cross";
            ap.slAtrMult           = 1.70;
            ap.tpAtrMult           = 2.95;
            ap.beTriggerAtr        = 1.50;
            ap.partialTriggerAtr   = 1.95;
            ap.partialFraction     = 0.40;
            ap.trailStartAtr       = 2.05;
            ap.trailStepAtr        = 1.00;
            ap.adxStrongThresh     = 26.0;
            ap.adxWeakThresh       = 17.0;
            ap.spreadUnstableRatio = 3.00;
            ap.maxSpreadRatio      = 2.75;
            ap.maxSpreadAtrPct     = 28.0;
            ap.minSignalScore      = 60.0;
            ap.lossCooldownBars    = 3;
            ap.recommendedSlippagePts = MathMax(30, m_profile.recommendedSlippagePts);
            ap.allow24x7Continuous = false;
            ap.tuningNotes         = "Wider wick clearance for JPY/EUR/GBP cross volatility";
            break;

         case ASSET_FOREX_EXOTIC:
            ap.profileName         = "Forex Exotic";
            ap.slAtrMult           = 1.90;
            ap.tpAtrMult           = 3.25;
            ap.beTriggerAtr        = 1.60;
            ap.partialTriggerAtr   = 2.10;
            ap.partialFraction     = 0.45;
            ap.trailStartAtr       = 2.20;
            ap.trailStepAtr        = 1.10;
            ap.adxStrongThresh     = 28.0;
            ap.adxWeakThresh       = 18.0;
            ap.spreadUnstableRatio = 3.20;
            ap.maxSpreadRatio      = 2.85;
            ap.maxSpreadAtrPct     = 34.0;
            ap.maxVolatilityRatio  = 3.80;
            ap.minTpToCostRatio    = 2.40;
            ap.minSignalScore      = 63.0;
            ap.lossCooldownBars    = 3;
            ap.recommendedSlippagePts = MathMax(45, m_profile.recommendedSlippagePts);
            ap.allow24x7Continuous = false;
            ap.tuningNotes         = "Strict cost-recovery threshold and wide stop clearance for exotics";
            break;

         case ASSET_METAL:
            ap.profileName         = "Metals (XAU/XAG)";
            ap.slAtrMult           = 1.75;
            ap.tpAtrMult           = 3.10;
            ap.beTriggerAtr        = 1.50;
            ap.partialTriggerAtr   = 2.00;
            ap.partialFraction     = 0.40;
            ap.trailStartAtr       = 2.10;
            ap.trailStepAtr        = 1.05;
            ap.adxStrongThresh     = 27.0;
            ap.adxWeakThresh       = 17.5;
            ap.maxSpreadAtrPct     = 26.0;
            ap.maxVolatilityRatio  = 3.60;
            ap.minSignalScore      = 61.0;
            ap.lossCooldownBars    = 3;
            ap.recommendedSlippagePts = MathMax(35, m_profile.recommendedSlippagePts);
            ap.allow24x7Continuous = false;
            ap.tuningNotes         = "Sweep-resistant SL + extended Chandelier runner for Gold/Silver";
            break;

         case ASSET_INDEX:
         case ASSET_ENERGY:
            ap.profileName         = (m_profile.assetClass == ASSET_INDEX) ? "Stock Index CFD" : "Energy CFD";
            ap.slAtrMult           = 1.75;
            ap.tpAtrMult           = 3.05;
            ap.beTriggerAtr        = 1.50;
            ap.partialTriggerAtr   = 2.00;
            ap.partialFraction     = 0.40;
            ap.trailStartAtr       = 2.05;
            ap.trailStepAtr        = 1.05;
            ap.adxStrongThresh     = 26.0;
            ap.adxWeakThresh       = 17.0;
            ap.maxSpreadAtrPct     = 28.0;
            ap.maxVolatilityRatio  = 3.60;
            ap.minSignalScore      = 60.0;
            ap.lossCooldownBars    = 3;
            ap.recommendedSlippagePts = MathMax(40, m_profile.recommendedSlippagePts);
            ap.allow24x7Continuous = false;
            ap.tuningNotes         = "Momentum-friendly index/energy continuation target sizing";
            break;

         case ASSET_SYNTHETIC:
            ap.profileName         = "Synthetic Volatility / Crash-Boom";
            ap.slAtrMult           = 1.90;
            ap.tpAtrMult           = 3.25;
            ap.beTriggerAtr        = 1.55;
            ap.partialTriggerAtr   = 2.05;
            ap.partialFraction     = 0.40;
            ap.trailStartAtr       = 2.15;
            ap.trailStepAtr        = 1.10;
            ap.adxStrongThresh     = 25.0;
            ap.adxWeakThresh       = 16.5;
            ap.volHighRatio        = 1.55;
            ap.volLowRatio         = 0.65;
            ap.spreadUnstableRatio = 3.10;
            ap.maxSpreadRatio      = 2.90;
            ap.maxSpreadAtrPct     = 30.0;
            ap.maxVolatilityRatio  = 4.20;
            ap.minVolatilityRatio  = 0.25;
            ap.minTpToCostRatio    = 2.20;
            ap.minSignalScore      = 59.0;
            ap.lossCooldownBars    = 2;
            ap.recommendedSlippagePts = MathMax(40, m_profile.recommendedSlippagePts);
            ap.allow24x7Continuous = true;
            ap.tuningNotes         = "24/7 synthetic expansion & spike-tolerant ATR regime scaling";
            break;

         case ASSET_CRYPTO:
            ap.profileName         = "Crypto CFD (24/7)";
            ap.slAtrMult           = 1.95;
            ap.tpAtrMult           = 3.40;
            ap.beTriggerAtr        = 1.60;
            ap.partialTriggerAtr   = 2.10;
            ap.partialFraction     = 0.40;
            ap.trailStartAtr       = 2.20;
            ap.trailStepAtr        = 1.15;
            ap.adxStrongThresh     = 26.0;
            ap.adxWeakThresh       = 17.0;
            ap.volHighRatio        = 1.55;
            ap.spreadUnstableRatio = 3.20;
            ap.maxSpreadRatio      = 3.00;
            ap.maxSpreadAtrPct     = 34.0;
            ap.maxVolatilityRatio  = 4.20;
            ap.minTpToCostRatio    = 2.40;
            ap.minSignalScore      = 61.0;
            ap.lossCooldownBars    = 3;
            ap.recommendedSlippagePts = MathMax(60, m_profile.recommendedSlippagePts);
            ap.allow24x7Continuous = true;
            ap.tuningNotes         = "24/7 crypto volatility & spread-cushion scaling";
            break;

         case ASSET_EQUITY:
            ap.profileName         = "Equity / Stock CFD";
            ap.slAtrMult           = 1.80;
            ap.tpAtrMult           = 3.10;
            ap.beTriggerAtr        = 1.50;
            ap.partialTriggerAtr   = 2.00;
            ap.partialFraction     = 0.40;
            ap.trailStartAtr       = 2.10;
            ap.trailStepAtr        = 1.05;
            ap.adxStrongThresh     = 26.0;
            ap.adxWeakThresh       = 17.0;
            ap.maxSpreadAtrPct     = 30.0;
            ap.maxVolatilityRatio  = 3.60;
            ap.minSignalScore      = 61.0;
            ap.lossCooldownBars    = 3;
            ap.recommendedSlippagePts = MathMax(35, m_profile.recommendedSlippagePts);
            ap.allow24x7Continuous = false;
            ap.tuningNotes         = "Gap & wick-safe Equity CFD scaling";
            break;

         default:
            ap.profileName         = "Broker CFD (Generic Auto)";
            ap.slAtrMult           = 1.75;
            ap.tpAtrMult           = 3.00;
            ap.beTriggerAtr        = 1.50;
            ap.partialTriggerAtr   = 1.95;
            ap.partialFraction     = 0.40;
            ap.trailStartAtr       = 2.05;
            ap.trailStepAtr        = 1.05;
            ap.maxSpreadAtrPct     = 30.0;
            ap.minSignalScore      = 60.0;
            ap.recommendedSlippagePts = MathMax(35, m_profile.recommendedSlippagePts);
            ap.allow24x7Continuous = m_profile.isSynthetic24x7;
            ap.tuningNotes         = "Dynamic tick/contract-normalized CFD baseline";
            break;
      }

      // Apply Empirical Market-DNA micro-adjustments learned from symbol history
      if(m_autoTuneFromHistory && m_profile.empiricalProfileReady)
      {
         // High-wick instruments receive slightly wider SL & trail cushion so liquidity wicks don't hunt stops
         if(m_profile.avgWickRatio > 0.56)
         {
            ap.slAtrMult    += 0.15;
            ap.trailStepAtr += 0.10;
         }
         // Spiky outlier instruments (Boom/Crash bursts, high-beta open spikes) get extra SL clearance & score discipline
         if(m_profile.spikeBarRatio >= 0.08)
         {
            ap.slAtrMult     += 0.15;
            ap.trailStepAtr  += 0.10;
            ap.minSignalScore = MathMin(72.0, ap.minSignalScore + 2.0);
         }
         // Smooth trending symbols earn extended take-profit targets
         if(m_profile.empiricalEffRatio >= 0.36)
         {
            ap.tpAtrMult += 0.25;
         }
         // High friction (spread consumes large slice of ATR) requires stronger score & higher R:R target
         if(m_profile.spreadToAtrBaselinePct >= 14.0)
         {
            ap.minSignalScore = MathMin(72.0, ap.minSignalScore + 3.0);
            ap.tpAtrMult     += 0.25;
            ap.beTriggerAtr  += 0.10;
         }
      }
      return ap;
   }

   double NormalizePrice(const double price) const
   {
      if(m_profile.tickSize > 0.0)
         return NormalizeDouble(MathRound(price / m_profile.tickSize) * m_profile.tickSize, m_profile.digits);
      return NormalizeDouble(price, m_profile.digits);
   }

   double NormalizeVolume(const double lots) const
   {
      if(m_profile.volumeStep <= 0.0 || lots < m_profile.volumeMin)
         return 0.0;
      double clamped = MathMax(m_profile.volumeMin, MathMin(m_profile.volumeMax, lots));
      double steps = MathFloor(((clamped - m_profile.volumeMin) + 1e-12) / m_profile.volumeStep);
      double res = NormalizeDouble(m_profile.volumeMin + steps * m_profile.volumeStep, m_profile.volumeDigits);
      if(res < m_profile.volumeMin) res = 0.0;
      if(res > m_profile.volumeMax) res = m_profile.volumeMax;
      return res;
   }

   double GetMinStopDistancePrice() const
   {
      int effectiveStops = MathMax(m_profile.stopsLevelPoints, m_profile.freezeLevelPoints);
      return MathMax((double)(effectiveStops + 3) * m_profile.point, m_profile.tickSize * 2.0);
   }

   double ResolveFallbackTickValue() const
   {
      MqlTick t;
      if(SymbolInfoTick(m_profile.symbol, t) && t.bid > 0.0)
      {
         double calcProfit = 0.0;
         if(OrderCalcProfit(ORDER_TYPE_BUY, m_profile.symbol, 1.0, t.bid, t.bid + m_profile.tickSize, calcProfit) &&
            calcProfit > 0.0 && MathIsValidNumber(calcProfit))
            return calcProfit;
      }
      if(m_profile.contractSize > 0.0 && m_profile.tickSize > 0.0)
         return m_profile.tickSize * m_profile.contractSize;
      return 0.0;
   }

   double GetLossPerLotForPriceDistance(const double priceDistance) const
   {
      if(priceDistance <= 0.0 || m_profile.tickSize <= 0.0)
         return 0.0;
      double tv = (m_profile.tickValueLoss > 0.0) ? m_profile.tickValueLoss : m_profile.tickValue;
      if(tv <= 0.0) tv = ResolveFallbackTickValue();
      if(tv <= 0.0) return 0.0;
      return (priceDistance / m_profile.tickSize) * tv;
   }

   double GetProfitPerLotForPriceDistance(const double priceDistance) const
   {
      if(priceDistance <= 0.0 || m_profile.tickSize <= 0.0)
         return 0.0;
      double tv = (m_profile.tickValueProfit > 0.0) ? m_profile.tickValueProfit : m_profile.tickValue;
      if(tv <= 0.0) tv = ResolveFallbackTickValue();
      if(tv <= 0.0) return 0.0;
      return (priceDistance / m_profile.tickSize) * tv;
   }

   double EstimateRiskMoneyForOrder(const ENUM_SIGNAL_DIRECTION dir, const double lots,
                                    const double openPrice, const double stopPrice) const
   {
      if(lots <= 0.0 || openPrice <= 0.0 || stopPrice <= 0.0) return 0.0;
      double slDist = MathAbs(openPrice - stopPrice);
      if(slDist <= 0.0) return 0.0;
      ENUM_ORDER_TYPE ot = (dir == SIGNAL_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      double calc = 0.0;
      if(OrderCalcProfit(ot, m_profile.symbol, lots, openPrice, stopPrice, calc) &&
         MathIsValidNumber(calc) && MathAbs(calc) > 0.0)
         return MathAbs(calc);
      return GetLossPerLotForPriceDistance(slDist) * lots;
   }

   double EstimateRewardMoneyForOrder(const ENUM_SIGNAL_DIRECTION dir, const double lots,
                                      const double openPrice, const double tpPrice) const
   {
      if(lots <= 0.0 || openPrice <= 0.0 || tpPrice <= 0.0) return 0.0;
      double tpDist = MathAbs(tpPrice - openPrice);
      if(tpDist <= 0.0) return 0.0;
      ENUM_ORDER_TYPE ot = (dir == SIGNAL_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      double calc = 0.0;
      if(OrderCalcProfit(ot, m_profile.symbol, lots, openPrice, tpPrice, calc) &&
         MathIsValidNumber(calc) && MathAbs(calc) > 0.0)
         return MathAbs(calc);
      return GetProfitPerLotForPriceDistance(tpDist) * lots;
   }

   double EstimateExecutionCostMoney(const double lots, const double spreadPoints, const double estSlippagePoints) const
   {
      if(lots <= 0.0 || m_profile.point <= 0.0) return 0.0;
      double spreadPrice = (spreadPoints + estSlippagePoints) * m_profile.point;
      double spreadCost  = GetLossPerLotForPriceDistance(spreadPrice) * lots;
      double commCost    = m_profile.estCommissionPerLot * lots;
      return spreadCost + commCost;
   }

   bool EstimateMargin(const ENUM_ORDER_TYPE orderType, const double volume, const double price, double &outMargin) const
   {
      outMargin = 0.0;
      if(volume <= 0.0 || price <= 0.0) return false;
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
