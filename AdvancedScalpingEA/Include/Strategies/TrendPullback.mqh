//+------------------------------------------------------------------+
//|                                                TrendPullback.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v3.1.0 Strategy 1: Depth-Measured Pullback|
//+------------------------------------------------------------------+
#ifndef __ASEA_STRATEGIES_TRENDPULLBACK_MQH__
#define __ASEA_STRATEGIES_TRENDPULLBACK_MQH__

#include "StrategyBase.mqh"

class CStrategyTrendPullback : public CStrategyBase
{
private:
   double m_minAdx;
   double m_pullbackAtrTol;

public:
   CStrategyTrendPullback() : CStrategyBase(STRAT_TREND_PULLBACK, "Trend Pullback")
   {
      m_minAdx = 20.0;
      m_pullbackAtrTol = 0.50;
   }

   void Configure(const bool enabled, const double slMult, const double tpMult, const int minSample,
                  const double minAdx, const double pullbackAtrTol)
   {
      ConfigureBase(enabled, slMult, tpMult, minSample);
      m_minAdx = MathMax(14.0, minAdx);
      m_pullbackAtrTol = MathMax(0.2, MathMin(1.2, pullbackAtrTol));
   }

   virtual ENUM_STRATEGY_SUITABILITY GetRegimeSuitability(const ENUM_MARKET_REGIME regime) const override
   {
      if(regime == REGIME_STRONG_BULL_TREND || regime == REGIME_STRONG_BEAR_TREND ||
         regime == REGIME_ESTABLISHED_BULL || regime == REGIME_ESTABLISHED_BEAR)
         return SUIT_SUITABLE;
      if(regime == REGIME_WEAK_BULL_TREND || regime == REGIME_WEAK_BEAR_TREND ||
         regime == REGIME_EARLY_TREND_BULL || regime == REGIME_EARLY_TREND_BEAR ||
         regime == REGIME_VOL_EXPANSION)
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
         outRejectReason = "Regime unsuitable (exhausted/non-trending): " + ctx.regime.label;
         return false;
      }
      if(!ctx.ind.isReady || !ctx.structure.isReady || ctx.ind.atr <= 0.0)
      {
         outRejectReason = "Indicators or structure not ready";
         return false;
      }
      if(ctx.ind.adxMain < m_minAdx || ctx.ind.momentumExhaustion)
      {
         outRejectReason = StringFormat("Weak ADX (%.1f < %.1f) or momentum exhaustion active", ctx.ind.adxMain, m_minAdx);
         return false;
      }

      double tol = ctx.ind.atr * m_pullbackAtrTol;
      bool bullStack = (ctx.ind.emaFast > ctx.ind.emaMedium && ctx.ind.emaMedium > ctx.ind.emaSlow);
      bool bearStack = (ctx.ind.emaFast < ctx.ind.emaMedium && ctx.ind.emaMedium < ctx.ind.emaSlow);
      double effSlMult = GetEffectiveSlMult(ctx, 1.0);
      double effTpMult = GetEffectiveTpMult(ctx, 1.0);
      double barRange = MathMax(ctx.market.high - ctx.market.low, MathMax(ctx.symbolProfile.point, 0.0000001));
      double body = MathAbs(ctx.market.close - ctx.market.open);

      // Strict HTF directional alignment (eliminate weak/choppy SIGNAL_NONE entries)
      bool bullMtfTailwind = (ctx.mtf.higherBias == SIGNAL_BUY && ctx.mtf.intermediateBias != SIGNAL_SELL);
      bool bearMtfTailwind = (ctx.mtf.higherBias == SIGNAL_SELL && ctx.mtf.intermediateBias != SIGNAL_BUY);
      bool bullWallClear = (ctx.structure.swingRangePos01 <= 0.70);
      bool bearWallClear = (ctx.structure.swingRangePos01 >= 0.30);

