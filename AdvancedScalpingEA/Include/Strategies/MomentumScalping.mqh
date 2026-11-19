//+------------------------------------------------------------------+
//|                                             MomentumScalping.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v3.1.0 Anti-Chase Momentum Scalp          |
//+------------------------------------------------------------------+
#ifndef __ASEA_STRATEGIES_MOMENTUMSCALPING_MQH__
#define __ASEA_STRATEGIES_MOMENTUMSCALPING_MQH__

#include "StrategyBase.mqh"

class CStrategyMomentumScalping : public CStrategyBase
{
private:
   double m_minRocAbs;
   double m_maxEmaExtAtr;

public:
   CStrategyMomentumScalping() : CStrategyBase(STRAT_MOMENTUM_SCALPING, "Momentum Scalping")
   {
      m_minRocAbs = 0.012;
      m_maxEmaExtAtr = 1.15;
   }

   void Configure(const bool enabled, const double slMult, const double tpMult, const int minSample, const double minRocAbs)
   {
      ConfigureBase(enabled, slMult, tpMult, minSample);
      m_minRocAbs = MathMax(0.004, minRocAbs);
   }

   virtual ENUM_STRATEGY_SUITABILITY GetRegimeSuitability(const ENUM_MARKET_REGIME regime) const override
   {
      if(regime == REGIME_STRONG_BULL_TREND || regime == REGIME_STRONG_BEAR_TREND ||
         regime == REGIME_ESTABLISHED_BULL || regime == REGIME_ESTABLISHED_BEAR ||
         regime == REGIME_VOL_EXPANSION || regime == REGIME_EARLY_TREND_BULL || regime == REGIME_EARLY_TREND_BEAR)
         return SUIT_SUITABLE;
      if(regime == REGIME_WEAK_BULL_TREND || regime == REGIME_WEAK_BEAR_TREND)
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
         outRejectReason = "Regime unsuitable for momentum: " + ctx.regime.label;
         return false;
      }
      if(!ctx.ind.isReady || ctx.ind.atr <= 0.0)
      {
         outRejectReason = "Indicators unavailable";
         return false;
      }

      // Strict anti-chase & exhaustion guard: never chase already extended moves
      if(ctx.ind.momentumExhaustion || MathAbs(ctx.ind.emaDistanceAtr) > m_maxEmaExtAtr)
      {
         outRejectReason = StringFormat("Overextended (%.2f ATR from EMA21 > %.2f) or exhaustion", ctx.ind.emaDistanceAtr, m_maxEmaExtAtr);
         return false;
      }
      if(ctx.ind.relativeVolume < 0.95)
      {
         outRejectReason = StringFormat("Relative volume %.2f < 0.95 for momentum thrust", ctx.ind.relativeVolume);
         return false;
      }
      if(ctx.ticks.isReady && ctx.ticks.momentumDeteriorating)
      {
         outRejectReason = "Short-term tick velocity decelerating";
         return false;
      }

      bool bullTickOk = (!ctx.ticks.isReady || ctx.ticks.microTrendBias > 0.05);
      bool bearTickOk = (!ctx.ticks.isReady || ctx.ticks.microTrendBias < -0.05);
      double effSlMult = GetEffectiveSlMult(ctx, 1.0);
      double effTpMult = GetEffectiveTpMult(ctx, 1.0);
      double barRange = MathMax(ctx.market.high - ctx.market.low, MathMax(ctx.symbolProfile.point, 0.0000001));
      double body = MathAbs(ctx.market.close - ctx.market.open);

      bool bullMtfTailwind = (ctx.mtf.higherBias == SIGNAL_BUY && ctx.mtf.intermediateBias != SIGNAL_SELL);
      bool bearMtfTailwind = (ctx.mtf.higherBias == SIGNAL_SELL && ctx.mtf.intermediateBias != SIGNAL_BUY);
      bool bullWallClear = !ctx.structure.isReady || (ctx.structure.swingRangePos01 <= 0.78);
      bool bearWallClear = !ctx.structure.isReady || (ctx.structure.swingRangePos01 >= 0.22);
      bool bullCandleConv = (ctx.market.close > ctx.market.open) && (body >= barRange * 0.42) && ((ctx.market.close - ctx.market.low) >= barRange * 0.60);
      bool bearCandleConv = (ctx.market.close < ctx.market.open) && (body >= barRange * 0.42) && ((ctx.market.high - ctx.market.close) >= barRange * 0.60);

      double atrPct = (ctx.market.close > 0.0) ? ((ctx.ind.atr / ctx.market.close) * 100.0) : 0.0;
      double effMinRoc = MathMax(m_minRocAbs, atrPct * 0.40);

      bool bullMom = (bullMtfTailwind && bullWallClear &&
                      ctx.ind.adxMain >= 21.0 &&
                      ctx.ind.macdHist > 0.0 &&
                      ctx.ind.macdHist > ctx.ind.prevMacdHist &&
                      ctx.ind.roc >= effMinRoc &&
                      ctx.ind.priceDisplacementAtr >= 0.42 &&
                      ctx.ind.directionalPersist >= 0.22 &&
                      ctx.ind.rsi >= 50.0 && ctx.ind.rsi <= 67.0 &&
                      ctx.ind.adxPlusDI > ctx.ind.adxMinusDI + 2.0 &&
                      ctx.ind.emaFast > ctx.ind.emaMedium && ctx.ind.emaMedium > ctx.ind.emaSlow &&
                      (!ctx.ind.vwapAvailable || ctx.market.close >= ctx.ind.vwap) &&
                      ctx.market.close <= ctx.ind.bbUpper &&
                      ctx.market.low <= ctx.ind.emaFast + ctx.ind.atr * 0.45 &&
                      ctx.candle.bias != SIGNAL_SELL &&
                      bullTickOk && bullCandleConv && ctx.market.close > ctx.ind.emaFast);

