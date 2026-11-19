//+------------------------------------------------------------------+
//|                                           StrategySelection.mqh  |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v3.1.0 Context & Expectancy Selector      |
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
      m_minSampleSize = 15;
      m_autoSelectBestOnly = false;
      m_minProfitFactor = 1.05;
   }

   void Configure(const int minSampleSize, const bool autoSelectBestOnly, const double minProfitFactor)
   {
      m_minSampleSize      = MathMax(10, minSampleSize);
      m_autoSelectBestOnly = autoSelectBestOnly;
      m_minProfitFactor    = MathMax(0.85, minProfitFactor);
   }

   double ComputePersonalityFit(const ENUM_STRATEGY_ID id, const ENUM_SYMBOL_PERSONALITY personality) const
   {
      if(personality == PERSONALITY_TRENDING)
      {
         if(id == STRAT_TREND_PULLBACK || id == STRAT_EMA_RIBBON || id == STRAT_MOMENTUM_SCALPING || id == STRAT_VOLATILITY_EXPANSION)
            return 7.0;
         if(id == STRAT_RANGE_SCALPING || id == STRAT_VWAP_REVERSION)
            return -5.0;
      }
      else if(personality == PERSONALITY_MEAN_REVERTING)
      {
         if(id == STRAT_RANGE_SCALPING || id == STRAT_VWAP_REVERSION || id == STRAT_REVERSAL_SCALPING || id == STRAT_LIQUIDITY_SWEEP)
            return 7.5;
         if(id == STRAT_BREAKOUT_SCALPING)
            return -6.0;
      }
      else if(personality == PERSONALITY_BREAKOUT_SWEEP)
      {
         if(id == STRAT_LIQUIDITY_SWEEP || id == STRAT_REVERSAL_SCALPING || id == STRAT_BREAKOUT_SCALPING)
            return 7.0;
         if(id == STRAT_MICRO_MOMENTUM)
            return -4.0;
      }
      return 0.0;
   }

   double ComputeStrategyUtility(const SStrategyStats &st, const ENUM_MARKET_REGIME regime,
                                 const ENUM_STRATEGY_SUITABILITY suit,
                                 const ENUM_SYMBOL_PERSONALITY personality = PERSONALITY_BALANCED) const
   {
      if(!st.enabledByInput || suit == SUIT_UNSUITABLE)
         return -1000.0;

      double base = (suit == SUIT_SUITABLE) ? 55.0 : 30.0;
      double dnaFit = ComputePersonalityFit(st.strategyId, personality);

      // Do not penalize or boost performance stats aggressively before minimum sample size
      if(st.totalTrades < m_minSampleSize)
         return base + dnaFit + (double)st.totalTrades * 0.1;

      double pfTerm    = MathMin(3.0, st.profitFactor) * 14.0;
      double evTerm    = (st.expectedValue > 0.0) ? 10.0 : -20.0;
      double ddPenalty = (st.maxDrawdownMoney > 0.0 && st.netProfit > 0.0)
                         ? MathMin(15.0, (st.maxDrawdownMoney / st.netProfit) * 5.0)
                         : 0.0;

      int rIdx = (int)regime;
      double regimeAdj = 0.0;
      if(rIdx >= 0 && rIdx <= EA_MAX_REGIMES && st.regimeTrades[rIdx] >= 5)
      {
         double regWr = (double)st.regimeWins[rIdx] / (double)st.regimeTrades[rIdx];
         regimeAdj = (st.regimeNetProfit[rIdx] > 0.0 && regWr >= 0.42) ? 10.0 : ((st.regimeNetProfit[rIdx] < 0.0) ? -14.0 : 0.0);
      }

      double recentAdj = 0.0;
      if(st.recentNetProfit < 0.0 && st.recentWinRatePct < 36.0) recentAdj = -16.0;
      else if(st.recentNetProfit > 0.0 && st.recentWinRatePct >= 52.0) recentAdj = 6.0;

      return base + dnaFit * 0.6 + pfTerm + evTerm + regimeAdj + recentAdj - ddPenalty;
   }

   // Sets outBestIdx = -1 when market is unfavorable or all suitable strategies show deterioration
   void EvaluateAll(CStrategyBase *&strategies[], const int count, const SRegimeState &regimeState,
                    int &outBestIdx, const ENUM_SYMBOL_PERSONALITY personality = PERSONALITY_BALANCED) const
   {
      outBestIdx = -1;
      double bestUtil = -1e9;
      bool marketBlocked = regimeState.isUnstable;

      for(int i = 0; i < count; i++)
      {
         if(strategies[i] == NULL) continue;
         SStrategyStats st = strategies[i].GetStats();
         ENUM_STRATEGY_SUITABILITY suit = marketBlocked ? SUIT_UNSUITABLE : strategies[i].GetRegimeSuitability(regimeState.regime);
         double util = ComputeStrategyUtility(st, regimeState.regime, suit, personality);

         bool detWarn = (st.totalTrades >= m_minSampleSize &&
                         ((st.profitFactor < m_minProfitFactor && st.netProfit < 0.0) ||
                          (st.recentNetProfit < 0.0 && st.recentWinRatePct < 34.0)));

         ENUM_STRATEGY_SUITABILITY reportedSuit = suit;
         if(suit != SUIT_UNSUITABLE && st.totalTrades < m_minSampleSize)
            reportedSuit = (suit == SUIT_SUITABLE) ? SUIT_SUITABLE : SUIT_INSUFFICIENT_DATA;

         bool rec = (!marketBlocked && (suit == SUIT_SUITABLE || suit == SUIT_CONDITIONAL) && !detWarn && st.enabledByInput);
         strategies[i].SetSelectorStatus(reportedSuit, MathMax(0.0, util), rec, detWarn);

         if(st.enabledByInput && !marketBlocked && (suit == SUIT_SUITABLE || suit == SUIT_CONDITIONAL))
         {
            // Withhold recommendation from unprofitable strategies once sample is mature
            if(st.totalTrades >= m_minSampleSize && st.profitFactor < 0.95 && st.expectedValue < 0.0)
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
      int rIdx = (int)regimeState.regime;

      if(!m_autoSelectBestOnly)
      {
         // Early safety circuit breaker for severe bleeders (>= 8 trades)
         if(st.totalTrades >= MathMin(8, m_minSampleSize) &&
            st.profitFactor < 0.78 &&
            st.expectedValue < 0.0 &&
            st.recentNetProfit < 0.0)
            return false;

         // Full sample gate: bench any sub-breakeven strategy (PF < 0.95 & negative EV/recent PnL)
         if(st.totalTrades >= m_minSampleSize &&
            st.profitFactor < 0.95 &&
            st.expectedValue < 0.0 &&
            st.recentNetProfit <= 0.0)
            return false;

         // Bench strategies proven unprofitable in this specific market regime (no bestIdx bypass)
         if(rIdx >= 0 && rIdx <= EA_MAX_REGIMES && st.regimeTrades[rIdx] >= 5)
         {
            double regWr = (double)st.regimeWins[rIdx] / (double)st.regimeTrades[rIdx];
            if(st.regimeNetProfit[rIdx] < 0.0 && regWr < 0.36)
               return false;
         }
         return true;
      }

      if(!st.hasSufficientSample) return strat.IsSuitableForRegime(regimeState.regime);
      return (idx == bestIdx);
   }
};

#endif // __ASEA_INTELLIGENCE_STRATEGYSELECTION_MQH__
