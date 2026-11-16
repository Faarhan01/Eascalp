//+------------------------------------------------------------------+
//|                                               RiskManagement.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.0.0 Portfolio & Currency Risk Engine   |
//+------------------------------------------------------------------+
#ifndef __ASEA_TRADING_RISKMANAGEMENT_MQH__
#define __ASEA_TRADING_RISKMANAGEMENT_MQH__

#include "../Core/Types.mqh"
#include "../Core/Diagnostics.mqh"
#include "../Market/SymbolIntelligence.mqh"

struct SRiskConfig
{
   double riskPerTradePct;
   double maxRiskPerTradePct;
   double maxPortfolioOpenRiskPct;
   double maxDailyLossPct;
   double maxWeeklyLossPct;
   double maxAccountDrawdownPct;
   int    maxConsecutiveLosses;
   int    maxOpenPositionsTotal;
   int    maxOpenPositionsPerSymbol;
   double maxAggregateLots;
   double maxSymbolLots;
   double maxCurrencyExposureLots;
   double minFreeMarginLevelPct;
   double minFreeMarginMoney;
   bool   allowMinLotFallback;
   double maxMinLotRiskPct;
   bool   emergencyStopAllNewEntries;

   void ResetDefaults()
   {
      riskPerTradePct = 1.00;
      maxRiskPerTradePct = 2.00;
      maxPortfolioOpenRiskPct = 5.00;
      maxDailyLossPct = 2.50;
      maxWeeklyLossPct = 6.00;
      maxAccountDrawdownPct = 10.00;
      maxConsecutiveLosses = 5;
      maxOpenPositionsTotal = 4;
      maxOpenPositionsPerSymbol = 2;
      maxAggregateLots = 5.0;
      maxSymbolLots = 2.0;
      maxCurrencyExposureLots = 2.5;
      minFreeMarginLevelPct = 150.0;
      minFreeMarginMoney = 5.0;
      allowMinLotFallback = true;
      maxMinLotRiskPct = 3.00;
      emergencyStopAllNewEntries = false;
   }
};

class CRiskManagement
{
private:
   SRiskConfig       m_cfg;
   long              m_magic;
   CDiagnostics     *m_diag;
   SRiskStatus       m_status;
   SCurrencyExposure m_currencyExp[16];
   int               m_currencyExpCount;
   double            m_activeSymbolLots;

   datetime          m_dayAnchor;
   datetime          m_weekAnchor;
   double            m_dayStartBalance;
   double            m_weekStartBalance;
   double            m_peakBalance;
   double            m_peakEquity;

   datetime GetDayStart(const datetime t) const
   {
      if(t <= 0) return 0;
      MqlDateTime dt;
      TimeToStruct(t, dt);
      dt.hour = 0; dt.min = 0; dt.sec = 0;
      return StructToTime(dt);
   }

   datetime GetWeekStart(const datetime t) const
   {
      if(t <= 0) return 0;
      MqlDateTime dt;
      TimeToStruct(t, dt);
      dt.hour = 0; dt.min = 0; dt.sec = 0;
      datetime day0 = StructToTime(dt);
      int daysSinceMon = (dt.day_of_week == 0) ? 6 : (dt.day_of_week - 1);
      return day0 - (datetime)(daysSinceMon * 86400);
   }

   void AddCurrencyExposure(const string ccy, const double signedLots, const double riskMoney)
   {
      if(ccy == "" || StringLen(ccy) < 3) return;
      for(int i = 0; i < m_currencyExpCount; i++)
      {
         if(m_currencyExp[i].currency == ccy)
         {
            m_currencyExp[i].netLots   += signedLots;
            m_currencyExp[i].riskMoney += riskMoney;
            return;
         }
      }
      if(m_currencyExpCount < 16)
      {
         m_currencyExp[m_currencyExpCount].currency  = ccy;
         m_currencyExp[m_currencyExpCount].netLots   = signedLots;
         m_currencyExp[m_currencyExpCount].riskMoney = riskMoney;
         m_currencyExpCount++;
      }
   }

