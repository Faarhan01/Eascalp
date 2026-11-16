//+------------------------------------------------------------------+
//|                                             BreakoutScalping.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.0.0 Retest & Displacement Breakout     |
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
      m_minBodyAtrRatio = 0.35;
   }

   void Configure(const bool enabled, const double slMult, const double tpMult, const int minSample, const double minBodyAtrRatio)
   {
      ConfigureBase(enabled, slMult, tpMult, minSample);
      m_minBodyAtrRatio = MathMax(0.2, MathMin(1.5, minBodyAtrRatio));
   }

   virtual ENUM_STRATEGY_SUITABILITY GetRegimeSuitability(const ENUM_MARKET_REGIME regime) const override
   {
      if(regime == REGIME_VOL_EXPANSION || regime == REGIME_EARLY_TREND_BULL || regime == REGIME_EARLY_TREND_BEAR ||
         regime == REGIME_TIGHT_CONSOLIDATION || regime == REGIME_WIDE_CONSOLIDATION)
         return SUIT_SUITABLE;
      if(regime == REGIME_STRONG_BULL_TREND || regime == REGIME_STRONG_BEAR_TREND ||
         regime == REGIME_ESTABLISHED_BULL || regime == REGIME_ESTABLISHED_BEAR ||
         regime == REGIME_WEAK_BULL_TREND || regime == REGIME_WEAK_BEAR_TREND ||
         regime == REGIME_ABNORMAL_VOLATILITY ||
         regime == REGIME_SIDEWAYS || regime == REGIME_VOL_CONTRACTION)
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
         outRejectReason = "Regime unsuitable for breakout: " + ctx.regime.label;
         return false;
      }
      if(!ctx.ind.isReady || !ctx.structure.isReady || ctx.ind.atr <= 0.0)
      {
         outRejectReason = "Structure or indicators not ready";
         return false;
      }
      if(ctx.structure.failedBreakout || MathAbs(ctx.ind.emaDistanceAtr) > 2.35)
      {
         outRejectReason = "Recent failed breakout or overextended climax bar — standing aside";
         return false;
      }

      double body = MathAbs(ctx.market.close - ctx.market.open);
      bool strongBody = (body >= ctx.ind.atr * m_minBodyAtrRatio) && (ctx.market.normalizedBarRangeAtr >= 0.65);
      bool activityConfirm = (ctx.regime.volatilityRatio >= 0.85 || ctx.ticks.activityRatio >= 1.05 || ctx.market.normalizedBarRangeAtr >= 0.90);

      // High-conviction breakout retest OR confirmed fresh breakout (Structure / Chart Pattern / Donchian / Band Expansion)
      bool bullRetest = (ctx.structure.lastEvent == STRUCT_RETEST_BULL && ctx.market.close > ctx.market.open && ctx.candle.bias != SIGNAL_SELL);
      bool bearRetest = (ctx.structure.lastEvent == STRUCT_RETEST_BEAR && ctx.market.close < ctx.market.open && ctx.candle.bias != SIGNAL_BUY);
      bool bullBandBreak = ((ctx.market.close > ctx.ind.bbUpper || (ctx.ind.donchianHigh > 0.0 && ctx.market.close > ctx.ind.donchianHigh)) &&
                            ctx.market.close > ctx.ind.donchianMid && ctx.ind.emaFast > ctx.ind.emaMedium);
      bool bearBandBreak = ((ctx.market.close < ctx.ind.bbLower || (ctx.ind.donchianLow > 0.0 && ctx.market.close < ctx.ind.donchianLow)) &&
                            ctx.market.close < ctx.ind.donchianMid && ctx.ind.emaFast < ctx.ind.emaMedium);

      bool bullMomOk = (ctx.market.close > ctx.market.open && (ctx.ind.macdHist > 0.0 || ctx.ind.macdHist > ctx.ind.prevMacdHist));
      bool bearMomOk = (ctx.market.close < ctx.market.open && (ctx.ind.macdHist < 0.0 || ctx.ind.macdHist < ctx.ind.prevMacdHist));

      bool bullBreak = bullRetest ||
                       ((ctx.structure.lastEvent == STRUCT_BOS_BULL || ctx.structure.lastEvent == STRUCT_BREAKOUT_UP ||
                         bullBandBreak ||
                         (ctx.chartPattern.pattern != PATTERN_NONE && ctx.chartPattern.bias == SIGNAL_BUY && ctx.market.close > ctx.chartPattern.breakoutLevel)) &&
                        strongBody && activityConfirm && bullMomOk);

      bool bearBreak = bearRetest ||
                       ((ctx.structure.lastEvent == STRUCT_BOS_BEAR || ctx.structure.lastEvent == STRUCT_BREAKOUT_DOWN ||
                         bearBandBreak ||
                         (ctx.chartPattern.pattern != PATTERN_NONE && ctx.chartPattern.bias == SIGNAL_SELL && ctx.market.close < ctx.chartPattern.breakoutLevel)) &&
                        strongBody && activityConfirm && bearMomOk);

      if(bullBreak && ctx.ind.rsi < 76.0)
      {
         double slDist = ComputeStructuralSLDist(ctx, SIGNAL_BUY, m_slAtrMult, m_slAtrMult * 1.40);
         double tpMultEff = ctx.mtf.alignedBullish ? (m_tpAtrMult * 1.20) : m_tpAtrMult;
         double tpDist = MathMax(slDist * 1.40, ctx.ind.atr * tpMultEff);
         string desc = bullRetest ? "Bullish breakout retest confirmation" : "Confirmed bullish structural/pattern breakout with displacement";
         PopulateCommonSignal(outSignal, ctx, SIGNAL_BUY, slDist, tpDist, bullRetest ? 0.85 : 0.79, desc,
                              StringFormat("BarRange=%.2fATR, VolR=%.2f, TickAct=%.2f", ctx.market.normalizedBarRangeAtr, ctx.regime.volatilityRatio, ctx.ticks.activityRatio),
                              ctx.structure.summary, ctx.chartPattern.name,
                              ctx.mtf.hasStrongConflict ? ctx.mtf.conflictReason : "None");
         return true;
      }

      if(bearBreak && ctx.ind.rsi > 24.0)
      {
         double slDist = ComputeStructuralSLDist(ctx, SIGNAL_SELL, m_slAtrMult, m_slAtrMult * 1.40);
         double tpMultEff = ctx.mtf.alignedBearish ? (m_tpAtrMult * 1.20) : m_tpAtrMult;
         double tpDist = MathMax(slDist * 1.40, ctx.ind.atr * tpMultEff);
         string desc = bearRetest ? "Bearish breakout retest confirmation" : "Confirmed bearish structural/pattern breakout with displacement";
         PopulateCommonSignal(outSignal, ctx, SIGNAL_SELL, slDist, tpDist, bearRetest ? 0.85 : 0.79, desc,
                              StringFormat("BarRange=%.2fATR, VolR=%.2f, TickAct=%.2f", ctx.market.normalizedBarRangeAtr, ctx.regime.volatilityRatio, ctx.ticks.activityRatio),
                              ctx.structure.summary, ctx.chartPattern.name,
                              ctx.mtf.hasStrongConflict ? ctx.mtf.conflictReason : "None");
         return true;
      }

      outRejectReason = "No confirmed breakout or retest with required displacement";
      return false;
   }

   virtual bool ShouldExitPosition(const SManagedPosition &pos, const SAnalysisContext &ctx, string &outExitReason) const override
   {
      if(pos.holdingSeconds < 180 || !ctx.structure.isReady) return false;
      if(pos.direction == SIGNAL_BUY && ctx.structure.lastEvent == STRUCT_FAILED_BREAKOUT_UP)
      {
         outExitReason = "BreakoutScalping exit: failed upside breakout re-entered range";
         return true;
      }
      if(pos.direction == SIGNAL_SELL && ctx.structure.lastEvent == STRUCT_FAILED_BREAKOUT_DOWN)
      {
         outExitReason = "BreakoutScalping exit: failed downside breakout re-entered range";
         return true;
      }
      return false;
   }
};

#endif // __ASEA_STRATEGIES_BREAKOUTSCALPING_MQH__
