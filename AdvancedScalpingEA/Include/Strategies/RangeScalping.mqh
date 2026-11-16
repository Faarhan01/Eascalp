//+------------------------------------------------------------------+
//|                                                RangeScalping.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.0.0 Strategy 5: Mean-Reversion Range   |
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
      m_maxAdx = 24.0;
   }

   void Configure(const bool enabled, const double slMult, const double tpMult, const int minSample, const double maxAdx)
   {
      ConfigureBase(enabled, slMult, tpMult, minSample);
      m_maxAdx = MathMax(14.0, MathMin(30.0, maxAdx));
   }

   virtual ENUM_STRATEGY_SUITABILITY GetRegimeSuitability(const ENUM_MARKET_REGIME regime) const override
   {
      if(regime == REGIME_SIDEWAYS || regime == REGIME_WIDE_CONSOLIDATION)
         return SUIT_SUITABLE;
      if(regime == REGIME_TIGHT_CONSOLIDATION || regime == REGIME_VOL_CONTRACTION)
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
         outRejectReason = "Range strategy strictly blocked outside sideways/consolidation: " + ctx.regime.label;
         return false;
      }
      if(!ctx.ind.isReady || !ctx.structure.isReady || ctx.ind.atr <= 0.0 || ctx.symbolProfile.point <= 0.0)
      {
         outRejectReason = "Indicators or structure not ready";
         return false;
      }
      if(ctx.ind.adxMain > m_maxAdx)
      {
         outRejectReason = StringFormat("ADX %.1f exceeds range ceiling %.1f", ctx.ind.adxMain, m_maxAdx);
         return false;
      }

      double rangeSpan = ctx.structure.rangeHigh - ctx.structure.rangeLow;
      double spreadPrice = ctx.market.spreadPoints * ctx.symbolProfile.point;
      if(rangeSpan < ctx.ind.atr * 1.60 || rangeSpan < spreadPrice * 7.0)
      {
         outRejectReason = "Range width too narrow relative to ATR/spread cost";
         return false;
      }

      // Range invalidation guard if active breakout occurred
      if(ctx.structure.lastEvent == STRUCT_BREAKOUT_UP || ctx.structure.lastEvent == STRUCT_BREAKOUT_DOWN ||
         ctx.structure.lastEvent == STRUCT_BOS_BULL || ctx.structure.lastEvent == STRUCT_BOS_BEAR)
      {
         outRejectReason = "Range invalidated by active breakout/BOS";
         return false;
      }

      double zoneTol = ctx.ind.atr * 0.50;
      bool nearBottom = (ctx.market.low <= ctx.structure.rangeLow + zoneTol) || (ctx.market.low <= ctx.ind.bbLower + zoneTol * 0.4);
      bool nearTop    = (ctx.market.high >= ctx.structure.rangeHigh - zoneTol) || (ctx.market.high >= ctx.ind.bbUpper - zoneTol * 0.4);

      if(nearBottom && (ctx.structure.supportRejectCount >= 1 || ctx.market.low <= ctx.ind.bbLower) &&
         ctx.ind.rsi <= 46.0 && (ctx.ind.stochK < 45.0 || ctx.ind.wpr < -60.0) &&
         ctx.market.close > ctx.market.open && ctx.candle.bias != SIGNAL_SELL)
      {
         double slStruct = (ctx.market.ask > ctx.structure.rangeLow)
                           ? MathMin(ctx.ind.atr * m_slAtrMult, MathMax(ctx.ind.atr * 0.80, (ctx.market.ask - ctx.structure.rangeLow) + ctx.ind.atr * 0.28))
                           : ctx.ind.atr * m_slAtrMult;
         double slDist = MathMin(ComputeStructuralSLDist(ctx, SIGNAL_BUY, m_slAtrMult, m_slAtrMult * 1.25), slStruct);
         double roomToTop = MathMax(slDist * 1.15, (ctx.structure.rangeHigh - ctx.market.ask) * 0.82);
         double midTarget = MathMax(slDist * 1.15, MathMin(ctx.ind.atr * m_tpAtrMult, roomToTop));
         double rawConf = (ctx.structure.supportRejectCount >= 2) ? 0.78 : 0.71;
         PopulateCommonSignal(outSignal, ctx, SIGNAL_BUY, slDist, midTarget, rawConf,
                              StringFormat("Range lower-boundary bounce (%d rejections) with oversold oscillator", ctx.structure.supportRejectCount),
                              StringFormat("ADX=%.1f, RSI=%.1f, StochK=%.1f, Width=%.1f ATR", ctx.ind.adxMain, ctx.ind.rsi, ctx.ind.stochK, ctx.structure.rangeWidthAtr),
                              ctx.structure.summary, ctx.candle.name, "None");
         return true;
      }

      if(nearTop && (ctx.structure.resistanceRejectCount >= 1 || ctx.market.high >= ctx.ind.bbUpper) &&
         ctx.ind.rsi >= 54.0 && (ctx.ind.stochK > 55.0 || ctx.ind.wpr > -40.0) &&
         ctx.market.close < ctx.market.open && ctx.candle.bias != SIGNAL_BUY)
      {
         double slStruct = (ctx.structure.rangeHigh > ctx.market.bid)
                           ? MathMin(ctx.ind.atr * m_slAtrMult, MathMax(ctx.ind.atr * 0.80, (ctx.structure.rangeHigh - ctx.market.bid) + ctx.ind.atr * 0.28))
                           : ctx.ind.atr * m_slAtrMult;
         double slDist = MathMin(ComputeStructuralSLDist(ctx, SIGNAL_SELL, m_slAtrMult, m_slAtrMult * 1.25), slStruct);
         double roomToBot = MathMax(slDist * 1.15, (ctx.market.bid - ctx.structure.rangeLow) * 0.82);
         double midTarget = MathMax(slDist * 1.15, MathMin(ctx.ind.atr * m_tpAtrMult, roomToBot));
         double rawConf = (ctx.structure.resistanceRejectCount >= 2) ? 0.78 : 0.71;
         PopulateCommonSignal(outSignal, ctx, SIGNAL_SELL, slDist, midTarget, rawConf,
                              StringFormat("Range upper-boundary fade (%d rejections) with overbought oscillator", ctx.structure.resistanceRejectCount),
                              StringFormat("ADX=%.1f, RSI=%.1f, StochK=%.1f, Width=%.1f ATR", ctx.ind.adxMain, ctx.ind.rsi, ctx.ind.stochK, ctx.structure.rangeWidthAtr),
                              ctx.structure.summary, ctx.candle.name, "None");
         return true;
      }

      outRejectReason = "Price not at validated multi-touch range boundary";
      return false;
   }

   virtual bool ShouldExitPosition(const SManagedPosition &pos, const SAnalysisContext &ctx, string &outExitReason) const override
   {
      if(pos.holdingSeconds < 120 || !ctx.structure.isReady) return false;
      if(ctx.regime.isTrending && ctx.ind.adxMain > m_maxAdx + 6.0)
      {
         outExitReason = "Range exit: regime shifted into directional trend";
         return true;
      }
      if(pos.direction == SIGNAL_BUY && (ctx.structure.lastEvent == STRUCT_BREAKOUT_DOWN || (pos.floatingPnL > 0.0 && ctx.market.close >= ctx.structure.rangeHigh - ctx.ind.atr * 0.2)))
      {
         outExitReason = "Range exit: opposite range boundary reached or downside breakdown";
         return true;
      }
      if(pos.direction == SIGNAL_SELL && (ctx.structure.lastEvent == STRUCT_BREAKOUT_UP || (pos.floatingPnL > 0.0 && ctx.market.close <= ctx.structure.rangeLow + ctx.ind.atr * 0.2)))
      {
         outExitReason = "Range exit: opposite range boundary reached or upside breakout";
         return true;
      }
      return false;
   }
};

#endif // __ASEA_STRATEGIES_RANGESCALPING_MQH__
