//+------------------------------------------------------------------+
//|                                         PerformanceAnalytics.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        Magic-Isolated Account & Trade Analytics  |
//+------------------------------------------------------------------+
#ifndef __ASEA_ANALYTICS_PERFORMANCEANALYTICS_MQH__
#define __ASEA_ANALYTICS_PERFORMANCEANALYTICS_MQH__

#include "../Core/Types.mqh"
#include "../Strategies/StrategyBase.mqh"
#include "Statistics.mqh"

#define ASEA_CURVE_CAP 240

class CPerformanceAnalytics
{
private:
   long            m_magic;
   double          m_initialBalance;
   SAccountMetrics m_metrics;

   double          m_tradeReturns[];
   int             m_returnCount;
   ulong           m_processedDeals[];
   int             m_dealCount;

   double          m_equityCurve[ASEA_CURVE_CAP];
   double          m_balanceCurve[ASEA_CURVE_CAP];
   double          m_drawdownCurve[ASEA_CURVE_CAP];
   int             m_curveCount;
   datetime        m_lastCurveSampleTime;

   double          m_peakEquitySeen;
   double          m_totalHoldSec;

   SSegmentedBucket m_bySymbol[];
   int              m_bySymbolCount;
   SSegmentedBucket m_bySession[];
   int              m_bySessionCount;
   SSegmentedBucket m_byWeekday[];
   int              m_byWeekdayCount;

   bool IsDealAlreadyProcessed(const ulong dealTicket) const
   {
      for(int i = m_dealCount - 1; i >= 0; i--)
      {
         if(m_processedDeals[i] == dealTicket) return true;
      }
      return false;
   }

   void MarkDealProcessed(const ulong dealTicket)
   {
      if(m_dealCount >= ArraySize(m_processedDeals))
         ArrayResize(m_processedDeals, m_dealCount + 128);
      m_processedDeals[m_dealCount++] = dealTicket;
   }

   ENUM_STRATEGY_ID ParseStrategy(const string cmt) const
   {
      int idx = StringFind(cmt, "|S");
      if(idx >= 0)
      {
         int sid = (int)StringToInteger(StringSubstr(cmt, idx + 2, 1));
         if(sid >= 0 && sid < EA_MAX_STRATEGIES) return (ENUM_STRATEGY_ID)sid;
      }
      return STRAT_TREND_PULLBACK;
   }

public:
   CPerformanceAnalytics()
   {
      m_magic = 0;
      m_initialBalance = 0.0;
      m_metrics.Reset();
      m_returnCount = 0;
      m_dealCount = 0;
      m_curveCount = 0;
      m_lastCurveSampleTime = 0;
      m_peakEquitySeen = 0.0;
      m_totalHoldSec = 0.0;
      m_bySymbolCount = 0;
      m_bySessionCount = 0;
      m_byWeekdayCount = 0;
   }

   void Initialize(const long magic)
   {
      m_magic = magic;
      m_initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      m_metrics.Reset();
      m_metrics.balance = m_initialBalance;
      m_metrics.equity  = AccountInfoDouble(ACCOUNT_EQUITY);
      m_peakEquitySeen  = MathMax(m_metrics.balance, m_metrics.equity);
      m_returnCount = 0;
      m_dealCount = 0;
      m_curveCount = 0;
      m_lastCurveSampleTime = 0;
      m_totalHoldSec = 0.0;
      ArrayResize(m_tradeReturns, 0);
      ArrayResize(m_processedDeals, 0);
      ArrayInitialize(m_equityCurve, 0.0);
      ArrayInitialize(m_balanceCurve, 0.0);
      ArrayInitialize(m_drawdownCurve, 0.0);
      m_bySymbolCount = 0;
      m_bySessionCount = 0;
      m_byWeekdayCount = 0;
   }

   // Reconstruct historical closed trades belonging ONLY to this EA's magic number
   int SyncDealHistory(CStrategyBase *&strategies[], const int stratCount, const bool is24x7,
                       double &outNewClosedPnL, string &outLastClosedSymbol,
                       ENUM_STRATEGY_ID &outLastStrat, long &outLastHoldSec)
   {
      outNewClosedPnL = 0.0;
      outLastClosedSymbol = "";
      outLastStrat = STRAT_TREND_PULLBACK;
      outLastHoldSec = 0;

      if(!HistorySelect(0, TimeCurrent() + 60))
         return 0;

      int newClosed = 0;
      int totalDeals = HistoryDealsTotal();
      datetime now = TimeCurrent();
      MqlDateTime nowDt;
      TimeToStruct(now, nowDt);

      for(int i = 0; i < totalDeals; i++)
      {
         ulong dealTicket = HistoryDealGetTicket(i);
         if(dealTicket == 0) continue;
         if(IsDealAlreadyProcessed(dealTicket)) continue;

         // Strict EA magic isolation
         if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != m_magic)
            continue;

         long entryType = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         if(entryType != DEAL_ENTRY_OUT && entryType != DEAL_ENTRY_OUT_BY)
            continue;

         MarkDealProcessed(dealTicket);

         double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
         double swap   = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
         double comm   = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
         double fee    = HistoryDealGetDouble(dealTicket, DEAL_FEE);
         double netPnL = profit + swap + comm + fee;
         datetime closeTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
         string sym = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
         string cmt = HistoryDealGetString(dealTicket, DEAL_COMMENT);
         long posId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);