   void TrackPositionCurrencies(const SManagedPosition &pos)
   {
      string base = SymbolInfoString(pos.symbol, SYMBOL_CURRENCY_BASE);
      string prof = SymbolInfoString(pos.symbol, SYMBOL_CURRENCY_PROFIT);
      if(StringLen(base) == 3 && StringLen(prof) == 3 && base != prof)
      {
         double sign = (pos.direction == SIGNAL_BUY) ? 1.0 : -1.0;
         AddCurrencyExposure(base,  sign * pos.volume, pos.currentRiskMoney);
         AddCurrencyExposure(prof, -sign * pos.volume, pos.currentRiskMoney);
      }
   }

public:
   CRiskManagement()
   {
      m_cfg.ResetDefaults();
      m_magic = 0;
      m_diag = NULL;
      m_status.Reset();
      m_currencyExpCount = 0;
      m_activeSymbolLots = 0.0;
      m_dayAnchor = 0; m_weekAnchor = 0;
      m_dayStartBalance = 0.0; m_weekStartBalance = 0.0;
      m_peakBalance = 0.0; m_peakEquity = 0.0;
   }

   void Initialize(const long magic, const SRiskConfig &cfg, CDiagnostics *diag)
   {
      m_magic = magic;
      m_cfg = cfg;
      m_diag = diag;
      m_status.Reset();
      m_currencyExpCount = 0;
      m_activeSymbolLots = 0.0;

      double bal = AccountInfoDouble(ACCOUNT_BALANCE);
      double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
      datetime now = TimeCurrent();
      m_dayAnchor  = GetDayStart(now);
      m_weekAnchor = GetWeekStart(now);
      m_dayStartBalance  = bal;
      m_weekStartBalance = bal;
      m_peakBalance = bal;
      m_peakEquity  = MathMax(bal, eq);
      m_status.maxConsecutiveLosses = 0;
   }

   void RestoreAnchors(const datetime dayAnchor, const datetime weekAnchor, const double dayBal,
                       const double weekBal, const double peakBal, const double peakEq,
                       const double maxDDPct, const int consecLoss, const int maxConsecLoss,
                       const bool lockout, const string lockoutReason)
   {
      if(dayAnchor > 0) m_dayAnchor = dayAnchor;
      if(weekAnchor > 0) m_weekAnchor = weekAnchor;
      if(dayBal > 0.0) m_dayStartBalance = dayBal;
      if(weekBal > 0.0) m_weekStartBalance = weekBal;
      if(peakBal > 0.0) m_peakBalance = peakBal;
      if(peakEq > 0.0) m_peakEquity = peakEq;
      m_status.maxHistoricalDrawdownPct = maxDDPct;
      m_status.consecutiveLosses = consecLoss;
      m_status.maxConsecutiveLosses = maxConsecLoss;
      m_status.lockoutActive = lockout;
      m_status.lockoutReason = lockoutReason;
   }

   void RecordClosedTradePnL(const double netPnL)
   {
      if(netPnL < 0.0)
      {
         m_status.consecutiveLosses++;
         if(m_status.consecutiveLosses > m_status.maxConsecutiveLosses)
            m_status.maxConsecutiveLosses = m_status.consecutiveLosses;
      }
      else if(netPnL > 0.0)
      {
         m_status.consecutiveLosses = 0;
      }
   }

   void Update(const string activeSymbol, const SManagedPosition &managedPositions[], const int managedCount)
   {
      datetime now = TimeCurrent();
      datetime curDay = GetDayStart(now);
      datetime curWeek = GetWeekStart(now);

      double bal = AccountInfoDouble(ACCOUNT_BALANCE);
      double eq  = AccountInfoDouble(ACCOUNT_EQUITY);
      double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      double usedMargin = AccountInfoDouble(ACCOUNT_MARGIN);
      double marginLvl  = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);