      if(bullStack && ctx.structure.structureBias >= 0 && bullMtfTailwind && bullWallClear &&
         ctx.ind.adxPlusDI > ctx.ind.adxMinusDI + 2.0 &&
         ctx.ind.emaDistanceAtr >= -0.35 && ctx.ind.emaDistanceAtr <= 0.95 &&
         (!ctx.ind.vwapAvailable || ctx.market.close >= ctx.ind.vwap - ctx.ind.atr * 0.15))
      {
         double swingSpan = MathMax(ctx.ind.atr * 1.3, ctx.structure.lastSwingHigh - ctx.structure.lastSwingLow);
         double retraceDepth = (ctx.structure.lastSwingHigh - ctx.market.low) / swingSpan;
         bool validDepth = (retraceDepth >= 0.22 && retraceDepth <= 0.72);
         bool touchedZone = (ctx.market.low <= ctx.ind.emaMedium + tol) &&
                            (ctx.market.close > ctx.ind.emaSlow) &&
                            (ctx.market.close >= ctx.ind.emaMedium - ctx.ind.atr * 0.08);
         bool closeConviction = (ctx.market.close > ctx.market.open) &&
                                (body >= barRange * 0.25) &&
                                ((ctx.market.close - ctx.market.low) >= barRange * 0.58);
         bool momRecovery = closeConviction &&
                            (ctx.candle.bias != SIGNAL_SELL) &&
                            (ctx.ind.macdHist > ctx.ind.prevMacdHist || (ctx.ind.rsi > ctx.ind.prevRsi && ctx.ind.stochK > ctx.ind.stochD)) &&
                            (ctx.ind.rsi >= 42.0 && ctx.ind.rsi <= 64.0);

         if(validDepth && touchedZone && momRecovery)
         {
            double slDist = ComputeStructuralSLDist(ctx, SIGNAL_BUY, effSlMult, effSlMult * 1.25);
            if(!HasClearRoomToTarget(ctx, SIGNAL_BUY, slDist, false))
            {
               outRejectReason = "Insufficient headroom to active resistance / HTF swing high";
               return false;
            }
            bool fibSweetSpot = (retraceDepth >= 0.36 && retraceDepth <= 0.64);
            double conf = fibSweetSpot ? 0.90 : 0.85;
            double tpMultEff = (ctx.mtf.alignedBullish && ctx.ind.adxMain >= 24.0) ? (effTpMult * 1.20) : effTpMult;
            double tpDist = MathMax(slDist * 1.65, ctx.ind.atr * tpMultEff);
            PopulateCommonSignal(outSignal, ctx, SIGNAL_BUY, slDist, tpDist, conf,
                                 StringFormat("Bull value pullback (%.0f%% retrace, SwingPos=%.0f%%) to EMA21 zone + HTF & momentum recovery", retraceDepth * 100.0, ctx.structure.swingRangePos01 * 100.0),
                                 StringFormat("ADX=%.1f, RSI=%.1f, Ext=%.2fATR, MACD_H+", ctx.ind.adxMain, ctx.ind.rsi, ctx.ind.emaDistanceAtr),
                                 ctx.structure.summary, ctx.candle.name,
                                 ctx.mtf.hasStrongConflict ? ctx.mtf.conflictReason : "None");
            double idealTrig = MathMax(ctx.ind.emaMedium, ctx.market.low + barRange * 0.35);
            if((ctx.market.close - ctx.ind.emaFast) > ctx.ind.atr * 0.35)
               ComputeOptimalPullbackTrigger(outSignal, ctx, 0.20, idealTrig);
            return true;
         }
         outRejectReason = "Pullback depth, value zone touch, or momentum recovery check failed";
         return false;
      }

