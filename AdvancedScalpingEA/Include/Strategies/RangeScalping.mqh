//+------------------------------------------------------------------+
//|                                                RangeScalping.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        Strategy 5: Mean-Reversion Range Scalping |
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
      m_maxAdx = MathMax(14.0, MathMin(30.0, maxAdx));
   }

   virtual bool IsSuitableForRegime(const ENUM_MARKET_REGIME regime) const override
   {
      // Strictly avoid applying range scalping in clearly trending markets
      return (regime == REGIME_SIDEWAYS || regime == REGIME_CONSOLIDATION ||
              regime == REGIME_LOW_VOLATILITY || regime == REGIME_VOL_CONTRACTION);
   }

   virtual bool Evaluate(const SAnalysisContext &ctx, STradeSignal &outSignal, string &outRejectReason) override
   {
      outSignal.Reset();
      outRejectReason = "";

      if(!m_enabled) { outRejectReason = "Strategy disabled by input"; return false; }
      if(!IsSuitableForRegime(ctx.regime.regime))
      {
         outRejectReason = "Range strategy blocked in trending/volatile regime: " + ctx.regime.label;
         return false;
      }
      if(!ctx.ind.isReady || !ctx.structure.isReady || ctx.ind.atr <= 0.0)
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
      if(rangeSpan < ctx.ind.atr * 1.5)
      {
         outRejectReason = "Range span too narrow relative to ATR/spread";
         return false;
      }

      double zoneTol = ctx.ind.atr * 0.45;
      bool nearBottom = (ctx.market.low <= ctx.structure.rangeLow + zoneTol) || (ctx.market.low <= ctx.ind.bbLower + zoneTol * 0.4);
      bool nearTop    = (ctx.market.high >= ctx.structure.rangeHigh - zoneTol) || (ctx.market.high >= ctx.ind.bbUpper - zoneTol * 0.4);

      if(nearBottom && ctx.ind.rsi <= 42.0 && ctx.ind.stochK < 35.0 && ctx.market.close > ctx.market.open)
      {
         double slDist = ctx.ind.atr * m_slAtrMult;
         double midTarget = MathMax(ctx.ind.atr * m_tpAtrMult, (ctx.ind.bbMiddle - ctx.market.ask));
         if(midTarget < ctx.ind.atr * 0.8) midTarget = ctx.ind.atr * m_tpAtrMult;
         PopulateCommonSignal(outSignal, ctx, SIGNAL_BUY, slDist, midTarget, 0.72,
                              "Range lower-boundary mean reversion with oversold oscillator confirmation",
                              StringFormat("ADX=%.1f, RSI=%.1f, StochK=%.1f", ctx.ind.adxMain, ctx.ind.rsi, ctx.ind.stochK),
                              ctx.structure.summary, ctx.candle.name, "None");
         return true;
      }

      if(nearTop && ctx.ind.rsi >= 58.0 && ctx.ind.stochK > 65.0 && ctx.market.close < ctx.market.open)
      {
         double slDist = ctx.ind.atr * m_slAtrMult;
         double midTarget = MathMax(ctx.ind.atr * m_tpAtrMult, (ctx.market.bid - ctx.ind.bbMiddle));
         if(midTarget < ctx.ind.atr * 0.8) midTarget = ctx.ind.atr * m_tpAtrMult;
         PopulateCommonSignal(outSignal, ctx, SIGNAL_SELL, slDist, midTarget, 0.72,
                              "Range upper-boundary mean reversion with overbought oscillator confirmation",
                              StringFormat("ADX=%.1f, RSI=%.1f, StochK=%.1f", ctx.ind.adxMain, ctx.ind.rsi, ctx.ind.stochK),
                              ctx.structure.summary, ctx.candle.name, "None");
         return true;
      }

      outRejectReason = "Price not at validated range boundary with oscillator confirmation";
      return false;
   }
};

#endif // __ASEA_STRATEGIES_RANGESCALPING_MQH__
