//+------------------------------------------------------------------+
//|                                                 MarketRegime.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.9.0 18-State Regime & Transition Engine|
//+------------------------------------------------------------------+
#ifndef __ASEA_MARKET_MARKETREGIME_MQH__
#define __ASEA_MARKET_MARKETREGIME_MQH__

#include "../Core/Types.mqh"
#include "MarketData.mqh"

class CMarketRegime
{
private:
   double             m_adxStrongThreshold;
   double             m_adxWeakThreshold;
   double             m_volHighRatio;
   double             m_volLowRatio;
   double             m_spreadUnstableRatio;
   SRegimeState       m_state;
   SRegimeState       m_barState;
   ENUM_MARKET_REGIME m_prevStableRegime;
   datetime           m_lastAnalyzedBar;
   datetime           m_stateSyncedBar;
   bool               m_unstableOverlayActive;
   double             m_cachedEffRatio;

   double ComputeEfficiencyRatio(const MqlRates &rates[], const int period) const
   {
      int total = ArraySize(rates);
      if(total <= period) return 0.0;
      double netChange = MathAbs(rates[0].close - rates[period].close);
      double sumMoves = 0.0;
      for(int i = 0; i < period; i++)
         sumMoves += MathAbs(rates[i].close - rates[i + 1].close);
      if(sumMoves <= 0.0) return 0.0;
      return netChange / sumMoves;
   }

public:
   CMarketRegime()
   {
      m_adxStrongThreshold  = 28.0;
      m_adxWeakThreshold    = 18.0;
      m_volHighRatio        = 1.45;
      m_volLowRatio         = 0.70;
      m_spreadUnstableRatio = 2.80;
      m_prevStableRegime    = REGIME_UNKNOWN;
      m_lastAnalyzedBar     = 0;
      m_stateSyncedBar      = 0;
      m_unstableOverlayActive = false;
      m_cachedEffRatio      = 0.0;
      m_state.Reset();
      m_barState.Reset();
   }

   void Configure(const double adxStrong, const double adxWeak, const double volHighRatio,
                  const double volLowRatio, const double spreadUnstableRatio)
   {
      m_adxStrongThreshold  = MathMax(20.0, adxStrong);
      m_adxWeakThreshold    = MathMax(10.0, MathMin(m_adxStrongThreshold - 2.0, adxWeak));
      m_volHighRatio        = MathMax(1.1, volHighRatio);
      m_volLowRatio         = MathMax(0.3, MathMin(0.95, volLowRatio));
      m_spreadUnstableRatio = MathMax(1.5, spreadUnstableRatio);
   }

