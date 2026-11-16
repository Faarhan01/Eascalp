//+------------------------------------------------------------------+
//|                                                SignalScoring.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.2.0 Non-Redundant 0-100 Scoring Engine |
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
      m_minScoreThreshold = 48.0;
   }

   void Configure(const double minScoreThreshold)
   {
      m_minScoreThreshold = MathMax(25.0, MathMin(95.0, minScoreThreshold));
   }

   double GetMinThreshold() const { return m_minScoreThreshold; }

   void ScoreSignal(STradeSignal &sig, const SAnalysisContext &ctx, const SStrategyStats &stratStats,
                    const ENUM_STRATEGY_SUITABILITY suitability) const
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

      // 1. Regime quality & stability (0..10)
      if(ctx.regime.isUnstable)
         b.regimeScore = 0.0;
      else if(suitability == SUIT_SUITABLE)
         b.regimeScore = 6.0 + 4.0 * ctx.regime.confidence;
      else if(suitability == SUIT_CONDITIONAL)
         b.regimeScore = 3.5 + 3.0 * ctx.regime.confidence;
      else
         b.regimeScore = 1.0;

      // 2. Market structure alignment, key level rejection/retest & session VWAP position (0..14)
      if(sig.strategyId == STRAT_REVERSAL_SCALPING)
      {
         if((dirSign > 0 && (ctx.structure.lastEvent == STRUCT_CHOCH_BULL || ctx.structure.lastEvent == STRUCT_LIQ_SWEEP_LOW || ctx.structure.lastEvent == STRUCT_FAILED_BREAKOUT_DOWN)) ||
            (dirSign < 0 && (ctx.structure.lastEvent == STRUCT_CHOCH_BEAR || ctx.structure.lastEvent == STRUCT_LIQ_SWEEP_HIGH || ctx.structure.lastEvent == STRUCT_FAILED_BREAKOUT_UP)))
            b.structureScore = 12.0;
         else
            b.structureScore = 5.0;
      }
      else if(sig.strategyId == STRAT_RANGE_SCALPING)
      {
         int touches = (dirSign > 0) ? ctx.structure.supportRejectCount : ctx.structure.resistanceRejectCount;
         b.structureScore = (touches >= 2) ? 13.0 : (touches == 1 ? 9.0 : 4.0);
      }
      else
      {
         if(ctx.structure.structureBias == dirSign) b.structureScore = 9.5;
         else if(ctx.structure.structureBias == 0)  b.structureScore = 5.5;
         else                                       b.structureScore = 2.0;

         if((dirSign > 0 && (ctx.structure.lastEvent == STRUCT_BOS_BULL || ctx.structure.lastEvent == STRUCT_RETEST_BULL || ctx.structure.lastEvent == STRUCT_BREAKOUT_UP)) ||
            (dirSign < 0 && (ctx.structure.lastEvent == STRUCT_BOS_BEAR || ctx.structure.lastEvent == STRUCT_RETEST_BEAR || ctx.structure.lastEvent == STRUCT_BREAKOUT_DOWN)))
            b.structureScore = MathMin(14.0, b.structureScore + 3.5);
      }

      // Clear room-to-opposing S/R wall assessment for non-breakout entries
      if(ctx.structure.isReady && sig.strategyId != STRAT_BREAKOUT_SCALPING && sig.takeProfit > 0.0 && sig.entryPrice > 0.0)
      {
         double tpDist = MathAbs(sig.takeProfit - sig.entryPrice);
         if(tpDist > 0.0)
         {
            if(dirSign > 0 && ctx.structure.nearestResistance > sig.entryPrice && ctx.structure.resistanceRejectCount >= 2)
            {
               double room = ctx.structure.nearestResistance - sig.entryPrice;
               if(room < tpDist * 0.55)
                  b.structureScore = MathMax(1.0, b.structureScore - 1.5);
               else if(room >= tpDist * 0.90)
                  b.structureScore = MathMin(14.0, b.structureScore + 1.0);
            }
            else if(dirSign < 0 && ctx.structure.nearestSupport > 0.0 && ctx.structure.nearestSupport < sig.entryPrice && ctx.structure.supportRejectCount >= 2)
            {
               double room = sig.entryPrice - ctx.structure.nearestSupport;
               if(room < tpDist * 0.55)
                  b.structureScore = MathMax(1.0, b.structureScore - 1.5);
               else if(room >= tpDist * 0.90)
                  b.structureScore = MathMin(14.0, b.structureScore + 1.0);
            }
         }
      }

      // Session VWAP positional confluence
      if(ctx.ind.vwapAvailable && ctx.ind.vwap > 0.0 && ctx.ind.atr > 0.0)
      {
         double vwapDistAtr = (ctx.market.close - ctx.ind.vwap) / ctx.ind.atr;
         if(sig.strategyId == STRAT_REVERSAL_SCALPING || sig.strategyId == STRAT_RANGE_SCALPING)
         {
            // Mean-reversion favors buying below VWAP or selling above VWAP toward the value mean
            if((dirSign > 0 && vwapDistAtr < -0.45) || (dirSign < 0 && vwapDistAtr > 0.45))
               b.structureScore = MathMin(14.0, b.structureScore + 1.5);
         }
         else
         {
            // Continuation strategies favor trading on the institutional side of session VWAP without extreme overextension
            if((dirSign > 0 && vwapDistAtr >= -0.25 && vwapDistAtr <= 2.2) ||
               (dirSign < 0 && vwapDistAtr <= 0.25  && vwapDistAtr >= -2.2))
               b.structureScore = MathMin(14.0, b.structureScore + 1.5);
            else if((dirSign > 0 && vwapDistAtr < -0.75) || (dirSign < 0 && vwapDistAtr > 0.75))
               b.structureScore = MathMax(1.0, b.structureScore - 1.0);
         }
      }

      // 3. Trend strength & EMA hierarchy (0..10)
      bool emaBull = (ctx.ind.emaFast > ctx.ind.emaMedium && ctx.ind.emaMedium > ctx.ind.emaSlow);
      bool emaBear = (ctx.ind.emaFast < ctx.ind.emaMedium && ctx.ind.emaMedium < ctx.ind.emaSlow);
      if(sig.strategyId == STRAT_RANGE_SCALPING)
         b.trendStrengthScore = (ctx.ind.adxMain <= 19.0) ? 9.5 : ((ctx.ind.adxMain <= 24.0) ? 6.5 : 2.0);
      else if(sig.strategyId == STRAT_REVERSAL_SCALPING)
         b.trendStrengthScore = (ctx.ind.adxMain <= 32.0) ? 8.0 : 4.0;
      else
      {
         double adxPts = MathMin(6.0, MathMax(1.0, (ctx.ind.adxMain / 35.0) * 6.0));
         double emaPts = ((dirSign > 0 && emaBull) || (dirSign < 0 && emaBear)) ? 4.0 :
                         (((dirSign > 0 && ctx.ind.emaFast > ctx.ind.emaMedium) || (dirSign < 0 && ctx.ind.emaFast < ctx.ind.emaMedium)) ? 2.0 : 0.5);
         b.trendStrengthScore = adxPts + emaPts;
      }

      // 4. Momentum quality & non-exhaustion (0..12)
      double momPts = 3.0;
      if((dirSign > 0 && ctx.ind.macdHist > 0.0 && ctx.ind.momentumAccel >= 0.0 && ctx.ind.rsi > 46.0 && ctx.ind.rsi < 72.0) ||
         (dirSign < 0 && ctx.ind.macdHist < 0.0 && ctx.ind.momentumAccel <= 0.0 && ctx.ind.rsi < 54.0 && ctx.ind.rsi > 28.0))
         momPts = 11.0;
      else if((dirSign > 0 && ctx.ind.macdHist > 0.0 && ctx.ind.rsi > 45.0 && ctx.ind.rsi < 74.0) ||
              (dirSign < 0 && ctx.ind.macdHist < 0.0 && ctx.ind.rsi < 55.0 && ctx.ind.rsi > 26.0))
         momPts = 8.5;
      else if((dirSign > 0 && ctx.ind.roc > 0.0) || (dirSign < 0 && ctx.ind.roc < 0.0))
         momPts = 7.0;
      if(sig.strategyId == STRAT_REVERSAL_SCALPING && ((dirSign > 0 && ctx.ind.bullDivergence) || (dirSign < 0 && ctx.ind.bearDivergence)))
         momPts = 12.0;
      else if(ctx.ind.momentumExhaustion && sig.strategyId != STRAT_REVERSAL_SCALPING)
         momPts = MathMax(1.0, momPts - 4.5);
      b.momentumScore = MathMin(12.0, momPts);

      // 5. Volatility normalized suitability (0..8)
      if(ctx.regime.volatilityState == VOL_NORMAL)
         b.volatilityScore = 8.0;
      else if(ctx.regime.volatilityState == VOL_HIGH)
         b.volatilityScore = (sig.strategyId == STRAT_VOLATILITY_EXPANSION || sig.strategyId == STRAT_BREAKOUT_SCALPING) ? 7.5 : 5.5;
      else if(ctx.regime.volatilityState == VOL_LOW)
         b.volatilityScore = (sig.strategyId == STRAT_RANGE_SCALPING) ? 6.5 : 3.0;
      else
         b.volatilityScore = 1.0;

      // 6. Combined non-duplicated candle + chart pattern confluence (0..10)
      double candlePart = 2.0;
      if(ctx.candle.pattern != CANDLE_NONE && ctx.candle.bias == sig.direction)
         candlePart = ctx.candle.contextValidated ? 5.5 : 4.0;
      else if(ctx.candle.pattern != CANDLE_NONE && ctx.candle.bias != SIGNAL_NONE && ctx.candle.bias != sig.direction)
         candlePart = 0.5;

      double chartPart = 2.0;
      if(ctx.chartPattern.pattern != PATTERN_NONE && ctx.chartPattern.bias == sig.direction)
         chartPart = 4.5 * ctx.chartPattern.confidence;
      else if(ctx.chartPattern.pattern != PATTERN_NONE && ctx.chartPattern.bias != SIGNAL_NONE && ctx.chartPattern.bias != sig.direction)
         chartPart = 0.5;
      b.patternConfluence = MathMin(10.0, candlePart + chartPart);

      // 7. Multi-timeframe weighted agreement (0..12)
      double mtfBase = (ctx.mtf.agreementScore / 100.0) * 12.0;
      if(ctx.mtf.higherBias == SIGNAL_NONE && mtfBase < 5.0)
         mtfBase = 5.0;
      else if(ctx.mtf.assessment == MTF_CONFLICTING || ((dirSign > 0 && ctx.mtf.higherBias == SIGNAL_SELL) || (dirSign < 0 && ctx.mtf.higherBias == SIGNAL_BUY)))
         mtfBase = (sig.strategyId == STRAT_REVERSAL_SCALPING) ? mtfBase * 0.65 : mtfBase * 0.35;
      b.mtfAgreementScore = MathMin(12.0, mtfBase);

      // 8. Cost-validated tick edge (0..8)
      if(ctx.ticks.isReady)
      {
         if(!ctx.ticks.tickProvidesNetEdge)
            b.tickEdgeScore = (sig.strategyId == STRAT_MICRO_MOMENTUM) ? 0.0 : 2.5;
         else if((dirSign > 0 && ctx.ticks.microTrendBias > 0.15) || (dirSign < 0 && ctx.ticks.microTrendBias < -0.15))
            b.tickEdgeScore = 8.0;
         else
            b.tickEdgeScore = 4.5;
      }
      else
      {
         b.tickEdgeScore = 3.5;
      }

      // 9. Execution cost margin (spread ratio + spread-to-ATR) (0..8)
      double spreadToAtrPct = (ctx.ind.atr > 0.0 && ctx.symbolProfile.point > 0.0)
                              ? ((ctx.market.spreadPoints * ctx.symbolProfile.point) / ctx.ind.atr) * 100.0
                              : 10.0;
      if(ctx.market.spreadRatio <= 1.10 && spreadToAtrPct <= 10.0)       b.executionCostScore = 8.0;
      else if(ctx.market.spreadRatio <= 1.35 && spreadToAtrPct <= 16.0)  b.executionCostScore = 6.0;
      else if(ctx.market.spreadRatio <= 1.75 && spreadToAtrPct <= 24.0)  b.executionCostScore = 3.5;
      else                                                               b.executionCostScore = 1.0;

      // 10. Strategy suitability & validated historical performance (0..8)
      double suitPart = (suitability == SUIT_SUITABLE) ? 4.0 : ((suitability == SUIT_CONDITIONAL) ? 2.5 : 0.5);
      double histPart = 2.0; // neutral until sufficient sample
      double perfAdj = 0.0;
      if(stratStats.hasSufficientSample)
      {
         if(stratStats.profitFactor >= 1.35 && !stratStats.deteriorationWarning)
         {
            histPart = 4.0;
            perfAdj = 3.0;
         }
         else if(stratStats.profitFactor >= 1.05 && !stratStats.deteriorationWarning)
            histPart = 2.8;
         else if(stratStats.deteriorationWarning || stratStats.profitFactor < 0.85)
         {
            histPart = 0.0;
            perfAdj = -6.0;
         }
         else
            histPart = 1.0;
      }
      b.strategySuitScore = suitPart + histPart;

      b.totalScore = b.regimeScore + b.structureScore + b.trendStrengthScore +
                     b.momentumScore + b.volatilityScore + b.patternConfluence +
                     b.mtfAgreementScore + b.tickEdgeScore + b.executionCostScore +
                     b.strategySuitScore + perfAdj;
      b.totalScore = MathMax(0.0, MathMin(100.0, b.totalScore));
      b.isValidatedScore = stratStats.hasSufficientSample;
      b.band = ClassifyBand(sig.direction, b.totalScore);

      sig.breakdown = b;
      sig.compositeScore = b.totalScore;
   }

   void ApplyMultiStrategyConsensus(STradeSignal &sig, const int agreeCount, const bool hasOppositeConflict) const
   {
      if(!sig.isValid || sig.direction == SIGNAL_NONE)
         return;

      sig.consensusCount = MathMax(1, agreeCount);
      sig.hasOppositeConflict = hasOppositeConflict;

      double adj = 0.0;
      if(agreeCount >= 3)      adj += 6.5;
      else if(agreeCount == 2) adj += 4.0;

      if(hasOppositeConflict)
      {
         adj -= 4.0;
         if(sig.conflictingConditions != "") sig.conflictingConditions += "; ";
         sig.conflictingConditions += "Weak opposite strategy conflict";
      }

      if(adj != 0.0)
      {
         double updated = MathMax(0.0, MathMin(100.0, sig.compositeScore + adj));
         sig.compositeScore = updated;
         sig.breakdown.totalScore = updated;
         sig.breakdown.band = ClassifyBand(sig.direction, updated);
         if(agreeCount >= 2)
            sig.rationale += StringFormat(" [Consensus=%d]", agreeCount);
      }
   }
};

#endif // __ASEA_TRADING_SIGNALSCORING_MQH__
