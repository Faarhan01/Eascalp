//+------------------------------------------------------------------+
//|                                             MomentumScalping.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.9.0 Volatility-Scaled Momentum Scalp  |
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
      m_minRocAbs = 0.010;
      m_maxEmaExtAtr = 1.85;
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

      // Anti-chase & exhaustion guard: never chase an already overextended move
      if(ctx.ind.momentumExhaustion || MathAbs(ctx.ind.emaDistanceAtr) > m_maxEmaExtAtr)
      {
         outRejectReason = StringFormat("Overextended (%.2f ATR from EMA21) or momentum exhaustion", ctx.ind.emaDistanceAtr);
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

      bool bullMtfTailwind = (ctx.mtf.higherBias == SIGNAL_BUY) || (ctx.mtf.higherBias == SIGNAL_NONE && ctx.mtf.intermediateBias == SIGNAL_BUY);
      bool bearMtfTailwind = (ctx.mtf.higherBias == SIGNAL_SELL) || (ctx.mtf.higherBias == SIGNAL_NONE && ctx.mtf.intermediateBias == SIGNAL_SELL);
      bool bullWallClear = !ctx.structure.isReady || !(ctx.structure.nearestResistance > ctx.market.close &&
                                                      (ctx.structure.nearestResistance - ctx.market.close) < ctx.ind.atr * 0.65 &&
                                                      ctx.structure.resistanceRejectCount >= 2);
      bool bearWallClear = !ctx.structure.isReady || !(ctx.structure.nearestSupport > 0.0 &&
                                                      ctx.structure.nearestSupport < ctx.market.close &&
                                                      (ctx.market.close - ctx.structure.nearestSupport) < ctx.ind.atr * 0.65 &&
                                                      ctx.structure.supportRejectCount >= 2);
      bool bullCandleConv = (ctx.market.close > ctx.market.open) && (body >= barRange * 0.40) && ((ctx.market.close - ctx.market.low) >= barRange * 0.60);
      bool bearCandleConv = (ctx.market.close < ctx.market.open) && (body >= barRange * 0.40) && ((ctx.market.high - ctx.market.close) >= barRange * 0.60);

      double atrPct = (ctx.market.close > 0.0) ? ((ctx.ind.atr / ctx.market.close) * 100.0) : 0.0;
      double effMinRoc = MathMax(m_minRocAbs, atrPct * 0.40);

      bool bullMom = (bullMtfTailwind && bullWallClear &&
                      ctx.ind.adxMain >= 19.5 &&
                      ctx.ind.macdHist > 0.0 &&
                      ctx.ind.macdHist > ctx.ind.prevMacdHist &&
                      ctx.ind.roc >= effMinRoc &&
                      ctx.ind.priceDisplacementAtr >= 0.45 &&
                      ctx.ind.directionalPersist >= 0.20 &&
                      ctx.ind.rsi >= 50.0 && ctx.ind.rsi <= 71.0 &&
                      ctx.ind.adxPlusDI > ctx.ind.adxMinusDI &&
                      ctx.ind.emaFast > ctx.ind.emaMedium && ctx.ind.emaMedium > ctx.ind.emaSlow &&
                      (!ctx.ind.vwapAvailable || ctx.market.close >= ctx.ind.vwap) &&
                      ctx.candle.bias != SIGNAL_SELL &&
                      bullTickOk && bullCandleConv && ctx.market.close > ctx.ind.emaFast);

      bool bearMom = (bearMtfTailwind && bearWallClear &&
                      ctx.ind.adxMain >= 19.5 &&
                      ctx.ind.macdHist < 0.0 &&
                      ctx.ind.macdHist < ctx.ind.prevMacdHist &&
                      ctx.ind.roc <= -effMinRoc &&
                      ctx.ind.priceDisplacementAtr <= -0.45 &&
                      ctx.ind.directionalPersist <= -0.20 &&
                      ctx.ind.rsi <= 50.0 && ctx.ind.rsi >= 29.0 &&
                      ctx.ind.adxMinusDI > ctx.ind.adxPlusDI &&
                      ctx.ind.emaFast < ctx.ind.emaMedium && ctx.ind.emaMedium < ctx.ind.emaSlow &&
                      (!ctx.ind.vwapAvailable || ctx.market.close <= ctx.ind.vwap) &&
                      ctx.candle.bias != SIGNAL_BUY &&
                      bearTickOk && bearCandleConv && ctx.market.close < ctx.ind.emaFast);

      if(bullMom)
      {
         double slDist = ComputeStructuralSLDist(ctx, SIGNAL_BUY, effSlMult, effSlMult * 1.40);
         double tpMultEff = (ctx.mtf.alignedBullish && ctx.ind.adxMain >= 22.0) ? (effTpMult * 1.25) : effTpMult;
         double tpDist = MathMax(slDist * 1.50, ctx.ind.atr * tpMultEff);
         PopulateCommonSignal(outSignal, ctx, SIGNAL_BUY, slDist, tpDist, 0.80,
                              "Bullish accelerating momentum with full EMA & HTF alignment (non-overextended)",
                              StringFormat("Disp=%.2fATR ROC=%.3f%% Persist=%.2f Ext=%.2fATR", ctx.ind.priceDisplacementAtr, ctx.ind.roc, ctx.ind.directionalPersist, ctx.ind.emaDistanceAtr),
                              ctx.structure.summary, ctx.candle.name,
                              ctx.mtf.hasStrongConflict ? ctx.mtf.conflictReason : "None");
         return true;
      }

      if(bearMom)
      {
         double slDist = ComputeStructuralSLDist(ctx, SIGNAL_SELL, effSlMult, effSlMult * 1.40);
         double tpMultEff = (ctx.mtf.alignedBearish && ctx.ind.adxMain >= 22.0) ? (effTpMult * 1.25) : effTpMult;
         double tpDist = MathMax(slDist * 1.50, ctx.ind.atr * tpMultEff);
         PopulateCommonSignal(outSignal, ctx, SIGNAL_SELL, slDist, tpDist, 0.80,
                              "Bearish accelerating momentum with full EMA & HTF alignment (non-overextended)",
                              StringFormat("Disp=%.2fATR ROC=%.3f%% Persist=%.2f Ext=%.2fATR", ctx.ind.priceDisplacementAtr, ctx.ind.roc, ctx.ind.directionalPersist, ctx.ind.emaDistanceAtr),
                              ctx.structure.summary, ctx.candle.name,
                              ctx.mtf.hasStrongConflict ? ctx.mtf.conflictReason : "None");
         return true;
      }

      outRejectReason = "Momentum acceleration or persistence criteria unmet";
      return false;
   }

   virtual bool ShouldExitPosition(const SManagedPosition &pos, const SAnalysisContext &ctx, string &outExitReason) const override
   {
      if(pos.holdingSeconds < 240 || !ctx.ind.isReady) return false;
      if(pos.direction == SIGNAL_BUY && ctx.ind.bearDivergence && ctx.ind.macdHist < ctx.ind.prevMacdHist && pos.floatingPnL > 0.0)
      {
         outExitReason = "MomentumScalping exit: bearish RSI divergence & fading MACD";
         return true;
      }
      if(pos.direction == SIGNAL_SELL && ctx.ind.bullDivergence && ctx.ind.macdHist > ctx.ind.prevMacdHist && pos.floatingPnL > 0.0)
      {
         outExitReason = "MomentumScalping exit: bullish RSI divergence & rising MACD";
         return true;
      }
      return false;
   }
};

#endif // __ASEA_STRATEGIES_MOMENTUMSCALPING_MQH__
