//+------------------------------------------------------------------+
//|                                                 MarketRegime.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        Market Regime & Volatility Classification |
//+------------------------------------------------------------------+
#ifndef __ASEA_MARKET_MARKETREGIME_MQH__
#define __ASEA_MARKET_MARKETREGIME_MQH__

#include "../Core/Types.mqh"
#include "MarketData.mqh"

class CMarketRegime
{
private:
   double       m_adxStrongThreshold;
   double       m_adxWeakThreshold;
   double       m_volHighRatio;
   double       m_volLowRatio;
   double       m_spreadUnstableRatio;
   SRegimeState m_state;

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
      m_spreadUnstableRatio = 2.20;
      m_state.Reset();
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
                 const SStructureState &structure, const STickMetrics &ticks)
   {
      m_state.Reset();
      SMarketSnapshot snap = data.GetSnapshot();
      if(!snap.dataReady || !ind.isReady)
         return false;

      MqlRates rates[];
      double effRatio = 0.0;
      if(data.CopyClosedRates(tf, 20, rates))
         effRatio = ComputeEfficiencyRatio(rates, 14);

      double volRatio = (ind.atrBaseline > 0.0) ? (ind.atr / ind.atrBaseline) : 1.0;

      m_state.trendStrength   = ind.adxMain;
      m_state.volatilityRatio = volRatio;
      m_state.efficiencyRatio = effRatio;

      if(volRatio >= 2.0)
         m_state.volatilityState = VOL_EXTREME;
      else if(volRatio >= m_volHighRatio)
         m_state.volatilityState = VOL_HIGH;
      else if(volRatio <= m_volLowRatio)
         m_state.volatilityState = VOL_LOW;
      else
         m_state.volatilityState = VOL_NORMAL;

      // 1. Unstable or abnormal conditions (extreme spread spike or chaotic volatility spike)
      if(snap.spreadRatio >= m_spreadUnstableRatio || ticks.spreadSpikeDetected ||
         (volRatio >= 2.4 && effRatio < 0.20))
      {
         m_state.regime     = REGIME_UNSTABLE;
         m_state.isVolatile = true;
         m_state.isUnstable = true;
         m_state.label      = RegimeToString(m_state.regime);
         return true;
      }

      bool bullStack = (ind.emaFast > ind.emaMedium && ind.emaMedium > ind.emaSlow && snap.close > ind.emaMedium);
      bool bearStack = (ind.emaFast < ind.emaMedium && ind.emaMedium < ind.emaSlow && snap.close < ind.emaMedium);

      // 2. Volatility expansion / contraction
      if(volRatio >= 1.35 && ind.bbWidthPct > 0.0 && ticks.activityRatio >= 1.35 && structure.lastEvent != STRUCT_NONE)
      {
         m_state.regime     = REGIME_VOL_EXPANSION;
         m_state.isVolatile = true;
         m_state.isTrending = (ind.adxMain >= m_adxWeakThreshold);
         m_state.label      = RegimeToString(m_state.regime);
         return true;
      }

      if(volRatio <= 0.65 && structure.inConsolidation)
      {
         m_state.regime    = REGIME_VOL_CONTRACTION;
         m_state.isRanging = true;
         m_state.label     = RegimeToString(m_state.regime);
         return true;
      }

      // 3. Directional Trends
      if(ind.adxMain >= m_adxStrongThreshold && effRatio >= 0.35)
      {
         if(bullStack && ind.adxPlusDI > ind.adxMinusDI)
         {
            m_state.regime     = REGIME_STRONG_BULL_TREND;
            m_state.isTrending = true;
            m_state.label      = RegimeToString(m_state.regime);
            return true;
         }
         if(bearStack && ind.adxMinusDI > ind.adxPlusDI)
         {
            m_state.regime     = REGIME_STRONG_BEAR_TREND;
            m_state.isTrending = true;
            m_state.label      = RegimeToString(m_state.regime);
            return true;
         }
      }

      if(ind.adxMain >= m_adxWeakThreshold)
      {
         if((bullStack || structure.structureBias > 0) && ind.adxPlusDI >= ind.adxMinusDI)
         {
            m_state.regime     = REGIME_WEAK_BULL_TREND;
            m_state.isTrending = true;
            m_state.label      = RegimeToString(m_state.regime);
            return true;
         }
         if((bearStack || structure.structureBias < 0) && ind.adxMinusDI >= ind.adxPlusDI)
         {
            m_state.regime     = REGIME_WEAK_BEAR_TREND;
            m_state.isTrending = true;
            m_state.label      = RegimeToString(m_state.regime);
            return true;
         }
      }

      // 4. High / Low volatility non-trending
      if(volRatio >= m_volHighRatio)
      {
         m_state.regime     = REGIME_HIGH_VOLATILITY;
         m_state.isVolatile = true;
         m_state.label      = RegimeToString(m_state.regime);
         return true;
      }
      if(volRatio <= m_volLowRatio)
      {
         m_state.regime    = REGIME_LOW_VOLATILITY;
         m_state.isRanging = true;
         m_state.label     = RegimeToString(m_state.regime);
         return true;
      }

      // 5. Consolidation vs Sideways
      if(structure.inConsolidation)
         m_state.regime = REGIME_CONSOLIDATION;
      else
         m_state.regime = REGIME_SIDEWAYS;

      m_state.isRanging = true;
      m_state.label = RegimeToString(m_state.regime);
      return true;
   }

   SRegimeState GetState() const { return m_state; }
};

#endif // __ASEA_MARKET_MARKETREGIME_MQH__