      if(curDay > 0 && curDay != m_dayAnchor)
      {
         bool firstInit = (m_dayAnchor == 0);
         m_dayAnchor = curDay;
         if(!firstInit || m_dayStartBalance <= 0.0)
            m_dayStartBalance = bal;
         if(!firstInit && m_status.lockoutActive)
         {
            if(StringFind(m_status.lockoutReason, "Daily") >= 0)
            {
               m_status.lockoutActive = false;
               m_status.lockoutReason = "";
            }
            else if(StringFind(m_status.lockoutReason, "consecutive") >= 0)
            {
               m_status.lockoutActive = false;
               m_status.lockoutReason = "";
               m_status.consecutiveLosses = MathMax(0, m_cfg.maxConsecutiveLosses - 2);
            }
         }
      }
      if(curWeek > 0 && curWeek != m_weekAnchor)
      {
         bool firstInitW = (m_weekAnchor == 0);
         m_weekAnchor = curWeek;
         if(!firstInitW || m_weekStartBalance <= 0.0)
            m_weekStartBalance = bal;
         if(!firstInitW && m_status.lockoutActive && StringFind(m_status.lockoutReason, "Weekly") >= 0)
         {
            m_status.lockoutActive = false;
            m_status.lockoutReason = "";
         }
      }

      if(bal > m_peakBalance) m_peakBalance = bal;
      if(eq  > m_peakEquity)  m_peakEquity  = eq;

      m_status.dailyPnL  = eq - m_dayStartBalance;
      m_status.weeklyPnL = eq - m_weekStartBalance;
      m_status.dailyLossLimitMoney  = m_dayStartBalance * (m_cfg.maxDailyLossPct / 100.0);
      m_status.weeklyLossLimitMoney = m_weekStartBalance * (m_cfg.maxWeeklyLossPct / 100.0);

      m_status.dailyLossUsedPct  = (m_status.dailyLossLimitMoney > 0.0 && m_status.dailyPnL < 0.0) ? MathMin(100.0, (-m_status.dailyPnL / m_status.dailyLossLimitMoney) * 100.0) : 0.0;
      m_status.weeklyLossUsedPct = (m_status.weeklyLossLimitMoney > 0.0 && m_status.weeklyPnL < 0.0) ? MathMin(100.0, (-m_status.weeklyPnL / m_status.weeklyLossLimitMoney) * 100.0) : 0.0;

      m_status.balanceDrawdownPct = (m_peakBalance > 0.0) ? MathMax(0.0, ((m_peakBalance - bal) / m_peakBalance) * 100.0) : 0.0;
      m_status.equityDrawdownPct  = (m_peakEquity  > 0.0) ? MathMax(0.0, ((m_peakEquity  - eq)  / m_peakEquity)  * 100.0) : 0.0;
      double curMaxDD = MathMax(m_status.balanceDrawdownPct, m_status.equityDrawdownPct);
      if(curMaxDD > m_status.maxHistoricalDrawdownPct)
         m_status.maxHistoricalDrawdownPct = curMaxDD;

      double totalLots = 0.0, symLots = 0.0, openRiskMoney = 0.0;
      int totalPos = 0, symPos = 0;
      m_currencyExpCount = 0;

      for(int i = 0; i < managedCount; i++)
      {
         totalPos++;
         totalLots += managedPositions[i].volume;
         openRiskMoney += MathMax(0.0, managedPositions[i].currentRiskMoney);
         TrackPositionCurrencies(managedPositions[i]);
         if(managedPositions[i].symbol == activeSymbol)
         {
            symPos++;
            symLots += managedPositions[i].volume;
         }
      }
      m_activeSymbolLots = symLots;

