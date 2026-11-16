//+------------------------------------------------------------------+
//|                                               TradeExecution.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.0.0 Multi-Symbol Reliable Execution    |
//+------------------------------------------------------------------+
#ifndef __ASEA_TRADING_TRADEEXECUTION_MQH__
#define __ASEA_TRADING_TRADEEXECUTION_MQH__

#include <Trade\Trade.mqh>
#include "../Core/Types.mqh"
#include "../Core/Diagnostics.mqh"
#include "../Market/SymbolIntelligence.mqh"

struct SSymbolExecBar
{
   string   symbol;
   datetime barTime;
};

class CTradeExecution
{
private:
   CTrade         m_trade;
   long           m_magic;
   int            m_maxSlippagePoints;
   int            m_maxRetries;
   CDiagnostics  *m_diag;
   SSymbolExecBar m_symbolExecBars[EA_MAX_SYMBOLS];
   int            m_symbolExecCount;

   string RetcodeToText(const uint code) const
   {
      switch(code)
      {
         case TRADE_RETCODE_DONE:            return "DONE";
         case TRADE_RETCODE_DONE_PARTIAL:    return "DONE_PARTIAL";
         case TRADE_RETCODE_REQUOTE:         return "REQUOTE";
         case TRADE_RETCODE_REJECT:          return "REJECT";
         case TRADE_RETCODE_NO_MONEY:        return "NO_MONEY";
         case TRADE_RETCODE_PRICE_CHANGED:   return "PRICE_CHANGED";
         case TRADE_RETCODE_PRICE_OFF:       return "OFF_QUOTES";
         case TRADE_RETCODE_INVALID_STOPS:   return "INVALID_STOPS";
         case TRADE_RETCODE_INVALID_VOLUME:  return "INVALID_VOLUME";
         case TRADE_RETCODE_INVALID_FILL:    return "INVALID_FILL";
         case TRADE_RETCODE_MARKET_CLOSED:   return "MARKET_CLOSED";
         case TRADE_RETCODE_TRADE_DISABLED:  return "TRADE_DISABLED";
         case TRADE_RETCODE_TIMEOUT:         return "TIMEOUT";
         case TRADE_RETCODE_CONNECTION:      return "NO_CONNECTION";
      }
      return StringFormat("RETCODE_%u", code);
   }

   ulong ResolveOpenPositionTicket(const string symbol, const ulong orderTicket, const ulong dealTicket = 0) const
   {
      if(dealTicket > 0 && HistoryDealSelect(dealTicket))
      {
         long posId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
         if(posId > 0 && PositionSelectByTicket((ulong)posId))
            return (ulong)posId;
      }
      if(orderTicket > 0 && PositionSelectByTicket(orderTicket))
         return orderTicket;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong pt = PositionGetTicket(i);
         if(pt > 0 && PositionSelectByTicket(pt) &&
            PositionGetString(POSITION_SYMBOL) == symbol &&
            PositionGetInteger(POSITION_MAGIC) == m_magic)
            return pt;
      }
      return orderTicket;
   }

   void RecordSymbolBarExec(const string sym, const datetime barTime)
   {
      for(int i = 0; i < m_symbolExecCount; i++)
      {
         if(m_symbolExecBars[i].symbol == sym)
         {
            m_symbolExecBars[i].barTime = barTime;
            return;
         }
      }
      if(m_symbolExecCount < EA_MAX_SYMBOLS)
      {
         m_symbolExecBars[m_symbolExecCount].symbol  = sym;
         m_symbolExecBars[m_symbolExecCount].barTime = barTime;
         m_symbolExecCount++;
      }
   }

