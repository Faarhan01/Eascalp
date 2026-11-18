//+------------------------------------------------------------------+
//|                                         PerformanceAnalytics.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.9.0 Magic-Isolated MFE/MAE & Buckets   |
//+------------------------------------------------------------------+
#ifndef __ASEA_ANALYTICS_PERFORMANCEANALYTICS_MQH__
#define __ASEA_ANALYTICS_PERFORMANCEANALYTICS_MQH__

#include "../Core/Types.mqh"
#include "../Strategies/StrategyBase.mqh"
#include "../Trading/PositionManagement.mqh"
#include "Statistics.mqh"

#define ASEA_CURVE_CAP 240

struct SClosedDealEvent
{
   ulong              dealTicket;
   ulong              positionTicket;
   string             symbol;
   string             signalId;
   ENUM_STRATEGY_ID   strategyId;
   ENUM_SIGNAL_DIRECTION direction;
   double             volume;
   double             closePrice;
   double             netPnL;
   double             commission;
   double             swap;
   double             mfeMoney;
   double             maeMoney;
   double             score;
   ENUM_MARKET_REGIME entryRegime;
   long               holdSec;
   datetime           closeTime;
   string             exitReason;
   bool               isPartialClose;
};

struct SPendingPosPnL
{
   long   posId;
   double accumNetPnL;
};

