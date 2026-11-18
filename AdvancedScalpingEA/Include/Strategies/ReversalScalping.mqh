//+------------------------------------------------------------------+
//|                                             ReversalScalping.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.9.0 Strategy 4: Structural Reversal    |
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
      m_rsiOversold = 32.0;
      m_rsiOverbought = 68.0;
   }

   void Configure(const bool enabled, const double slMult, const double tpMult, const int minSample,
                  const double rsiOS, const double rsiOB)
   {
      ConfigureBase(enabled, slMult, tpMult, minSample);
      m_rsiOversold   = MathMax(15.0, MathMin(40.0, rsiOS));
      m_rsiOverbought = MathMin(85.0, MathMax(60.0, rsiOB));
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
      if(!ctx.ind.isReady || !ctx.structure.isReady || ctx.ind.atr <= 0.0)
      {
         outRejectReason = "Indicators or structure not ready";
         return false;
      }

      // Guard against fading strong established trends or high persistence moves
      if(ctx.ind.adxMain > 28.0 && MathAbs(ctx.ind.directionalPersist) > 0.45 && !ctx.structure.failedBreakout)
      {
         outRejectReason = "Runaway directional persistence active without failed breakout";
         return false;
      }
      if(ctx.market.spreadRatio > 1.80)
      {
         outRejectReason = StringFormat("Spread ratio %.2f too wide for reversal entry", ctx.market.spreadRatio);
         return false;
      }

      double effSlMult = GetEffectiveSlMult(ctx, 1.0);
      double effTpMult = GetEffectiveTpMult(ctx, 1.0);

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
                            (ctx.candle.contextValidated || ctx.ind.bullDivergence));
      bool bullExhaust   = (ctx.ind.bullDivergence || ctx.ind.momentumExhaustion ||
                            ctx.ind.rsi <= m_rsiOversold || ctx.ind.cci <= -110.0 || ctx.market.low <= ctx.ind.bbLower);
      bool bullHtfSafe   = (ctx.mtf.higherBias != SIGNAL_SELL) || (ctx.ind.bullDivergence && ctx.structure.failedBreakout);

      if(bullHighConv && bullCandleRev && bullExhaust && bullHtfSafe && ctx.ind.emaDistanceAtr <= -0.45)
      {
         double slDist = ComputeStructuralSLDist(ctx, SIGNAL_BUY, effSlMult, effSlMult * 1.40);
         double tpDist = MathMax(slDist * 1.50, ctx.ind.atr * effTpMult);
         double rawConf = ctx.ind.bullDivergence ? 0.84 : 0.78;
         PopulateCommonSignal(outSignal, ctx, SIGNAL_BUY, slDist, tpDist, rawConf,
                              "Bullish reversal: high-conviction CHoCH/sweep/divergence + validated reversal candle",
                              StringFormat("RSI=%.1f, CCI=%.1f, Div=%s, DistATR=%.2f",
                                           ctx.ind.rsi, ctx.ind.cci, ctx.ind.bullDivergence ? "Y" : "N", ctx.ind.emaDistanceAtr),
                              ctx.structure.summary, ctx.candle.name,
                              ctx.mtf.higherBias == SIGNAL_SELL ? "Counter-HTF warning" : "None");
         return true;
      }

      bool bearHighConv  = (ctx.ind.bearDivergence ||
                            ctx.structure.lastEvent == STRUCT_CHOCH_BEAR ||
                            ctx.structure.lastEvent == STRUCT_FAILED_BREAKOUT_UP ||
                            ctx.structure.lastEvent == STRUCT_LIQ_SWEEP_HIGH);
      bool bearCandleRev = (ctx.market.close < ctx.market.open && ctx.candle.bias == SIGNAL_SELL && isBearRevCandle &&
                            (ctx.candle.contextValidated || ctx.ind.bearDivergence));
      bool bearExhaust   = (ctx.ind.bearDivergence || ctx.ind.momentumExhaustion ||
                            ctx.ind.rsi >= m_rsiOverbought || ctx.ind.cci >= 110.0 || ctx.market.high >= ctx.ind.bbUpper);
      bool bearHtfSafe   = (ctx.mtf.higherBias != SIGNAL_BUY) || (ctx.ind.bearDivergence && ctx.structure.failedBreakout);

      if(bearHighConv && bearCandleRev && bearExhaust && bearHtfSafe && ctx.ind.emaDistanceAtr >= 0.45)
      {
         double slDist = ComputeStructuralSLDist(ctx, SIGNAL_SELL, effSlMult, effSlMult * 1.40);
         double tpDist = MathMax(slDist * 1.50, ctx.ind.atr * effTpMult);
         double rawConf = ctx.ind.bearDivergence ? 0.84 : 0.78;
         PopulateCommonSignal(outSignal, ctx, SIGNAL_SELL, slDist, tpDist, rawConf,
                              "Bearish reversal: high-conviction CHoCH/sweep/divergence + validated reversal candle",
                              StringFormat("RSI=%.1f, CCI=%.1f, Div=%s, DistATR=%.2f",
                                           ctx.ind.rsi, ctx.ind.cci, ctx.ind.bearDivergence ? "Y" : "N", ctx.ind.emaDistanceAtr),
                              ctx.structure.summary, ctx.candle.name,
                              ctx.mtf.higherBias == SIGNAL_BUY ? "Counter-HTF warning" : "None");
         return true;
      }

      outRejectReason = "Missing high-conviction sweep/CHoCH/divergence + validated reversal candle + exhaustion";
      return false;
   }

   virtual bool ShouldExitPosition(const SManagedPosition &pos, const SAnalysisContext &ctx, string &outExitReason) const override
   {
      if(pos.holdingSeconds < 180 || !ctx.ind.isReady) return false;
      if(pos.direction == SIGNAL_BUY && pos.floatingPnL > 0.0 && (ctx.ind.rsi >= 70.0 || ctx.structure.lastEvent == STRUCT_REJECTION_HIGH))
      {
         outExitReason = "Reversal exit: profitable mean-reversion/resistance rejection reached";
         return true;
      }
      if(pos.direction == SIGNAL_SELL && pos.floatingPnL > 0.0 && (ctx.ind.rsi <= 30.0 || ctx.structure.lastEvent == STRUCT_REJECTION_LOW))
      {
         outExitReason = "Reversal exit: profitable mean-reversion/support rejection reached";
         return true;
      }
      return false;
   }
};

#endif // __ASEA_STRATEGIES_REVERSALSCALPING_MQH__
