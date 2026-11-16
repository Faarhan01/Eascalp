//+------------------------------------------------------------------+
//|                                           PositionManagement.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.2.0 MFE/MAE, Cost-BE & Chandelier Trail|
//+------------------------------------------------------------------+
#ifndef __ASEA_TRADING_POSITIONMANAGEMENT_MQH__
#define __ASEA_TRADING_POSITIONMANAGEMENT_MQH__

#include "../Core/Types.mqh"
#include "../Core/Diagnostics.mqh"
#include "../Market/SymbolIntelligence.mqh"
#include "../Strategies/StrategyBase.mqh"
#include "TradeExecution.mqh"

struct SPosMgmtConfig
{
   bool   enableBreakEven;
   double breakEvenTriggerAtr;
   double breakEvenLockAtr;
   bool   enablePartialClose;
   double partialCloseTriggerAtr;
   double partialCloseFraction;
   bool   enableTrailingStop;
   bool   useProgressiveTrail;
   bool   useChandelierTrail;
   double trailingStartAtr;
   double trailingStepAtr;
   bool   enableStructureExit;
   bool   enableMomentumExit;
   bool   enableStrategyExit;
   bool   enableOppositeSignalExit;
   bool   enableMaxHoldExit;
   int    maxHoldingMinutes;
   bool   closeBeforeWeekend;
   int    fridayCloseHour;

   void ResetDefaults()
   {
      enableBreakEven = true;
      breakEvenTriggerAtr = 1.0;
      breakEvenLockAtr = 0.15;
      enablePartialClose = true;
      partialCloseTriggerAtr = 1.25;
      partialCloseFraction = 0.50;
      enableTrailingStop = true;
      useProgressiveTrail = true;
      useChandelierTrail = true;
      trailingStartAtr = 1.4;
      trailingStepAtr = 0.9;
      enableStructureExit = true;
      enableMomentumExit = true;
      enableStrategyExit = true;
      enableOppositeSignalExit = false;
      enableMaxHoldExit = true;
      maxHoldingMinutes = 120;
      closeBeforeWeekend = false;
      fridayCloseHour = 21;
   }
};

struct SPositionTrack
{
   ulong              ticket;
   string             symbol;
   string             signalId;
   ENUM_MARKET_REGIME entryRegime;
   double             initialVolume;
   double             initialSL;
   double             bestFavorablePrice;
   double             mfeMoney;
   double             maeMoney;
   bool               partialExitTaken;
   string             lastExitReason;