struct SPosEntryAccum
{
   long     posId;
   datetime earliestOpenTime;
   string   openComment;
   double   totalOpenVol;
   double   totalOpenComm;
   double   totalOpenFee;
};

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
   int             m_lastHistoryTotal;
   int             m_lastScannedDealIdx;

   double          m_equityCurve[ASEA_CURVE_CAP];
   double          m_balanceCurve[ASEA_CURVE_CAP];
   double          m_drawdownCurve[ASEA_CURVE_CAP];
   int             m_curveCount;
   datetime        m_lastCurveSampleTime;

   double          m_peakEquitySeen;
   double          m_totalHoldSec;
   double          m_totalMfeMoney;
   double          m_totalMaeMoney;

   int             m_lastDayKey;
   datetime        m_lastWeekAnchor;
   int             m_lastMonthKey;

   // Score bands: 0=(<60), 1=(60-74), 2=(75+)
   double          m_scoreBandNet[3];
   int             m_scoreBandTrades[3];
   // Regime PnL buckets
   double          m_regimeNet[EA_MAX_REGIMES + 1];
   int             m_regimeTrades[EA_MAX_REGIMES + 1];

   SSegmentedBucket m_bySymbol[];
   int              m_bySymbolCount;
   SSegmentedBucket m_bySession[];
   int              m_bySessionCount;
   SSegmentedBucket m_byWeekday[];
   int              m_byWeekdayCount;
   SSegmentedBucket m_byHour[];
   int              m_byHourCount;
   SSegmentedBucket m_byMonth[];
   int              m_byMonthCount;

   SPendingPosPnL   m_partialPos[];
   int              m_partialPosCount;
   SPosEntryAccum   m_entryLedger[];
   int              m_entryLedgerCount;

   bool IsSymbol24x7(const string sym, const bool fallback24x7) const
   {
      if(sym == "") return fallback24x7;
      datetime ft = 0, tt = 0;
      bool sun = SymbolInfoSessionTrade(sym, SUNDAY, 0, ft, tt);
      bool sat = SymbolInfoSessionTrade(sym, SATURDAY, 0, ft, tt);
      if(sun && sat) return true;
      string u = sym;
      StringToUpper(u);
      if(StringFind(u, "STEP") >= 0 || StringFind(u, "VOLATILITY") >= 0 ||
         StringFind(u, "CRASH") >= 0 || StringFind(u, "BOOM") >= 0 ||
         StringFind(u, "BTC") >= 0 || StringFind(u, "ETH") >= 0 || StringFind(u, "SOL") >= 0)
         return true;
      return fallback24x7;
   }

   void AddPartialPosPnL(const long posId, const double netPnL)
   {
      if(posId <= 0) return;
      for(int i = 0; i < m_partialPosCount; i++)
      {
         if(m_partialPos[i].posId == posId)
         {
            m_partialPos[i].accumNetPnL += netPnL;
            return;
         }
      }
      if(m_partialPosCount >= ArraySize(m_partialPos))
         ArrayResize(m_partialPos, m_partialPosCount + 32);
      m_partialPos[m_partialPosCount].posId = posId;
      m_partialPos[m_partialPosCount].accumNetPnL = netPnL;
      m_partialPosCount++;
   }

   double PopPartialPosPnL(const long posId)
   {
      if(posId <= 0) return 0.0;
      for(int i = 0; i < m_partialPosCount; i++)
      {
         if(m_partialPos[i].posId == posId)
         {
            double val = m_partialPos[i].accumNetPnL;
            m_partialPos[i] = m_partialPos[m_partialPosCount - 1];
            m_partialPosCount--;
            return val;
         }
      }
      return 0.0;
   }

   void UpsertEntryLedger(const long posId, const datetime openT, const string openCmt,
                          const double oVol, const double oComm, const double oFee)
   {
      if(posId <= 0) return;
      for(int i = 0; i < m_entryLedgerCount; i++)
      {
         if(m_entryLedger[i].posId == posId)
         {
            if(openT > 0 && (m_entryLedger[i].earliestOpenTime == 0 || openT < m_entryLedger[i].earliestOpenTime))
               m_entryLedger[i].earliestOpenTime = openT;
            if(m_entryLedger[i].openComment == "" && openCmt != "")
               m_entryLedger[i].openComment = openCmt;
            if(oVol > 0.0) m_entryLedger[i].totalOpenVol += oVol;
            m_entryLedger[i].totalOpenComm += oComm;
            m_entryLedger[i].totalOpenFee  += oFee;
            return;
         }
      }
      if(m_entryLedgerCount >= ArraySize(m_entryLedger))
         ArrayResize(m_entryLedger, m_entryLedgerCount + 32);
      m_entryLedger[m_entryLedgerCount].posId            = posId;
      m_entryLedger[m_entryLedgerCount].earliestOpenTime = openT;
      m_entryLedger[m_entryLedgerCount].openComment      = openCmt;
      m_entryLedger[m_entryLedgerCount].totalOpenVol     = (oVol > 0.0) ? oVol : 0.0;
      m_entryLedger[m_entryLedgerCount].totalOpenComm    = oComm;
      m_entryLedger[m_entryLedgerCount].totalOpenFee     = oFee;
      m_entryLedgerCount++;
   }

   bool ReadEntryLedger(const long posId, const bool removeEntry, datetime &outEarliestT,
                        string &outOpenCmt, double &outOpenVol, double &outOpenComm, double &outOpenFee)
   {
      if(posId <= 0) return false;
      for(int i = 0; i < m_entryLedgerCount; i++)
      {
         if(m_entryLedger[i].posId == posId)
         {
            outEarliestT = m_entryLedger[i].earliestOpenTime;
            outOpenCmt   = m_entryLedger[i].openComment;
            outOpenVol   = m_entryLedger[i].totalOpenVol;
            outOpenComm  = m_entryLedger[i].totalOpenComm;
            outOpenFee   = m_entryLedger[i].totalOpenFee;
            if(removeEntry)
            {
               m_entryLedger[i] = m_entryLedger[m_entryLedgerCount - 1];
               m_entryLedgerCount--;
            }
            return true;
         }
      }
      return false;
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

   void RolloverPeriodMetrics(const datetime refTime)
   {
      if(refTime <= 0) return;
      MqlDateTime dt;
      TimeToStruct(refTime, dt);
      int dayKey   = dt.year * 1000 + dt.day_of_year;
      int monthKey = dt.year * 100 + dt.mon;
      datetime wk  = GetWeekStart(refTime);

      if(m_lastDayKey == 0) m_lastDayKey = dayKey;
      else if(dayKey != m_lastDayKey)
      {
         m_metrics.realizedDailyPnL = 0.0;
         m_lastDayKey = dayKey;
      }

      if(m_lastWeekAnchor == 0) m_lastWeekAnchor = wk;
      else if(wk != m_lastWeekAnchor)
      {
         m_metrics.realizedWeeklyPnL = 0.0;
         m_lastWeekAnchor = wk;
      }

      if(m_lastMonthKey == 0) m_lastMonthKey = monthKey;
      else if(monthKey != m_lastMonthKey)
      {
         m_metrics.realizedMonthlyPnL = 0.0;
         m_lastMonthKey = monthKey;
      }
   }

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
         int secondBar = StringFind(cmt, "|", idx + 2);
         int len = (secondBar > idx + 2) ? (secondBar - (idx + 2)) : 2;
         int sid = (int)StringToInteger(StringSubstr(cmt, idx + 2, len));
         if(sid >= 0 && sid < EA_MAX_STRATEGIES) return (ENUM_STRATEGY_ID)sid;
      }
      return STRAT_TREND_PULLBACK;
   }

   double ParseScore(const string cmt) const
   {
      int idx = StringFind(cmt, "|S");
      if(idx >= 0)
      {
         int secondBar = StringFind(cmt, "|", idx + 2);
         if(secondBar > idx)
            return StringToDouble(StringSubstr(cmt, secondBar + 1));
      }
      return -1.0;
   }

