//+------------------------------------------------------------------+
//|                                       LiquiditySweepScalping.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v3.1.0 Strategy 8: Stop-Hunt & Sweep Rej. |
//+------------------------------------------------------------------+
#ifndef __ASEA_STRATEGIES_LIQUIDITYSWEEPSCALPING_MQH__
#define __ASEA_STRATEGIES_LIQUIDITYSWEEPSCALPING_MQH__

#include "StrategyBase.mqh"

class CStrategyLiquiditySweepScalping : public CStrategyBase
{
private:
   double m_minWickRatio;

public:
   CStrategyLiquiditySweepScalping() : CStrategyBase(STRAT_LIQUIDITY_SWEEP, "Liquidity Sweep")
   {
      m_minWickRatio = 0.44;
   }

   void Configure(const bool enabled, const double slMult, const double tpMult, const int minSample,
                  const double minWickRatio = 0.44)
   {
      ConfigureBase(enabled, slMult, tpMult, minSample);
      m_minWickRatio = MathMax(0.32, MathMin(0.65, minWickRatio));
   }

   virtual ENUM_STRATEGY_SUITABILITY GetRegimeSuitability(const ENUM_MARKET_REGIME regime) const override
   {
      if(regime == REGIME_POTENTIAL_REVERSAL || regime == REGIME_SIDEWAYS ||
         regime == REGIME_WIDE_CONSOLIDATION || regime == REGIME_TREND_EXHAUSTION)
         return SUIT_SUITABLE;
      if(regime == REGIME_WEAK_BULL_TREND || regime == REGIME_WEAK_BEAR_TREND ||
         regime == REGIME_EARLY_TREND_BULL || regime == REGIME_EARLY_TREND_BEAR)
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
         outRejectReason = "Regime unsuitable for liquidity sweep fade: " + ctx.regime.label;
         return false;
      }
      if(!ctx.ind.isReady || !ctx.structure.isReady || ctx.ind.atr <= 0.0 || ctx.symbolProfile.point <= 0.0)
      {
         outRejectReason = "Indicators or structure not ready";
         return false;
      }
      if(ctx.market.spreadRatio > 1.75)
      {
         outRejectReason = StringFormat("Spread ratio %.2f too wide for sweep entry", ctx.market.spreadRatio);
         return false;
      }

      double barRange = MathMax(ctx.market.high - ctx.market.low, ctx.symbolProfile.point);
      if(ctx.market.normalizedBarRangeAtr < 0.70)
      {
         outRejectReason = "Sweep candle range too small relative to ATR";
         return false;
      }

      double bodyTop = MathMax(ctx.market.open, ctx.market.close);
      double bodyBot = MathMin(ctx.market.open, ctx.market.close);
      double lowerWick = bodyBot - ctx.market.low;
      double upperWick = ctx.market.high - bodyTop;
      double lowerWickFrac = lowerWick / barRange;
      double upperWickFrac = upperWick / barRange;

      double effSlMult = GetEffectiveSlMult(ctx, 0.92);
      double effTpMult = GetEffectiveTpMult(ctx, 1.05);

      // Reference swing/Donchian & PDH/PDL institutional pools
      double bullPool = (ctx.structure.lastSwingLow > 0.0) ? ctx.structure.lastSwingLow : ctx.ind.donchianLow;
      double bearPool = (ctx.structure.lastSwingHigh > 0.0) ? ctx.structure.lastSwingHigh : ctx.ind.donchianHigh;
      bool bullSweepPDL = (ctx.structure.prevDayLow > 0.0 &&
                           ctx.market.low < ctx.structure.prevDayLow - ctx.ind.atr * 0.03 &&
                           ctx.market.low >= ctx.structure.prevDayLow - ctx.ind.atr * 0.75 &&
                           ctx.market.close > ctx.structure.prevDayLow);
      bool bearSweepPDH = (ctx.structure.prevDayHigh > 0.0 &&
                           ctx.market.high > ctx.structure.prevDayHigh + ctx.ind.atr * 0.03 &&
                           ctx.market.high <= ctx.structure.prevDayHigh + ctx.ind.atr * 0.75 &&
                           ctx.market.close < ctx.structure.prevDayHigh);