   void Reset()
   {
      ticket = 0; symbol = ""; signalId = "";
      entryRegime = REGIME_UNKNOWN;
      initialVolume = 0.0; initialSL = 0.0;
      bestFavorablePrice = 0.0;
      mfeMoney = 0.0; maeMoney = 0.0;
      partialExitTaken = false; lastExitReason = "SL/TP/BrokerClose";
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
   SPositionTrack   m_tracks[64];
   int              m_trackCount;

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

   int FindTrackIndex(const ulong ticket) const
   {
      for(int i = 0; i < m_trackCount; i++)
      {
         if(m_tracks[i].ticket == ticket)
            return i;
      }
      return -1;
   }

   void PruneClosedTracks()
   {
      if(m_trackCount <= 0) return;
      for(int i = m_trackCount - 1; i >= 0; i--)
      {
         bool stillOpen = (m_tracks[i].ticket > 0 && PositionSelectByTicket(m_tracks[i].ticket));
         if(!stillOpen)
         {
            for(int j = i + 1; j < m_trackCount; j++)
               m_tracks[j - 1] = m_tracks[j];
            m_trackCount--;
            m_tracks[m_trackCount].Reset();
         }
      }
   }

   int EnsureTrack(const ulong ticket, const string symbol, const double vol, const double sl, const double openPrice = 0.0)
   {
      int idx = FindTrackIndex(ticket);
      if(idx >= 0) return idx;
      if(m_trackCount >= 64)
         PruneClosedTracks();
      if(m_trackCount >= 64)
      {
         for(int i = 1; i < 64; i++)
            m_tracks[i - 1] = m_tracks[i];
         m_trackCount = 63;
      }
      idx = m_trackCount++;
      m_tracks[idx].Reset();
      m_tracks[idx].ticket = ticket;
      m_tracks[idx].symbol = symbol;
      m_tracks[idx].initialVolume = vol;
      m_tracks[idx].initialSL = sl;
      m_tracks[idx].bestFavorablePrice = openPrice;
      return idx;
   }

   void SetExitReason(const ulong ticket, const string reason)
   {
      int idx = FindTrackIndex(ticket);
      if(idx >= 0)
         m_tracks[idx].lastExitReason = reason;
   }

public:
   CPositionManagement()
   {
      m_magic = 0;
      m_cfg.ResetDefaults();
      m_diag = NULL;
      m_posCount = 0;
      m_trackCount = 0;
      ArrayResize(m_positions, 0);
      for(int i = 0; i < 64; i++)
         m_tracks[i].Reset();
   }

   void Initialize(const long magic, const SPosMgmtConfig &cfg, CDiagnostics *diag)
   {
      m_magic = magic;
      m_cfg = cfg;
      m_diag = diag;
      m_posCount = 0;
      m_trackCount = 0;
      ArrayResize(m_positions, 0);
   }

   void RegisterNewEntryMeta(const ulong ticket, const string symbol, const string signalId,
                             const ENUM_MARKET_REGIME entryRegime, const double initVol, const double initSL)
   {
      if(ticket == 0) return;
      double openPx = 0.0;
      if(PositionSelectByTicket(ticket))
         openPx = PositionGetDouble(POSITION_PRICE_OPEN);
      int idx = EnsureTrack(ticket, symbol, initVol, initSL, openPx);
      m_tracks[idx].signalId = signalId;
      m_tracks[idx].entryRegime = entryRegime;
      m_tracks[idx].initialVolume = initVol;
      m_tracks[idx].initialSL = initSL;
      if(openPx > 0.0) m_tracks[idx].bestFavorablePrice = openPx;
   }

   bool GetTrackedMeta(const ulong ticket, double &outMfe, double &outMae, string &outExitReason,
                       string &outSignalId, ENUM_MARKET_REGIME &outEntryRegime) const
   {
      int idx = FindTrackIndex(ticket);
      if(idx < 0)
      {
         outMfe = 0.0; outMae = 0.0; outExitReason = "SL/TP/BrokerClose";
         outSignalId = ""; outEntryRegime = REGIME_UNKNOWN;
         return false;
      }
      outMfe = m_tracks[idx].mfeMoney;
      outMae = m_tracks[idx].maeMoney;
      outExitReason = m_tracks[idx].lastExitReason;
      outSignalId = m_tracks[idx].signalId;
      outEntryRegime = m_tracks[idx].entryRegime;
      return true;
   }

   void RefreshOwnedPositions(const string activeSymbol, const CSymbolIntelligence &activeSymIntel)
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
         if(PositionGetInteger(POSITION_MAGIC) != m_magic) continue;

         SManagedPosition p;
         p.Reset();
         p.ticket       = ticket;
         p.symbol       = PositionGetString(POSITION_SYMBOL);
         long pType     = PositionGetInteger(POSITION_TYPE);
         p.direction    = (pType == POSITION_TYPE_BUY) ? SIGNAL_BUY : SIGNAL_SELL;
         p.volume       = PositionGetDouble(POSITION_VOLUME);
         p.openPrice    = PositionGetDouble(POSITION_PRICE_OPEN);
         p.currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         p.currentSL    = PositionGetDouble(POSITION_SL);
         p.takeProfit   = PositionGetDouble(POSITION_TP);
         p.floatingPnL  = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         p.openTime     = (datetime)PositionGetInteger(POSITION_TIME);
         p.holdingSeconds = (long)(now - p.openTime);

         int tIdx = EnsureTrack(ticket, p.symbol, p.volume, p.currentSL, p.openPrice);
         if(p.floatingPnL > m_tracks[tIdx].mfeMoney) m_tracks[tIdx].mfeMoney = p.floatingPnL;
         if(p.floatingPnL < m_tracks[tIdx].maeMoney) m_tracks[tIdx].maeMoney = p.floatingPnL;

         if(m_tracks[tIdx].bestFavorablePrice <= 0.0)
            m_tracks[tIdx].bestFavorablePrice = p.openPrice;
         if(p.direction == SIGNAL_BUY && p.currentPrice > m_tracks[tIdx].bestFavorablePrice)
            m_tracks[tIdx].bestFavorablePrice = p.currentPrice;
         else if(p.direction == SIGNAL_SELL && p.currentPrice > 0.0 && p.currentPrice < m_tracks[tIdx].bestFavorablePrice)
            m_tracks[tIdx].bestFavorablePrice = p.currentPrice;

         // Synchronize partial-close flag on terminal restarts when volume is already smaller than initialVolume
         if(!m_tracks[tIdx].partialExitTaken && m_tracks[tIdx].initialVolume > 0.0 && p.volume < m_tracks[tIdx].initialVolume * 0.90)
            m_tracks[tIdx].partialExitTaken = true;

         p.initialVolume    = m_tracks[tIdx].initialVolume;
         p.initialSL        = m_tracks[tIdx].initialSL;
         p.mfeMoney         = m_tracks[tIdx].mfeMoney;
         p.maeMoney         = m_tracks[tIdx].maeMoney;
         p.partialExitTaken = m_tracks[tIdx].partialExitTaken;
         p.signalId         = m_tracks[tIdx].signalId;
         p.entryRegime      = m_tracks[tIdx].entryRegime;
         p.lastExitReason   = m_tracks[tIdx].lastExitReason;

         string cmt = PositionGetString(POSITION_COMMENT);
         p.strategyId   = ParseStrategyFromComment(cmt);
         p.strategyName = StrategyIdToName(p.strategyId);
         p.signalScore  = ParseScoreFromComment(cmt);

         if(p.direction == SIGNAL_BUY && p.currentSL >= p.openPrice && p.currentSL > 0.0)
            p.breakEvenApplied = true;
         else if(p.direction == SIGNAL_SELL && p.currentSL <= p.openPrice && p.currentSL > 0.0)
            p.breakEvenApplied = true;

         if(p.currentSL > 0.0)
         {
            double slDist = (p.direction == SIGNAL_BUY) ? MathMax(0.0, p.currentPrice - p.currentSL)
                                                        : MathMax(0.0, p.currentSL - p.currentPrice);
            if(slDist > 0.0)
            {
               if(p.symbol == activeSymbol)
                  p.currentRiskMoney = activeSymIntel.EstimateRiskMoneyForOrder(p.direction, p.volume, p.currentPrice, p.currentSL);
               else
               {
                  double calcRisk = 0.0;
                  ENUM_ORDER_TYPE ot = (p.direction == SIGNAL_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
                  if(OrderCalcProfit(ot, p.symbol, p.volume, p.currentPrice, p.currentSL, calcRisk) &&
                     MathIsValidNumber(calcRisk) && MathAbs(calcRisk) > 0.0)
                     p.currentRiskMoney = MathAbs(calcRisk);
                  else
                  {
                     double tickSz  = SymbolInfoDouble(p.symbol, SYMBOL_TRADE_TICK_SIZE);
                     double tickVal = SymbolInfoDouble(p.symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
                     if(tickVal <= 0.0) tickVal = SymbolInfoDouble(p.symbol, SYMBOL_TRADE_TICK_VALUE);
                     if(tickSz > 0.0 && tickVal > 0.0)
                        p.currentRiskMoney = ((slDist / tickSz) * tickVal) * p.volume;
                  }
               }
            }
         }

         m_positions[m_posCount++] = p;
      }
      ArrayResize(m_positions, m_posCount);
   }

   void ManageSymbolPositions(const string sym, const SAnalysisContext &ctx, const STradeSignal &latestSignal,
                              const CSymbolIntelligence &symIntel, CStrategyBase *&strategies[],
                              const int stratCount, CTradeExecution &exec)
   {
      if(m_posCount <= 0 || !ctx.market.dataReady) return;

      SSymbolProfile prof = symIntel.GetProfile();
      double effAtr = (ctx.ind.isReady && ctx.ind.atr > 0.0)
                      ? ctx.ind.atr
                      : (ctx.market.spreadPoints * prof.point * 6.0);
      double minStopDist = symIntel.GetMinStopDistancePrice();
      datetime now = TimeCurrent();

      // Compute cost-covering break-even price buffer (commission distance + modest 25% spread slippage cushion; entry spread is already in openPrice)
      double lossPerPt = symIntel.GetLossPerLotForPriceDistance(prof.point);
      double commPts   = (lossPerPt > 0.0 && prof.estCommissionPerLot > 0.0) ? (prof.estCommissionPerLot / lossPerPt) : 0.0;
      double costBeBuf = (ctx.market.spreadPoints * 0.25 + commPts + 2.0) * prof.point;

      int tfMinutes = MathMax(1, PeriodSeconds(ctx.market.timeframe) / 60);
      long effMaxHoldMin = (tfMinutes > 5)
                           ? MathMax((long)m_cfg.maxHoldingMinutes, (long)tfMinutes * 16)
                           : (long)m_cfg.maxHoldingMinutes;

      MqlDateTime dt;
      TimeToStruct(now, dt);
      bool weekendClosingWindow = (m_cfg.closeBeforeWeekend && !prof.isSynthetic24x7 &&
                                   dt.day_of_week == FRIDAY && dt.hour >= m_cfg.fridayCloseHour);

      for(int i = 0; i < m_posCount; i++)
      {
         SManagedPosition p = m_positions[i];
         if(p.symbol != sym) continue;

         long holdMin = (long)(now - p.openTime) / 60;
         int tIdx = FindTrackIndex(p.ticket);

         // 0. Optional pre-weekend Friday close protection
         if(weekendClosingWindow)
         {
            string rsn = "Pre-weekend Friday close protection";
            SetExitReason(p.ticket, rsn);
            exec.ClosePosition(p.ticket, p.symbol, rsn, symIntel);
            continue;
         }

         // 1. Maximum holding duration exit (scaled on M15+ charts so swing/intraday bars are not clipped prematurely)
         if(m_cfg.enableMaxHoldExit && m_cfg.maxHoldingMinutes > 0 && holdMin >= effMaxHoldMin)
         {
            string rsn = StringFormat("Max holding duration (%I64d min)", holdMin);
            SetExitReason(p.ticket, rsn);
            exec.ClosePosition(p.ticket, p.symbol, rsn, symIntel);
            continue;
         }

         // 2. Independent strategy-specific exit rule hook
         if(m_cfg.enableStrategyExit)
         {
            int sid = (int)p.strategyId;
            if(sid >= 0 && sid < stratCount && strategies[sid] != NULL)
            {
               string stratExitReason = "";
               if(strategies[sid].ShouldExitPosition(p, ctx, stratExitReason))
               {
                  SetExitReason(p.ticket, stratExitReason);
                  exec.ClosePosition(p.ticket, p.symbol, stratExitReason, symIntel);
                  continue;
               }
            }
         }

         // 3. Opposite strong signal exit (current bar only to avoid stale cached signal triggers)
         if(m_cfg.enableOppositeSignalExit && latestSignal.isValid &&
            latestSignal.timestamp >= ctx.market.barTime &&
            latestSignal.compositeScore >= 72.0 &&
            latestSignal.direction != SIGNAL_NONE && latestSignal.direction != p.direction)
         {
            string rsn = "Opposite high-score signal";
            SetExitReason(p.ticket, rsn);
            exec.ClosePosition(p.ticket, p.symbol, rsn, symIntel);
            continue;
         }

         // 4. Momentum deterioration exit
         if(m_cfg.enableMomentumExit && holdMin >= 15 && ctx.ind.isReady && p.floatingPnL < 0.0)
         {
            if(p.direction == SIGNAL_BUY && ctx.ind.macdHist < 0.0 && ctx.ind.rsi < 40.0 && ctx.market.close < ctx.ind.emaSlow)
            {
               SetExitReason(p.ticket, "Momentum deterioration exit");
               exec.ClosePosition(p.ticket, p.symbol, "Bullish momentum deterioration exit", symIntel);
               continue;
            }
            if(p.direction == SIGNAL_SELL && ctx.ind.macdHist > 0.0 && ctx.ind.rsi > 60.0 && ctx.market.close > ctx.ind.emaSlow)
            {
               SetExitReason(p.ticket, "Momentum deterioration exit");
               exec.ClosePosition(p.ticket, p.symbol, "Bearish momentum deterioration exit", symIntel);
               continue;
            }
         }

         double profitDist = (p.direction == SIGNAL_BUY) ? (ctx.market.bid - p.openPrice) : (p.openPrice - ctx.market.ask);
         double newSL = p.currentSL;

         // 5. Momentum-confirmed CHoCH exit (unconfirmed CHoCH while profitable tightens SL instead of premature close)
         if(m_cfg.enableStructureExit && ctx.structure.isReady && holdMin >= 5 && ctx.ind.isReady)
         {
            if(p.direction == SIGNAL_BUY && ctx.structure.lastEvent == STRUCT_CHOCH_BEAR)
            {
               if(ctx.ind.macdHist < 0.0 && ctx.market.close < ctx.ind.emaFast)
               {
                  SetExitReason(p.ticket, "Bearish CHoCH structure exit");
                  exec.ClosePosition(p.ticket, p.symbol, "Bearish CHoCH structure exit", symIntel);
                  continue;
               }
               else if(profitDist > effAtr * 0.30)
               {
                  double tightSL = ctx.market.bid - effAtr * 0.55;
                  if(tightSL <= ctx.market.bid - minStopDist && (newSL <= 0.0 || tightSL > newSL))
                     newSL = tightSL;
               }
            }
            if(p.direction == SIGNAL_SELL && ctx.structure.lastEvent == STRUCT_CHOCH_BULL)
            {
               if(ctx.ind.macdHist > 0.0 && ctx.market.close > ctx.ind.emaFast)
               {
                  SetExitReason(p.ticket, "Bullish CHoCH structure exit");
                  exec.ClosePosition(p.ticket, p.symbol, "Bullish CHoCH structure exit", symIntel);
                  continue;
               }
               else if(profitDist > effAtr * 0.30)
               {
                  double tightSL = ctx.market.ask + effAtr * 0.55;
                  if(tightSL >= ctx.market.ask + minStopDist && (newSL <= 0.0 || tightSL < newSL))
                     newSL = tightSL;
               }
            }
         }

         // 6. Partial profit scaling (guarded against un-splittable min-lots and immediate post-scale BE)
         bool triggerImmediateBE = false;
         if(m_cfg.enablePartialClose && !p.partialExitTaken && profitDist >= effAtr * m_cfg.partialCloseTriggerAtr)
         {
            double partVol = symIntel.NormalizeVolume(p.volume * MathMax(0.20, MathMin(0.75, m_cfg.partialCloseFraction)));
            if(p.volume >= prof.volumeMin * 2.0 && partVol >= prof.volumeMin && (p.volume - partVol) >= prof.volumeMin)
            {
               if(exec.ClosePartial(p.ticket, partVol, p.symbol, "ATR partial take-profit", symIntel))
               {
                  if(tIdx >= 0) m_tracks[tIdx].partialExitTaken = true;
                  p.partialExitTaken = true;
                  triggerImmediateBE = true;
               }
            }
            else
            {
               // Un-splittable minimum lot size: suppress repeat checks and advance SL to BE instead
               if(tIdx >= 0) m_tracks[tIdx].partialExitTaken = true;
               p.partialExitTaken = true;
               triggerImmediateBE = true;
            }
         }

         // 7. Cost-covering Break-Even & Progressive Tiered Chandelier Trailing (strictly monotonic)
         double bestFav = (tIdx >= 0 && m_tracks[tIdx].bestFavorablePrice > 0.0)
                          ? m_tracks[tIdx].bestFavorablePrice
                          : ((p.direction == SIGNAL_BUY) ? ctx.market.bid : ctx.market.ask);
         double volTrailMult = (ctx.regime.volatilityState == VOL_HIGH) ? 1.15 : 1.0;

         double progMult = 1.0;
         if(m_cfg.useProgressiveTrail && effAtr > 0.0)
         {
            double profitAtr = profitDist / effAtr;
            if(profitAtr >= 3.0)      progMult = 0.55;
            else if(profitAtr >= 2.0) progMult = 0.75;
         }

         double initSlDist = (p.initialSL > 0.0) ? MathAbs(p.openPrice - p.initialSL) : 0.0;
         double effBeTrigger = (initSlDist > 0.0)
                               ? MathMin(effAtr * m_cfg.breakEvenTriggerAtr, MathMax(effAtr * 0.70, initSlDist * 1.02))
                               : (effAtr * m_cfg.breakEvenTriggerAtr);

         if(p.direction == SIGNAL_BUY)
         {
            if((m_cfg.enableBreakEven && profitDist >= effBeTrigger) || triggerImmediateBE)
            {
               double beLock = MathMax(effAtr * m_cfg.breakEvenLockAtr, costBeBuf);
               double beSL = p.openPrice + beLock;
               if(beSL <= ctx.market.bid - minStopDist && (newSL <= 0.0 || beSL > newSL))
                  newSL = beSL;
            }
            if(m_cfg.enableTrailingStop && profitDist >= effAtr * m_cfg.trailingStartAtr)
            {
               double anchor = m_cfg.useChandelierTrail ? MathMax(bestFav, ctx.market.bid) : ctx.market.bid;
               double trailSL = anchor - effAtr * m_cfg.trailingStepAtr * volTrailMult * progMult;
               if(trailSL <= ctx.market.bid - minStopDist && (newSL <= 0.0 || trailSL > newSL))
                  newSL = trailSL;
            }
            if(newSL > 0.0 && (p.currentSL <= 0.0 || newSL > p.currentSL + prof.point))
               exec.ModifyPositionStops(p.ticket, newSL, p.takeProfit, symIntel);
         }
         else if(p.direction == SIGNAL_SELL)
         {
            if((m_cfg.enableBreakEven && profitDist >= effBeTrigger) || triggerImmediateBE)
            {
               double beLock = MathMax(effAtr * m_cfg.breakEvenLockAtr, costBeBuf);
               double beSL = p.openPrice - beLock;
               if(beSL >= ctx.market.ask + minStopDist && (newSL <= 0.0 || beSL < newSL))
                  newSL = beSL;
            }
            if(m_cfg.enableTrailingStop && profitDist >= effAtr * m_cfg.trailingStartAtr)
            {
               double anchor = m_cfg.useChandelierTrail ? MathMin(bestFav, ctx.market.ask) : ctx.market.ask;
               double trailSL = anchor + effAtr * m_cfg.trailingStepAtr * volTrailMult * progMult;
               if(trailSL >= ctx.market.ask + minStopDist && (newSL <= 0.0 || trailSL < newSL))
                  newSL = trailSL;
            }
            if(newSL > 0.0 && (p.currentSL <= 0.0 || newSL < p.currentSL - prof.point))
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