         // Find opening deal for holding duration & strategy attribution
         long holdSec = 0;
         string openCmt = cmt;
         for(int j = i - 1; j >= 0; j--)
         {
            ulong dOpen = HistoryDealGetTicket(j);
            if(HistoryDealGetInteger(dOpen, DEAL_POSITION_ID) == posId &&
               HistoryDealGetInteger(dOpen, DEAL_ENTRY) == DEAL_ENTRY_IN)
            {
               datetime openT = (datetime)HistoryDealGetInteger(dOpen, DEAL_TIME);
               holdSec = (long)MathMax(0L, (long)(closeTime - openT));
               if(openCmt == "") openCmt = HistoryDealGetString(dOpen, DEAL_COMMENT);
               break;
            }
         }

         ENUM_STRATEGY_ID sid = ParseStrategy(openCmt);
         if((int)sid >= 0 && (int)sid < stratCount && strategies[(int)sid] != NULL)
            strategies[(int)sid].RecordTradeOutcome(netPnL, holdSec, REGIME_UNKNOWN);

         // Update overall metrics
         m_metrics.totalTrades++;
         m_metrics.totalNetProfit += netPnL;
         m_totalHoldSec += (double)holdSec;
         m_metrics.avgHoldingSeconds = m_totalHoldSec / (double)m_metrics.totalTrades;

         if(netPnL >= 0.0)
         {
            m_metrics.winningTrades++;
            m_metrics.grossProfit += netPnL;
            if(netPnL > m_metrics.largestWin) m_metrics.largestWin = netPnL;
            m_metrics.currentConsecutiveWins++;
            m_metrics.currentConsecutiveLosses = 0;
            if(m_metrics.currentConsecutiveWins > m_metrics.maxConsecutiveWins)
               m_metrics.maxConsecutiveWins = m_metrics.currentConsecutiveWins;
         }
         else
         {
            m_metrics.losingTrades++;
            m_metrics.grossLoss += MathAbs(netPnL);
            if(netPnL < m_metrics.largestLoss) m_metrics.largestLoss = netPnL;
            m_metrics.currentConsecutiveLosses++;
            m_metrics.currentConsecutiveWins = 0;
            if(m_metrics.currentConsecutiveLosses > m_metrics.maxConsecutiveLosses)
               m_metrics.maxConsecutiveLosses = m_metrics.currentConsecutiveLosses;
         }

         // Period realized buckets
         MqlDateTime cDt;
         TimeToStruct(closeTime, cDt);
         if(cDt.year == nowDt.year && cDt.mon == nowDt.mon)
         {
            m_metrics.realizedMonthlyPnL += netPnL;
            if(cDt.day_of_year == nowDt.day_of_year)
               m_metrics.realizedDailyPnL += netPnL;
            if(MathAbs(nowDt.day_of_year - cDt.day_of_year) <= 6)
               m_metrics.realizedWeeklyPnL += netPnL;
         }

         // Return series for Sharpe/Sortino
         if(m_returnCount >= ArraySize(m_tradeReturns))
            ArrayResize(m_tradeReturns, m_returnCount + 64);
         double denom = MathMax(100.0, AccountInfoDouble(ACCOUNT_BALANCE));
         m_tradeReturns[m_returnCount++] = netPnL / denom;

         // Segmented buckets
         CStatisticsUtil::UpdateBucket(m_bySymbol, m_bySymbolCount, sym, netPnL);
         ENUM_TRADING_SESSION sess = CStatisticsUtil::ClassifySession(closeTime, is24x7);
         CStatisticsUtil::UpdateBucket(m_bySession, m_bySessionCount, EnumToString(sess), netPnL);
         CStatisticsUtil::UpdateBucket(m_byWeekday, m_byWeekdayCount, IntegerToString(cDt.day_of_week), netPnL);

