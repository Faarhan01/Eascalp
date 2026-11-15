//+------------------------------------------------------------------+
//|                                             BreakoutScalping.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        Strategy 3: Confirmed Breakout Scalping   |
//+------------------------------------------------------------------+
#ifndef __ASEA_STRATEGIES_BREAKOUTSCALPING_MQH__
#define __ASEA_STRATEGIES_BREAKOUTSCALPING_MQH__

#include "StrategyBase.mqh"

class CStrategyBreakoutScalping : public CStrategyBase
{
private:
   double m_minBodyAtrRatio;

public:
   CStrategyBreakoutScalping() : CStrategyBase(STRAT_BREAKOUT_SCALPING, "Breakout Scalping")
   {
      m_minBodyAtrRatio = 0.45;
   }

   void Configure(const bool enabled, const double slMult, const double tpMult, const int minSample, const double minBodyAtrRatio)
   {
      ConfigureBase(enabled, slMult, tpMult, minSample);
      m_minBodyAtrRatio = MathMax(0.2, MathMin(1.5, minBodyAtrRatio));
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
         outRejectReason = "Regime unsuitable for breakout: " + ctx.regime.label;
         return false;
      }
      if(!ctx.ind.isReady || !ctx.structure.isReady || ctx.ind.atr <= 0.0)
      {
         outRejectReason = "Structure or indicators not ready";
         return false;
      }

      double body = MathAbs(ctx.market.close - ctx.market.open);
      bool strongBody = (body >= ctx.ind.atr * m_minBodyAtrRatio);
      bool volConfirm = (ctx.regime.volatilityRatio >= 1.05 || ctx.ticks.activityRatio >= 1.15);

      bool bullBreak = (ctx.structure.lastEvent == STRUCT_BOS_BULL || ctx.structure.lastEvent == STRUCT_BREAKOUT_UP ||
                        (ctx.chartPattern.pattern != PATTERN_NONE && ctx.chartPattern.bias == SIGNAL_BUY && ctx.market.close > ctx.chartPattern.breakoutLevel));

      bool bearBreak = (ctx.structure.lastEvent == STRUCT_BOS_BEAR || ctx.structure.lastEvent == STRUCT_BREAKOUT_DOWN ||
                        (ctx.chartPattern.pattern != PATTERN_NONE && ctx.chartPattern.bias == SIGNAL_SELL && ctx.market.close < ctx.chartPattern.breakoutLevel));

      if(bullBreak && ctx.market.close > ctx.market.open && strongBody && volConfirm && ctx.ind.rsi < 76.0)
      {
         double slDist = ctx.ind.atr * m_slAtrMult;
         double tpDist = ctx.ind.atr * m_tpAtrMult;
         PopulateCommonSignal(outSignal, ctx, SIGNAL_BUY, slDist, tpDist, 0.80,
                              "Confirmed bullish structural/pattern breakout with candle body & activity expansion",
                              StringFormat("VolRatio=%.2f, TickAct=%.2f, RSI=%.1f", ctx.regime.volatilityRatio, ctx.ticks.activityRatio, ctx.ind.rsi),
                              ctx.structure.summary, ctx.chartPattern.name,
                              ctx.mtf.hasStrongConflict ? ctx.mtf.conflictReason : "None");
         return true;
      }

      if(bearBreak && ctx.market.close < ctx.market.open && strongBody && volConfirm && ctx.ind.rsi > 24.0)
      {
         double slDist = ctx.ind.atr * m_slAtrMult;
         double tpDist = ctx.ind.atr * m_tpAtrMult;
         PopulateCommonSignal(outSignal, ctx, SIGNAL_SELL, slDist, tpDist, 0.80,
                              "Confirmed bearish structural/pattern breakout with candle body & activity expansion",
                              StringFormat("VolRatio=%.2f, TickAct=%.2f, RSI=%.1f", ctx.regime.volatilityRatio, ctx.ticks.activityRatio, ctx.ind.rsi),
                              ctx.structure.summary, ctx.chartPattern.name,
                              ctx.mtf.hasStrongConflict ? ctx.mtf.conflictReason : "None");
         return true;
      }

      outRejectReason = "No confirmed breakout event with body/volume expansion";
      return false;
   }
};

#endif // __ASEA_STRATEGIES_BREAKOUTSCALPING_MQH__