   bool Classify(const CMarketData &data, const ENUM_TIMEFRAMES tf, const SIndicatorValues &ind,
                 const SStructureState &structure, const STickMetrics &ticks, const double pipPoints = 1.0)
   {
      if(!data.IsDataReady() || !ind.isReady)
      {
         m_state.Reset();
         m_stateSyncedBar = 0;
         m_unstableOverlayActive = false;
         return false;
      }

      datetime barT = data.GetBarTime();
      bool barRecalc = (barT != m_lastAnalyzedBar || m_barState.regime == REGIME_UNKNOWN);
      if(barRecalc)
      {
         double closedClose = data.GetClosedClose();
         ENUM_MARKET_REGIME prevClosed = m_barState.regime;
         m_barState.Reset();
         m_barState.previousRegime = prevClosed;

         MqlRates rates[];
         if(data.CopyAvailableClosedRates(tf, 16, 20, rates))
            m_cachedEffRatio = ComputeEfficiencyRatio(rates, 14);
         m_lastAnalyzedBar = barT;

         double effRatio = m_cachedEffRatio;
         double volRatio = ind.relativeAtr;
         m_barState.trendStrength          = ind.adxMain;
         m_barState.volatilityRatio        = volRatio;
         m_barState.volatilityPercentile   = ind.volatilityPercentile;
         m_barState.efficiencyRatio        = effRatio;
         m_barState.directionalPersistence = ind.directionalPersist;

         if(volRatio >= 2.2)
            m_barState.volatilityState = VOL_ABNORMAL;
         else if(volRatio >= m_volHighRatio)
            m_barState.volatilityState = VOL_HIGH;
         else if(volRatio <= m_volLowRatio)
            m_barState.volatilityState = VOL_LOW;
         else
            m_barState.volatilityState = VOL_NORMAL;

         m_barState.supportingMeasurements = StringFormat("ADX=%.1f VolR=%.2f ER=%.2f Persist=%.2f Disp=%.2fATR",
                                                          ind.adxMain, volRatio, effRatio, ind.directionalPersist, ind.priceDisplacementAtr);

         if(volRatio >= 2.85 || (ind.volatilityPercentile >= 99.0 && volRatio >= 2.0))
         {
            m_barState.regime = REGIME_ABNORMAL_VOLATILITY;
            m_barState.isVolatile = true; m_barState.isUnstable = (effRatio < 0.15 && volRatio >= 3.0); m_barState.confidence = 0.88;
         }
         else if(structure.structuralReversal || (structure.failedBreakout && (ind.bullDivergence || ind.bearDivergence)))
         {
            m_barState.regime = REGIME_POTENTIAL_REVERSAL;
            m_barState.confidence = 0.78;
         }
         else if(ind.momentumExhaustion || (structure.trendExhaustion && MathAbs(ind.emaDistanceAtr) > 2.35 && (ind.rsi >= 72.0 || ind.rsi <= 28.0)))
         {
            m_barState.regime = REGIME_TREND_EXHAUSTION;
            m_barState.isTrending = true; m_barState.confidence = 0.76;
         }
         else if(volRatio >= 1.32 && ind.shortLongVolRatio >= 1.25 && ind.bbWidthPct > ind.prevBbWidthPct &&
                 (!ticks.isReady || ticks.activityRatio >= 1.10 || ind.bbWidthPct > ind.prevBbWidthPct * 1.03))
         {
            m_barState.regime = REGIME_VOL_EXPANSION;
            m_barState.isVolatile = true; m_barState.isTrending = (ind.adxMain >= m_adxWeakThreshold); m_barState.confidence = 0.82;
         }
         else if(volRatio <= 0.68 && ind.volatilityPercentile <= 25.0 && structure.tightConsolidation)
         {
            m_barState.regime = REGIME_VOL_CONTRACTION;
            m_barState.isRanging = true; m_barState.confidence = 0.84;
         }
         else
         {
            bool bullStack = (ind.emaFast > ind.emaMedium && ind.emaMedium > ind.emaSlow && closedClose > ind.emaMedium);
            bool bearStack = (ind.emaFast < ind.emaMedium && ind.emaMedium < ind.emaSlow && closedClose < ind.emaMedium);

            if(ind.adxMain >= m_adxStrongThreshold && effRatio >= 0.28)
            {
               if(bullStack && ind.adxPlusDI > ind.adxMinusDI && ind.directionalPersist >= 0.2)
               {
                  m_barState.regime = (closedClose > ind.smaTrend && structure.hasHH && structure.hasHL)
                                      ? REGIME_ESTABLISHED_BULL : REGIME_STRONG_BULL_TREND;
                  m_barState.isTrending = true; m_barState.confidence = 0.88;
               }
               else if(bearStack && ind.adxMinusDI > ind.adxPlusDI && ind.directionalPersist <= -0.2)
               {
                  m_barState.regime = (closedClose < ind.smaTrend && structure.hasLH && structure.hasLL)
                                      ? REGIME_ESTABLISHED_BEAR : REGIME_STRONG_BEAR_TREND;
                  m_barState.isTrending = true; m_barState.confidence = 0.88;
               }
            }

            if(m_barState.regime == REGIME_UNKNOWN && ind.adxMain >= m_adxWeakThreshold)
            {
               if(ind.emaFast > ind.emaMedium && ind.adxPlusDI > ind.adxMinusDI && ind.macdHist > 0.0 &&
                  (m_prevStableRegime == REGIME_SIDEWAYS || m_prevStableRegime == REGIME_TIGHT_CONSOLIDATION || m_prevStableRegime == REGIME_VOL_CONTRACTION))
               {
                  m_barState.regime = REGIME_EARLY_TREND_BULL;
                  m_barState.isTrending = true; m_barState.confidence = 0.74;
               }
               else if(ind.emaFast < ind.emaMedium && ind.adxMinusDI > ind.adxPlusDI && ind.macdHist < 0.0 &&
                       (m_prevStableRegime == REGIME_SIDEWAYS || m_prevStableRegime == REGIME_TIGHT_CONSOLIDATION || m_prevStableRegime == REGIME_VOL_CONTRACTION))
               {
                  m_barState.regime = REGIME_EARLY_TREND_BEAR;
                  m_barState.isTrending = true; m_barState.confidence = 0.74;
               }
               else if((bullStack || structure.structureBias > 0) && ind.adxPlusDI >= ind.adxMinusDI)
               {
                  m_barState.regime = REGIME_WEAK_BULL_TREND;
                  m_barState.isTrending = true; m_barState.confidence = 0.68;
               }
               else if((bearStack || structure.structureBias < 0) && ind.adxMinusDI >= ind.adxPlusDI)
               {
                  m_barState.regime = REGIME_WEAK_BEAR_TREND;
                  m_barState.isTrending = true; m_barState.confidence = 0.68;
               }
            }

            if(m_barState.regime == REGIME_UNKNOWN)
            {
               if(structure.tightConsolidation)
               {
                  m_barState.regime = REGIME_TIGHT_CONSOLIDATION;
                  m_barState.isRanging = true; m_barState.confidence = 0.78;
               }
               else if(structure.wideConsolidation)
               {
                  m_barState.regime = REGIME_WIDE_CONSOLIDATION;
                  m_barState.isRanging = true; m_barState.confidence = 0.74;
               }
               else
               {
                  m_barState.regime = REGIME_SIDEWAYS;
                  m_barState.isRanging = true; m_barState.confidence = 0.66;
               }
            }
         }

         m_barState.transitionDetected = (prevClosed != REGIME_UNKNOWN && m_barState.regime != prevClosed);
         if(m_barState.regime != REGIME_UNKNOWN && m_barState.regime != REGIME_ABNORMAL_VOLATILITY)
            m_prevStableRegime = m_barState.regime;
         m_barState.label = RegimeToString(m_barState.regime);
      }

      // Apply live spread-spike instability as a non-destructive overlay on top of the cached bar regime
      double minSpreadPts = MathMax(2.0, pipPoints * 1.0);
      double curSpreadRatio = data.GetSpreadRatio();
      double curSpreadPts   = data.GetSpreadPoints();
      bool unstableNow = ((curSpreadRatio >= m_spreadUnstableRatio && curSpreadPts > minSpreadPts) ||
                          (ticks.spreadSpikeDetected && curSpreadRatio >= 2.40));

      if(barRecalc || m_stateSyncedBar != barT || unstableNow != m_unstableOverlayActive)
      {
         m_state = m_barState;
         if(unstableNow)
         {
            m_state.regime     = REGIME_UNSTABLE;
            m_state.isVolatile = true;
            m_state.isUnstable = true;
            m_state.confidence = 0.92;
            m_state.label      = RegimeToString(REGIME_UNSTABLE);
         }
         m_stateSyncedBar = barT;
         m_unstableOverlayActive = unstableNow;
      }

      return true;
   }

   bool         IsUnstable() const { return m_state.isUnstable; }
   SRegimeState GetState() const   { return m_state; }
};

#endif // __ASEA_MARKET_MARKETREGIME_MQH__