      bool notRunawayBear = !(ctx.ind.adxMain >= 26.0 && ctx.ind.adxMinusDI > ctx.ind.adxPlusDI + 8.0) &&
                            (ctx.structure.lastEvent != STRUCT_BOS_BEAR);
      bool notRunawayBull = !(ctx.ind.adxMain >= 26.0 && ctx.ind.adxPlusDI > ctx.ind.adxMinusDI + 8.0) &&
                            (ctx.structure.lastEvent != STRUCT_BOS_BULL);

      // Bullish stop-hunt sweep below support or PDL snapping closed back inside range with rejection wick
      bool bullSweepEvent = (ctx.structure.lastEvent == STRUCT_LIQ_SWEEP_LOW ||
                             ctx.structure.lastEvent == STRUCT_FAILED_BREAKOUT_DOWN ||
                             bullSweepPDL ||
                             (bullPool > 0.0 && ctx.market.low < bullPool - ctx.ind.atr * 0.04 &&
                              ctx.market.low >= bullPool - ctx.ind.atr * 0.75 &&
                              ctx.market.close > bullPool));
      bool bullRejClose = (lowerWickFrac >= m_minWickRatio) &&
                          ((ctx.market.close > ctx.market.open && (ctx.market.close - ctx.market.low) >= barRange * 0.62) ||
                           (ctx.market.close - ctx.market.low) >= barRange * 0.74) &&
                          (ctx.candle.bias != SIGNAL_SELL) &&
                          (ctx.ind.rsi <= 43.0) &&
                          (ctx.ind.rsi >= ctx.ind.prevRsi || ctx.ind.macdHist > ctx.ind.prevMacdHist);

      bool bullAtExtremum = (ctx.structure.isDiscountZone || ctx.structure.swingRangePos01 <= 0.38 ||
                             bullSweepPDL || (bullPool > 0.0 && ctx.market.low <= bullPool));
      bool bearAtExtremum = (ctx.structure.isPremiumZone || ctx.structure.swingRangePos01 >= 0.62 ||
                             bearSweepPDH || (bearPool > 0.0 && ctx.market.high >= bearPool));

      if(bullAtExtremum && bullSweepEvent && bullRejClose && notRunawayBear && ctx.mtf.higherBias != SIGNAL_SELL)
      {
         double rawSweepStopDist = MathMax(ctx.ind.atr * effSlMult, (ctx.market.ask - ctx.market.low) + ctx.ind.atr * 0.25);
         double slDist = MathMin(ctx.ind.atr * (effSlMult * 1.25), MathMax(ComputeStructuralSLDist(ctx, SIGNAL_BUY, effSlMult * 0.85, effSlMult * 1.25), rawSweepStopDist));
         if(!HasClearRoomToTarget(ctx, SIGNAL_BUY, slDist, false))
         {
            outRejectReason = "Liquidity sweep BUY blocked near overhead resistance wall";
            return false;
         }
         double tpDist = MathMax(slDist * 1.65, ctx.ind.atr * effTpMult);
         double rawConf = (bullSweepPDL && ctx.ind.relativeVolume >= 1.15) ? 0.90 : 0.85;
         PopulateCommonSignal(outSignal, ctx, SIGNAL_BUY, slDist, tpDist, rawConf,
                              StringFormat("Bullish %s (Swing=%.0f%%) with %.0f%% lower rejection wick", bullSweepPDL ? "PDL liquidity sweep" : "liquidity sweep below pool", ctx.structure.swingRangePos01 * 100.0, lowerWickFrac * 100.0),
                              StringFormat("RSI=%.1f, ADX=%.1f, SweepWick=%.0f%%, VolR=%.2f, RVOL=%.2f", ctx.ind.rsi, ctx.ind.adxMain, lowerWickFrac * 100.0, ctx.regime.volatilityRatio, ctx.ind.relativeVolume),
                              ctx.structure.summary, ctx.candle.name,
                              ctx.mtf.hasStrongConflict ? ctx.mtf.conflictReason : "None");
         return true;
      }

