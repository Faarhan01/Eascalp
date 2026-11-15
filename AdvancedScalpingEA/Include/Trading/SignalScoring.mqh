//+------------------------------------------------------------------+
//|                                                SignalScoring.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        0-100 Quantitative Signal Scoring Engine  |
//+------------------------------------------------------------------+
#ifndef __ASEA_TRADING_SIGNALSCORING_MQH__
#define __ASEA_TRADING_SIGNALSCORING_MQH__

#include "../Core/Types.mqh"
#include "../Strategies/StrategyBase.mqh"

class CSignalScoring
{
private:
   double m_minScoreThreshold;

   ENUM_SIGNAL_STRENGTH_BAND ClassifyBand(const ENUM_SIGNAL_DIRECTION dir, const double score) const
   {
      if(dir == SIGNAL_NONE || score < 40.0) return STRENGTH_NEUTRAL;
      if(dir == SIGNAL_BUY)
      {
         if(score >= 78.0) return STRENGTH_STRONG_BULL;
         if(score >= 60.0) return STRENGTH_MOD_BULL;
         return STRENGTH_WEAK_BULL;
      }
      if(score >= 78.0) return STRENGTH_STRONG_BEAR;
      if(score >= 60.0) return STRENGTH_MOD_BEAR;
      return STRENGTH_WEAK_BEAR;
   }

public:
   CSignalScoring()
   {
      m_minScoreThreshold = 62.0;
   }

   void Configure(const double minScoreThreshold)
   {
      m_minScoreThreshold = MathMax(25.0, MathMin(95.0, minScoreThreshold));
   }

   double GetMinThreshold() const { return m_minScoreThreshold; }

