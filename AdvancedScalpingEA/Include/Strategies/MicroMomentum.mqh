//+------------------------------------------------------------------+
//|                                                MicroMomentum.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.9.0 Strategy 7: Tick Micro-Momentum    |
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
      m_minConsecTicks = 5;
      m_minVelocityPtsSec = 1.0;
      m_maxSpreadToAtrPct = 20.0;
   }

   void Configure(const bool enabled, const double slMult, const double tpMult, const int minSample,
                  const int minConsecTicks, const double minVel, const double maxSpreadAtrPct)
   {
      ConfigureBase(enabled, slMult, tpMult, minSample);
      m_minConsecTicks    = MathMax(4, MathMin(12, minConsecTicks));
      m_minVelocityPtsSec = MathMax(0.2, minVel);
      m_maxSpreadToAtrPct = MathMax(5.0, MathMin(40.0, maxSpreadAtrPct));
   }

   virtual ENUM_STRATEGY_SUITABILITY GetRegimeSuitability(const ENUM_MARKET_REGIME regime) const override
   {
      if(regime == REGIME_STRONG_BULL_TREND || regime == REGIME_STRONG_BEAR_TREND ||
         regime == REGIME_EARLY_TREND_BULL || regime == REGIME_EARLY_TREND_BEAR ||
         regime == REGIME_VOL_EXPANSION)
         return SUIT_SUITABLE;
      if(regime == REGIME_ESTABLISHED_BULL || regime == REGIME_ESTABLISHED_BEAR ||
         regime == REGIME_WEAK_BULL_TREND || regime == REGIME_WEAK_BEAR_TREND)
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
         outRejectReason = "Regime unsuitable for tick micro-momentum: " + ctx.regime.label;
         return false;
      }
      if(!ctx.ticks.isReady || !ctx.ind.isReady || ctx.ind.atr <= 0.0 || ctx.symbolProfile.point <= 0.0)
      {
         outRejectReason = "Tick buffer or ATR not ready";
         return false;
      }
      if(ctx.ind.adxMain < 20.0)
      {
         outRejectReason = StringFormat("ADX %.1f below 20.0 micro-momentum trend floor", ctx.ind.adxMain);
         return false;
      }

      // Cost-validated tick edge + strict spread ceiling
      bool strongTickRun = ((ctx.ticks.consecutiveUpTicks >= m_minConsecTicks || ctx.ticks.consecutiveDownTicks >= m_minConsecTicks) &&
                            ctx.ticks.directionalPersistence >= 0.62 &&
                            MathAbs(ctx.ticks.shortTermDisplacement) > ctx.market.spreadPoints * 1.25);
      if(!ctx.ticks.tickProvidesNetEdge && !strongTickRun)
      {
         outRejectReason = "Tick displacement does not clear spread/execution cost safety factor";
         return false;
      }
      if(ctx.ticks.spreadSpikeDetected || ctx.market.spreadRatio > 1.65)
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
      if(ctx.ticks.momentumDeteriorating || ctx.ticks.directionalPersistence < 0.62)
      {
         outRejectReason = StringFormat("Tick persistence %.2f too low or velocity decelerating", ctx.ticks.directionalPersistence);
         return false;
      }
      if(ctx.ind.momentumExhaustion || MathAbs(ctx.ind.emaDistanceAtr) > 1.85 || ctx.structure.failedBreakout)
      {
         outRejectReason = StringFormat("Overextended (%.2f ATR) or momentum exhaustion / failed breakout", ctx.ind.emaDistanceAtr);
         return false;
      }

      double pipPts = (ctx.symbolProfile.pipSize > 0.0 && ctx.symbolProfile.point > 0.0)
                      ? MathMax(1.0, ctx.symbolProfile.pipSize / ctx.symbolProfile.point)
                      : 1.0;
      double effMinVel = MathMax(0.30, m_minVelocityPtsSec * MathMax(0.25, pipPts * 0.1));
      double effSlMult = GetEffectiveSlMult(ctx, 1.00);
      double effTpMult = GetEffectiveTpMult(ctx, 0.95);
      bool bullMtfTailwind = (ctx.mtf.higherBias == SIGNAL_BUY) || (ctx.mtf.higherBias == SIGNAL_NONE && ctx.mtf.intermediateBias == SIGNAL_BUY);
      bool bearMtfTailwind = (ctx.mtf.higherBias == SIGNAL_SELL) || (ctx.mtf.higherBias == SIGNAL_NONE && ctx.mtf.intermediateBias == SIGNAL_SELL);

      bool bullBurst = (ctx.ticks.consecutiveUpTicks >= m_minConsecTicks &&
                        ctx.ticks.priceVelocity >= effMinVel &&
                        ctx.ticks.priceAcceleration >= 0.0 &&
                        ctx.ticks.microTrendBias >= 0.35 &&
                        ctx.ind.emaFast > ctx.ind.emaMedium &&
                        ctx.ind.emaMedium > ctx.ind.emaSlow &&
                        ctx.ind.macdHist > 0.0 &&
                        ctx.ind.rsi >= 48.0 && ctx.ind.rsi <= 70.0 &&
                        bullMtfTailwind);

      if(bullBurst)
      {
         double slDist = ComputeStructuralSLDist(ctx, SIGNAL_BUY, effSlMult, effSlMult * 1.30);
         double tpDist = MathMax(slDist * 1.45, ctx.ind.atr * effTpMult);
         PopulateCommonSignal(outSignal, ctx, SIGNAL_BUY, slDist, tpDist, 0.76,
                              "Bullish cost-validated tick velocity, EMA-stack & MTF burst",
                              StringFormat("UpTicks=%d, Vel=%.2f pts/s, Persist=%.2f, ADX=%.1f",
                                           ctx.ticks.consecutiveUpTicks, ctx.ticks.priceVelocity, ctx.ticks.directionalPersistence, ctx.ind.adxMain),
                              ctx.structure.summary, ctx.candle.name,
                              ctx.mtf.hasStrongConflict ? ctx.mtf.conflictReason : "None");
         return true;
      }

      bool bearBurst = (ctx.ticks.consecutiveDownTicks >= m_minConsecTicks &&
                        ctx.ticks.priceVelocity <= -effMinVel &&
                        ctx.ticks.priceAcceleration <= 0.0 &&
                        ctx.ticks.microTrendBias <= -0.35 &&
                        ctx.ind.emaFast < ctx.ind.emaMedium &&
                        ctx.ind.emaMedium < ctx.ind.emaSlow &&
                        ctx.ind.macdHist < 0.0 &&
                        ctx.ind.rsi <= 52.0 && ctx.ind.rsi >= 30.0 &&
                        bearMtfTailwind);

      if(bearBurst)
      {
         double slDist = ComputeStructuralSLDist(ctx, SIGNAL_SELL, effSlMult, effSlMult * 1.30);
         double tpDist = MathMax(slDist * 1.45, ctx.ind.atr * effTpMult);
         PopulateCommonSignal(outSignal, ctx, SIGNAL_SELL, slDist, tpDist, 0.76,
                              "Bearish cost-validated tick velocity, EMA-stack & MTF burst",
                              StringFormat("DownTicks=%d, Vel=%.2f pts/s, Persist=%.2f, ADX=%.1f",
                                           ctx.ticks.consecutiveDownTicks, ctx.ticks.priceVelocity, ctx.ticks.directionalPersistence, ctx.ind.adxMain),
                              ctx.structure.summary, ctx.candle.name,
                              ctx.mtf.hasStrongConflict ? ctx.mtf.conflictReason : "None");
         return true;
      }

      outRejectReason = "Tick velocity/persistence/EMA-stack/MTF criteria not met";
      return false;
   }

   virtual bool ShouldExitPosition(const SManagedPosition &pos, const SAnalysisContext &ctx, string &outExitReason) const override
   {
      if(pos.holdingSeconds < 30 || !ctx.ticks.isReady) return false;
      if(pos.direction == SIGNAL_BUY && ctx.ticks.momentumDeteriorating && ctx.ticks.microTrendBias < -0.35)
      {
         outExitReason = "MicroMomentum exit: tick burst reversed downward";
         return true;
      }
      if(pos.direction == SIGNAL_SELL && ctx.ticks.momentumDeteriorating && ctx.ticks.microTrendBias > 0.35)
      {
         outExitReason = "MicroMomentum exit: tick burst reversed upward";
         return true;
      }
      return false;
   }
};

#endif // __ASEA_STRATEGIES_MICROMOMENTUM_MQH__
