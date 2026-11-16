//+------------------------------------------------------------------+
//|                                             MomentumScalping.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.0.0 Anti-Chase Momentum Scalping       |
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
      m_maxEmaExtAtr = 2.0;
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

      bool bullTickOk = (!ctx.ticks.isReady || ctx.ticks.microTrendBias > 0.02);
      bool bearTickOk = (!ctx.ticks.isReady || ctx.ticks.microTrendBias < -0.02);

      bool bullMom = (ctx.ind.macdHist > 0.0 &&
                      (ctx.ind.macdHist >= ctx.ind.prevMacdHist || ctx.ind.momentumAccel >= -0.02) &&
                      (ctx.ind.roc >= m_minRocAbs || ctx.ind.priceDisplacementAtr >= 0.55) &&
                      ctx.ind.directionalPersist >= 0.05 &&
                      ctx.ind.rsi > 49.0 && ctx.ind.rsi < 74.0 &&
                      ctx.ind.adxPlusDI > ctx.ind.adxMinusDI &&
                      ctx.ind.emaFast > ctx.ind.emaMedium &&
                      ctx.candle.bias != SIGNAL_SELL &&
                      bullTickOk && ctx.market.close > ctx.ind.emaFast);

      bool bearMom = (ctx.ind.macdHist < 0.0 &&
                      (ctx.ind.macdHist <= ctx.ind.prevMacdHist || ctx.ind.momentumAccel <= 0.02) &&
                      (ctx.ind.roc <= -m_minRocAbs || ctx.ind.priceDisplacementAtr <= -0.55) &&
                      ctx.ind.directionalPersist <= -0.05 &&
                      ctx.ind.rsi < 51.0 && ctx.ind.rsi > 26.0 &&
                      ctx.ind.adxMinusDI > ctx.ind.adxPlusDI &&
                      ctx.ind.emaFast < ctx.ind.emaMedium &&
                      ctx.candle.bias != SIGNAL_BUY &&
                      bearTickOk && ctx.market.close < ctx.ind.emaFast);

      if(bullMom)
      {
         double slDist = ComputeStructuralSLDist(ctx, SIGNAL_BUY, m_slAtrMult, m_slAtrMult * 1.40);
         double tpMultEff = (ctx.mtf.alignedBullish && ctx.ind.adxMain >= 22.0) ? (m_tpAtrMult * 1.25) : m_tpAtrMult;
         double tpDist = MathMax(slDist * 1.35, ctx.ind.atr * tpMultEff);
         PopulateCommonSignal(outSignal, ctx, SIGNAL_BUY, slDist, tpDist, 0.78,
                              "Bullish accelerating momentum with directional persistence (non-overextended)",
                              StringFormat("ROC=%.3f%% Accel=%.3f Persist=%.2f Ext=%.2fATR", ctx.ind.roc, ctx.ind.momentumAccel, ctx.ind.directionalPersist, ctx.ind.emaDistanceAtr),
                              ctx.structure.summary, ctx.candle.name,
                              ctx.mtf.hasStrongConflict ? ctx.mtf.conflictReason : "None");
         return true;
      }

      if(bearMom)
      {
         double slDist = ComputeStructuralSLDist(ctx, SIGNAL_SELL, m_slAtrMult, m_slAtrMult * 1.40);
         double tpMultEff = (ctx.mtf.alignedBearish && ctx.ind.adxMain >= 22.0) ? (m_tpAtrMult * 1.25) : m_tpAtrMult;
         double tpDist = MathMax(slDist * 1.35, ctx.ind.atr * tpMultEff);
         PopulateCommonSignal(outSignal, ctx, SIGNAL_SELL, slDist, tpDist, 0.78,
                              "Bearish accelerating momentum with directional persistence (non-overextended)",
                              StringFormat("ROC=%.3f%% Accel=%.3f Persist=%.2f Ext=%.2fATR", ctx.ind.roc, ctx.ind.momentumAccel, ctx.ind.directionalPersist, ctx.ind.emaDistanceAtr),
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