      // Bearish stop-hunt sweep above resistance or PDH snapping closed back inside range with rejection wick
      bool bearSweepEvent = (ctx.structure.lastEvent == STRUCT_LIQ_SWEEP_HIGH ||
                             ctx.structure.lastEvent == STRUCT_FAILED_BREAKOUT_UP ||
                             bearSweepPDH ||
                             (bearPool > 0.0 && ctx.market.high > bearPool + ctx.ind.atr * 0.04 &&
                              ctx.market.high <= bearPool + ctx.ind.atr * 0.75 &&
                              ctx.market.close < bearPool));
      bool bearRejClose = (upperWickFrac >= m_minWickRatio) &&
                          ((ctx.market.close < ctx.market.open && (ctx.market.high - ctx.market.close) >= barRange * 0.62) ||
                           (ctx.market.high - ctx.market.close) >= barRange * 0.74) &&
                          (ctx.candle.bias != SIGNAL_BUY) &&
                          (ctx.ind.rsi >= 57.0) &&
                          (ctx.ind.rsi <= ctx.ind.prevRsi || ctx.ind.macdHist < ctx.ind.prevMacdHist);

      if(bearAtExtremum && bearSweepEvent && bearRejClose && notRunawayBull && ctx.mtf.higherBias != SIGNAL_BUY)
      {
         double rawSweepStopDist = MathMax(ctx.ind.atr * effSlMult, (ctx.market.high - ctx.market.bid) + ctx.ind.atr * 0.25);
         double slDist = MathMin(ctx.ind.atr * (effSlMult * 1.25), MathMax(ComputeStructuralSLDist(ctx, SIGNAL_SELL, effSlMult * 0.85, effSlMult * 1.25), rawSweepStopDist));
         if(!HasClearRoomToTarget(ctx, SIGNAL_SELL, slDist, false))
         {
            outRejectReason = "Liquidity sweep SELL blocked near floor support wall";
            return false;
         }
         double tpDist = MathMax(slDist * 1.65, ctx.ind.atr * effTpMult);
         double rawConf = (bearSweepPDH && ctx.ind.relativeVolume >= 1.15) ? 0.90 : 0.85;
         PopulateCommonSignal(outSignal, ctx, SIGNAL_SELL, slDist, tpDist, rawConf,
                              StringFormat("Bearish %s (Swing=%.0f%%) with %.0f%% upper rejection wick", bearSweepPDH ? "PDH liquidity sweep" : "liquidity sweep above pool", ctx.structure.swingRangePos01 * 100.0, upperWickFrac * 100.0),
                              StringFormat("RSI=%.1f, ADX=%.1f, SweepWick=%.0f%%, VolR=%.2f, RVOL=%.2f", ctx.ind.rsi, ctx.ind.adxMain, upperWickFrac * 100.0, ctx.regime.volatilityRatio, ctx.ind.relativeVolume),
                              ctx.structure.summary, ctx.candle.name,
                              ctx.mtf.hasStrongConflict ? ctx.mtf.conflictReason : "None");
         return true;
      }

      outRejectReason = "No confirmed stop-hunt sweep with 44%+ rejection wick & RSI extreme";
      return false;
   }

   virtual bool ShouldExitPosition(const SManagedPosition &pos, const SAnalysisContext &ctx, string &outExitReason) const override
   {
      if(pos.holdingSeconds < 300 || !ctx.structure.isReady || pos.floatingPnL <= 0.0) return false;
      double initSlDist = (pos.initialSL > 0.0) ? MathAbs(pos.openPrice - pos.initialSL) : ctx.ind.atr * 1.65;
      double profitDist = (pos.direction == SIGNAL_BUY) ? (pos.currentPrice - pos.openPrice) : (pos.openPrice - pos.currentPrice);
      if(profitDist < initSlDist * 0.80) return false;

      if(pos.direction == SIGNAL_BUY && ctx.structure.lastEvent == STRUCT_LIQ_SWEEP_HIGH)
      {
         outExitReason = "LiquiditySweep exit: opposing high-side liquidity sweep in >=0.8R profit";
         return true;
      }
      if(pos.direction == SIGNAL_SELL && ctx.structure.lastEvent == STRUCT_LIQ_SWEEP_LOW)
      {
         outExitReason = "LiquiditySweep exit: opposing low-side liquidity sweep in >=0.8R profit";
         return true;
      }
      return false;
   }
};

#endif // __ASEA_STRATEGIES_LIQUIDITYSWEEPSCALPING_MQH__
