//+------------------------------------------------------------------+
//|                                                MicroMomentum.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v3.1.0 Strategy 7: Tick Micro-Momentum    |
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
      m_minConsecTicks = 7;
      m_minVelocityPtsSec = 1.2;
      m_maxSpreadToAtrPct = 12.0;
   }

   void Configure(const bool enabled, const double slMult, const double tpMult, const int minSample,
                  const int minConsecTicks, const double minVel, const double maxSpreadAtrPct)
   {
      ConfigureBase(enabled, slMult, tpMult, minSample);
      m_minConsecTicks    = MathMax(5, MathMin(15, minConsecTicks));
      m_minVelocityPtsSec = MathMax(0.2, minVel);
      m_maxSpreadToAtrPct = MathMax(5.0, MathMin(30.0, maxSpreadAtrPct));
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
      if(ctx.ind.adxMain < 21.0 || (!ctx.ind.adxRising && ctx.ind.adxMain < 24.0))
      {
         outRejectReason = StringFormat("ADX %.1f below floor or non-expanding for micro-momentum", ctx.ind.adxMain);
         return false;
      }

      // Cost-validated tick edge + strict persistence & spread ceiling
      bool strongTickRun = ((ctx.ticks.consecutiveUpTicks >= m_minConsecTicks || ctx.ticks.consecutiveDownTicks >= m_minConsecTicks) &&
                            ctx.ticks.directionalPersistence >= 0.72 &&
                            MathAbs(ctx.ticks.shortTermDisplacement) > ctx.market.spreadPoints * 2.00);
      if(!ctx.ticks.tickProvidesNetEdge || !strongTickRun)
      {
         outRejectReason = "Tick run/persistence (<0.72) or displacement (<2x spread) insufficient";
         return false;
      }
      if(ctx.ticks.spreadSpikeDetected || ctx.market.spreadRatio > 1.50)
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
      if(ctx.ticks.momentumDeteriorating)
      {
         outRejectReason = "Tick velocity decelerating";
         return false;
      }
      if(ctx.ind.momentumExhaustion || MathAbs(ctx.ind.emaDistanceAtr) > 1.25 || ctx.structure.failedBreakout)
      {
         outRejectReason = StringFormat("Overextended (%.2f ATR > 1.25) or momentum exhaustion / failed breakout", ctx.ind.emaDistanceAtr);
         return false;
      }

      double pipPts = (ctx.symbolProfile.pipSize > 0.0 && ctx.symbolProfile.point > 0.0)
                      ? MathMax(1.0, ctx.symbolProfile.pipSize / ctx.symbolProfile.point)
                      : 1.0;
      double effMinVel = MathMax(0.40, m_minVelocityPtsSec * MathMax(0.25, pipPts * 0.1));
      double effSlMult = GetEffectiveSlMult(ctx, 1.00);
      double effTpMult = GetEffectiveTpMult(ctx, 1.00);
      bool bullMtfTailwind = (ctx.mtf.higherBias == SIGNAL_BUY && ctx.mtf.intermediateBias == SIGNAL_BUY);
      bool bearMtfTailwind = (ctx.mtf.higherBias == SIGNAL_SELL && ctx.mtf.intermediateBias == SIGNAL_SELL);

      bool bullRangeOk = !ctx.structure.isReady || (ctx.structure.swingRangePos01 <= 0.78);
      bool bearRangeOk = !ctx.structure.isReady || (ctx.structure.swingRangePos01 >= 0.22);

      bool bullBurst = (bullRangeOk &&
                        ctx.ticks.consecutiveUpTicks >= m_minConsecTicks &&
                        ctx.ticks.priceVelocity >= effMinVel &&
                        ctx.ticks.priceAcceleration >= 0.0 &&
                        ctx.ticks.microTrendBias >= 0.45 &&
                        ctx.ind.emaFast > ctx.ind.emaMedium &&
                        ctx.ind.emaMedium > ctx.ind.emaSlow &&
                        ctx.ind.macdHist > 0.0 &&
                        ctx.ind.rsi >= 48.0 && ctx.ind.rsi <= 67.0 &&
                        bullMtfTailwind);

      if(bullBurst)
      {
         double slDist = ComputeStructuralSLDist(ctx, SIGNAL_BUY, effSlMult, effSlMult * 1.25);
         if(!HasClearRoomToTarget(ctx, SIGNAL_BUY, slDist, false))
         {
            outRejectReason = "Micro-momentum BUY blocked near resistance / HTF high";
            return false;
         }
         double tpDist = MathMax(slDist * 1.60, ctx.ind.atr * effTpMult);
         PopulateCommonSignal(outSignal, ctx, SIGNAL_BUY, slDist, tpDist, 0.78,
                              "Bullish cost-validated tick velocity, EMA-stack & dual MTF burst",
                              StringFormat("UpTicks=%d, Vel=%.2f pts/s, Persist=%.2f, ADX=%.1f",
                                           ctx.ticks.consecutiveUpTicks, ctx.ticks.priceVelocity, ctx.ticks.directionalPersistence, ctx.ind.adxMain),
                              ctx.structure.summary, ctx.candle.name,
                              ctx.mtf.hasStrongConflict ? ctx.mtf.conflictReason : "None");
         return true;
      }

      bool bearBurst = (bearRangeOk &&
                        ctx.ticks.consecutiveDownTicks >= m_minConsecTicks &&
                        ctx.ticks.priceVelocity <= -effMinVel &&
                        ctx.ticks.priceAcceleration <= 0.0 &&
                        ctx.ticks.microTrendBias <= -0.45 &&
                        ctx.ind.emaFast < ctx.ind.emaMedium &&
                        ctx.ind.emaMedium < ctx.ind.emaSlow &&
                        ctx.ind.macdHist < 0.0 &&
                        ctx.ind.rsi <= 52.0 && ctx.ind.rsi >= 33.0 &&
                        bearMtfTailwind);

      if(bearBurst)
      {
         double slDist = ComputeStructuralSLDist(ctx, SIGNAL_SELL, effSlMult, effSlMult * 1.25);
         if(!HasClearRoomToTarget(ctx, SIGNAL_SELL, slDist, false))
         {
            outRejectReason = "Micro-momentum SELL blocked near support / HTF low";
            return false;
         }
         double tpDist = MathMax(slDist * 1.60, ctx.ind.atr * effTpMult);
         PopulateCommonSignal(outSignal, ctx, SIGNAL_SELL, slDist, tpDist, 0.78,
                              "Bearish cost-validated tick velocity, EMA-stack & dual MTF burst",
                              StringFormat("DownTicks=%d, Vel=%.2f pts/s, Persist=%.2f, ADX=%.1f",
                                           ctx.ticks.consecutiveDownTicks, ctx.ticks.priceVelocity, ctx.ticks.directionalPersistence, ctx.ind.adxMain),
                              ctx.structure.summary, ctx.candle.name,
                              ctx.mtf.hasStrongConflict ? ctx.mtf.conflictReason : "None");
         return true;
      }

      outRejectReason = "Tick velocity/persistence/EMA-stack/dual-MTF criteria not met";
      return false;
   }

   virtual bool ShouldExitPosition(const SManagedPosition &pos, const SAnalysisContext &ctx, string &outExitReason) const override
   {
      if(pos.holdingSeconds < 120 || !ctx.ticks.isReady || pos.floatingPnL <= 0.0) return false;
      if(pos.direction == SIGNAL_BUY && ctx.ticks.momentumDeteriorating && ctx.ticks.microTrendBias < -0.45)
      {
         outExitReason = "MicroMomentum exit: profitable tick burst reversed downward";
         return true;
      }
      if(pos.direction == SIGNAL_SELL && ctx.ticks.momentumDeteriorating && ctx.ticks.microTrendBias > 0.45)
      {
         outExitReason = "MicroMomentum exit: profitable tick burst reversed upward";
         return true;
      }
      return false;
   }
};

#endif // __ASEA_STRATEGIES_MICROMOMENTUM_MQH__
