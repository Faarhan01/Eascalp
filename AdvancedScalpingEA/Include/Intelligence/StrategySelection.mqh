//+------------------------------------------------------------------+
//|                                           StrategySelection.mqh  |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        Sample-Gated Strategy Evaluation Engine   |
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
      m_minSampleSize = MathMax(15, minSampleSize);
      m_autoSelectBestOnly = autoSelectBestOnly;
      m_minProfitFactor = MathMax(0.8, minProfitFactor);
   }

   double ComputeStrategyUtility(const SStrategyStats &st, const ENUM_MARKET_REGIME regime, const bool suitableRegime) const
   {
      if(!st.enabledByInput) return -1000.0;
      double base = suitableRegime ? 50.0 : 10.0;

      // Do not rank aggressively before reaching minimum sample size
      if(st.totalTrades < m_minSampleSize)
         return base + (double)st.totalTrades * 0.1;

      double pfTerm = MathMin(3.0, st.profitFactor) * 15.0;
      double evTerm = (st.expectedValue > 0.0) ? 10.0 : -15.0;
      double ddPenalty = (st.maxDrawdownMoney > 0.0 && st.netProfit > 0.0) ? MathMin(15.0, (st.maxDrawdownMoney / st.netProfit) * 5.0) : 0.0;

      // Regime-specific sample check (require >= 8 trades in this regime before adjusting)
      int rIdx = (int)regime;
      double regimeAdj = 0.0;
      if(rIdx >= 0 && rIdx < 12 && st.regimeTrades[rIdx] >= 8)
         regimeAdj = (st.regimeNetProfit[rIdx] > 0.0) ? 8.0 : -10.0;

      // Recent performance deterioration penalty
      double recentPenalty = (st.recentNetProfit < 0.0 && st.recentWinRatePct < 35.0) ? 12.0 : 0.0;

      return base + pfTerm + evTerm + regimeAdj - ddPenalty - recentPenalty;
   }

   void EvaluateAll(CStrategyBase *&strategies[], const int count, const ENUM_MARKET_REGIME currentRegime,
                    int &outBestIdx) const
   {
      outBestIdx = -1;
      double bestUtil = -1e9;

      for(int i = 0; i < count; i++)
      {
         if(strategies[i] == NULL) continue;
         SStrategyStats st = strategies[i].GetStats();
         bool suitable = strategies[i].IsSuitableForRegime(currentRegime);
         double util = ComputeStrategyUtility(st, currentRegime, suitable);

         bool detWarn = (st.totalTrades >= m_minSampleSize &&
                         ((st.profitFactor < m_minProfitFactor && st.netProfit < 0.0) ||
                          (st.recentNetProfit < 0.0 && st.recentWinRatePct < 32.0)));
         bool rec = (suitable && !detWarn && st.enabledByInput);
         strategies[i].SetSelectorRecommendation(rec, detWarn);

         if(st.enabledByInput && suitable && util > bestUtil)
         {
            bestUtil = util;
            outBestIdx = i;
         }
      }
   }

   bool IsStrategyPermittedBySelector(const CStrategyBase *strat, const int idx, const int bestIdx) const
   {
      if(strat == NULL || !strat.IsEnabled()) return false;
      if(!m_autoSelectBestOnly) return true;
      SStrategyStats st = strat.GetStats();
      // Until sufficient sample sizes exist across strategies, allow suitable strategies to gather research data
      if(!st.hasSufficientSample) return true;
      return (idx == bestIdx);
   }
};

#endif // __ASEA_INTELLIGENCE_STRATEGYSELECTION_MQH__
