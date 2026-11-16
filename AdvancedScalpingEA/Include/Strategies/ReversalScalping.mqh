//+------------------------------------------------------------------+
//|                                             ReversalScalping.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.0.0 Strategy 4: Structural Reversal    |
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
      if(ctx.ind.adxMain > 36.0 && MathAbs(ctx.ind.directionalPersist) > 0.65 && !ctx.structure.failedBreakout)
      {
         outRejectReason = "Runaway directional persistence active without failed breakout";
         return false;
      }

      bool bullStructRev = (ctx.structure.lastEvent == STRUCT_CHOCH_BULL ||
                            ctx.structure.lastEvent == STRUCT_LIQ_SWEEP_LOW ||
                            ctx.structure.lastEvent == STRUCT_FAILED_BREAKOUT_DOWN ||
                            ctx.structure.lastEvent == STRUCT_REJECTION_LOW ||
                            ctx.structure.structuralReversal || ctx.ind.bullDivergence);
      bool bullHighConv  = (ctx.ind.bullDivergence ||
                            ctx.structure.lastEvent == STRUCT_CHOCH_BULL ||
                            ctx.structure.lastEvent == STRUCT_FAILED_BREAKOUT_DOWN ||
                            ctx.structure.lastEvent == STRUCT_LIQ_SWEEP_LOW);
      bool bullCandleRev = (ctx.candle.bias != SIGNAL_SELL) &&
                           ((ctx.candle.bias == SIGNAL_BUY) ||
                            (ctx.market.close > ctx.market.open && ctx.market.low <= ctx.structure.nearestSupport + ctx.ind.atr * 0.45));
      bool bullExhaust   = (ctx.ind.bullDivergence || ctx.ind.momentumExhaustion ||
                            ctx.ind.rsi <= m_rsiOversold || ctx.ind.cci <= -100.0 || ctx.market.low <= ctx.ind.bbLower);
      bool bullHtfSafe   = (ctx.mtf.higherBias != SIGNAL_SELL) || (bullHighConv && ctx.market.close > ctx.market.open);

      if(bullStructRev && bullCandleRev && bullExhaust && bullHtfSafe && ctx.ind.emaDistanceAtr <= -0.20)
      {
         double slDist = ComputeStructuralSLDist(ctx, SIGNAL_BUY, m_slAtrMult, m_slAtrMult * 1.40);
         double tpDist = MathMax(slDist * 1.40, ctx.ind.atr * m_tpAtrMult);
         double rawConf = ctx.ind.bullDivergence ? 0.80 : 0.74;
         PopulateCommonSignal(outSignal, ctx, SIGNAL_BUY, slDist, tpDist, rawConf,
                              "Bullish reversal: exhaustion/divergence + sweep/CHoCH + rejection confirmation",
                              StringFormat("RSI=%.1f, CCI=%.1f, Div=%s, DistATR=%.2f",
                                           ctx.ind.rsi, ctx.ind.cci, ctx.ind.bullDivergence ? "Y" : "N", ctx.ind.emaDistanceAtr),
                              ctx.structure.summary, ctx.candle.name,
                              ctx.mtf.higherBias == SIGNAL_SELL ? "Counter-HTF warning" : "None");
         return true;
      }

      bool bearStructRev = (ctx.structure.lastEvent == STRUCT_CHOCH_BEAR ||
                            ctx.structure.lastEvent == STRUCT_LIQ_SWEEP_HIGH ||
                            ctx.structure.lastEvent == STRUCT_FAILED_BREAKOUT_UP ||
                            ctx.structure.lastEvent == STRUCT_REJECTION_HIGH ||
                            ctx.structure.structuralReversal || ctx.ind.bearDivergence);
      bool bearHighConv  = (ctx.ind.bearDivergence ||
                            ctx.structure.lastEvent == STRUCT_CHOCH_BEAR ||
                            ctx.structure.lastEvent == STRUCT_FAILED_BREAKOUT_UP ||
                            ctx.structure.lastEvent == STRUCT_LIQ_SWEEP_HIGH);
      bool bearCandleRev = (ctx.candle.bias != SIGNAL_BUY) &&
                           ((ctx.candle.bias == SIGNAL_SELL) ||
                            (ctx.market.close < ctx.market.open && ctx.market.high >= ctx.structure.nearestResistance - ctx.ind.atr * 0.45));
      bool bearExhaust   = (ctx.ind.bearDivergence || ctx.ind.momentumExhaustion ||
                            ctx.ind.rsi >= m_rsiOverbought || ctx.ind.cci >= 100.0 || ctx.market.high >= ctx.ind.bbUpper);
      bool bearHtfSafe   = (ctx.mtf.higherBias != SIGNAL_BUY) || (bearHighConv && ctx.market.close < ctx.market.open);

      if(bearStructRev && bearCandleRev && bearExhaust && bearHtfSafe && ctx.ind.emaDistanceAtr >= 0.20)
      {
         double slDist = ComputeStructuralSLDist(ctx, SIGNAL_SELL, m_slAtrMult, m_slAtrMult * 1.40);
         double tpDist = MathMax(slDist * 1.40, ctx.ind.atr * m_tpAtrMult);
         double rawConf = ctx.ind.bearDivergence ? 0.80 : 0.74;
         PopulateCommonSignal(outSignal, ctx, SIGNAL_SELL, slDist, tpDist, rawConf,
                              "Bearish reversal: exhaustion/divergence + sweep/CHoCH + validated rejection candle",
                              StringFormat("RSI=%.1f, CCI=%.1f, Div=%s, DistATR=%.2f",
                                           ctx.ind.rsi, ctx.ind.cci, ctx.ind.bearDivergence ? "Y" : "N", ctx.ind.emaDistanceAtr),
                              ctx.structure.summary, ctx.candle.name,
                              ctx.mtf.higherBias == SIGNAL_BUY ? "Counter-HTF warning" : "None");
         return true;
      }

      outRejectReason = "Missing combined structural sweep/CHoCH + validated candle + exhaustion/divergence";
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