      double maxCcyLots = 0.0;
      string topCcy = "NONE";
      for(int i = 0; i < m_currencyExpCount; i++)
      {
         double absLots = MathAbs(m_currencyExp[i].netLots);
         if(absLots > maxCcyLots)
         {
            maxCcyLots = absLots;
            topCcy = m_currencyExp[i].currency;
         }
      }

      m_status.openPositionsCount      = totalPos;
      m_status.symbolPositionsCount    = symPos;
      m_status.totalOpenExposureLots   = totalLots;
      m_status.maxCurrencyExposureLots = maxCcyLots;
      m_status.topExposedCurrency      = topCcy;
      m_status.currentOpenRiskMoney    = openRiskMoney;
      m_status.currentOpenRiskPct      = (bal > 0.0) ? (openRiskMoney / bal) * 100.0 : 0.0;
      m_status.freeMargin              = freeMargin;
      m_status.marginLevelPct          = marginLvl;
      m_status.marginUtilizationPct    = (eq > 0.0) ? (usedMargin / eq) * 100.0 : 0.0;

      if(m_status.lockoutActive && !m_cfg.emergencyStopAllNewEntries && StringFind(m_status.lockoutReason, "Emergency") >= 0)
      {
         m_status.lockoutActive = false;
         m_status.lockoutReason = "";
      }

      m_status.tradingAllowed = true;
      if(m_cfg.emergencyStopAllNewEntries)
      {
         m_status.lockoutActive = true;
         m_status.lockoutReason = "Emergency input lockout enabled";
      }
      else if(m_status.equityDrawdownPct >= m_cfg.maxAccountDrawdownPct)
      {
         m_status.lockoutActive = true;
         m_status.lockoutReason = StringFormat("Max account drawdown reached (%.2f%% >= %.2f%%)", m_status.equityDrawdownPct, m_cfg.maxAccountDrawdownPct);
      }
      else if(m_status.dailyLossLimitMoney > 0.0 && (-m_status.dailyPnL) >= m_status.dailyLossLimitMoney)
      {
         m_status.lockoutActive = true;
         m_status.lockoutReason = StringFormat("Daily loss limit reached (%.2f)", m_status.dailyPnL);
      }
      else if(m_status.weeklyLossLimitMoney > 0.0 && (-m_status.weeklyPnL) >= m_status.weeklyLossLimitMoney)
      {
         m_status.lockoutActive = true;
         m_status.lockoutReason = StringFormat("Weekly loss limit reached (%.2f)", m_status.weeklyPnL);
      }
      else if(m_status.consecutiveLosses >= m_cfg.maxConsecutiveLosses)
      {
         m_status.lockoutActive = true;
         m_status.lockoutReason = StringFormat("Max consecutive losses reached (%d)", m_status.consecutiveLosses);
      }
      else if(m_status.currentOpenRiskPct >= m_cfg.maxPortfolioOpenRiskPct)
      {
         m_status.tradingAllowed = false;
         m_status.lockoutReason = StringFormat("Portfolio open risk cap reached (%.2f%% >= %.2f%%)", m_status.currentOpenRiskPct, m_cfg.maxPortfolioOpenRiskPct);
      }
      else if(totalPos >= m_cfg.maxOpenPositionsTotal)
      {
         m_status.tradingAllowed = false;
         m_status.lockoutReason = StringFormat("Max total positions reached (%d/%d)", totalPos, m_cfg.maxOpenPositionsTotal);
      }
      else if(symPos >= m_cfg.maxOpenPositionsPerSymbol)
      {
         m_status.tradingAllowed = false;
         m_status.lockoutReason = StringFormat("Max symbol positions reached (%d/%d)", symPos, m_cfg.maxOpenPositionsPerSymbol);
      }
      else if(freeMargin < m_cfg.minFreeMarginMoney || (marginLvl > 0.0 && marginLvl < m_cfg.minFreeMarginLevelPct))
      {
         m_status.tradingAllowed = false;
         m_status.lockoutReason = StringFormat("Margin safety threshold triggered (Free=%.2f, Level=%.1f%%)", freeMargin, marginLvl);
      }

