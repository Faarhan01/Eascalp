//+------------------------------------------------------------------+
//|                                          VolatilityExpansion.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        Strategy 6: Volatility Expansion Scalping |
//+------------------------------------------------------------------+
#ifndef __ASEA_STRATEGIES_VOLATILITYEXPANSION_MQH__
#define __ASEA_STRATEGIES_VOLATILITYEXPANSION_MQH__

#include "StrategyBase.mqh"

class CStrategyVolatilityExpansion : public CStrategyBase
{
private:
   double m_minVolRatio;

public:
   CStrategyVolatilityExpansion() : CStrategyBase(STRAT_VOLATILITY_EXPANSION, "Volatility Expansion")
   {
      m_minVolRatio = 1.25;
   }

   void Configure(const bool enabled, const double slMult, const double tpMult, const int minSample, const double minVolRatio)
   {
      ConfigureBase(enabled, slMult, tpMult, minSample);
      m_minVolRatio = MathMax(1.05, MathMin(3.0, minVolRatio));
   }

   virtual bool IsSuitableForRegime(const ENUM_MARKET_REGIME regime) const override
   {
      return (regime == REGIME_VOL_EXPANSION || regime == REGIME_HIGH_VOLATILITY ||
              regime == REGIME_STRONG_BULL_TREND || regime == REGIME_STRONG_BEAR_TREND);
   }

   virtual bool Evaluate(const SAnalysisContext &ctx, STradeSignal &outSignal, string &outRejectReason) override
   {
      outSignal.Reset();
      outRejectReason = "";

      if(!m_enabled) { outRejectReason = "Strategy disabled by input"; return false; }
      if(!IsSuitableForRegime(ctx.regime.regime))
      {
         outRejectReason = "No volatility expansion regime: " + ctx.regime.label;
         return false;
      }
      if(!ctx.ind.isReady || !ctx.ticks.isReady || ctx.ind.atr <= 0.0)
      {
         outRejectReason = "Indicators or tick metrics unavailable";
         return false;
      }
      if(ctx.regime.volatilityRatio < m_minVolRatio)
      {
         outRejectReason = StringFormat("ATR ratio %.2f below expansion threshold %.2f", ctx.regime.volatilityRatio, m_minVolRatio);
         return false;
      }

      double barBody = MathAbs(ctx.market.close - ctx.market.open);
      bool impulseBar = (barBody >= ctx.ind.atr * 0.55) && (ctx.ticks.activityRatio >= 1.25);

      if(impulseBar && ctx.market.close > ctx.ind.bbUpper && ctx.ind.macdHist > 0.0 && ctx.ticks.microTrendBias > 0.1)
      {
         double slDist = ctx.ind.atr * m_slAtrMult;
         double tpDist = ctx.ind.atr * m_tpAtrMult;
         PopulateCommonSignal(outSignal, ctx, SIGNAL_BUY, slDist, tpDist, 0.77,
                              "Bullish volatility expansion breaking upper Bollinger Band with tick surge",
                              StringFormat("ATR_Ratio=%.2f, BB_W=%.2f%%, TickAct=%.2f", ctx.regime.volatilityRatio, ctx.ind.bbWidthPct, ctx.ticks.activityRatio),
                              ctx.structure.summary, ctx.candle.name, "None");
         return true;
      }

      if(impulseBar && ctx.market.close < ctx.ind.bbLower && ctx.ind.macdHist < 0.0 && ctx.ticks.microTrendBias < -0.1)
      {
         double slDist = ctx.ind.atr * m_slAtrMult;
         double tpDist = ctx.ind.atr * m_tpAtrMult;
         PopulateCommonSignal(outSignal, ctx, SIGNAL_SELL, slDist, tpDist, 0.77,
                              "Bearish volatility expansion breaking lower Bollinger Band with tick surge",
                              StringFormat("ATR_Ratio=%.2f, BB_W=%.2f%%, TickAct=%.2f", ctx.regime.volatilityRatio, ctx.ind.bbWidthPct, ctx.ticks.activityRatio),
                              ctx.structure.summary, ctx.candle.name, "None");
         return true;
      }

      outRejectReason = "Volatility expansion lacking directional band break + tick confirmation";
      return false;
   }
};

#endif // __ASEA_STRATEGIES_VOLATILITYEXPANSION_MQH__
