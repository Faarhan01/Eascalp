//+------------------------------------------------------------------+
//|                                                RangeScalping.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v3.1.0 Strategy 5: Multi-Touch Range    |
//+------------------------------------------------------------------+
#ifndef __ASEA_STRATEGIES_RANGESCALPING_MQH__
#define __ASEA_STRATEGIES_RANGESCALPING_MQH__

#include "StrategyBase.mqh"

class CStrategyRangeScalping : public CStrategyBase
{
private:
   double m_maxAdx;

public:
   CStrategyRangeScalping() : CStrategyBase(STRAT_RANGE_SCALPING, "Range Scalping")
   {
      m_maxAdx = 22.0;
   }

   void Configure(const bool enabled, const double slMult, const double tpMult, const int minSample, const double maxAdx)
   {
      ConfigureBase(enabled, slMult, tpMult, minSample);
      m_maxAdx = MathMax(14.0, MathMin(28.0, maxAdx));
   }

   virtual ENUM_STRATEGY_SUITABILITY GetRegimeSuitability(const ENUM_MARKET_REGIME regime) const override
   {
      if(regime == REGIME_SIDEWAYS || regime == REGIME_WIDE_CONSOLIDATION)
         return SUIT_SUITABLE;
      if(regime == REGIME_VOL_CONTRACTION)
         return SUIT_CONDITIONAL;
      return SUIT_UNSUITABLE;
   }

