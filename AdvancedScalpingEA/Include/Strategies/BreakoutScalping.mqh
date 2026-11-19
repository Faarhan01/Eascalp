//+------------------------------------------------------------------+
//|                                             BreakoutScalping.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v3.1.0 Retest & Compression Breakout      |
//+------------------------------------------------------------------+
#ifndef __ASEA_STRATEGIES_BREAKOUTSCALPING_MQH__
#define __ASEA_STRATEGIES_BREAKOUTSCALPING_MQH__

#include "StrategyBase.mqh"

class CStrategyBreakoutScalping : public CStrategyBase
{
private:
   double m_minBodyAtrRatio;
   double m_minRvol;

public:
   CStrategyBreakoutScalping() : CStrategyBase(STRAT_BREAKOUT_SCALPING, "Breakout Scalping")
   {
      m_minBodyAtrRatio = 0.40;
      m_minRvol = 1.10;
   }

   void Configure(const bool enabled, const double slMult, const double tpMult, const int minSample,
                  const double minBodyAtrRatio, const double minRvol = 1.10)
   {
      ConfigureBase(enabled, slMult, tpMult, minSample);
      m_minBodyAtrRatio = MathMax(0.25, MathMin(1.5, minBodyAtrRatio));
      m_minRvol = MathMax(0.50, MathMin(3.0, minRvol));
   }