public:
   CPerformanceAnalytics()
   {
      m_magic = 0;
      m_initialBalance = 0.0;
      m_metrics.Reset();
      m_returnCount = 0;
      m_dealCount = 0;
      m_lastHistoryTotal = -1;
      m_lastScannedDealIdx = 0;
      m_curveCount = 0;
      m_lastCurveSampleTime = 0;
      m_peakEquitySeen = 0.0;
      m_totalHoldSec = 0.0;
      m_totalMfeMoney = 0.0;
      m_totalMaeMoney = 0.0;
      m_lastDayKey = 0;
      m_lastWeekAnchor = 0;
      m_lastMonthKey = 0;
      ArrayInitialize(m_scoreBandNet, 0.0);
      ArrayInitialize(m_scoreBandTrades, 0);
      ArrayInitialize(m_regimeNet, 0.0);
      ArrayInitialize(m_regimeTrades, 0);
      m_bySymbolCount = 0; m_bySessionCount = 0; m_byWeekdayCount = 0;
      m_byHourCount = 0; m_byMonthCount = 0;
      m_partialPosCount = 0;
      m_entryLedgerCount = 0;
   }

   void Initialize(const long magic)
   {
      m_magic = magic;
      m_initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      m_metrics.Reset();
      m_metrics.initialBalance = m_initialBalance;
      m_metrics.balance = m_initialBalance;
      m_metrics.equity  = AccountInfoDouble(ACCOUNT_EQUITY);
      m_peakEquitySeen  = MathMax(m_metrics.balance, m_metrics.equity);
      m_returnCount = 0;
      m_dealCount = 0;
      m_lastHistoryTotal = -1;
      m_lastScannedDealIdx = 0;
      m_curveCount = 0;
      m_lastCurveSampleTime = 0;
      m_totalHoldSec = 0.0;
      m_totalMfeMoney = 0.0;
      m_totalMaeMoney = 0.0;
      m_lastDayKey = 0;
      m_lastWeekAnchor = 0;
      m_lastMonthKey = 0;
      ArrayResize(m_tradeReturns, 0);
      ArrayResize(m_processedDeals, 0);
      ArrayResize(m_partialPos, 0);
      ArrayResize(m_entryLedger, 0);
      m_partialPosCount = 0;
      m_entryLedgerCount = 0;
      ArrayInitialize(m_equityCurve, 0.0);
      ArrayInitialize(m_balanceCurve, 0.0);
      ArrayInitialize(m_drawdownCurve, 0.0);
      ArrayInitialize(m_scoreBandNet, 0.0);
      ArrayInitialize(m_scoreBandTrades, 0);
      ArrayInitialize(m_regimeNet, 0.0);
      ArrayInitialize(m_regimeTrades, 0);
      m_bySymbolCount = 0; m_bySessionCount = 0; m_byWeekdayCount = 0;
      m_byHourCount = 0; m_byMonthCount = 0;
   }

   int SyncDealHistory(CStrategyBase *&strategies[], const int stratCount, const CPositionManagement &posMgmt,
                       const bool fallbackIs24x7, SClosedDealEvent &outEvents[], double &outTotalNewPnL,
                       const bool isBootstrap = false)
   {
      outTotalNewPnL = 0.0;
      ArrayResize(outEvents, 0);

      datetime now = SafeCurrentTime();
      if(!HistorySelect(0, now + 60))
         return 0;

      int totalDeals = HistoryDealsTotal();
      if(totalDeals == m_lastHistoryTotal && m_lastScannedDealIdx >= totalDeals)
         return 0;

      bool checkDuplicates = (totalDeals < m_lastScannedDealIdx);
      if(checkDuplicates)
         m_lastScannedDealIdx = 0;
      int scanStart = MathMax(0, m_lastScannedDealIdx);

      int newClosed = 0;
      RolloverPeriodMetrics(now);
      MqlDateTime nowDt;
      TimeToStruct(now, nowDt);
      datetime curWeekStart = GetWeekStart(now);

      for(int i = scanStart; i < totalDeals; i++)
      {
         ulong dealTicket = HistoryDealGetTicket(i);
         if(dealTicket == 0) continue;
         if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != m_magic) continue;

         long entryType = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         if(entryType == DEAL_ENTRY_IN)
         {
            long inPosId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
            if(inPosId > 0)
            {
               UpsertEntryLedger(inPosId,
                                 (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME),
                                 HistoryDealGetString(dealTicket, DEAL_COMMENT),
                                 HistoryDealGetDouble(dealTicket, DEAL_VOLUME),
                                 HistoryDealGetDouble(dealTicket, DEAL_COMMISSION),
                                 HistoryDealGetDouble(dealTicket, DEAL_FEE));
            }
            continue;
         }
         if(entryType != DEAL_ENTRY_OUT && entryType != DEAL_ENTRY_OUT_BY) continue;
         if(checkDuplicates && IsDealAlreadyProcessed(dealTicket)) continue;

         MarkDealProcessed(dealTicket);

         double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
         double swap   = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
         double comm   = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
         double fee    = HistoryDealGetDouble(dealTicket, DEAL_FEE);
         datetime closeTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
         string sym   = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
         string cmt   = HistoryDealGetString(dealTicket, DEAL_COMMENT);
         long posId   = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
         double vol   = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
         double price = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
         long dType   = HistoryDealGetInteger(dealTicket, DEAL_TYPE);

         bool stillOpenAfterDeal = (posId > 0 && PositionSelectByTicket((ulong)posId));

         long holdSec = 0;
         string openCmt = "";
         double totalOpenVol  = 0.0;
         double totalOpenComm = 0.0;
         double totalOpenFee  = 0.0;
         datetime earliestOpenT = 0;

         if(!ReadEntryLedger(posId, !stillOpenAfterDeal, earliestOpenT, openCmt, totalOpenVol, totalOpenComm, totalOpenFee))
         {
            // Fallback reverse scan only if entry deal was absent from incremental ledger (e.g. partial history window)
            for(int j = i - 1; j >= 0; j--)
            {
               ulong dOpen = HistoryDealGetTicket(j);
               if(HistoryDealGetInteger(dOpen, DEAL_POSITION_ID) == posId &&
                  HistoryDealGetInteger(dOpen, DEAL_ENTRY) == DEAL_ENTRY_IN)
               {
                  datetime openT = (datetime)HistoryDealGetInteger(dOpen, DEAL_TIME);
                  if(openT > 0 && (earliestOpenT == 0 || openT < earliestOpenT))
                     earliestOpenT = openT;
                  string c = HistoryDealGetString(dOpen, DEAL_COMMENT);
                  if(openCmt == "" && c != "")
                     openCmt = c;
                  double oVol = HistoryDealGetDouble(dOpen, DEAL_VOLUME);
                  if(oVol > 0.0) totalOpenVol += oVol;
                  totalOpenComm += HistoryDealGetDouble(dOpen, DEAL_COMMISSION);
                  totalOpenFee  += HistoryDealGetDouble(dOpen, DEAL_FEE);
               }
            }
         }
         if(earliestOpenT > 0)
            holdSec = (long)MathMax(0L, (long)(closeTime - earliestOpenT));
         double ratio = (totalOpenVol > 0.0) ? MathMin(1.0, vol / totalOpenVol) : 1.0;
         comm += (totalOpenComm * ratio);
         fee  += (totalOpenFee  * ratio);
         double netPnL = profit + swap + comm + fee;
         if(openCmt == "")
            openCmt = cmt;

         double mfe = 0.0, mae = 0.0;
         string exitReason = "SL/TP/BrokerClose", sigId = "";
         ENUM_MARKET_REGIME entryRegime = REGIME_UNKNOWN;
         posMgmt.GetTrackedMeta((ulong)posId, mfe, mae, exitReason, sigId, entryRegime);
         if(stillOpenAfterDeal)
            exitReason = "Partial Take-Profit";
         else if(exitReason == "SL/TP/BrokerClose")
         {
            string cmtLower = cmt;
            StringToLower(cmtLower);
            if(StringFind(cmtLower, "[tp") >= 0)      exitReason = "Take-Profit Hit";
            else if(StringFind(cmtLower, "[sl") >= 0) exitReason = "Stop-Loss Hit";
         }

         ENUM_STRATEGY_ID sid = ParseStrategy(openCmt);
         double sigScore = ParseScore(openCmt);

         // Realized cashflow accounting updated on every closing deal
         m_metrics.totalNetProfit   += netPnL;
         m_metrics.totalCommissions += (comm + fee);
         m_metrics.totalSwaps       += swap;

         MqlDateTime cDt;
         TimeToStruct(closeTime, cDt);
         if(cDt.year == nowDt.year && cDt.mon == nowDt.mon)
            m_metrics.realizedMonthlyPnL += netPnL;
         if(cDt.year == nowDt.year && cDt.day_of_year == nowDt.day_of_year)
            m_metrics.realizedDailyPnL += netPnL;
         if(GetWeekStart(closeTime) == curWeekStart)
            m_metrics.realizedWeeklyPnL += netPnL;

         if(stillOpenAfterDeal)
         {
            // Partial close: accumulate partial PnL into position buffer so full trade counts once on final exit
            AddPartialPosPnL(posId, netPnL);
         }
         else
         {
            double fullTradePnL = PopPartialPosPnL(posId) + netPnL;
            if((int)sid >= 0 && (int)sid < stratCount && strategies[(int)sid] != NULL)
               strategies[(int)sid].RecordTradeOutcome(fullTradePnL, holdSec, entryRegime);

            m_metrics.totalTrades++;
            m_totalHoldSec  += (double)holdSec;
            m_totalMfeMoney += mfe;
            m_totalMaeMoney += mae;
            m_metrics.avgHoldingSeconds = m_totalHoldSec / (double)m_metrics.totalTrades;
            m_metrics.avgMfeMoney       = m_totalMfeMoney / (double)m_metrics.totalTrades;
            m_metrics.avgMaeMoney       = m_totalMaeMoney / (double)m_metrics.totalTrades;

            if(fullTradePnL >= 0.0)
            {
               m_metrics.winningTrades++;
               m_metrics.grossProfit += fullTradePnL;
               if(fullTradePnL > m_metrics.largestWin) m_metrics.largestWin = fullTradePnL;
               m_metrics.currentConsecutiveWins++;
               m_metrics.currentConsecutiveLosses = 0;
               if(m_metrics.currentConsecutiveWins > m_metrics.maxConsecutiveWins)
                  m_metrics.maxConsecutiveWins = m_metrics.currentConsecutiveWins;
            }
            else
            {
               m_metrics.losingTrades++;
               m_metrics.grossLoss += MathAbs(fullTradePnL);
               if(fullTradePnL < m_metrics.largestLoss) m_metrics.largestLoss = fullTradePnL;
               m_metrics.currentConsecutiveLosses++;
               m_metrics.currentConsecutiveWins = 0;
               if(m_metrics.currentConsecutiveLosses > m_metrics.maxConsecutiveLosses)
                  m_metrics.maxConsecutiveLosses = m_metrics.currentConsecutiveLosses;
            }

            if(m_returnCount >= ArraySize(m_tradeReturns))
               ArrayResize(m_tradeReturns, m_returnCount + 64);
            double denom = MathMax(100.0, AccountInfoDouble(ACCOUNT_BALANCE));
            m_tradeReturns[m_returnCount++] = fullTradePnL / denom;

            if(sigScore >= 0.0)
            {
               int sb = (sigScore >= 75.0) ? 2 : ((sigScore >= 60.0) ? 1 : 0);
               m_scoreBandTrades[sb]++;
               m_scoreBandNet[sb] += fullTradePnL;
            }

            int rIdx = (int)entryRegime;
            if(rIdx >= 0 && rIdx <= EA_MAX_REGIMES)
            {
               m_regimeTrades[rIdx]++;
               m_regimeNet[rIdx] += fullTradePnL;
            }

            bool sym24x7 = IsSymbol24x7(sym, fallbackIs24x7);
            CStatisticsUtil::UpdateBucket(m_bySymbol, m_bySymbolCount, sym, fullTradePnL, mfe, mae);
            ENUM_TRADING_SESSION sess = CStatisticsUtil::ClassifySession(closeTime, sym24x7);
            CStatisticsUtil::UpdateBucket(m_bySession, m_bySessionCount, EnumToString(sess), fullTradePnL, mfe, mae);
            CStatisticsUtil::UpdateBucket(m_byWeekday, m_byWeekdayCount, IntegerToString(cDt.day_of_week), fullTradePnL, mfe, mae);
            CStatisticsUtil::UpdateBucket(m_byHour, m_byHourCount, StringFormat("%02d", cDt.hour), fullTradePnL, mfe, mae);
            CStatisticsUtil::UpdateBucket(m_byMonth, m_byMonthCount, StringFormat("%04d-%02d", cDt.year, cDt.mon), fullTradePnL, mfe, mae);

            if(!isBootstrap)
            {
               ArrayResize(outEvents, newClosed + 1);
               outEvents[newClosed].dealTicket     = dealTicket;
               outEvents[newClosed].positionTicket = (ulong)posId;
               outEvents[newClosed].symbol         = sym;
               outEvents[newClosed].signalId       = sigId;
               outEvents[newClosed].strategyId     = sid;
               outEvents[newClosed].direction      = (dType == DEAL_TYPE_SELL) ? SIGNAL_BUY : SIGNAL_SELL;
               outEvents[newClosed].volume         = vol;
               outEvents[newClosed].closePrice     = price;
               outEvents[newClosed].netPnL         = fullTradePnL;
               outEvents[newClosed].commission     = comm + fee;
               outEvents[newClosed].swap           = swap;
               outEvents[newClosed].mfeMoney       = mfe;
               outEvents[newClosed].maeMoney       = mae;
               outEvents[newClosed].score          = sigScore;
               outEvents[newClosed].entryRegime    = entryRegime;
               outEvents[newClosed].holdSec        = holdSec;
               outEvents[newClosed].closeTime      = closeTime;
               outEvents[newClosed].exitReason     = exitReason;
               outEvents[newClosed].isPartialClose = false;
               outTotalNewPnL += fullTradePnL;
               newClosed++;
            }
         }

         if(stillOpenAfterDeal && !isBootstrap)
         {
            ArrayResize(outEvents, newClosed + 1);
            outEvents[newClosed].dealTicket     = dealTicket;
            outEvents[newClosed].positionTicket = (ulong)posId;
            outEvents[newClosed].symbol         = sym;
            outEvents[newClosed].signalId       = sigId;
            outEvents[newClosed].strategyId     = sid;
            outEvents[newClosed].direction      = (dType == DEAL_TYPE_SELL) ? SIGNAL_BUY : SIGNAL_SELL;
            outEvents[newClosed].volume         = vol;
            outEvents[newClosed].closePrice     = price;
            outEvents[newClosed].netPnL         = netPnL;
            outEvents[newClosed].commission     = comm + fee;
            outEvents[newClosed].swap           = swap;
            outEvents[newClosed].mfeMoney       = mfe;
            outEvents[newClosed].maeMoney       = mae;
            outEvents[newClosed].score          = sigScore;
            outEvents[newClosed].entryRegime    = entryRegime;
            outEvents[newClosed].holdSec        = holdSec;
            outEvents[newClosed].closeTime      = closeTime;
            outEvents[newClosed].exitReason     = exitReason;
            outEvents[newClosed].isPartialClose = true;
            newClosed++;
         }
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

      m_lastHistoryTotal = totalDeals;
      m_lastScannedDealIdx = totalDeals;
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

      datetime now = SafeCurrentTime();
      RolloverPeriodMetrics(now);
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

   void GetScoreBandMetrics(double &outNet[], int &outTrades[]) const
   {
      ArrayResize(outNet, 3);
      ArrayResize(outTrades, 3);
      for(int i = 0; i < 3; i++) { outNet[i] = m_scoreBandNet[i]; outTrades[i] = m_scoreBandTrades[i]; }
   }

   void GetRegimeMetrics(double &outNet[], int &outTrades[]) const
   {
      ArrayResize(outNet, EA_MAX_REGIMES + 1);
      ArrayResize(outTrades, EA_MAX_REGIMES + 1);
      for(int i = 0; i <= EA_MAX_REGIMES; i++) { outNet[i] = m_regimeNet[i]; outTrades[i] = m_regimeTrades[i]; }
   }

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

   bool GetSegmentedSummary(string &outSessionSummary, string &outSymbolSummary) const
   {
      outSessionSummary = "No session data";
      outSymbolSummary  = "No symbol data";
      if(m_bySessionCount <= 0 && m_bySymbolCount <= 0)
         return false;

      if(m_bySessionCount > 0)
      {
         int bestIdx = 0, worstIdx = 0;
         for(int i = 1; i < m_bySessionCount; i++)
         {
            if(m_bySession[i].netProfit > m_bySession[bestIdx].netProfit) bestIdx = i;
            if(m_bySession[i].netProfit < m_bySession[worstIdx].netProfit) worstIdx = i;
         }
         if(bestIdx == worstIdx)
            outSessionSummary = StringFormat("%s:%.2f(%dt)", m_bySession[bestIdx].key, m_bySession[bestIdx].netProfit, m_bySession[bestIdx].trades);
         else
            outSessionSummary = StringFormat("Best %s:%.2f(%dt) | Weak %s:%.2f(%dt)",
                                             m_bySession[bestIdx].key, m_bySession[bestIdx].netProfit, m_bySession[bestIdx].trades,
                                             m_bySession[worstIdx].key, m_bySession[worstIdx].netProfit, m_bySession[worstIdx].trades);
      }

      if(m_bySymbolCount > 0)
      {
         int bestSym = 0, worstSym = 0;
         for(int i = 1; i < m_bySymbolCount; i++)
         {
            if(m_bySymbol[i].netProfit > m_bySymbol[bestSym].netProfit) bestSym = i;
            if(m_bySymbol[i].netProfit < m_bySymbol[worstSym].netProfit) worstSym = i;
         }
         if(bestSym == worstSym)
            outSymbolSummary = StringFormat("%s:%.2f(%dt)", m_bySymbol[bestSym].key, m_bySymbol[bestSym].netProfit, m_bySymbol[bestSym].trades);
         else
            outSymbolSummary = StringFormat("Top %s:%.2f(%dt) | Weak %s:%.2f(%dt)",
                                            m_bySymbol[bestSym].key, m_bySymbol[bestSym].netProfit, m_bySymbol[bestSym].trades,
                                            m_bySymbol[worstSym].key, m_bySymbol[worstSym].netProfit, m_bySymbol[worstSym].trades);
      }
      return true;
   }
};

#endif // __ASEA_ANALYTICS_PERFORMANCEANALYTICS_MQH__