         outNewClosedPnL += netPnL;
         outLastClosedSymbol = sym;
         outLastStrat = sid;
         outLastHoldSec = holdSec;
         newClosed++;
      }

      if(m_metrics.totalTrades > 0)
      {
         m_metrics.winRatePct    = ((double)m_metrics.winningTrades / (double)m_metrics.totalTrades) * 100.0;
         m_metrics.profitFactor  = (m_metrics.grossLoss > 0.0) ? (m_metrics.grossProfit / m_metrics.grossLoss) : ((m_metrics.grossProfit > 0.0) ? 9.99 : 0.0);
         m_metrics.expectedValue = m_metrics.totalNetProfit / (double)m_metrics.totalTrades;
         m_metrics.avgWin        = (m_metrics.winningTrades > 0) ? (m_metrics.grossProfit / (double)m_metrics.winningTrades) : 0.0;
         m_metrics.avgLoss       = (m_metrics.losingTrades  > 0) ? (m_metrics.grossLoss   / (double)m_metrics.losingTrades)  : 0.0;

         double sr = 0.0, so = 0.0;
         bool validRatios = CStatisticsUtil::ComputeSharpeAndSortino(m_tradeReturns, m_returnCount, sr, so);
         m_metrics.sharpeRatio  = sr;
         m_metrics.sortinoRatio = so;
         m_metrics.sharpeValid  = validRatios;
         m_metrics.sortinoValid = validRatios;
      }

      return newClosed;
   }

   void UpdateLiveAccountState(const SManagedPosition &managedPositions[], const int managedCount)
   {
      m_metrics.balance = AccountInfoDouble(ACCOUNT_BALANCE);
      m_metrics.equity  = AccountInfoDouble(ACCOUNT_EQUITY);

      double eaFloating = 0.0;
      for(int i = 0; i < managedCount; i++)
         eaFloating += managedPositions[i].floatingPnL;
      m_metrics.floatingPnL = eaFloating;

      if(m_metrics.equity > m_peakEquitySeen)
         m_peakEquitySeen = m_metrics.equity;

      double ddMoney = MathMax(0.0, m_peakEquitySeen - m_metrics.equity);
      double ddPct   = (m_peakEquitySeen > 0.0) ? (ddMoney / m_peakEquitySeen) * 100.0 : 0.0;
      if(ddMoney > m_metrics.maxDrawdownMoney) m_metrics.maxDrawdownMoney = ddMoney;
      if(ddPct   > m_metrics.maxDrawdownPct)   m_metrics.maxDrawdownPct   = ddPct;
      if(ddPct   > m_metrics.relativeDrawdownPct) m_metrics.relativeDrawdownPct = ddPct;

      if(m_initialBalance > m_metrics.equity)
      {
         double absDD = m_initialBalance - m_metrics.equity;
         if(absDD > m_metrics.absoluteDrawdownMoney) m_metrics.absoluteDrawdownMoney = absDD;
      }

      m_metrics.recoveryFactor = (m_metrics.maxDrawdownMoney > 0.0) ? (m_metrics.totalNetProfit / m_metrics.maxDrawdownMoney) : 0.0;

      // Sample curve at most once every 60 seconds
      datetime now = TimeCurrent();
      if(m_curveCount == 0 || (now - m_lastCurveSampleTime) >= 60)
      {
         m_lastCurveSampleTime = now;
         if(m_curveCount < ASEA_CURVE_CAP)
         {
            m_equityCurve[m_curveCount]   = m_metrics.equity;
            m_balanceCurve[m_curveCount]  = m_metrics.balance;
            m_drawdownCurve[m_curveCount] = ddPct;
            m_curveCount++;
         }
         else
         {
            for(int i = 1; i < ASEA_CURVE_CAP; i++)
            {
               m_equityCurve[i - 1]   = m_equityCurve[i];
               m_balanceCurve[i - 1]  = m_balanceCurve[i];
               m_drawdownCurve[i - 1] = m_drawdownCurve[i];
            }
            m_equityCurve[ASEA_CURVE_CAP - 1]   = m_metrics.equity;
            m_balanceCurve[ASEA_CURVE_CAP - 1]  = m_metrics.balance;
            m_drawdownCurve[ASEA_CURVE_CAP - 1] = ddPct;
         }
      }
   }

   SAccountMetrics GetMetrics() const { return m_metrics; }

   int GetCurveData(double &outEq[], double &outBal[], double &outDD[]) const
   {
      ArrayResize(outEq, m_curveCount);
      ArrayResize(outBal, m_curveCount);
      ArrayResize(outDD, m_curveCount);
      for(int i = 0; i < m_curveCount; i++)
      {
         outEq[i]  = m_equityCurve[i];
         outBal[i] = m_balanceCurve[i];
         outDD[i]  = m_drawdownCurve[i];
      }
      return m_curveCount;
   }
};

#endif // __ASEA_ANALYTICS_PERFORMANCEANALYTICS_MQH__
