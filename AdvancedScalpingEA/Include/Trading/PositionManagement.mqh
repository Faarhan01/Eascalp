//+------------------------------------------------------------------+
//|                                           PositionManagement.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        Protective Position & Exit Management     |
//+------------------------------------------------------------------+
#ifndef __ASEA_TRADING_POSITIONMANAGEMENT_MQH__
#define __ASEA_TRADING_POSITIONMANAGEMENT_MQH__

#include "../Core/Types.mqh"
#include "../Core/Diagnostics.mqh"
#include "../Market/SymbolIntelligence.mqh"
#include "TradeExecution.mqh"

struct SPosMgmtConfig
{
   bool   enableBreakEven;
   double breakEvenTriggerAtr;
   double breakEvenLockAtr;
   bool   enableTrailingStop;
   double trailingStartAtr;
   double trailingStepAtr;
   bool   enableStructureExit;
   bool   enableMomentumExit;
   bool   enableOppositeSignalExit;
   bool   enableMaxHoldExit;
   int    maxHoldingMinutes;

   void ResetDefaults()
   {
      enableBreakEven = true;
      breakEvenTriggerAtr = 1.0;
      breakEvenLockAtr = 0.15;
      enableTrailingStop = true;
      trailingStartAtr = 1.4;
      trailingStepAtr = 0.9;
      enableStructureExit = true;
      enableMomentumExit = true;
      enableOppositeSignalExit = false;
      enableMaxHoldExit = true;
      maxHoldingMinutes = 120;
   }
};

class CPositionManagement
{
private:
   long             m_magic;
   SPosMgmtConfig   m_cfg;
   CDiagnostics    *m_diag;
   SManagedPosition m_positions[];
   int              m_posCount;

   ENUM_STRATEGY_ID ParseStrategyFromComment(const string cmt) const
   {
      int idx = StringFind(cmt, "|S");
      if(idx >= 0)
      {
         int sid = (int)StringToInteger(StringSubstr(cmt, idx + 2, 1));
         if(sid >= 0 && sid < EA_MAX_STRATEGIES)
            return (ENUM_STRATEGY_ID)sid;
      }
      return STRAT_TREND_PULLBACK;
   }

   double ParseScoreFromComment(const string cmt) const
   {
      int idx = StringFind(cmt, "|S");
      if(idx >= 0)
      {
         int secondBar = StringFind(cmt, "|", idx + 2);
         if(secondBar > idx)
            return StringToDouble(StringSubstr(cmt, secondBar + 1));
      }
      return 0.0;
   }

public:
   CPositionManagement()
   {
      m_magic = 0;
      m_cfg.ResetDefaults();
      m_diag = NULL;
      m_posCount = 0;
      ArrayResize(m_positions, 0);
   }

   void Initialize(const long magic, const SPosMgmtConfig &cfg, CDiagnostics *diag)
   {
      m_magic = magic;
      m_cfg = cfg;
      m_diag = diag;
      m_posCount = 0;
      ArrayResize(m_positions, 0);
   }

   void RefreshOwnedPositions(const CSymbolIntelligence &symIntel)
   {
      int total = PositionsTotal();
      ArrayResize(m_positions, MathMax(1, total));
      m_posCount = 0;

      datetime now = TimeCurrent();
      for(int i = 0; i < total; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(!PositionSelectByTicket(ticket)) continue;

         // Strict magic-number isolation: never manage manual or other EA positions
         if(PositionGetInteger(POSITION_MAGIC) != m_magic)
            continue;

         SManagedPosition p;
         p.Reset();
         p.ticket      = ticket;
         p.symbol      = PositionGetString(POSITION_SYMBOL);
         long pType    = PositionGetInteger(POSITION_TYPE);
         p.direction   = (pType == POSITION_TYPE_BUY) ? SIGNAL_BUY : SIGNAL_SELL;
         p.volume      = PositionGetDouble(POSITION_VOLUME);
         p.openPrice   = PositionGetDouble(POSITION_PRICE_OPEN);
         p.currentPrice= PositionGetDouble(POSITION_PRICE_CURRENT);
         p.currentSL   = PositionGetDouble(POSITION_SL);
         p.initialSL   = p.currentSL;
         p.takeProfit  = PositionGetDouble(POSITION_TP);
         p.floatingPnL = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         p.openTime    = (datetime)PositionGetInteger(POSITION_TIME);
         p.holdingSeconds = (long)(now - p.openTime);

         string cmt = PositionGetString(POSITION_COMMENT);
         p.strategyId   = ParseStrategyFromComment(cmt);
         p.strategyName = StrategyIdToName(p.strategyId);
         p.signalScore  = ParseScoreFromComment(cmt);

         if(p.direction == SIGNAL_BUY && p.currentSL >= p.openPrice && p.currentSL > 0.0)
            p.breakEvenApplied = true;
         else if(p.direction == SIGNAL_SELL && p.currentSL <= p.openPrice && p.currentSL > 0.0)
            p.breakEvenApplied = true;

         // Estimate remaining risk in account currency if SL is set
         if(p.currentSL > 0.0 && p.symbol == symIntel.GetProfile().symbol)
         {
            double slDist = (p.direction == SIGNAL_BUY) ? MathMax(0.0, p.currentPrice - p.currentSL)
                                                        : MathMax(0.0, p.currentSL - p.currentPrice);
            double lossPerLot = symIntel.GetLossPerLotForPriceDistance(slDist);
            p.currentRiskMoney = lossPerLot * p.volume;
         }

         m_positions[m_posCount++] = p;
      }
      ArrayResize(m_positions, m_posCount);
   }

