//+------------------------------------------------------------------+
//|                                             MomentumScalping.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        Strategy 2: Momentum Scalping             |
//+------------------------------------------------------------------+
#ifndef __ASEA_STRATEGIES_MOMENTUMSCALPING_MQH__
#define __ASEA_STRATEGIES_MOMENTUMSCALPING_MQH__

#include "StrategyBase.mqh"

class CStrategyMomentumScalping : public CStrategyBase
{
private:
   double m_minRocAbs;

public:
   CStrategyMomentumScalping() : CStrategyBase(STRAT_MOMENTUM_SCALPING, "Momentum Scalping")
   {
      m_minRocAbs = 0.03;
   }

   void Configure(const bool enabled, const double slMult, const double tpMult, const int minSample, const double minRocAbs)
   {
      ConfigureBase(enabled, slMult, tpMult, minSample);
      m_minRocAbs = MathMax(0.005, minRocAbs);
   }

   virtual bool IsSuitableForRegime(const ENUM_MARKET_REGIME regime) const override
   {
      return (regime == REGIME_STRONG_BULL_TREND || regime == REGIME_STRONG_BEAR_TREND ||
              regime == REGIME_WEAK_BULL_TREND || regime == REGIME_WEAK_BEAR_TREND ||
              regime == REGIME_VOL_EXPANSION);
   }

   virtual bool Evaluate(const SAnalysisContext &ctx, STradeSignal &outSignal, string &outRejectReason) override
   {
      outSignal.Reset();
      outRejectReason = "";

      if(!m_enabled) { outRejectReason = "Strategy disabled by input"; return false; }
      if(!IsSuitableForRegime(ctx.regime.regime))
      {
         outRejectReason = "Unsuitable regime for momentum: " + ctx.regime.label;
         return false;
      }
      if(!ctx.ind.isReady || !ctx.ticks.isReady || ctx.ind.atr <= 0.0)
      {
         outRejectReason = "Data/indicators/ticks not ready";
         return false;
      }

      bool bullMom = (ctx.ind.macdHist > 0.0 && ctx.ind.roc >= m_minRocAbs &&
                      ctx.ind.rsi > 53.0 && ctx.ind.rsi < 74.0 &&
                      ctx.ind.adxPlusDI > ctx.ind.adxMinusDI &&
                      ctx.ticks.microTrendBias > 0.15 && ctx.market.close > ctx.ind.emaFast);

      bool bearMom = (ctx.ind.macdHist < 0.0 && ctx.ind.roc <= -m_minRocAbs &&
                      ctx.ind.rsi < 47.0 && ctx.ind.rsi > 26.0 &&
                      ctx.ind.adxMinusDI > ctx.ind.adxPlusDI &&
                      ctx.ticks.microTrendBias < -0.15 && ctx.market.close < ctx.ind.emaFast);

      if(bullMom && !ctx.mtf.hasStrongConflict)
      {
         double slDist = ctx.ind.atr * m_slAtrMult;
         double tpDist = ctx.ind.atr * m_tpAtrMult;
         PopulateCommonSignal(outSignal, ctx, SIGNAL_BUY, slDist, tpDist, 0.76,
                              "Bullish momentum surge aligned with MACD, ROC, and tick bias",
                              StringFormat("MACD_H=%.5f, ROC=%.3f%%, RSI=%.1f", ctx.ind.macdHist, ctx.ind.roc, ctx.ind.rsi),
                              ctx.structure.summary, ctx.candle.name, "None");
         return true;
      }

      if(bearMom && !ctx.mtf.hasStrongConflict)
      {
         double slDist = ctx.ind.atr * m_slAtrMult;
         double tpDist = ctx.ind.atr * m_tpAtrMult;
         PopulateCommonSignal(outSignal, ctx, SIGNAL_SELL, slDist, tpDist, 0.76,
                              "Bearish momentum surge aligned with MACD, ROC, and tick bias",
                              StringFormat("MACD_H=%.5f, ROC=%.3f%%, RSI=%.1f", ctx.ind.macdHist, ctx.ind.roc, ctx.ind.rsi),
                              ctx.structure.summary, ctx.candle.name, "None");
         return true;
      }

      outRejectReason = ctx.mtf.hasStrongConflict ? ("MTF conflict: " + ctx.mtf.conflictReason) : "Momentum thresholds or tick bias not aligned";
      return false;
   }
};

#endif // __ASEA_STRATEGIES_MOMENTUMSCALPING_MQH__
