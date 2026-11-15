//+------------------------------------------------------------------+
//|                                               TradeExecution.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        Reliable Broker & Paper Order Execution   |
//+------------------------------------------------------------------+
#ifndef __ASEA_TRADING_TRADEEXECUTION_MQH__
#define __ASEA_TRADING_TRADEEXECUTION_MQH__

#include <Trade\Trade.mqh>
#include "../Core/Types.mqh"
#include "../Core/Diagnostics.mqh"
#include "../Market/SymbolIntelligence.mqh"

class CTradeExecution
{
private:
   CTrade        m_trade;
   long          m_magic;
   int           m_maxSlippagePoints;
   int           m_maxRetries;
   CDiagnostics *m_diag;
   datetime      m_lastExecBarTime;
   ulong         m_paperTicketSeq;

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
         case TRADE_RETCODE_MARKET_CLOSED:   return "MARKET_CLOSED";
         case TRADE_RETCODE_TRADE_DISABLED:  return "TRADE_DISABLED";
         case TRADE_RETCODE_TIMEOUT:         return "TIMEOUT";
         case TRADE_RETCODE_CONNECTION:      return "NO_CONNECTION";
      }
      return StringFormat("RETCODE_%u", code);
   }

public:
   CTradeExecution()
   {
      m_magic = 510299;
      m_maxSlippagePoints = 25;
      m_maxRetries = 2;
      m_diag = NULL;
      m_lastExecBarTime = 0;
      m_paperTicketSeq = 900000001;
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

   bool IsDuplicateBarExecution(const datetime currentBarTime) const
   {
      return (currentBarTime > 0 && currentBarTime == m_lastExecBarTime);
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

      if(opMode == EA_MODE_RESEARCH_ONLY)
      {
         res.retcodeDesc = "RESEARCH_ONLY_OBSERVED";
         return res;
      }

      if(opMode == EA_MODE_DEMO_PAPER)
      {
         res.executed = true;
         res.isPaperTrade = true;
         res.positionTicket = m_paperTicketSeq++;
         res.orderTicket = res.positionTicket;
         res.filledPrice = sig.entryPrice;
         res.filledVolume = lots;
         res.retcode = TRADE_RETCODE_DONE;
         res.retcodeDesc = "PAPER_FILLED";
         m_lastExecBarTime = barTime;
         return res;
      }

      // Safety gate: never execute on real-money account unless BOTH explicit inputs are enabled
      long acctMode = AccountInfoInteger(ACCOUNT_TRADE_MODE);
      if(acctMode == ACCOUNT_TRADE_MODE_REAL)
      {
         if(opMode != EA_MODE_LIVE_TRADING || !liveAck1 || !liveAck2)
         {
            res.retcodeDesc = "LIVE_TRADING_BLOCKED_BY_SAFETY_GUARD";
            if(m_diag != NULL)
               m_diag.Log(LOG_WARN, "TradeExecution", "Blocked real-account order attempt: live trading is disabled by default.", "live_block", 60);
            return res;
         }
      }

      SSymbolProfile prof = symIntel.GetProfile();
      m_trade.SetTypeFilling(prof.preferredFilling);
      m_trade.SetDeviationInPoints((ulong)m_maxSlippagePoints);

      double normVol = symIntel.NormalizeVolume(lots);
      double normSL  = symIntel.NormalizePrice(sig.stopLoss);
      double normTP  = symIntel.NormalizePrice(sig.takeProfit);
      string comment = StringFormat("ASEA|S%d|%.0f", (int)sig.strategyId, sig.compositeScore);

      for(int attempt = 1; attempt <= m_maxRetries; attempt++)
      {
         MqlTick t;
         if(!SymbolInfoTick(prof.symbol, t))
         {
            res.retcodeDesc = "TICK_REFRESH_FAILED";
            break;
         }

         double reqPrice = symIntel.NormalizePrice((sig.direction == SIGNAL_BUY) ? t.ask : t.bid);
         res.requestedPrice = reqPrice;

         bool sent = false;
         if(sig.direction == SIGNAL_BUY)
            sent = m_trade.Buy(normVol, prof.symbol, reqPrice, normSL, normTP, comment);
         else if(sig.direction == SIGNAL_SELL)
            sent = m_trade.Sell(normVol, prof.symbol, reqPrice, normSL, normTP, comment);

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
            res.positionTicket = res.orderTicket;
            m_lastExecBarTime = barTime;

            if(m_diag != NULL)
               m_diag.Log(LOG_INFO, "TradeExecution",
                          StringFormat("Executed %s %s %.2f lots @ %.5f (SL=%.5f TP=%.5f, Slip=%.1f pts, Code=%s)",
                                       DirectionToString(sig.direction), prof.symbol, res.filledVolume, res.filledPrice,
                                       normSL, normTP, res.slippagePoints, res.retcodeDesc));
            return res;
         }

         if(m_diag != NULL)
            m_diag.Log(LOG_WARN, "TradeExecution",
                       StringFormat("Attempt %d/%d failed: %s (%s)", attempt, m_maxRetries, res.retcodeDesc, m_trade.ResultRetcodeDescription()));

         if(res.retcode != TRADE_RETCODE_REQUOTE && res.retcode != TRADE_RETCODE_PRICE_CHANGED && res.retcode != TRADE_RETCODE_TIMEOUT)
            break;
      }

      return res;
   }

   bool ClosePosition(const ulong ticket, const string symbol, const string reason)
   {
      if(!PositionSelectByTicket(ticket))
         return false;
      if(PositionGetInteger(POSITION_MAGIC) != m_magic)
         return false;

      bool ok = m_trade.PositionClose(ticket, (ulong)m_maxSlippagePoints);
      if(m_diag != NULL)
         m_diag.Log(ok ? LOG_INFO : LOG_WARN, "TradeExecution",
                    StringFormat("ClosePosition #%I64u (%s) reason='%s' -> %s (%s)",
                                 ticket, symbol, reason, ok ? "OK" : "FAIL", m_trade.ResultRetcodeDescription()));
      return ok;
   }

   bool ModifyPositionStops(const ulong ticket, const double newSL, const double newTP, const CSymbolIntelligence &symIntel)
   {
      if(!PositionSelectByTicket(ticket))
         return false;
      if(PositionGetInteger(POSITION_MAGIC) != m_magic)
         return false;

      double normSL = symIntel.NormalizePrice(newSL);
      double normTP = symIntel.NormalizePrice(newTP);
      double curSL  = PositionGetDouble(POSITION_SL);
      double curTP  = PositionGetDouble(POSITION_TP);

      if(MathAbs(normSL - curSL) < symIntel.GetProfile().point && MathAbs(normTP - curTP) < symIntel.GetProfile().point)
         return true;

      return m_trade.PositionModify(ticket, normSL, normTP);
   }
};

#endif // __ASEA_TRADING_TRADEEXECUTION_MQH__