   void ScoreSignal(STradeSignal &sig, const SAnalysisContext &ctx, const SStrategyStats &stratStats,
                    const bool suitableRegime) const
   {
      sig.breakdown.Reset();
      if(!sig.isValid || sig.direction == SIGNAL_NONE)
      {
         sig.compositeScore = 0.0;
         return;
      }

      SScoreBreakdown b;
      b.Reset();
      int dirSign = (sig.direction == SIGNAL_BUY) ? 1 : -1;

      // 1. Market direction alignment (0..10)
      bool emaBull = (ctx.ind.emaFast > ctx.ind.emaMedium && ctx.ind.emaMedium > ctx.ind.emaSlow);
      bool emaBear = (ctx.ind.emaFast < ctx.ind.emaMedium && ctx.ind.emaMedium < ctx.ind.emaSlow);
      if((dirSign > 0 && emaBull) || (dirSign < 0 && emaBear))
         b.directionScore = 10.0;
      else if((dirSign > 0 && ctx.ind.emaFast > ctx.ind.emaMedium) || (dirSign < 0 && ctx.ind.emaFast < ctx.ind.emaMedium))
         b.directionScore = 6.5;
      else
         b.directionScore = 3.0;

      // 2. Market structure alignment (0..12)
      if(ctx.structure.structureBias == dirSign)
         b.structureScore = 9.0;
      else if(ctx.structure.structureBias == 0)
         b.structureScore = 5.0;
      else
         b.structureScore = 2.0;
      if((dirSign > 0 && (ctx.structure.lastEvent == STRUCT_BOS_BULL || ctx.structure.lastEvent == STRUCT_CHOCH_BULL || ctx.structure.lastEvent == STRUCT_LIQ_SWEEP_LOW)) ||
         (dirSign < 0 && (ctx.structure.lastEvent == STRUCT_BOS_BEAR || ctx.structure.lastEvent == STRUCT_CHOCH_BEAR || ctx.structure.lastEvent == STRUCT_LIQ_SWEEP_HIGH)))
         b.structureScore = MathMin(12.0, b.structureScore + 3.0);

      // 3. Trend strength (0..10)
      if(sig.strategyId == STRAT_RANGE_SCALPING)
         b.trendStrengthScore = (ctx.ind.adxMain <= 20.0) ? 9.0 : 4.0;
      else
         b.trendStrengthScore = MathMin(10.0, MathMax(2.0, (ctx.ind.adxMain / 35.0) * 10.0));

      // 4. Momentum (0..10)
      if((dirSign > 0 && ctx.ind.macdHist > 0.0 && ctx.ind.rsi > 48.0 && ctx.ind.rsi < 72.0) ||
         (dirSign < 0 && ctx.ind.macdHist < 0.0 && ctx.ind.rsi < 52.0 && ctx.ind.rsi > 28.0))
         b.momentumScore = 9.0;
      else if((dirSign > 0 && ctx.ind.roc > 0.0) || (dirSign < 0 && ctx.ind.roc < 0.0))
         b.momentumScore = 6.0;
      else
         b.momentumScore = 3.0;

      // 5. Volatility suitability (0..8)
      if(ctx.regime.volatilityState == VOL_NORMAL)
         b.volatilityScore = 8.0;
      else if(ctx.regime.volatilityState == VOL_HIGH)
         b.volatilityScore = 6.0;
      else if(ctx.regime.volatilityState == VOL_LOW)
         b.volatilityScore = (sig.strategyId == STRAT_RANGE_SCALPING) ? 6.5 : 3.5;
      else
         b.volatilityScore = 1.5;

      // 6. Candlestick confirmation (0..8)
      if(ctx.candle.pattern != CANDLE_NONE && ctx.candle.bias == sig.direction)
         b.candleScore = ctx.candle.contextValidated ? 8.0 : 5.0;
      else if(ctx.candle.pattern == CANDLE_NONE)
         b.candleScore = 3.0;
      else
         b.candleScore = 1.0;

      // 7. Chart pattern confirmation (0..8)
      if(ctx.chartPattern.pattern != PATTERN_NONE && ctx.chartPattern.bias == sig.direction)
         b.patternScore = 8.0 * ctx.chartPattern.confidence;
      else if(ctx.chartPattern.pattern == PATTERN_NONE)
         b.patternScore = 3.0;
      else
         b.patternScore = 1.0;

      // 8. Multi-timeframe agreement (0..12)
      double mtfBase = (ctx.mtf.agreementScore / 100.0) * 12.0;
      if((dirSign > 0 && ctx.mtf.higherBias == SIGNAL_SELL) || (dirSign < 0 && ctx.mtf.higherBias == SIGNAL_BUY))
         mtfBase *= 0.35;
      b.mtfAgreementScore = mtfBase;

      // 9. Tick behavior (0..8)
      if(ctx.ticks.isReady)
      {
         if((dirSign > 0 && ctx.ticks.microTrendBias > 0.15) || (dirSign < 0 && ctx.ticks.microTrendBias < -0.15))
            b.tickBehaviorScore = 7.5;
         else if(MathAbs(ctx.ticks.microTrendBias) <= 0.15)
            b.tickBehaviorScore = 4.5;
         else
            b.tickBehaviorScore = 1.5;
      }
      else
      {
         b.tickBehaviorScore = 4.0;
      }

      // 10. Spread conditions (0..6)
      if(ctx.market.spreadRatio <= 1.1)       b.spreadScore = 6.0;
      else if(ctx.market.spreadRatio <= 1.4)  b.spreadScore = 4.5;
      else if(ctx.market.spreadRatio <= 1.8)  b.spreadScore = 2.5;
      else                                    b.spreadScore = 0.5;

      // 11. Strategy historical performance (0..4) - neutral 2.0 until min sample reached
      if(!stratStats.hasSufficientSample)
         b.strategyPerfScore = 2.0;
      else if(stratStats.profitFactor >= 1.35 && !stratStats.deteriorationWarning)
         b.strategyPerfScore = 4.0;
      else if(stratStats.profitFactor >= 1.0)
         b.strategyPerfScore = 2.5;
      else
         b.strategyPerfScore = 0.5;

      // 12. Market regime suitability (0..4)
      b.regimeSuitScore = suitableRegime ? 4.0 : 0.5;

      b.totalScore = b.directionScore + b.structureScore + b.trendStrengthScore +
                     b.momentumScore + b.volatilityScore + b.candleScore +
                     b.patternScore + b.mtfAgreementScore + b.tickBehaviorScore +
                     b.spreadScore + b.strategyPerfScore + b.regimeSuitScore;
      b.totalScore = MathMax(0.0, MathMin(100.0, b.totalScore));
      b.band = ClassifyBand(sig.direction, b.totalScore);

      sig.breakdown = b;
      sig.compositeScore = b.totalScore;
   }
};

#endif // __ASEA_TRADING_SIGNALSCORING_MQH__