      if(m_status.lockoutActive)
      {
         m_status.tradingAllowed = false;
         m_status.statusLabel = "LOCKED: " + m_status.lockoutReason;
      }
      else if(!m_status.tradingAllowed)
      {
         m_status.statusLabel = "CAPPED: " + m_status.lockoutReason;
      }
      else
      {
         m_status.statusLabel = "NOMINAL";
      }
   }

   double GetCurrencyNetLots(const string ccy) const
   {
      for(int i = 0; i < m_currencyExpCount; i++)
      {
         if(m_currencyExp[i].currency == ccy)
            return m_currencyExp[i].netLots;
      }
      return 0.0;
   }

   double CalculateFixedFractionalVolume(const STradeSignal &sig, const CSymbolIntelligence &symIntel, string &outReason) const
   {
      outReason = "";
      if(m_status.lockoutActive || !m_status.tradingAllowed)
      {
         outReason = m_status.lockoutReason;
         return 0.0;
      }

      SSymbolProfile prof = symIntel.GetProfile();
      if(!prof.isValid)
      {
         outReason = "Invalid symbol specifications";
         return 0.0;
      }

      double slDist = MathAbs(sig.entryPrice - sig.stopLoss);
      if(slDist <= 0.0)
      {
         outReason = "Zero stop-loss distance";
         return 0.0;
      }

      double lossPerLot = symIntel.EstimateRiskMoneyForOrder(sig.direction, 1.0, sig.entryPrice, sig.stopLoss);
      if(lossPerLot <= 0.0 || !MathIsValidNumber(lossPerLot))
      {
         outReason = "Unable to compute tick loss per lot reliably";
         return 0.0;
      }

      double effRiskPct = MathMin(m_cfg.riskPerTradePct, m_cfg.maxRiskPerTradePct);
      double basisCapital = MathMin(AccountInfoDouble(ACCOUNT_BALANCE), AccountInfoDouble(ACCOUNT_EQUITY));
      if(basisCapital <= 0.0)
      {
         outReason = "Non-positive account equity/balance";
         return 0.0;
      }

      // Anti-Martingale drawdown & losing-streak risk scaling to contain drawdown
      double ddScale = 1.0;
      if(m_status.equityDrawdownPct >= 6.5)      ddScale = 0.35;
      else if(m_status.equityDrawdownPct >= 4.0) ddScale = 0.55;
      else if(m_status.equityDrawdownPct >= 2.0) ddScale = 0.75;

      double streakScale = 1.0;
      if(m_status.consecutiveLosses >= 4)      streakScale = 0.40;
      else if(m_status.consecutiveLosses == 3) streakScale = 0.55;
      else if(m_status.consecutiveLosses == 2) streakScale = 0.75;

      effRiskPct *= MathMin(ddScale, streakScale);

      // Cap individual trade risk by remaining portfolio open risk headroom
      double remainingPortRiskPct = MathMax(0.0, m_cfg.maxPortfolioOpenRiskPct - m_status.currentOpenRiskPct);
      effRiskPct = MathMin(effRiskPct, remainingPortRiskPct);
      if(effRiskPct <= 0.005)
      {
         outReason = "Portfolio open risk headroom exhausted";
         return 0.0;
      }

      double riskMoney = basisCapital * (effRiskPct / 100.0);
      double rawLots = riskMoney / lossPerLot;

      double remainingTotalLots  = MathMax(0.0, m_cfg.maxAggregateLots - m_status.totalOpenExposureLots);
      double remainingSymbolLots = MathMax(0.0, m_cfg.maxSymbolLots - m_activeSymbolLots);
      double maxAllowedByCaps = MathMin(remainingTotalLots, remainingSymbolLots);

      // Enforce shared currency exposure ceiling for Forex pairs
      if(StringLen(prof.currencyBase) == 3 && StringLen(prof.currencyProfit) == 3 && prof.currencyBase != prof.currencyProfit)
      {
         double sign = (sig.direction == SIGNAL_BUY) ? 1.0 : -1.0;
         double curBase = GetCurrencyNetLots(prof.currencyBase);
         double curProf = GetCurrencyNetLots(prof.currencyProfit);
         double baseCap = (sign * curBase > 0.0) ? MathMax(0.0, m_cfg.maxCurrencyExposureLots - MathAbs(curBase)) : m_cfg.maxCurrencyExposureLots;
         double profCap = (-sign * curProf > 0.0) ? MathMax(0.0, m_cfg.maxCurrencyExposureLots - MathAbs(curProf)) : m_cfg.maxCurrencyExposureLots;
         maxAllowedByCaps = MathMin(maxAllowedByCaps, MathMin(baseCap, profCap));
      }

      // Margin-safe proportional clamping so high-leverage/margin instruments step down safely instead of failing at order send
      double probeLots = MathMax(rawLots, prof.volumeMin);
      double estReqMargin = 0.0;
      ENUM_ORDER_TYPE mType = (sig.direction == SIGNAL_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      if(symIntel.EstimateMargin(mType, probeLots, sig.entryPrice, estReqMargin) && estReqMargin > 0.0)
      {
         double safeMarginBudget = m_status.freeMargin * 0.72;
         if(safeMarginBudget > 0.0)
         {
            double maxMarginLots = probeLots * (safeMarginBudget / estReqMargin);
            rawLots = MathMin(rawLots, maxMarginLots);
            maxAllowedByCaps = MathMin(maxAllowedByCaps, maxMarginLots);
         }
      }

      rawLots = MathMin(rawLots, maxAllowedByCaps);
      double normLots = symIntel.NormalizeVolume(rawLots);

      // Safe minimum-lot fallback for smaller balances when exposure caps still permit volumeMin
      double allowedRiskCeiling = m_cfg.maxRiskPerTradePct * 1.15;
      if(normLots < prof.volumeMin && m_cfg.allowMinLotFallback && maxAllowedByCaps >= prof.volumeMin)
      {
         double minLotRiskPct = ((prof.volumeMin * lossPerLot) / basisCapital) * 100.0;
         if(minLotRiskPct <= m_cfg.maxMinLotRiskPct &&
            (m_status.currentOpenRiskPct + minLotRiskPct) <= (m_cfg.maxPortfolioOpenRiskPct + m_cfg.maxMinLotRiskPct))
         {
            normLots = prof.volumeMin;
            allowedRiskCeiling = m_cfg.maxMinLotRiskPct;
         }
      }

      if(normLots < prof.volumeMin)
      {
         outReason = StringFormat("Risk/exposure-capped volume %.4f below minimum lot %.4f", rawLots, prof.volumeMin);
         return 0.0;
      }

      double actualRiskPct = ((normLots * lossPerLot) / basisCapital) * 100.0;
      if(actualRiskPct > allowedRiskCeiling)
      {
         outReason = StringFormat("Normalized min lot risk %.2f%% exceeds max risk cap %.2f%%", actualRiskPct, allowedRiskCeiling);
         return 0.0;
      }

      return normLots;
   }

   SRiskStatus GetStatus() const      { return m_status; }
   datetime    GetDayAnchor() const   { return m_dayAnchor; }
   datetime    GetWeekAnchor() const  { return m_weekAnchor; }
   double      GetDayStartBal() const { return m_dayStartBalance; }
   double      GetWeekStartBal() const{ return m_weekStartBalance; }
   double      GetPeakBalance() const { return m_peakBalance; }
   double      GetPeakEquity() const  { return m_peakEquity; }
};

#endif // __ASEA_TRADING_RISKMANAGEMENT_MQH__