public:
   CTradeExecution()
   {
      m_magic = 510299;
      m_maxSlippagePoints = 25;
      m_maxRetries = 2;
      m_diag = NULL;
      m_symbolExecCount = 0;
      for(int i = 0; i < EA_MAX_SYMBOLS; i++)
      {
         m_symbolExecBars[i].symbol = "";
         m_symbolExecBars[i].barTime = 0;
      }
   }

   void Initialize(const long magic, const int maxSlippagePts, const int maxRetries, CDiagnostics *diag)
   {
      m_magic = magic;
      m_maxSlippagePoints = MathMax(1, maxSlippagePts);
      m_maxRetries = MathMax(1, MathMin(5, maxRetries));
      m_diag = diag;
      m_trade.SetExpertMagicNumber((ulong)m_magic);
      m_trade.SetDeviationInPoints((ulong)m_maxSlippagePoints);
      m_trade.SetAsyncMode(false);
   }

   bool IsDuplicateBarExecution(const string symbol, const datetime currentBarTime) const
   {
      if(currentBarTime <= 0) return false;
      for(int i = 0; i < m_symbolExecCount; i++)
      {
         if(m_symbolExecBars[i].symbol == symbol && m_symbolExecBars[i].barTime == currentBarTime)
            return true;
      }
      return false;
   }

   SExecutionResult Execute(const STradeSignal &sig, const double lots, const CSymbolIntelligence &symIntel,
                            const ENUM_EA_OPERATING_MODE opMode, const bool liveAck1, const bool liveAck2,
                            const datetime barTime)
   {
      SExecutionResult res;
      res.Reset();
      res.executionTime = TimeCurrent();
      res.requestedVolume = lots;
      res.requestedPrice = sig.entryPrice;

      SSymbolProfile prof = symIntel.GetProfile();
      double estCost = symIntel.EstimateExecutionCostMoney(lots, (double)prof.spreadPoints, 0.0);
      res.estimatedCostMoney = estCost;

      if(opMode == EA_MODE_RESEARCH_ONLY)
      {
         res.retcodeDesc = "RESEARCH_ONLY_OBSERVED";
         return res;
      }

      long acctMode = AccountInfoInteger(ACCOUNT_TRADE_MODE);
      if(acctMode == ACCOUNT_TRADE_MODE_REAL)
      {
         if(opMode != EA_MODE_LIVE_TRADING || !liveAck1 || !liveAck2)
         {
            res.retcodeDesc = "LIVE_TRADING_DISABLED_BY_USER_INPUT";
            if(m_diag != NULL)
               m_diag.Log(LOG_WARN, "TradeExecution", "Blocked real-account order attempt: user input disabled live trading.", "live_block", 60);
            return res;
         }
      }

      ENUM_ORDER_TYPE_FILLING fillModes[3] = {prof.preferredFilling, ORDER_FILLING_IOC, ORDER_FILLING_RETURN};
      if(prof.preferredFilling == ORDER_FILLING_IOC)
      {
         fillModes[1] = ORDER_FILLING_FOK;
         fillModes[2] = ORDER_FILLING_RETURN;
      }
      else if(prof.preferredFilling == ORDER_FILLING_FOK)
      {
         fillModes[1] = ORDER_FILLING_IOC;
         fillModes[2] = ORDER_FILLING_RETURN;
      }
      else
      {
         fillModes[1] = ORDER_FILLING_IOC;
         fillModes[2] = ORDER_FILLING_FOK;
      }

      int fillIdx = 0;
      int effSlippage = MathMax(m_maxSlippagePoints, prof.recommendedSlippagePts);
      m_trade.SetTypeFilling(fillModes[fillIdx]);
      m_trade.SetDeviationInPoints((ulong)effSlippage);

      double normVol = symIntel.NormalizeVolume(lots);
      if(normVol < prof.volumeMin)
      {
         res.retcode = TRADE_RETCODE_INVALID_VOLUME;
         res.retcodeDesc = "VOLUME_BELOW_MIN";
         return res;
      }

      double normSL  = symIntel.NormalizePrice(sig.stopLoss);
      double normTP  = symIntel.NormalizePrice(sig.takeProfit);
      double minStopDist = symIntel.GetMinStopDistancePrice();
      string comment = StringFormat("ASEA|S%d|%.0f", (int)sig.strategyId, sig.compositeScore);
      bool stopAdjustedRetried = false;

      int totalTries = MathMax(3, m_maxRetries + 2);
      for(int attempt = 1; attempt <= totalTries; attempt++)
      {
         MqlTick t;
         if(!SymbolInfoTick(prof.symbol, t))
         {
            res.retcodeDesc = "TICK_REFRESH_FAILED";
            break;
         }

         double reqPrice = symIntel.NormalizePrice((sig.direction == SIGNAL_BUY) ? t.ask : t.bid);
         res.requestedPrice = reqPrice;

         double curSL = normSL;
         double curTP = normTP;
         if(minStopDist > 0.0)
         {
            double reqStopPad = minStopDist + prof.point;
            if(sig.direction == SIGNAL_BUY)
            {
               if(curSL > 0.0 && curSL > (reqPrice - reqStopPad))
                  curSL = symIntel.NormalizePrice(reqPrice - reqStopPad);
               if(curTP > 0.0 && curTP < (reqPrice + reqStopPad))
                  curTP = symIntel.NormalizePrice(reqPrice + reqStopPad);
            }
            else if(sig.direction == SIGNAL_SELL)
            {
               if(curSL > 0.0 && curSL < (reqPrice + reqStopPad))
                  curSL = symIntel.NormalizePrice(reqPrice + reqStopPad);
               if(curTP > 0.0 && curTP > (reqPrice - reqStopPad))
                  curTP = symIntel.NormalizePrice(reqPrice - reqStopPad);
            }
         }

         bool sent = false;
         if(sig.direction == SIGNAL_BUY)
            sent = m_trade.Buy(normVol, prof.symbol, reqPrice, curSL, curTP, comment);
         else if(sig.direction == SIGNAL_SELL)
            sent = m_trade.Sell(normVol, prof.symbol, reqPrice, curSL, curTP, comment);

         res.retcode     = m_trade.ResultRetcode();
         res.retcodeDesc = RetcodeToText(res.retcode);
         res.orderTicket = m_trade.ResultOrder();
         res.dealTicket  = m_trade.ResultDeal();

         if(sent && (res.retcode == TRADE_RETCODE_DONE || res.retcode == TRADE_RETCODE_DONE_PARTIAL))
         {
            res.executed = true;
            res.filledPrice  = (m_trade.ResultPrice() > 0.0) ? m_trade.ResultPrice() : reqPrice;
            res.filledVolume = (m_trade.ResultVolume() > 0.0) ? m_trade.ResultVolume() : normVol;
            if(prof.point > 0.0)
               res.slippagePoints = MathAbs(res.filledPrice - reqPrice) / prof.point;
            res.estimatedCostMoney = symIntel.EstimateExecutionCostMoney(res.filledVolume, (double)prof.spreadPoints, res.slippagePoints);
            res.positionTicket = ResolveOpenPositionTicket(prof.symbol, res.orderTicket, res.dealTicket);
            RecordSymbolBarExec(prof.symbol, barTime);

            if(m_diag != NULL)
               m_diag.Log(LOG_INFO, "TradeExecution",
                          StringFormat("Executed %s %s %.2f lots @ %.5f (SL=%.5f TP=%.5f, Slip=%.1f pts, Cost=%.2f, Code=%s)",
                                       DirectionToString(sig.direction), prof.symbol, res.filledVolume, res.filledPrice,
                                       curSL, curTP, res.slippagePoints, res.estimatedCostMoney, res.retcodeDesc));
            return res;
         }

         if(m_diag != NULL)
            m_diag.Log(LOG_WARN, "TradeExecution",
                       StringFormat("Attempt %d/%d failed: %s (%s)", attempt, totalTries, res.retcodeDesc, m_trade.ResultRetcodeDescription()));

         if(res.retcode == TRADE_RETCODE_INVALID_FILL && fillIdx < 2)
         {
            fillIdx++;
            m_trade.SetTypeFilling(fillModes[fillIdx]);
            continue;
         }
         if(res.retcode == TRADE_RETCODE_INVALID_STOPS && !stopAdjustedRetried)
         {
            stopAdjustedRetried = true;
            minStopDist = MathMax(minStopDist * 1.8, (double)(prof.spreadPoints + 25) * prof.point);
            continue;
         }
         if(res.retcode != TRADE_RETCODE_REQUOTE && res.retcode != TRADE_RETCODE_PRICE_CHANGED && res.retcode != TRADE_RETCODE_TIMEOUT)
            break;
      }

      return res;
   }

   bool ClosePosition(const ulong ticket, const string symbol, const string reason, const CSymbolIntelligence &symIntel)
   {
      if(!PositionSelectByTicket(ticket))
         return false;
      if(PositionGetInteger(POSITION_MAGIC) != m_magic)
         return false;

      SSymbolProfile prof = symIntel.GetProfile();
      ulong closeSlippage = (ulong)MathMax(m_maxSlippagePoints, prof.recommendedSlippagePts);
      ENUM_ORDER_TYPE_FILLING modes[3] = {ORDER_FILLING_IOC, ORDER_FILLING_FOK, ORDER_FILLING_RETURN};
      m_trade.SetTypeFilling(prof.preferredFilling);
      bool ok = m_trade.PositionClose(ticket, closeSlippage);
      for(int i = 0; !ok && m_trade.ResultRetcode() == TRADE_RETCODE_INVALID_FILL && i < 3; i++)
      {
         m_trade.SetTypeFilling(modes[i]);
         ok = m_trade.PositionClose(ticket, closeSlippage);
      }

      if(m_diag != NULL)
         m_diag.Log(ok ? LOG_INFO : LOG_WARN, "TradeExecution",
                    StringFormat("ClosePosition #%I64u (%s) reason='%s' -> %s (%s)",
                                 ticket, symbol, reason, ok ? "OK" : "FAIL", m_trade.ResultRetcodeDescription()));
      return ok;
   }

   bool ClosePartial(const ulong ticket, const double closeVol, const string symbol, const string reason,
                     const CSymbolIntelligence &symIntel)
   {
      if(!PositionSelectByTicket(ticket))
         return false;
      if(PositionGetInteger(POSITION_MAGIC) != m_magic)
         return false;

      double curVol = PositionGetDouble(POSITION_VOLUME);
      double normClose = symIntel.NormalizeVolume(closeVol);
      SSymbolProfile prof = symIntel.GetProfile();
      if(normClose < prof.volumeMin || (curVol - normClose) < prof.volumeMin)
         return false;

      ulong closeSlippage = (ulong)MathMax(m_maxSlippagePoints, prof.recommendedSlippagePts);
      ENUM_ORDER_TYPE_FILLING modes[3] = {ORDER_FILLING_IOC, ORDER_FILLING_FOK, ORDER_FILLING_RETURN};
      m_trade.SetTypeFilling(prof.preferredFilling);
      bool ok = m_trade.PositionClosePartial(ticket, normClose, closeSlippage);
      for(int i = 0; !ok && m_trade.ResultRetcode() == TRADE_RETCODE_INVALID_FILL && i < 3; i++)
      {
         m_trade.SetTypeFilling(modes[i]);
         ok = m_trade.PositionClosePartial(ticket, normClose, closeSlippage);
      }

      if(m_diag != NULL)
         m_diag.Log(ok ? LOG_INFO : LOG_WARN, "TradeExecution",
                    StringFormat("ClosePartial #%I64u (%s) %.2f lots reason='%s' -> %s (%s)",
                                 ticket, symbol, normClose, reason, ok ? "OK" : "FAIL", m_trade.ResultRetcodeDescription()));
      return ok;
   }

   bool ModifyPositionStops(const ulong ticket, const double newSL, const double newTP, const CSymbolIntelligence &symIntel)
   {
      if(!PositionSelectByTicket(ticket))
         return false;
      if(PositionGetInteger(POSITION_MAGIC) != m_magic)
         return false;

      SSymbolProfile prof = symIntel.GetProfile();
      double normSL = symIntel.NormalizePrice(newSL);
      double normTP = symIntel.NormalizePrice(newTP);
      double curSL  = PositionGetDouble(POSITION_SL);
      double curTP  = PositionGetDouble(POSITION_TP);

      if(MathAbs(normSL - curSL) < prof.point && MathAbs(normTP - curTP) < prof.point)
         return true;

      // Guard against broker freeze distance around market price before submitting modify request
      double minStopDist = symIntel.GetMinStopDistancePrice();
      if(minStopDist > 0.0)
      {
         long pType = PositionGetInteger(POSITION_TYPE);
         double refPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         if(refPrice > 0.0)
         {
            if(pType == POSITION_TYPE_BUY && normSL > 0.0 && normSL > (refPrice - minStopDist))
               return false;
            if(pType == POSITION_TYPE_SELL && normSL > 0.0 && normSL < (refPrice + minStopDist))
               return false;
            if(prof.freezeLevelPoints > 0)
            {
               double freezeDist = (double)prof.freezeLevelPoints * prof.point;
               if(curSL > 0.0 && MathAbs(refPrice - curSL) <= freezeDist)
                  return false;
               if(curTP > 0.0 && MathAbs(refPrice - curTP) <= freezeDist)
                  return false;
            }
         }
      }

      return m_trade.PositionModify(ticket, normSL, normTP);
   }
};

#endif // __ASEA_TRADING_TRADEEXECUTION_MQH__
