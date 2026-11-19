//+------------------------------------------------------------------+
//|                                             ReversalScalping.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v3.1.0 Strategy 4: Structural Reversal    |
//+------------------------------------------------------------------+
#ifndef __ASEA_STRATEGIES_REVERSALSCALPING_MQH__
#define __ASEA_STRATEGIES_REVERSALSCALPING_MQH__

#include "StrategyBase.mqh"

class CStrategyReversalScalping : public CStrategyBase
{
private:
   double m_rsiOversold;
   double m_rsiOverbought;

public:
   CStrategyReversalScalping() : CStrategyBase(STRAT_REVERSAL_SCALPING, "Reversal Scalping")
   {
      m_rsiOversold = 30.0;
      m_rsiOverbought = 70.0;
   }

   void Configure(const bool enabled, const double slMult, const double tpMult, const int minSample,
                  const double rsiOS, const double rsiOB)
   {
      ConfigureBase(enabled, slMult, tpMult, minSample);
      m_rsiOversold   = MathMax(15.0, MathMin(36.0, rsiOS));
      m_rsiOverbought = MathMin(85.0, MathMax(64.0, rsiOB));
   }

   virtual ENUM_STRATEGY_SUITABILITY GetRegimeSuitability(const ENUM_MARKET_REGIME regime) const override
   {
      if(regime == REGIME_POTENTIAL_REVERSAL || regime == REGIME_TREND_EXHAUSTION)
         return SUIT_SUITABLE;
      if(regime == REGIME_WEAK_BULL_TREND || regime == REGIME_WEAK_BEAR_TREND ||
         regime == REGIME_WIDE_CONSOLIDATION || regime == REGIME_SIDEWAYS)
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
         outRejectReason = "Reversal blocked in runaway/unstable regime: " + ctx.regime.label;
         return false;
      }
      if(!ctx.ind.isReady || !ctx.structure.isReady || ctx.ind.atr <= 0.0 || ctx.symbolProfile.point <= 0.0)
      {
         outRejectReason = "Indicators or structure not ready";
         return false;
      }

      // Guard against catching falling knives in established directional trends
      if(ctx.ind.adxMain > 26.0 && MathAbs(ctx.ind.directionalPersist) > 0.38 && !ctx.structure.failedBreakout)
      {
         outRejectReason = "Runaway directional persistence active without failed breakout";
         return false;
      }
      if(ctx.market.spreadRatio > 1.75)
      {
         outRejectReason = StringFormat("Spread ratio %.2f too wide for reversal entry", ctx.market.spreadRatio);
         return false;
      }

      double effSlMult = GetEffectiveSlMult(ctx, 1.0);
      double effTpMult = GetEffectiveTpMult(ctx, 1.0);
      double barRange = MathMax(ctx.market.high - ctx.market.low, ctx.symbolProfile.point);

      bool isBullRevCandle = (ctx.candle.pattern == CANDLE_HAMMER || ctx.candle.pattern == CANDLE_BULL_PINBAR ||
                              ctx.candle.pattern == CANDLE_BULL_ENGULFING || ctx.candle.pattern == CANDLE_MORNING_STAR ||
                              ctx.candle.pattern == CANDLE_OUTSIDE_BAR);
      bool isBearRevCandle = (ctx.candle.pattern == CANDLE_SHOOTING_STAR || ctx.candle.pattern == CANDLE_BEAR_PINBAR ||
                              ctx.candle.pattern == CANDLE_BEAR_ENGULFING || ctx.candle.pattern == CANDLE_EVENING_STAR ||
                              ctx.candle.pattern == CANDLE_OUTSIDE_BAR);

      bool bullHighConv  = (ctx.ind.bullDivergence ||
                            ctx.structure.lastEvent == STRUCT_CHOCH_BULL ||
                            ctx.structure.lastEvent == STRUCT_FAILED_BREAKOUT_DOWN ||
                            ctx.structure.lastEvent == STRUCT_LIQ_SWEEP_LOW);
      bool bullCandleRev = (ctx.market.close > ctx.market.open && ctx.candle.bias == SIGNAL_BUY && isBullRevCandle &&
                            ((ctx.market.close - ctx.market.low) >= barRange * 0.60) &&
                            (ctx.candle.contextValidated || ctx.ind.bullDivergence));
      bool bullExhaust   = (ctx.ind.bullDivergence || ctx.ind.rsi <= m_rsiOversold || ctx.ind.cci <= -135.0);
      bool bullHtfSafe   = (ctx.mtf.higherBias != SIGNAL_SELL) ||
                           (ctx.ind.bullDivergence && ctx.structure.failedBreakout && ctx.ind.emaDistanceAtr <= -1.60);

      bool bullExtremum = (ctx.structure.isDiscountZone || ctx.structure.swingRangePos01 <= 0.35 || ctx.ind.donchianPos01 <= 0.25) &&
                          (!ctx.ind.vwapAvailable || ctx.ind.vwapStdDev <= 0.0 || ctx.ind.vwapZScore <= -1.0);
      bool bearExtremum = (ctx.structure.isPremiumZone || ctx.structure.swingRangePos01 >= 0.65 || ctx.ind.donchianPos01 >= 0.75) &&
                          (!ctx.ind.vwapAvailable || ctx.ind.vwapStdDev <= 0.0 || ctx.ind.vwapZScore >= 1.0);

