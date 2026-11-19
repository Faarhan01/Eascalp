//+------------------------------------------------------------------+
//|                                                SignalScoring.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v3.1.0 Non-Redundant 0-100 Scoring Engine |
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
      m_minScoreThreshold = 64.0;
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

      // 1. Regime quality, trend efficiency & stability (0..10)
      if(ctx.regime.isUnstable)
         b.regimeScore = 0.0;
      else if(suitability == SUIT_SUITABLE)
         b.regimeScore = 5.0 + 4.0 * ctx.regime.confidence + ((ctx.regime.efficiencyRatio >= 0.28) ? 1.0 : 0.0);
      else if(suitability == SUIT_CONDITIONAL)
         b.regimeScore = 2.5 + 3.0 * ctx.regime.confidence;
      else
         b.regimeScore = 0.0;

      // 2. Market structure alignment, key level rejection/retest & session VWAP position (0..14)
      bool isRevOrMeanRev = (sig.strategyId == STRAT_REVERSAL_SCALPING ||
                             sig.strategyId == STRAT_LIQUIDITY_SWEEP ||
                             sig.strategyId == STRAT_VWAP_REVERSION);
      if(isRevOrMeanRev)
      {
         bool bullSweepEv = (ctx.structure.lastEvent == STRUCT_LIQ_SWEEP_LOW || ctx.structure.lastEvent == STRUCT_FAILED_BREAKOUT_DOWN || ctx.structure.lastEvent == STRUCT_REJECTION_LOW);
         bool bearSweepEv = (ctx.structure.lastEvent == STRUCT_LIQ_SWEEP_HIGH || ctx.structure.lastEvent == STRUCT_FAILED_BREAKOUT_UP || ctx.structure.lastEvent == STRUCT_REJECTION_HIGH);
         if((dirSign > 0 && (ctx.structure.lastEvent == STRUCT_CHOCH_BULL || bullSweepEv)) ||
            (dirSign < 0 && (ctx.structure.lastEvent == STRUCT_CHOCH_BEAR || bearSweepEv)))
            b.structureScore = (sig.strategyId == STRAT_LIQUIDITY_SWEEP) ? 12.5 : 11.5;
         else if(sig.strategyId == STRAT_VWAP_REVERSION &&
                 ((dirSign > 0 && ctx.market.close <= ctx.structure.nearestSupport + ctx.ind.atr * 0.65) ||
                  (dirSign < 0 && ctx.structure.nearestResistance > 0.0 && ctx.market.close >= ctx.structure.nearestResistance - ctx.ind.atr * 0.65)))
            b.structureScore = 9.0;
         else
            b.structureScore = 4.5;
      }
      else if(sig.strategyId == STRAT_RANGE_SCALPING)
      {
         int touches = (dirSign > 0) ? ctx.structure.supportRejectCount : ctx.structure.resistanceRejectCount;
         b.structureScore = (touches >= 2) ? 12.5 : (touches == 1 ? 8.0 : 2.0);
      }
      else
      {
         if(ctx.structure.structureBias == dirSign) b.structureScore = 8.5;
         else if(ctx.structure.structureBias == 0)  b.structureScore = 3.5;
         else                                       b.structureScore = 0.0;

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
               if(room < tpDist * 0.60)
                  b.structureScore = MathMax(0.0, b.structureScore - 3.0);
               else if(room >= tpDist * 0.90)
                  b.structureScore = MathMin(14.0, b.structureScore + 1.0);
            }
            else if(dirSign < 0 && ctx.structure.nearestSupport > 0.0 && ctx.structure.nearestSupport < sig.entryPrice && ctx.structure.supportRejectCount >= 2)
            {
               double room = sig.entryPrice - ctx.structure.nearestSupport;
               if(room < tpDist * 0.60)
                  b.structureScore = MathMax(0.0, b.structureScore - 3.0);
               else if(room >= tpDist * 0.90)
                  b.structureScore = MathMin(14.0, b.structureScore + 1.0);
            }
         }
      }

      // Session VWAP positional confluence
      if(ctx.ind.vwapAvailable && ctx.ind.vwap > 0.0 && ctx.ind.atr > 0.0)
      {
         double vwapDistAtr = (ctx.market.close - ctx.ind.vwap) / ctx.ind.atr;
         if(isRevOrMeanRev || sig.strategyId == STRAT_RANGE_SCALPING)
         {
            if((dirSign > 0 && vwapDistAtr < -0.45) || (dirSign < 0 && vwapDistAtr > 0.45))
            {
               double vwapBonus = (sig.strategyId == STRAT_VWAP_REVERSION && MathAbs(vwapDistAtr) >= 1.40) ? 2.0 : 1.5;
               b.structureScore = MathMin(14.0, b.structureScore + vwapBonus);
            }
         }
         else
         {
            if((dirSign > 0 && vwapDistAtr >= 0.0 && vwapDistAtr <= 2.0) ||
               (dirSign < 0 && vwapDistAtr <= 0.0 && vwapDistAtr >= -2.0))
               b.structureScore = MathMin(14.0, b.structureScore + 1.5);
            else if((dirSign > 0 && vwapDistAtr < -0.60) || (dirSign < 0 && vwapDistAtr > 0.60))
               b.structureScore = MathMax(0.0, b.structureScore - 2.0);
         }
      }

      // Graph Swing Extremum / Value-Zone & HTF wall confluence
      if(ctx.structure.isReady && sig.strategyId != STRAT_BREAKOUT_SCALPING && sig.strategyId != STRAT_VOLATILITY_EXPANSION)
      {
         if(isRevOrMeanRev || sig.strategyId == STRAT_RANGE_SCALPING)
         {
            if((dirSign > 0 && ctx.structure.isDiscountZone) || (dirSign < 0 && ctx.structure.isPremiumZone))
               b.structureScore = MathMin(14.0, b.structureScore + 1.5);
         }
         else
         {
            if((dirSign > 0 && ctx.structure.swingRangePos01 <= 0.55) || (dirSign < 0 && ctx.structure.swingRangePos01 >= 0.45))
               b.structureScore = MathMin(14.0, b.structureScore + 1.0);
            else if((dirSign > 0 && ctx.structure.swingRangePos01 >= 0.78) || (dirSign < 0 && ctx.structure.swingRangePos01 <= 0.22))
               b.structureScore = MathMax(0.0, b.structureScore - 2.0);
         }
      }

      // Previous Daily High/Low (PDH/PDL) & H1 HTF swing boundary institutional reference awareness
      if(ctx.structure.prevDayHigh > 0.0 && ctx.structure.prevDayLow > 0.0 && ctx.ind.atr > 0.0)
      {
         if(isRevOrMeanRev || sig.strategyId == STRAT_RANGE_SCALPING)
         {
            bool sweptPdl = (dirSign > 0 && ctx.market.low <= ctx.structure.prevDayLow + ctx.ind.atr * 0.10 && ctx.market.close > ctx.structure.prevDayLow);
            bool sweptPdh = (dirSign < 0 && ctx.market.high >= ctx.structure.prevDayHigh - ctx.ind.atr * 0.10 && ctx.market.close < ctx.structure.prevDayHigh);
            if(sweptPdl || sweptPdh)
               b.structureScore = MathMin(14.0, b.structureScore + 1.5);
         }
         else if(sig.strategyId != STRAT_BREAKOUT_SCALPING)
         {
            bool blockedByPdh = (dirSign > 0 && ctx.market.close < ctx.structure.prevDayHigh &&
                                 (ctx.structure.prevDayHigh - ctx.market.close) < ctx.ind.atr * 0.55);
            bool blockedByPdl = (dirSign < 0 && ctx.market.close > ctx.structure.prevDayLow &&
                                 (ctx.market.close - ctx.structure.prevDayLow) < ctx.ind.atr * 0.55);
            bool blockedByHtfHi = (dirSign > 0 && ctx.structure.htfSwingHigh > ctx.market.close &&
                                   (ctx.structure.htfSwingHigh - ctx.market.close) < ctx.ind.atr * 0.55);
            bool blockedByHtfLo = (dirSign < 0 && ctx.structure.htfSwingLow > 0.0 && ctx.market.close > ctx.structure.htfSwingLow &&
                                   (ctx.market.close - ctx.structure.htfSwingLow) < ctx.ind.atr * 0.55);
            if(blockedByPdh || blockedByPdl || blockedByHtfHi || blockedByHtfLo)
               b.structureScore = MathMax(0.0, b.structureScore - 2.0);
         }
      }

      // 3. Trend strength & EMA hierarchy (0..10)
      bool emaBull = (ctx.ind.emaFast > ctx.ind.emaMedium && ctx.ind.emaMedium > ctx.ind.emaSlow);
      bool emaBear = (ctx.ind.emaFast < ctx.ind.emaMedium && ctx.ind.emaMedium < ctx.ind.emaSlow);
      if(sig.strategyId == STRAT_RANGE_SCALPING || sig.strategyId == STRAT_VWAP_REVERSION)
         b.trendStrengthScore = (ctx.ind.adxMain <= 18.0) ? 9.5 : ((ctx.ind.adxMain <= 23.0) ? 6.5 : 2.0);
      else if(sig.strategyId == STRAT_REVERSAL_SCALPING || sig.strategyId == STRAT_LIQUIDITY_SWEEP)
         b.trendStrengthScore = (ctx.ind.adxMain <= 28.0) ? 8.0 : 3.5;
      else
      {
         double adxPts = MathMin(6.0, MathMax(0.5, ((ctx.ind.adxMain - 10.0) / 25.0) * 6.0));
         if(ctx.ind.adxRising) adxPts = MathMin(6.0, adxPts + 0.5);
         double emaPts = ((dirSign > 0 && emaBull) || (dirSign < 0 && emaBear)) ? 4.0 :
                         (((dirSign > 0 && ctx.ind.emaFast > ctx.ind.emaMedium) || (dirSign < 0 && ctx.ind.emaFast < ctx.ind.emaMedium)) ? 2.0 : 0.0);
         double ribbonBonus = (sig.strategyId == STRAT_EMA_RIBBON &&
                               ((dirSign > 0 && ctx.ind.emaSlow >= ctx.ind.smaTrend) ||
                                (dirSign < 0 && ctx.ind.emaSlow <= ctx.ind.smaTrend))) ? 1.5 : 0.0;
         b.trendStrengthScore = MathMin(10.0, adxPts + emaPts + ribbonBonus);
      }

      // 4. Momentum quality & non-exhaustion (0..12)
      double momPts = 1.5;
      if((dirSign > 0 && ctx.ind.macdHist > 0.0 && ctx.ind.momentumAccel >= 0.0 && ctx.ind.rsi > 48.0 && ctx.ind.rsi < 70.0) ||
         (dirSign < 0 && ctx.ind.macdHist < 0.0 && ctx.ind.momentumAccel <= 0.0 && ctx.ind.rsi < 52.0 && ctx.ind.rsi > 30.0))
         momPts = 11.5;
      else if((dirSign > 0 && ctx.ind.macdHist > 0.0 && ctx.ind.rsi > 45.0 && ctx.ind.rsi < 72.0) ||
              (dirSign < 0 && ctx.ind.macdHist < 0.0 && ctx.ind.rsi < 55.0 && ctx.ind.rsi > 28.0))
         momPts = 8.5;
      else if((dirSign > 0 && ctx.ind.roc > 0.0) || (dirSign < 0 && ctx.ind.roc < 0.0))
         momPts = 5.5;
      if(isRevOrMeanRev && ((dirSign > 0 && ctx.ind.bullDivergence) || (dirSign < 0 && ctx.ind.bearDivergence)))
         momPts = 12.0;
      else if(ctx.ind.momentumExhaustion && !isRevOrMeanRev)
         momPts = MathMax(0.0, momPts - 5.5);

      // Volume conviction adjustment (RVOL confirmation for breakouts/momentum & stopping-volume sweeps)
      if(sig.strategyId == STRAT_BREAKOUT_SCALPING || sig.strategyId == STRAT_VOLATILITY_EXPANSION ||
         sig.strategyId == STRAT_MOMENTUM_SCALPING || sig.strategyId == STRAT_EMA_RIBBON)
      {
         if(ctx.ind.relativeVolume >= 1.25)      momPts += 1.0;
         else if(ctx.ind.relativeVolume < 0.75)  momPts = MathMax(0.0, momPts - 1.5);
      }
      else if(isRevOrMeanRev && ctx.ind.relativeVolume >= 1.20)
      {
         momPts += 0.5;
      }
      b.momentumScore = MathMin(12.0, momPts);

      // 5. Volatility normalized suitability (0..8)
      if(ctx.regime.volatilityState == VOL_NORMAL)
         b.volatilityScore = 7.0;
      else if(ctx.regime.volatilityState == VOL_HIGH)
         b.volatilityScore = (sig.strategyId == STRAT_VOLATILITY_EXPANSION || sig.strategyId == STRAT_BREAKOUT_SCALPING) ? 8.0 : 4.5;
      else if(ctx.regime.volatilityState == VOL_LOW)
         b.volatilityScore = (sig.strategyId == STRAT_RANGE_SCALPING || sig.strategyId == STRAT_VWAP_REVERSION) ? 6.0 : 2.0;
      else
         b.volatilityScore = 0.5;

      // 6. Combined non-duplicated candle + chart pattern confluence (0..10, 0 when absent/opposing)
      double candlePart = 0.0;
      if(ctx.candle.pattern != CANDLE_NONE && ctx.candle.bias == sig.direction)
         candlePart = ctx.candle.contextValidated ? 5.5 : 3.0;
      else if(ctx.candle.pattern != CANDLE_NONE && ctx.candle.bias != SIGNAL_NONE && ctx.candle.bias != sig.direction)
         candlePart = 0.0;

      double chartPart = 0.0;
      if(ctx.chartPattern.pattern != PATTERN_NONE && ctx.chartPattern.bias == sig.direction)
         chartPart = 4.5 * ctx.chartPattern.confidence;
      b.patternConfluence = MathMin(10.0, candlePart + chartPart);

      // 7. Multi-timeframe weighted agreement (0..12, no artificial boost for dead neutral HTF)
      bool allowCounterHtfTol = (isRevOrMeanRev || sig.strategyId == STRAT_RANGE_SCALPING);
      double mtfBase = (ctx.mtf.agreementScore / 100.0) * 12.0;
      bool opposesHtf = ((dirSign > 0 && ctx.mtf.higherBias == SIGNAL_SELL) || (dirSign < 0 && ctx.mtf.higherBias == SIGNAL_BUY));
      if(ctx.mtf.higherBias == SIGNAL_NONE && ctx.mtf.intermediateBias == SIGNAL_NONE)
         mtfBase = MathMin(3.0, mtfBase);
      else if(ctx.mtf.assessment == MTF_CONFLICTING || opposesHtf)
         mtfBase = allowCounterHtfTol ? (mtfBase * 0.45) : 0.0;
      b.mtfAgreementScore = MathMin(12.0, mtfBase);

      // 8. Cost-validated tick edge (0..8, 0 if spread consumes tick movement)
      if(ctx.ticks.isReady)
      {
         if(!ctx.ticks.tickProvidesNetEdge)
            b.tickEdgeScore = 0.0;
         else if((dirSign > 0 && ctx.ticks.microTrendBias > 0.20) || (dirSign < 0 && ctx.ticks.microTrendBias < -0.20))
            b.tickEdgeScore = 8.0;
         else
            b.tickEdgeScore = 4.0;
      }
      else
      {
         b.tickEdgeScore = 2.0;
      }

      // 9. Execution cost margin (spread ratio + spread-to-ATR) (0..8)
      double spreadToAtrPct = (ctx.ind.atr > 0.0 && ctx.symbolProfile.point > 0.0)
                              ? ((ctx.market.spreadPoints * ctx.symbolProfile.point) / ctx.ind.atr) * 100.0
                              : 10.0;
      if(ctx.market.spreadRatio <= 1.10 && spreadToAtrPct <= 9.0)        b.executionCostScore = 8.0;
      else if(ctx.market.spreadRatio <= 1.35 && spreadToAtrPct <= 15.0)  b.executionCostScore = 6.0;
      else if(ctx.market.spreadRatio <= 1.75 && spreadToAtrPct <= 22.0)  b.executionCostScore = 3.0;
      else                                                               b.executionCostScore = 0.5;

      // 10. Strategy suitability & validated historical performance (0..8)
      double suitPart = (suitability == SUIT_SUITABLE) ? 4.5 : ((suitability == SUIT_CONDITIONAL) ? 2.0 : 0.0);
      double histPart = 1.0; // lean cold-start prior
      double perfAdj = 0.0;
      if(stratStats.hasSufficientSample)
      {
         if(stratStats.profitFactor >= 1.35 && !stratStats.deteriorationWarning)
         {
            histPart = 3.5;
            perfAdj = 3.5;
         }
         else if(stratStats.profitFactor >= 1.05 && !stratStats.deteriorationWarning)
            histPart = 2.5;
         else if(stratStats.deteriorationWarning || stratStats.profitFactor < 0.92)
         {
            histPart = 0.0;
            perfAdj = -9.0;
         }
         else
            histPart = 0.5;
      }
      b.strategySuitScore = suitPart + histPart;

      double htfCounterPenalty = (opposesHtf && !allowCounterHtfTol) ? -9.0 : 0.0;
      double htfNeutralPenalty = (!allowCounterHtfTol && ctx.mtf.higherBias == SIGNAL_NONE) ? -4.0 : 0.0;
      double rrAdj = 0.0;
      if(sig.entryPrice > 0.0 && sig.stopLoss > 0.0 && sig.takeProfit > 0.0)
      {
         double slD = MathAbs(sig.entryPrice - sig.stopLoss);
         double tpD = MathAbs(sig.takeProfit - sig.entryPrice);
         if(slD > 0.0)
         {
            double rr = tpD / slD;
            if(rr < 1.50)       rrAdj = -4.5;
            else if(rr >= 1.85) rrAdj = 2.5;
         }
      }

      double dnaAdj = 0.0;
      if(ctx.symbolProfile.empiricalProfileReady)
      {
         double aff = 1.0;
         if(sig.strategyId == STRAT_LIQUIDITY_SWEEP)
            aff = ctx.assetProfile.sweepAffinity;
         else if(sig.strategyId == STRAT_RANGE_SCALPING || sig.strategyId == STRAT_VWAP_REVERSION || sig.strategyId == STRAT_REVERSAL_SCALPING)
            aff = ctx.assetProfile.meanRevAffinity;
         else
            aff = ctx.assetProfile.trendAffinity;
         dnaAdj = MathMax(-3.0, MathMin(3.5, (aff - 1.0) * 10.0));
      }

      double vwapZBonus = 0.0;
      if(isRevOrMeanRev && ctx.ind.vwapAvailable && ctx.ind.vwapStdDev > 0.0)
      {
         if((dirSign > 0 && ctx.ind.vwapZScore <= -1.6) || (dirSign < 0 && ctx.ind.vwapZScore >= 1.6))
            vwapZBonus = 1.5;
      }

      b.totalScore = b.regimeScore + b.structureScore + b.trendStrengthScore +
                     b.momentumScore + b.volatilityScore + b.patternConfluence +
                     b.mtfAgreementScore + b.tickEdgeScore + b.executionCostScore +
                     b.strategySuitScore + perfAdj + htfCounterPenalty + htfNeutralPenalty + rrAdj + dnaAdj + vwapZBonus;
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