      if(bearStack && ctx.structure.structureBias <= 0 && bearMtfTailwind && bearWallClear &&
         ctx.ind.adxMinusDI > ctx.ind.adxPlusDI + 2.0 &&
         ctx.ind.emaDistanceAtr <= 0.35 && ctx.ind.emaDistanceAtr >= -0.95 &&
         (!ctx.ind.vwapAvailable || ctx.market.close <= ctx.ind.vwap + ctx.ind.atr * 0.15))
      {
         double swingSpan = MathMax(ctx.ind.atr * 1.3, ctx.structure.lastSwingHigh - ctx.structure.lastSwingLow);
         double retraceDepth = (ctx.market.high - ctx.structure.lastSwingLow) / swingSpan;
         bool validDepth = (retraceDepth >= 0.22 && retraceDepth <= 0.72);
         bool touchedZone = (ctx.market.high >= ctx.ind.emaMedium - tol) &&
                            (ctx.market.close < ctx.ind.emaSlow) &&
                            (ctx.market.close <= ctx.ind.emaMedium + ctx.ind.atr * 0.08);
         bool closeConviction = (ctx.market.close < ctx.market.open) &&
                                (body >= barRange * 0.25) &&
                                ((ctx.market.high - ctx.market.close) >= barRange * 0.58);
         bool momRecovery = closeConviction &&
                            (ctx.candle.bias != SIGNAL_BUY) &&
                            (ctx.ind.macdHist < ctx.ind.prevMacdHist || (ctx.ind.rsi < ctx.ind.prevRsi && ctx.ind.stochK < ctx.ind.stochD)) &&
                            (ctx.ind.rsi <= 58.0 && ctx.ind.rsi >= 36.0);

         if(validDepth && touchedZone && momRecovery)
         {
            double slDist = ComputeStructuralSLDist(ctx, SIGNAL_SELL, effSlMult, effSlMult * 1.25);
            if(!HasClearRoomToTarget(ctx, SIGNAL_SELL, slDist, false))
            {
               outRejectReason = "Insufficient headroom to active support / HTF swing low";
               return false;
            }
            bool fibSweetSpot = (retraceDepth >= 0.36 && retraceDepth <= 0.64);
            double conf = fibSweetSpot ? 0.90 : 0.85;
            double tpMultEff = (ctx.mtf.alignedBearish && ctx.ind.adxMain >= 24.0) ? (effTpMult * 1.20) : effTpMult;
            double tpDist = MathMax(slDist * 1.65, ctx.ind.atr * tpMultEff);
            PopulateCommonSignal(outSignal, ctx, SIGNAL_SELL, slDist, tpDist, conf,
                                 StringFormat("Bear value pullback (%.0f%% retrace, SwingPos=%.0f%%) to EMA21 zone + HTF & momentum recovery", retraceDepth * 100.0, ctx.structure.swingRangePos01 * 100.0),
                                 StringFormat("ADX=%.1f, RSI=%.1f, Ext=%.2fATR, MACD_H-", ctx.ind.adxMain, ctx.ind.rsi, ctx.ind.emaDistanceAtr),
                                 ctx.structure.summary, ctx.candle.name,
                                 ctx.mtf.hasStrongConflict ? ctx.mtf.conflictReason : "None");
            double idealTrig = MathMin(ctx.ind.emaMedium, ctx.market.high - barRange * 0.35);
            if((ctx.ind.emaFast - ctx.market.close) > ctx.ind.atr * 0.35)
               ComputeOptimalPullbackTrigger(outSignal, ctx, 0.20, idealTrig);
            return true;
         }
         outRejectReason = "Pullback depth, value zone touch, or momentum recovery check failed";
         return false;
      }

      outRejectReason = "No aligned trend stack, HTF alignment, or value-zone confluence";
      return false;
   }

   virtual bool ShouldExitPosition(const SManagedPosition &pos, const SAnalysisContext &ctx, string &outExitReason) const override
   {
      if(pos.holdingSeconds < 900 || !ctx.ind.isReady) return false;
      if(pos.direction == SIGNAL_BUY && ctx.market.close < ctx.ind.emaSlow && ctx.ind.macdHist < 0.0 &&
         (ctx.structure.lastEvent == STRUCT_CHOCH_BEAR || ctx.mtf.higherBias == SIGNAL_SELL))
      {
         outExitReason = "TrendPullback exit: close below EMA55 + MACD & CHoCH/HTF bear reversal";
         return true;
      }
      if(pos.direction == SIGNAL_SELL && ctx.market.close > ctx.ind.emaSlow && ctx.ind.macdHist > 0.0 &&
         (ctx.structure.lastEvent == STRUCT_CHOCH_BULL || ctx.mtf.higherBias == SIGNAL_BUY))
      {
         outExitReason = "TrendPullback exit: close above EMA55 + MACD & CHoCH/HTF bull reversal";
         return true;
      }
      return false;
   }
};

#endif // __ASEA_STRATEGIES_TRENDPULLBACK_MQH__