      bool bearMom = (bearMtfTailwind && bearWallClear &&
                      ctx.ind.adxMain >= 21.0 &&
                      ctx.ind.macdHist < 0.0 &&
                      ctx.ind.macdHist < ctx.ind.prevMacdHist &&
                      ctx.ind.roc <= -effMinRoc &&
                      ctx.ind.priceDisplacementAtr <= -0.42 &&
                      ctx.ind.directionalPersist <= -0.22 &&
                      ctx.ind.rsi <= 50.0 && ctx.ind.rsi >= 33.0 &&
                      ctx.ind.adxMinusDI > ctx.ind.adxPlusDI + 2.0 &&
                      ctx.ind.emaFast < ctx.ind.emaMedium && ctx.ind.emaMedium < ctx.ind.emaSlow &&
                      (!ctx.ind.vwapAvailable || ctx.market.close <= ctx.ind.vwap) &&
                      ctx.market.close >= ctx.ind.bbLower &&
                      ctx.market.high >= ctx.ind.emaFast - ctx.ind.atr * 0.45 &&
                      ctx.candle.bias != SIGNAL_BUY &&
                      bearTickOk && bearCandleConv && ctx.market.close < ctx.ind.emaFast);

      if(bullMom)
      {
         double slDist = ComputeStructuralSLDist(ctx, SIGNAL_BUY, effSlMult, effSlMult * 1.25);
         if(!HasClearRoomToTarget(ctx, SIGNAL_BUY, slDist, false))
         {
            outRejectReason = "Insufficient headroom to active resistance / HTF swing high";
            return false;
         }
         double tpMultEff = (ctx.mtf.alignedBullish && ctx.ind.adxMain >= 24.0) ? (effTpMult * 1.20) : effTpMult;
         double tpDist = MathMax(slDist * 1.65, ctx.ind.atr * tpMultEff);
         PopulateCommonSignal(outSignal, ctx, SIGNAL_BUY, slDist, tpDist, 0.82,
                              "Bullish accelerating momentum launching from EMA9 value zone with HTF alignment",
                              StringFormat("Disp=%.2fATR ROC=%.3f%% Persist=%.2f Ext=%.2fATR", ctx.ind.priceDisplacementAtr, ctx.ind.roc, ctx.ind.directionalPersist, ctx.ind.emaDistanceAtr),
                              ctx.structure.summary, ctx.candle.name,
                              ctx.mtf.hasStrongConflict ? ctx.mtf.conflictReason : "None");
         ComputeOptimalPullbackTrigger(outSignal, ctx, 0.20);
         return true;
      }

      if(bearMom)
      {
         double slDist = ComputeStructuralSLDist(ctx, SIGNAL_SELL, effSlMult, effSlMult * 1.25);
         if(!HasClearRoomToTarget(ctx, SIGNAL_SELL, slDist, false))
         {
            outRejectReason = "Insufficient headroom to active support / HTF swing low";
            return false;
         }
         double tpMultEff = (ctx.mtf.alignedBearish && ctx.ind.adxMain >= 24.0) ? (effTpMult * 1.20) : effTpMult;
         double tpDist = MathMax(slDist * 1.65, ctx.ind.atr * tpMultEff);
         PopulateCommonSignal(outSignal, ctx, SIGNAL_SELL, slDist, tpDist, 0.82,
                              "Bearish accelerating momentum launching from EMA9 value zone with HTF alignment",
                              StringFormat("Disp=%.2fATR ROC=%.3f%% Persist=%.2f Ext=%.2fATR", ctx.ind.priceDisplacementAtr, ctx.ind.roc, ctx.ind.directionalPersist, ctx.ind.emaDistanceAtr),
                              ctx.structure.summary, ctx.candle.name,
                              ctx.mtf.hasStrongConflict ? ctx.mtf.conflictReason : "None");
         ComputeOptimalPullbackTrigger(outSignal, ctx, 0.20);
         return true;
      }

      outRejectReason = "Momentum acceleration, value-zone proximity, or HTF alignment unmet";
      return false;
   }

   virtual bool ShouldExitPosition(const SManagedPosition &pos, const SAnalysisContext &ctx, string &outExitReason) const override
   {
      if(pos.holdingSeconds < 600 || !ctx.ind.isReady) return false;
      double initSlDist = (pos.initialSL > 0.0) ? MathAbs(pos.openPrice - pos.initialSL) : ctx.ind.atr * 1.65;
      double profitDist = (pos.direction == SIGNAL_BUY) ? (pos.currentPrice - pos.openPrice) : (pos.openPrice - pos.currentPrice);
      if(pos.direction == SIGNAL_BUY && profitDist >= initSlDist * 1.10 && ctx.ind.bearDivergence && ctx.ind.macdHist < ctx.ind.prevMacdHist)
      {
         outExitReason = "MomentumScalping exit: bearish RSI divergence & fading MACD above 1.1R";
         return true;
      }
      if(pos.direction == SIGNAL_SELL && profitDist >= initSlDist * 1.10 && ctx.ind.bullDivergence && ctx.ind.macdHist > ctx.ind.prevMacdHist)
      {
         outExitReason = "MomentumScalping exit: bullish RSI divergence & rising MACD above 1.1R";
         return true;
      }
      return false;
   }
};

#endif // __ASEA_STRATEGIES_MOMENTUMSCALPING_MQH__