   virtual ENUM_STRATEGY_SUITABILITY GetRegimeSuitability(const ENUM_MARKET_REGIME regime) const override
   {
      if(regime == REGIME_VOL_EXPANSION || regime == REGIME_EARLY_TREND_BULL || regime == REGIME_EARLY_TREND_BEAR ||
         regime == REGIME_TIGHT_CONSOLIDATION || regime == REGIME_WIDE_CONSOLIDATION)
         return SUIT_SUITABLE;
      if(regime == REGIME_STRONG_BULL_TREND || regime == REGIME_STRONG_BEAR_TREND ||
         regime == REGIME_ESTABLISHED_BULL || regime == REGIME_ESTABLISHED_BEAR ||
         regime == REGIME_WEAK_BULL_TREND || regime == REGIME_WEAK_BEAR_TREND ||
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
         outRejectReason = "Regime unsuitable for breakout (abnormal/chop): " + ctx.regime.label;
         return false;
      }
      if(!ctx.ind.isReady || !ctx.structure.isReady || ctx.ind.atr <= 0.0)
      {
         outRejectReason = "Structure or indicators not ready";
         return false;
      }
      if(ctx.structure.failedBreakout || MathAbs(ctx.ind.emaDistanceAtr) > 1.45)
      {
         outRejectReason = StringFormat("Recent failed breakout or overextended bar (%.2f ATR > 1.45) — standing aside", ctx.ind.emaDistanceAtr);
         return false;
      }

      if(ctx.ind.relativeVolume < m_minRvol)
      {
         outRejectReason = StringFormat("Relative volume %.2f below %.2f for breakout conviction", ctx.ind.relativeVolume, m_minRvol);
         return false;
      }

      double barRange = MathMax(ctx.market.high - ctx.market.low, MathMax(ctx.symbolProfile.point, 0.0000001));
      double body = MathAbs(ctx.market.close - ctx.market.open);
      bool strongBody = (body >= ctx.ind.atr * m_minBodyAtrRatio) &&
                        (body >= barRange * 0.50) &&
                        (ctx.market.normalizedBarRangeAtr >= 0.72);
      bool bullCloseConv = ((ctx.market.close - ctx.market.low) >= barRange * 0.62);
      bool bearCloseConv = ((ctx.market.high - ctx.market.close) >= barRange * 0.62);
      bool activityConfirm = (ctx.regime.volatilityRatio >= 0.92 || ctx.ticks.activityRatio >= 1.05 ||
                              ctx.market.normalizedBarRangeAtr >= 0.95 || ctx.ind.relativeVolume >= 1.25);
      double effSlMult = GetEffectiveSlMult(ctx, 1.0);
      double effTpMult = GetEffectiveTpMult(ctx, 1.08);

      bool bullMtfTailwind = (ctx.mtf.higherBias == SIGNAL_BUY) ||
                             (ctx.mtf.higherBias == SIGNAL_NONE && ctx.mtf.intermediateBias == SIGNAL_BUY && ctx.ind.adxMain >= 22.0 && ctx.regime.efficiencyRatio >= 0.30);
      bool bearMtfTailwind = (ctx.mtf.higherBias == SIGNAL_SELL) ||
                             (ctx.mtf.higherBias == SIGNAL_NONE && ctx.mtf.intermediateBias == SIGNAL_SELL && ctx.ind.adxMain >= 22.0 && ctx.regime.efficiencyRatio >= 0.30);
      bool bullWallClear = !(ctx.structure.nearestResistance > ctx.market.close &&
                             (ctx.structure.nearestResistance - ctx.market.close) < ctx.ind.atr * 0.85 &&
                             ctx.structure.resistanceRejectCount >= 2);
      bool bearWallClear = !(ctx.structure.nearestSupport > 0.0 &&
                             ctx.structure.nearestSupport < ctx.market.close &&
                             (ctx.market.close - ctx.structure.nearestSupport) < ctx.ind.atr * 0.85 &&
                             ctx.structure.supportRejectCount >= 2);

      // Fresh breakout from compression/range or clean structural retest (no outer-BB chasing!)
      bool bullRetest = (ctx.structure.lastEvent == STRUCT_RETEST_BULL && ctx.market.close > ctx.market.open &&
                         bullCloseConv && ctx.candle.bias != SIGNAL_SELL && ctx.ind.emaFast >= ctx.ind.emaMedium);
      bool bearRetest = (ctx.structure.lastEvent == STRUCT_RETEST_BEAR && ctx.market.close < ctx.market.open &&
                         bearCloseConv && ctx.candle.bias != SIGNAL_BUY && ctx.ind.emaFast <= ctx.ind.emaMedium);
      bool bullDonchianBreak = (ctx.ind.donchianHigh > 0.0 && ctx.market.close > ctx.ind.donchianHigh &&
                                ctx.market.open <= ctx.ind.donchianHigh + ctx.ind.atr * 0.15 &&
                                ctx.ind.emaFast > ctx.ind.emaMedium);
      bool bearDonchianBreak = (ctx.ind.donchianLow > 0.0 && ctx.market.close < ctx.ind.donchianLow &&
                                ctx.market.open >= ctx.ind.donchianLow - ctx.ind.atr * 0.15 &&
                                ctx.ind.emaFast < ctx.ind.emaMedium);

      bool bullMomOk = (ctx.market.close > ctx.market.open && bullCloseConv && ctx.ind.macdHist > 0.0 &&
                        ctx.ind.adxMain >= 18.5 && ctx.ind.adxPlusDI > ctx.ind.adxMinusDI && ctx.ind.emaFast > ctx.ind.emaMedium);
      bool bearMomOk = (ctx.market.close < ctx.market.open && bearCloseConv && ctx.ind.macdHist < 0.0 &&
                        ctx.ind.adxMain >= 18.5 && ctx.ind.adxMinusDI > ctx.ind.adxPlusDI && ctx.ind.emaFast < ctx.ind.emaMedium);

      bool bullBreak = (bullMtfTailwind && bullWallClear) &&
                       (bullRetest ||
                        ((ctx.structure.lastEvent == STRUCT_BOS_BULL || ctx.structure.lastEvent == STRUCT_BREAKOUT_UP ||
                          bullDonchianBreak ||
                          (ctx.chartPattern.pattern != PATTERN_NONE && ctx.chartPattern.bias == SIGNAL_BUY && ctx.market.close > ctx.chartPattern.breakoutLevel)) &&
                         strongBody && activityConfirm && bullMomOk));

      bool bearBreak = (bearMtfTailwind && bearWallClear) &&
                       (bearRetest ||
                        ((ctx.structure.lastEvent == STRUCT_BOS_BEAR || ctx.structure.lastEvent == STRUCT_BREAKOUT_DOWN ||
                          bearDonchianBreak ||
                          (ctx.chartPattern.pattern != PATTERN_NONE && ctx.chartPattern.bias == SIGNAL_SELL && ctx.market.close < ctx.chartPattern.breakoutLevel)) &&
                         strongBody && activityConfirm && bearMomOk));

      if(bullBreak && ctx.ind.rsi < 69.0)
      {
         double slDist = ComputeStructuralSLDist(ctx, SIGNAL_BUY, effSlMult, effSlMult * 1.25);
         if(!HasClearRoomToTarget(ctx, SIGNAL_BUY, slDist, true))
         {
            outRejectReason = "Breakout blocked directly below PDH or HTF swing ceiling";
            return false;
         }
         double tpMultEff = ctx.mtf.alignedBullish ? (effTpMult * 1.20) : effTpMult;
         double tpDist = MathMax(slDist * 1.65, ctx.ind.atr * tpMultEff);
         string desc = bullRetest ? "Bullish breakout retest confirmation" : "Confirmed fresh bullish structural/Donchian breakout with volume";
         PopulateCommonSignal(outSignal, ctx, SIGNAL_BUY, slDist, tpDist, bullRetest ? 0.87 : 0.82, desc,
                              StringFormat("BarRange=%.2fATR, VolR=%.2f, RVOL=%.2f, Ext=%.2fATR",
                                           ctx.market.normalizedBarRangeAtr, ctx.regime.volatilityRatio, ctx.ind.relativeVolume, ctx.ind.emaDistanceAtr),
                              ctx.structure.summary, ctx.chartPattern.name,
                              ctx.mtf.hasStrongConflict ? ctx.mtf.conflictReason : "None");
         if(!bullRetest && (ctx.market.close - ctx.ind.emaFast) >= ctx.ind.atr * 0.45)
         {
            double retestBase = (ctx.structure.rangeHigh > ctx.market.low && ctx.structure.rangeHigh < ctx.market.close)
                                ? (ctx.structure.rangeHigh + ctx.ind.atr * 0.08)
                                : (ctx.market.low + barRange * 0.40);
            ComputeOptimalPullbackTrigger(outSignal, ctx, 0.22, retestBase);
         }
         return true;
      }

      if(bearBreak && ctx.ind.rsi > 31.0)
      {
         double slDist = ComputeStructuralSLDist(ctx, SIGNAL_SELL, effSlMult, effSlMult * 1.25);
         if(!HasClearRoomToTarget(ctx, SIGNAL_SELL, slDist, true))
         {
            outRejectReason = "Breakout blocked directly above PDL or HTF swing floor";
            return false;
         }
         double tpMultEff = ctx.mtf.alignedBearish ? (effTpMult * 1.20) : effTpMult;
         double tpDist = MathMax(slDist * 1.65, ctx.ind.atr * tpMultEff);
         string desc = bearRetest ? "Bearish breakout retest confirmation" : "Confirmed fresh bearish structural/Donchian breakout with volume";
         PopulateCommonSignal(outSignal, ctx, SIGNAL_SELL, slDist, tpDist, bearRetest ? 0.87 : 0.82, desc,
                              StringFormat("BarRange=%.2fATR, VolR=%.2f, RVOL=%.2f, Ext=%.2fATR",
                                           ctx.market.normalizedBarRangeAtr, ctx.regime.volatilityRatio, ctx.ind.relativeVolume, ctx.ind.emaDistanceAtr),
                              ctx.structure.summary, ctx.chartPattern.name,
                              ctx.mtf.hasStrongConflict ? ctx.mtf.conflictReason : "None");
         if(!bearRetest && (ctx.ind.emaFast - ctx.market.close) >= ctx.ind.atr * 0.45)
         {
            double retestBase = (ctx.structure.rangeLow > 0.0 && ctx.structure.rangeLow < ctx.market.high && ctx.structure.rangeLow > ctx.market.close)
                                ? (ctx.structure.rangeLow - ctx.ind.atr * 0.08)
                                : (ctx.market.high - barRange * 0.40);
            ComputeOptimalPullbackTrigger(outSignal, ctx, 0.22, retestBase);
         }
         return true;
      }

      outRejectReason = "No fresh breakout/retest with required RVOL, HTF tailwind & non-extended displacement";
      return false;
   }

   virtual bool ShouldExitPosition(const SManagedPosition &pos, const SAnalysisContext &ctx, string &outExitReason) const override
   {
      if(pos.holdingSeconds < 300 || !ctx.structure.isReady) return false;
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