   virtual bool Evaluate(const SAnalysisContext &ctx, STradeSignal &outSignal, string &outRejectReason) override
   {
      outSignal.Reset();
      outRejectReason = "";

      if(!m_enabled) { outRejectReason = "Strategy disabled by input"; return false; }
      if(!IsSuitableForRegime(ctx.regime.regime))
      {
         outRejectReason = "Range strategy strictly blocked outside wide sideways/consolidation: " + ctx.regime.label;
         return false;
      }
      if(!ctx.ind.isReady || !ctx.structure.isReady || ctx.ind.atr <= 0.0 || ctx.symbolProfile.point <= 0.0)
      {
         outRejectReason = "Indicators or structure not ready";
         return false;
      }
      double effMaxAdx = MathMin(m_maxAdx, 19.5);
      if(ctx.ind.adxMain > effMaxAdx)
      {
         outRejectReason = StringFormat("ADX %.1f exceeds range ceiling %.1f", ctx.ind.adxMain, effMaxAdx);
         return false;
      }
      if(ctx.regime.efficiencyRatio > 0.30)
      {
         outRejectReason = StringFormat("Efficiency ratio %.2f too directional for range mean-reversion", ctx.regime.efficiencyRatio);
         return false;
      }

      double rangeSpan = ctx.structure.rangeHigh - ctx.structure.rangeLow;
      double spreadPrice = ctx.market.spreadPoints * ctx.symbolProfile.point;
      if(rangeSpan < MathMax(ctx.ind.atr * 2.40, spreadPrice * 12.0))
      {
         outRejectReason = "Range width too narrow relative to 2.4 ATR / spread cost";
         return false;
      }

      // Range invalidation guard if active breakout occurred
      if(ctx.structure.lastEvent == STRUCT_BREAKOUT_UP || ctx.structure.lastEvent == STRUCT_BREAKOUT_DOWN ||
         ctx.structure.lastEvent == STRUCT_BOS_BULL || ctx.structure.lastEvent == STRUCT_BOS_BEAR)
      {
         outRejectReason = "Range invalidated by active breakout/BOS";
         return false;
      }

      double effSlMult = GetEffectiveSlMult(ctx, 0.95);
      double effTpMult = GetEffectiveTpMult(ctx, 0.90);
      double zoneTol = ctx.ind.atr * 0.38;
      double barRange = MathMax(ctx.market.high - ctx.market.low, ctx.symbolProfile.point);
      double body = MathAbs(ctx.market.close - ctx.market.open);
      bool bullCloseConv = (ctx.market.close > ctx.market.open) && (body >= barRange * 0.25) && ((ctx.market.close - ctx.market.low) >= barRange * 0.58);
      bool bearCloseConv = (ctx.market.close < ctx.market.open) && (body >= barRange * 0.25) && ((ctx.market.high - ctx.market.close) >= barRange * 0.58);

      bool nearBottom = (ctx.market.low <= ctx.structure.rangeLow + zoneTol) &&
                        (ctx.market.low <= ctx.ind.bbLower + zoneTol * 0.45) &&
                        (ctx.structure.swingRangePos01 <= 0.32 || ctx.ind.donchianPos01 <= 0.25);
      bool nearTop    = (ctx.market.high >= ctx.structure.rangeHigh - zoneTol) &&
                        (ctx.market.high >= ctx.ind.bbUpper - zoneTol * 0.45) &&
                        (ctx.structure.swingRangePos01 >= 0.68 || ctx.ind.donchianPos01 >= 0.75);

      // Strictly block fading against active higher-timeframe direction
      bool bullHtfAllowed = (ctx.mtf.higherBias == SIGNAL_NONE || ctx.mtf.higherBias == SIGNAL_BUY);
      bool bearHtfAllowed = (ctx.mtf.higherBias == SIGNAL_NONE || ctx.mtf.higherBias == SIGNAL_SELL);

      if(nearBottom && bullHtfAllowed &&
         ctx.structure.supportRejectCount >= 2 &&
         ctx.ind.rsi <= 36.0 && ctx.ind.stochK < 30.0 &&
         bullCloseConv && ctx.candle.bias != SIGNAL_SELL)
      {
         double slStruct = (ctx.market.ask > ctx.structure.rangeLow)
                           ? MathMin(ctx.ind.atr * effSlMult, MathMax(ctx.ind.atr * 0.90, (ctx.market.ask - ctx.structure.rangeLow) + ctx.ind.atr * 0.30))
                           : ctx.ind.atr * effSlMult;
         double slDist = MathMin(ComputeStructuralSLDist(ctx, SIGNAL_BUY, effSlMult, effSlMult * 1.25), slStruct);
         if(!HasClearRoomToTarget(ctx, SIGNAL_BUY, slDist, false))
         {
            outRejectReason = "Insufficient headroom to overhead resistance / HTF high";
            return false;
         }
         double roomToTop = (ctx.structure.rangeHigh - ctx.market.ask) * 0.85;
         if(roomToTop < slDist * 1.55)
         {
            outRejectReason = "Insufficient range headroom to upper boundary for >=1.55 R:R";
            return false;
         }
         double midTarget = MathMax(slDist * 1.55, MathMin(ctx.ind.atr * effTpMult, roomToTop));
         PopulateCommonSignal(outSignal, ctx, SIGNAL_BUY, slDist, midTarget, 0.82,
                              StringFormat("Multi-touch range lower bounce (%d rejections, Swing=%.0f%%) + OS oscillator", ctx.structure.supportRejectCount, ctx.structure.swingRangePos01 * 100.0),
                              StringFormat("ADX=%.1f, ER=%.2f, RSI=%.1f, StochK=%.1f, Width=%.1f ATR", ctx.ind.adxMain, ctx.regime.efficiencyRatio, ctx.ind.rsi, ctx.ind.stochK, ctx.structure.rangeWidthAtr),
                              ctx.structure.summary, ctx.candle.name, "None");
         return true;
      }

      if(nearTop && bearHtfAllowed &&
         ctx.structure.resistanceRejectCount >= 2 &&
         ctx.ind.rsi >= 64.0 && ctx.ind.stochK > 70.0 &&
         bearCloseConv && ctx.candle.bias != SIGNAL_BUY)
      {
         double slStruct = (ctx.structure.rangeHigh > ctx.market.bid)
                           ? MathMin(ctx.ind.atr * effSlMult, MathMax(ctx.ind.atr * 0.90, (ctx.structure.rangeHigh - ctx.market.bid) + ctx.ind.atr * 0.30))
                           : ctx.ind.atr * effSlMult;
         double slDist = MathMin(ComputeStructuralSLDist(ctx, SIGNAL_SELL, effSlMult, effSlMult * 1.25), slStruct);
         if(!HasClearRoomToTarget(ctx, SIGNAL_SELL, slDist, false))
         {
            outRejectReason = "Insufficient headroom to floor support / HTF low";
            return false;
         }
         double roomToBot = (ctx.market.bid - ctx.structure.rangeLow) * 0.85;
         if(roomToBot < slDist * 1.55)
         {
            outRejectReason = "Insufficient range headroom to lower boundary for >=1.55 R:R";
            return false;
         }
         double midTarget = MathMax(slDist * 1.55, MathMin(ctx.ind.atr * effTpMult, roomToBot));
         PopulateCommonSignal(outSignal, ctx, SIGNAL_SELL, slDist, midTarget, 0.82,
                              StringFormat("Multi-touch range upper fade (%d rejections, Swing=%.0f%%) + OB oscillator", ctx.structure.resistanceRejectCount, ctx.structure.swingRangePos01 * 100.0),
                              StringFormat("ADX=%.1f, ER=%.2f, RSI=%.1f, StochK=%.1f, Width=%.1f ATR", ctx.ind.adxMain, ctx.regime.efficiencyRatio, ctx.ind.rsi, ctx.ind.stochK, ctx.structure.rangeWidthAtr),
                              ctx.structure.summary, ctx.candle.name, "None");
         return true;
      }

      outRejectReason = "Price not at validated >=2-touch extremum range boundary";
      return false;
   }

   virtual bool ShouldExitPosition(const SManagedPosition &pos, const SAnalysisContext &ctx, string &outExitReason) const override
   {
      if(pos.holdingSeconds < 240 || !ctx.structure.isReady) return false;
      if(pos.direction == SIGNAL_BUY && (ctx.structure.lastEvent == STRUCT_BREAKOUT_DOWN || (pos.floatingPnL > 0.0 && ctx.market.close >= ctx.structure.rangeHigh - ctx.ind.atr * 0.15)))
      {
         outExitReason = "Range exit: opposite range boundary reached or downside breakdown";
         return true;
      }
      if(pos.direction == SIGNAL_SELL && (ctx.structure.lastEvent == STRUCT_BREAKOUT_UP || (pos.floatingPnL > 0.0 && ctx.market.close <= ctx.structure.rangeLow + ctx.ind.atr * 0.15)))
      {
         outExitReason = "Range exit: opposite range boundary reached or upside breakout";
         return true;
      }
      return false;
   }
};

#endif // __ASEA_STRATEGIES_RANGESCALPING_MQH__
