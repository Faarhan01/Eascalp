//+------------------------------------------------------------------+
//|                                               RiskManagement.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        Independent Capital Preservation Engine   |
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
   double maxDailyLossPct;
   double maxWeeklyLossPct;
   double maxAccountDrawdownPct;
   int    maxConsecutiveLosses;
   int    maxOpenPositionsTotal;
   int    maxOpenPositionsPerSymbol;
   double maxAggregateLots;
   double maxSymbolLots;
   double minFreeMarginLevelPct;
   double minFreeMarginMoney;
   bool   emergencyStopAllNewEntries;

   void ResetDefaults()
   {
      riskPerTradePct = 0.50;
      maxRiskPerTradePct = 1.00;
      maxDailyLossPct = 2.00;
      maxWeeklyLossPct = 5.00;
      maxAccountDrawdownPct = 10.00;
      maxConsecutiveLosses = 5;
      maxOpenPositionsTotal = 3;
      maxOpenPositionsPerSymbol = 2;
      maxAggregateLots = 5.0;
      maxSymbolLots = 2.0;
      minFreeMarginLevelPct = 200.0;
      minFreeMarginMoney = 100.0;
      emergencyStopAllNewEntries = false;
   }
};

class CRiskManagement
{
private:
   SRiskConfig   m_cfg;
   long          m_magic;
   CDiagnostics *m_diag;
   SRiskStatus   m_status;

   datetime      m_dayAnchor;
   datetime      m_weekAnchor;
   double        m_dayStartBalance;
   double        m_weekStartBalance;
   double        m_peakBalance;
   double        m_peakEquity;

   datetime GetDayStart(const datetime t) const
   {
      MqlDateTime dt;
      TimeToStruct(t, dt);
      dt.hour = 0; dt.min = 0; dt.sec = 0;
      return StructToTime(dt);
   }

   datetime GetWeekStart(const datetime t) const
   {
      MqlDateTime dt;
      TimeToStruct(t, dt);
      dt.hour = 0; dt.min = 0; dt.sec = 0;
      datetime day0 = StructToTime(dt);
      int daysSinceMon = (dt.day_of_week == 0) ? 6 : (dt.day_of_week - 1);
      return day0 - (datetime)(daysSinceMon * 86400);
   }

public:
   CRiskManagement()
   {
      m_cfg.ResetDefaults();
      m_magic = 0;
      m_diag = NULL;
      m_status.Reset();
      m_dayAnchor = 0;
      m_weekAnchor = 0;
      m_dayStartBalance = 0.0;
      m_weekStartBalance = 0.0;
      m_peakBalance = 0.0;
      m_peakEquity = 0.0;
   }

   void Initialize(const long magic, const SRiskConfig &cfg, CDiagnostics *diag)
   {
      m_magic = magic;
      m_cfg = cfg;
      m_diag = diag;
      m_status.Reset();

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
      double marginLvl  = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);

      if(curDay != m_dayAnchor)
      {
         m_dayAnchor = curDay;
         m_dayStartBalance = bal;
         // Daily lockout clears automatically on new trading day unless account DD / emergency lockout remains
         if(m_status.lockoutActive && StringFind(m_status.lockoutReason, "Daily") >= 0)
         {
            m_status.lockoutActive = false;
            m_status.lockoutReason = "";
         }
      }
      if(curWeek != m_weekAnchor)
      {
         m_weekAnchor = curWeek;
         m_weekStartBalance = bal;
         if(m_status.lockoutActive && StringFind(m_status.lockoutReason, "Weekly") >= 0)
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

      // Aggregate EA exposure (strictly filtered to EA's own positions)
      double totalLots = 0.0, symLots = 0.0, openRiskMoney = 0.0;
      int totalPos = 0, symPos = 0;

      for(int i = 0; i < managedCount; i++)
      {
         totalPos++;
         totalLots += managedPositions[i].volume;
         openRiskMoney += MathMax(0.0, managedPositions[i].currentRiskMoney);
         if(managedPositions[i].symbol == activeSymbol)
         {
            symPos++;
            symLots += managedPositions[i].volume;
         }
      }

      m_status.openPositionsCount    = totalPos;
      m_status.symbolPositionsCount  = symPos;
      m_status.totalOpenExposureLots = totalLots;
      m_status.currentOpenRiskMoney  = openRiskMoney;
      m_status.currentOpenRiskPct    = (bal > 0.0) ? (openRiskMoney / bal) * 100.0 : 0.0;
      m_status.freeMargin            = freeMargin;
      m_status.marginLevelPct        = marginLvl;

      // Evaluate fail-safe lockouts
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

      double lossPerLot = symIntel.GetLossPerLotForPriceDistance(slDist);
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

      double riskMoney = basisCapital * (effRiskPct / 100.0);
      double rawLots = riskMoney / lossPerLot;

      // Enforce per-symbol and aggregate lot caps
      double remainingTotalLots  = MathMax(0.0, m_cfg.maxAggregateLots - m_status.totalOpenExposureLots);
      double remainingSymbolLots = MathMax(0.0, m_cfg.maxSymbolLots - m_status.totalOpenExposureLots);
      rawLots = MathMin(rawLots, MathMin(remainingTotalLots, remainingSymbolLots));

      double normLots = symIntel.NormalizeVolume(rawLots);
      if(normLots < prof.volumeMin)
      {
         outReason = StringFormat("Risk-adjusted volume %.4f below minimum lot %.4f (fail-safe reject)", rawLots, prof.volumeMin);
         return 0.0;
      }

      // Verify actual normalized risk does not breach maxRiskPerTradePct
      double actualRiskPct = ((normLots * lossPerLot) / basisCapital) * 100.0;
      if(actualRiskPct > m_cfg.maxRiskPerTradePct * 1.10)
      {
         outReason = StringFormat("Normalized min lot risk %.2f%% exceeds max risk cap %.2f%%", actualRiskPct, m_cfg.maxRiskPerTradePct);
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
