//+------------------------------------------------------------------+
//|                                                TrendPullback.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.9.0 Strategy 1: Depth-Measured Pullback|
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
      m_minAdx = 18.0;
      m_pullbackAtrTol = 0.60;
   }

   void Configure(const bool enabled, const double slMult, const double tpMult, const int minSample,
                  const double minAdx, const double pullbackAtrTol)
   {
      ConfigureBase(enabled, slMult, tpMult, minSample);
      m_minAdx = MathMax(12.0, minAdx);
      m_pullbackAtrTol = MathMax(0.2, MathMin(1.5, pullbackAtrTol));
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
         outRejectReason = StringFormat("Weak ADX (%.1f) or momentum exhaustion active", ctx.ind.adxMain);
         return false;
      }

      double tol = ctx.ind.atr * m_pullbackAtrTol;
      bool bullStack = (ctx.ind.emaFast > ctx.ind.emaMedium && ctx.ind.emaMedium > ctx.ind.emaSlow);
      bool bearStack = (ctx.ind.emaFast < ctx.ind.emaMedium && ctx.ind.emaMedium < ctx.ind.emaSlow);
      double effSlMult = GetEffectiveSlMult(ctx, 1.0);
      double effTpMult = GetEffectiveTpMult(ctx, 1.0);
      double barRange = MathMax(ctx.market.high - ctx.market.low, MathMax(ctx.symbolProfile.point, 0.0000001));
      double body = MathAbs(ctx.market.close - ctx.market.open);

      bool bullMtfTailwind = (ctx.mtf.higherBias == SIGNAL_BUY) || (ctx.mtf.higherBias == SIGNAL_NONE && ctx.mtf.intermediateBias == SIGNAL_BUY);
      bool bearMtfTailwind = (ctx.mtf.higherBias == SIGNAL_SELL) || (ctx.mtf.higherBias == SIGNAL_NONE && ctx.mtf.intermediateBias == SIGNAL_SELL);
      bool bullWallClear = !(ctx.structure.nearestResistance > ctx.market.close &&
                             (ctx.structure.nearestResistance - ctx.market.close) < ctx.ind.atr * 0.70 &&
                             ctx.structure.resistanceRejectCount >= 2);
      bool bearWallClear = !(ctx.structure.nearestSupport > 0.0 &&
                             ctx.structure.nearestSupport < ctx.market.close &&
                             (ctx.market.close - ctx.structure.nearestSupport) < ctx.ind.atr * 0.70 &&
                             ctx.structure.supportRejectCount >= 2);

      if(bullStack && ctx.structure.structureBias >= 0 && bullMtfTailwind && bullWallClear &&
         ctx.ind.adxPlusDI > ctx.ind.adxMinusDI && ctx.ind.emaDistanceAtr <= 1.25 &&
         (!ctx.ind.vwapAvailable || ctx.market.close >= ctx.ind.vwap - ctx.ind.atr * 0.25))
      {
         // Measure pullback depth relative to recent swing range
         double swingSpan = MathMax(ctx.ind.atr * 1.3, ctx.structure.lastSwingHigh - ctx.structure.lastSwingLow);
         double retraceDepth = (ctx.structure.lastSwingHigh - ctx.market.low) / swingSpan;
         bool validDepth = (retraceDepth >= 0.18 && retraceDepth <= 0.78);
         bool touchedZone = (ctx.market.low <= ctx.ind.emaFast + tol || ctx.market.low <= ctx.ind.emaMedium + tol) &&
                            (ctx.market.close > ctx.ind.emaSlow) &&
                            (ctx.market.close >= ctx.ind.emaMedium - ctx.ind.atr * 0.10);
         bool closeConviction = (ctx.market.close > ctx.market.open) &&
                                (body >= barRange * 0.20) &&
                                ((ctx.market.close - ctx.market.low) >= barRange * 0.55);
         bool momRecovery = closeConviction &&
                            (ctx.candle.bias != SIGNAL_SELL) &&
                            (ctx.ind.macdHist > ctx.ind.prevMacdHist || (ctx.ind.rsi > ctx.ind.prevRsi && ctx.ind.stochK > ctx.ind.stochD)) &&
                            (ctx.ind.rsi >= 44.0 && ctx.ind.rsi <= 67.0);

         if(validDepth && touchedZone && momRecovery)
         {
            bool fibSweetSpot = (retraceDepth >= 0.36 && retraceDepth <= 0.64);
            double conf = fibSweetSpot ? 0.89 : 0.84;
            double slDist = ComputeStructuralSLDist(ctx, SIGNAL_BUY, effSlMult, effSlMult * 1.45);
            double tpMultEff = (ctx.mtf.alignedBullish && ctx.ind.adxMain >= 22.0) ? (effTpMult * 1.25) : effTpMult;
            double tpDist = MathMax(slDist * 1.50, ctx.ind.atr * tpMultEff);
            PopulateCommonSignal(outSignal, ctx, SIGNAL_BUY, slDist, tpDist, conf,
                                 StringFormat("Bull pullback (%.0f%% retrace) to EMA zone/structure with momentum recovery", retraceDepth * 100.0),
                                 StringFormat("ADX=%.1f, RSI=%.1f, MACD_H slope+", ctx.ind.adxMain, ctx.ind.rsi),
                                 ctx.structure.summary, ctx.candle.name,
                                 ctx.mtf.hasStrongConflict ? ctx.mtf.conflictReason : "None");
            return true;
         }
         outRejectReason = "Pullback depth, close conviction, or momentum recovery check failed";
         return false;
      }

      if(bearStack && ctx.structure.structureBias <= 0 && bearMtfTailwind && bearWallClear &&
         ctx.ind.adxMinusDI > ctx.ind.adxPlusDI && ctx.ind.emaDistanceAtr >= -1.25 &&
         (!ctx.ind.vwapAvailable || ctx.market.close <= ctx.ind.vwap + ctx.ind.atr * 0.25))
      {
         double swingSpan = MathMax(ctx.ind.atr * 1.3, ctx.structure.lastSwingHigh - ctx.structure.lastSwingLow);
         double retraceDepth = (ctx.market.high - ctx.structure.lastSwingLow) / swingSpan;
         bool validDepth = (retraceDepth >= 0.18 && retraceDepth <= 0.78);
         bool touchedZone = (ctx.market.high >= ctx.ind.emaFast - tol || ctx.market.high >= ctx.ind.emaMedium - tol) &&
                            (ctx.market.close < ctx.ind.emaSlow) &&
                            (ctx.market.close <= ctx.ind.emaMedium + ctx.ind.atr * 0.10);
         bool closeConviction = (ctx.market.close < ctx.market.open) &&
                                (body >= barRange * 0.20) &&
                                ((ctx.market.high - ctx.market.close) >= barRange * 0.55);
         bool momRecovery = closeConviction &&
                            (ctx.candle.bias != SIGNAL_BUY) &&
                            (ctx.ind.macdHist < ctx.ind.prevMacdHist || (ctx.ind.rsi < ctx.ind.prevRsi && ctx.ind.stochK < ctx.ind.stochD)) &&
                            (ctx.ind.rsi <= 56.0 && ctx.ind.rsi >= 33.0);

         if(validDepth && touchedZone && momRecovery)
         {
            bool fibSweetSpot = (retraceDepth >= 0.36 && retraceDepth <= 0.64);
            double conf = fibSweetSpot ? 0.89 : 0.84;
            double slDist = ComputeStructuralSLDist(ctx, SIGNAL_SELL, effSlMult, effSlMult * 1.45);
            double tpMultEff = (ctx.mtf.alignedBearish && ctx.ind.adxMain >= 22.0) ? (effTpMult * 1.25) : effTpMult;
            double tpDist = MathMax(slDist * 1.50, ctx.ind.atr * tpMultEff);
            PopulateCommonSignal(outSignal, ctx, SIGNAL_SELL, slDist, tpDist, conf,
                                 StringFormat("Bear pullback (%.0f%% retrace) to EMA zone/structure with momentum recovery", retraceDepth * 100.0),
                                 StringFormat("ADX=%.1f, RSI=%.1f, MACD_H slope-", ctx.ind.adxMain, ctx.ind.rsi),
                                 ctx.structure.summary, ctx.candle.name,
                                 ctx.mtf.hasStrongConflict ? ctx.mtf.conflictReason : "None");
            return true;
         }
         outRejectReason = "Pullback depth, close conviction, or momentum recovery check failed";
         return false;
      }

      outRejectReason = "No aligned trend stack, MTF tailwind, or VWAP confluence";
      return false;
   }

   virtual bool ShouldExitPosition(const SManagedPosition &pos, const SAnalysisContext &ctx, string &outExitReason) const override
   {
      if(pos.holdingSeconds < 300 || !ctx.ind.isReady) return false;
      if(pos.direction == SIGNAL_BUY && ctx.market.close < ctx.ind.emaSlow && ctx.ind.macdHist < 0.0 && ctx.structure.lastEvent == STRUCT_CHOCH_BEAR)
      {
         outExitReason = "TrendPullback exit: close below EMA55 + bearish CHoCH & MACD";
         return true;
      }
      if(pos.direction == SIGNAL_SELL && ctx.market.close > ctx.ind.emaSlow && ctx.ind.macdHist > 0.0 && ctx.structure.lastEvent == STRUCT_CHOCH_BULL)
      {
         outExitReason = "TrendPullback exit: close above EMA55 + bullish CHoCH & MACD";
         return true;
      }
      return false;
   }
};

#endif // __ASEA_STRATEGIES_TRENDPULLBACK_MQH__