   void ManageActivePositions(const string activeSymbol, const SMarketSnapshot &market, const SIndicatorValues &ind,
                              const SStructureState &structure, const STradeSignal &latestSignal,
                              const CSymbolIntelligence &symIntel, CTradeExecution &exec)
   {
      if(m_posCount <= 0 || !market.dataReady) return;

      double effAtr = (ind.isReady && ind.atr > 0.0) ? ind.atr : (market.spreadPoints * symIntel.GetProfile().point * 6.0);
      double minStopDist = symIntel.GetMinStopDistancePrice();
      datetime now = TimeCurrent();

      for(int i = 0; i < m_posCount; i++)
      {
         SManagedPosition p = m_positions[i];
         if(p.symbol != activeSymbol) continue;

         long holdMin = (long)(now - p.openTime) / 60;

         // 1. Maximum holding duration exit
         if(m_cfg.enableMaxHoldExit && holdMin >= m_cfg.maxHoldingMinutes)
         {
            exec.ClosePosition(p.ticket, p.symbol, StringFormat("Max holding duration (%I64d min)", holdMin));
            continue;
         }

         // 2. Opposite strong signal exit
         if(m_cfg.enableOppositeSignalExit && latestSignal.isValid && latestSignal.compositeScore >= 72.0 &&
            latestSignal.direction != SIGNAL_NONE && latestSignal.direction != p.direction)
         {
            exec.ClosePosition(p.ticket, p.symbol, "Opposite high-score signal");
            continue;
         }

         // 3. Momentum deterioration exit (only if trade held > 15m and momentum strongly reversed)
         if(m_cfg.enableMomentumExit && holdMin >= 15 && ind.isReady && p.floatingPnL < 0.0)
         {
            if(p.direction == SIGNAL_BUY && ind.macdHist < 0.0 && ind.rsi < 40.0 && market.close < ind.emaSlow)
            {
               exec.ClosePosition(p.ticket, p.symbol, "Bullish momentum deterioration exit");
               continue;
            }
            if(p.direction == SIGNAL_SELL && ind.macdHist > 0.0 && ind.rsi > 60.0 && market.close > ind.emaSlow)
            {
               exec.ClosePosition(p.ticket, p.symbol, "Bearish momentum deterioration exit");
               continue;
            }
         }

         // 4. Structure-based exit
         if(m_cfg.enableStructureExit && structure.isReady && holdMin >= 5)
         {
            if(p.direction == SIGNAL_BUY && structure.lastEvent == STRUCT_CHOCH_BEAR)
            {
               exec.ClosePosition(p.ticket, p.symbol, "Bearish CHoCH structure exit");
               continue;
            }
            if(p.direction == SIGNAL_SELL && structure.lastEvent == STRUCT_CHOCH_BULL)
            {
               exec.ClosePosition(p.ticket, p.symbol, "Bullish CHoCH structure exit");
               continue;
            }
         }

         // 5. Break-Even & Trailing Stop (strictly tightening SL; never widening risk!)
         double newSL = p.currentSL;
         if(p.direction == SIGNAL_BUY)
         {
            double profitDist = market.bid - p.openPrice;
            if(m_cfg.enableBreakEven && !p.breakEvenApplied && profitDist >= effAtr * m_cfg.breakEvenTriggerAtr)
            {
               double beSL = p.openPrice + effAtr * m_cfg.breakEvenLockAtr;
               if(beSL <= market.bid - minStopDist && (newSL <= 0.0 || beSL > newSL))
                  newSL = beSL;
            }
            if(m_cfg.enableTrailingStop && profitDist >= effAtr * m_cfg.trailingStartAtr)
            {
               double trailSL = market.bid - effAtr * m_cfg.trailingStepAtr;
               if(trailSL <= market.bid - minStopDist && (newSL <= 0.0 || trailSL > newSL))
                  newSL = trailSL;
            }
            // Guarantee protective stop never moves backward (never increases risk)
            if(newSL > 0.0 && (p.currentSL <= 0.0 || newSL > p.currentSL + symIntel.GetProfile().point))
               exec.ModifyPositionStops(p.ticket, newSL, p.takeProfit, symIntel);
         }
         else if(p.direction == SIGNAL_SELL)
         {
            double profitDist = p.openPrice - market.ask;
            if(m_cfg.enableBreakEven && !p.breakEvenApplied && profitDist >= effAtr * m_cfg.breakEvenTriggerAtr)
            {
               double beSL = p.openPrice - effAtr * m_cfg.breakEvenLockAtr;
               if(beSL >= market.ask + minStopDist && (newSL <= 0.0 || beSL < newSL))
                  newSL = beSL;
            }
            if(m_cfg.enableTrailingStop && profitDist >= effAtr * m_cfg.trailingStartAtr)
            {
               double trailSL = market.ask + effAtr * m_cfg.trailingStepAtr;
               if(trailSL >= market.ask + minStopDist && (newSL <= 0.0 || trailSL < newSL))
                  newSL = trailSL;
            }
            if(newSL > 0.0 && (p.currentSL <= 0.0 || newSL < p.currentSL - symIntel.GetProfile().point))
               exec.ModifyPositionStops(p.ticket, newSL, p.takeProfit, symIntel);
         }
      }
   }

   int GetManagedPositions(SManagedPosition &outArr[]) const
   {
      ArrayResize(outArr, m_posCount);
      for(int i = 0; i < m_posCount; i++)
         outArr[i] = m_positions[i];
      return m_posCount;
   }

   int GetCount() const { return m_posCount; }
};

#endif // __ASEA_TRADING_POSITIONMANAGEMENT_MQH__