      if(bullExtremum && bullHighConv && bullCandleRev && bullExhaust && bullHtfSafe && ctx.ind.emaDistanceAtr <= -1.15)
      {
         double slDist = ComputeStructuralSLDist(ctx, SIGNAL_BUY, effSlMult, effSlMult * 1.25);
         if(!HasClearRoomToTarget(ctx, SIGNAL_BUY, slDist, false))
         {
            outRejectReason = "Reversal blocked near active overhead resistance";
            return false;
         }
         double tpDist = MathMax(slDist * 1.65, ctx.ind.atr * effTpMult);
         double rawConf = ctx.ind.bullDivergence ? 0.85 : 0.80;
         PopulateCommonSignal(outSignal, ctx, SIGNAL_BUY, slDist, tpDist, rawConf,
                              StringFormat("Bullish extremum reversal (Swing=%.0f%%): CHoCH/sweep/div + rejection candle", ctx.structure.swingRangePos01 * 100.0),
                              StringFormat("RSI=%.1f, CCI=%.1f, Div=%s, DistATR=%.2f, VZ=%.1f",
                                           ctx.ind.rsi, ctx.ind.cci, ctx.ind.bullDivergence ? "Y" : "N", ctx.ind.emaDistanceAtr, ctx.ind.vwapZScore),
                              ctx.structure.summary, ctx.candle.name,
                              ctx.mtf.higherBias == SIGNAL_SELL ? "Counter-HTF warning" : "None");
         return true;
      }

      bool bearHighConv  = (ctx.ind.bearDivergence ||
                            ctx.structure.lastEvent == STRUCT_CHOCH_BEAR ||
                            ctx.structure.lastEvent == STRUCT_FAILED_BREAKOUT_UP ||
                            ctx.structure.lastEvent == STRUCT_LIQ_SWEEP_HIGH);
      bool bearCandleRev = (ctx.market.close < ctx.market.open && ctx.candle.bias == SIGNAL_SELL && isBearRevCandle &&
                            ((ctx.market.high - ctx.market.close) >= barRange * 0.60) &&
                            (ctx.candle.contextValidated || ctx.ind.bearDivergence));
      bool bearExhaust   = (ctx.ind.bearDivergence || ctx.ind.rsi >= m_rsiOverbought || ctx.ind.cci >= 135.0);
      bool bearHtfSafe   = (ctx.mtf.higherBias != SIGNAL_BUY) ||
                           (ctx.ind.bearDivergence && ctx.structure.failedBreakout && ctx.ind.emaDistanceAtr >= 1.60);

      if(bearExtremum && bearHighConv && bearCandleRev && bearExhaust && bearHtfSafe && ctx.ind.emaDistanceAtr >= 1.15)
      {
         double slDist = ComputeStructuralSLDist(ctx, SIGNAL_SELL, effSlMult, effSlMult * 1.25);
         if(!HasClearRoomToTarget(ctx, SIGNAL_SELL, slDist, false))
         {
            outRejectReason = "Reversal blocked near active floor support";
            return false;
         }
         double tpDist = MathMax(slDist * 1.65, ctx.ind.atr * effTpMult);
         double rawConf = ctx.ind.bearDivergence ? 0.85 : 0.80;
         PopulateCommonSignal(outSignal, ctx, SIGNAL_SELL, slDist, tpDist, rawConf,
                              StringFormat("Bearish extremum reversal (Swing=%.0f%%): CHoCH/sweep/div + rejection candle", ctx.structure.swingRangePos01 * 100.0),
                              StringFormat("RSI=%.1f, CCI=%.1f, Div=%s, DistATR=%.2f, VZ=%.1f",
                                           ctx.ind.rsi, ctx.ind.cci, ctx.ind.bearDivergence ? "Y" : "N", ctx.ind.emaDistanceAtr, ctx.ind.vwapZScore),
                              ctx.structure.summary, ctx.candle.name,
                              ctx.mtf.higherBias == SIGNAL_BUY ? "Counter-HTF warning" : "None");
         return true;
      }

      outRejectReason = "Missing graph extremum + >=1.15 ATR stretch + exhaustion + validated sweep/CHoCH/divergence";
      return false;
   }

   virtual bool ShouldExitPosition(const SManagedPosition &pos, const SAnalysisContext &ctx, string &outExitReason) const override
   {
      if(pos.holdingSeconds < 300 || !ctx.ind.isReady || pos.floatingPnL <= 0.0) return false;
      double initSlDist = (pos.initialSL > 0.0) ? MathAbs(pos.openPrice - pos.initialSL) : ctx.ind.atr * 1.65;
      double profitDist = (pos.direction == SIGNAL_BUY) ? (pos.currentPrice - pos.openPrice) : (pos.openPrice - pos.currentPrice);
      if(profitDist < initSlDist) return false;

      if(pos.direction == SIGNAL_BUY && ctx.ind.rsi >= 70.0 && ctx.structure.lastEvent == STRUCT_REJECTION_HIGH)
      {
         outExitReason = "Reversal exit: >=1R profit + overbought resistance rejection";
         return true;
      }
      if(pos.direction == SIGNAL_SELL && ctx.ind.rsi <= 30.0 && ctx.structure.lastEvent == STRUCT_REJECTION_LOW)
      {
         outExitReason = "Reversal exit: >=1R profit + oversold support rejection";
         return true;
      }
      return false;
   }
};

#endif // __ASEA_STRATEGIES_REVERSALSCALPING_MQH__
