//+------------------------------------------------------------------+
//|                                                MicroMomentum.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        Strategy 7: Tick Micro-Momentum Scalping  |
//+------------------------------------------------------------------+
#ifndef __ASEA_STRATEGIES_MICROMOMENTUM_MQH__
#define __ASEA_STRATEGIES_MICROMOMENTUM_MQH__

#include "StrategyBase.mqh"

class CStrategyMicroMomentum : public CStrategyBase
{
private:
   int    m_minConsecTicks;
   double m_minVelocityPtsSec;
   double m_maxSpreadToAtrPct;

public:
   CStrategyMicroMomentum() : CStrategyBase(STRAT_MICRO_MOMENTUM, "Micro-Momentum")
   {
      m_minConsecTicks = 4;
      m_minVelocityPtsSec = 2.0;
      m_maxSpreadToAtrPct = 18.0;
   }

   void Configure(const bool enabled, const double slMult, const double tpMult, const int minSample,
                  const int minConsecTicks, const double minVel, const double maxSpreadAtrPct)
   {
      ConfigureBase(enabled, slMult, tpMult, minSample);
      m_minConsecTicks    = MathMax(3, MathMin(12, minConsecTicks));
      m_minVelocityPtsSec = MathMax(0.2, minVel);
      m_maxSpreadToAtrPct = MathMax(5.0, MathMin(40.0, maxSpreadAtrPct));
   }

   virtual bool IsSuitableForRegime(const ENUM_MARKET_REGIME regime) const override
   {
      return (regime != REGIME_UNSTABLE && regime != REGIME_LOW_VOLATILITY);
   }

   virtual bool Evaluate(const SAnalysisContext &ctx, STradeSignal &outSignal, string &outRejectReason) override
   {
      outSignal.Reset();
      outRejectReason = "";

      if(!m_enabled) { outRejectReason = "Strategy disabled by input"; return false; }
      if(!IsSuitableForRegime(ctx.regime.regime))
      {
         outRejectReason = "Regime unsuitable for micro-momentum: " + ctx.regime.label;
         return false;
      }
      if(!ctx.ticks.isReady || !ctx.ind.isReady || ctx.ind.atr <= 0.0 || ctx.symbolProfile.point <= 0.0)
      {
         outRejectReason = "Tick buffer or ATR not ready";
         return false;
      }

      // Mandatory spread & execution-cost filter
      if(ctx.ticks.spreadSpikeDetected || ctx.market.spreadRatio > 1.45)
      {
         outRejectReason = StringFormat("Spread expansion blocked micro-momentum (ratio=%.2f)", ctx.market.spreadRatio);
         return false;
      }
      double spreadPrice = ctx.market.spreadPoints * ctx.symbolProfile.point;
      double spreadToAtrPct = (spreadPrice / ctx.ind.atr) * 100.0;
      if(spreadToAtrPct > m_maxSpreadToAtrPct)
      {
         outRejectReason = StringFormat("Execution cost too high: spread %.1f%% of ATR (limit %.1f%%)", spreadToAtrPct, m_maxSpreadToAtrPct);
         return false;
      }

      bool bullBurst = (ctx.ticks.consecutiveUpTicks >= m_minConsecTicks &&
                        ctx.ticks.priceVelocity >= m_minVelocityPtsSec &&
                        ctx.ticks.priceAcceleration > 0.0 &&
                        ctx.ticks.microTrendBias >= 0.45 &&
                        ctx.ind.emaFast >= ctx.ind.emaMedium &&
                        ctx.mtf.higherBias != SIGNAL_SELL);

      if(bullBurst)
      {
         double slDist = ctx.ind.atr * m_slAtrMult;
         double tpDist = ctx.ind.atr * m_tpAtrMult;
         PopulateCommonSignal(outSignal, ctx, SIGNAL_BUY, slDist, tpDist, 0.70,
                              "Bullish tick velocity & acceleration burst passing spread-cost filter",
                              StringFormat("UpTicks=%d, Vel=%.2f pts/s, SpreadCost=%.1f%% ATR", ctx.ticks.consecutiveUpTicks, ctx.ticks.priceVelocity, spreadToAtrPct),
                              ctx.structure.summary, ctx.candle.name,
                              ctx.mtf.hasStrongConflict ? ctx.mtf.conflictReason : "None");
         return true;
      }

      bool bearBurst = (ctx.ticks.consecutiveDownTicks >= m_minConsecTicks &&
                        ctx.ticks.priceVelocity <= -m_minVelocityPtsSec &&
                        ctx.ticks.priceAcceleration < 0.0 &&
                        ctx.ticks.microTrendBias <= -0.45 &&
                        ctx.ind.emaFast <= ctx.ind.emaMedium &&
                        ctx.mtf.higherBias != SIGNAL_BUY);

      if(bearBurst)
      {
         double slDist = ctx.ind.atr * m_slAtrMult;
         double tpDist = ctx.ind.atr * m_tpAtrMult;
         PopulateCommonSignal(outSignal, ctx, SIGNAL_SELL, slDist, tpDist, 0.70,
                              "Bearish tick velocity & acceleration burst passing spread-cost filter",
                              StringFormat("DownTicks=%d, Vel=%.2f pts/s, SpreadCost=%.1f%% ATR", ctx.ticks.consecutiveDownTicks, ctx.ticks.priceVelocity, spreadToAtrPct),
                              ctx.structure.summary, ctx.candle.name,
                              ctx.mtf.hasStrongConflict ? ctx.mtf.conflictReason : "None");
         return true;
      }

      outRejectReason = "Tick velocity/consecutive-run/HTF alignment criteria not met";
      return false;
   }
};

#endif // __ASEA_STRATEGIES_MICROMOMENTUM_MQH__
