//+------------------------------------------------------------------+
//|                                           StrategySelection.mqh  |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.0.0 Context & Expectancy Selector      |
//+------------------------------------------------------------------+
#ifndef __ASEA_INTELLIGENCE_STRATEGYSELECTION_MQH__
#define __ASEA_INTELLIGENCE_STRATEGYSELECTION_MQH__

#include "../Core/Types.mqh"
#include "../Strategies/StrategyBase.mqh"

class CStrategySelection
{
private:
   int    m_minSampleSize;
   bool   m_autoSelectBestOnly;
   double m_minProfitFactor;

public:
   CStrategySelection()
   {
      m_minSampleSize = 20;
      m_autoSelectBestOnly = false;
      m_minProfitFactor = 1.05;
   }

   void Configure(const int minSampleSize, const bool autoSelectBestOnly, const double minProfitFactor)
   {
      m_minSampleSize      = MathMax(15, minSampleSize);
      m_autoSelectBestOnly = autoSelectBestOnly;
      m_minProfitFactor    = MathMax(0.8, minProfitFactor);
   }

   double ComputeStrategyUtility(const SStrategyStats &st, const ENUM_MARKET_REGIME regime,
                                 const ENUM_STRATEGY_SUITABILITY suit) const
   {
      if(!st.enabledByInput || suit == SUIT_UNSUITABLE)
         return -1000.0;

      double base = (suit == SUIT_SUITABLE) ? 55.0 : 30.0;

      // Do not penalize or boost aggressively before minimum sample size
      if(st.totalTrades < m_minSampleSize)
         return base + (double)st.totalTrades * 0.1;

      double pfTerm    = MathMin(3.0, st.profitFactor) * 14.0;
      double evTerm    = (st.expectedValue > 0.0) ? 10.0 : -18.0;
      double ddPenalty = (st.maxDrawdownMoney > 0.0 && st.netProfit > 0.0)
                         ? MathMin(15.0, (st.maxDrawdownMoney / st.netProfit) * 5.0)
                         : 0.0;

      int rIdx = (int)regime;
      double regimeAdj = 0.0;
      if(rIdx >= 0 && rIdx <= EA_MAX_REGIMES && st.regimeTrades[rIdx] >= 8)
         regimeAdj = (st.regimeNetProfit[rIdx] > 0.0) ? 8.0 : -12.0;

      double recentPenalty = (st.recentNetProfit < 0.0 && st.recentWinRatePct < 34.0) ? 14.0 : 0.0;

      return base + pfTerm + evTerm + regimeAdj - ddPenalty - recentPenalty;
   }

   // Sets outBestIdx = -1 when market is unfavorable or all suitable strategies show deterioration
   void EvaluateAll(CStrategyBase *&strategies[], const int count, const SRegimeState &regimeState,
                    int &outBestIdx) const
   {
      outBestIdx = -1;
      double bestUtil = -1e9;
      bool marketBlocked = regimeState.isUnstable;

      for(int i = 0; i < count; i++)
      {
         if(strategies[i] == NULL) continue;
         SStrategyStats st = strategies[i].GetStats();
         ENUM_STRATEGY_SUITABILITY suit = marketBlocked ? SUIT_UNSUITABLE : strategies[i].GetRegimeSuitability(regimeState.regime);
         double util = ComputeStrategyUtility(st, regimeState.regime, suit);

         bool detWarn = (st.totalTrades >= m_minSampleSize &&
                         ((st.profitFactor < m_minProfitFactor && st.netProfit < 0.0) ||
                          (st.recentNetProfit < 0.0 && st.recentWinRatePct < 32.0)));

         ENUM_STRATEGY_SUITABILITY reportedSuit = suit;
         if(suit != SUIT_UNSUITABLE && st.totalTrades < m_minSampleSize)
            reportedSuit = (suit == SUIT_SUITABLE) ? SUIT_SUITABLE : SUIT_INSUFFICIENT_DATA;

         bool rec = (!marketBlocked && (suit == SUIT_SUITABLE || suit == SUIT_CONDITIONAL) && !detWarn && st.enabledByInput);
         strategies[i].SetSelectorStatus(reportedSuit, MathMax(0.0, util), rec, detWarn);

         if(st.enabledByInput && !marketBlocked && (suit == SUIT_SUITABLE || suit == SUIT_CONDITIONAL))
         {
            // If sufficient sample exists and strategy is clearly unprofitable, withhold automatic recommendation
            if(st.totalTrades >= m_minSampleSize && st.profitFactor < 0.90 && st.expectedValue < 0.0)
               continue;

            if(util > bestUtil)
            {
               bestUtil = util;
               outBestIdx = i;
            }
         }
      }
   }

   bool IsStrategyPermittedBySelector(const CStrategyBase *strat, const int idx, const int bestIdx,
                                      const SRegimeState &regimeState) const
   {
      if(strat == NULL || !strat.IsEnabled()) return false;
      if(regimeState.isUnstable) return false;
      if(bestIdx < 0 && m_autoSelectBestOnly) return false;

      SStrategyStats st = strat.GetStats();
      if(!m_autoSelectBestOnly)
      {
         // Bench chronically losing strategies once minimum statistical sample confirms deterioration
         if(st.totalTrades >= m_minSampleSize &&
            st.profitFactor < 0.78 &&
            st.expectedValue < 0.0 &&
            st.recentNetProfit < 0.0)
            return false;
         return true;
      }

      if(!st.hasSufficientSample) return strat.IsSuitableForRegime(regimeState.regime);
      return (idx == bestIdx);
   }
};

#endif // __ASEA_INTELLIGENCE_STRATEGYSELECTION_MQH__
