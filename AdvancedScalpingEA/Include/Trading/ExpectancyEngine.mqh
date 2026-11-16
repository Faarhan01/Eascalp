//+------------------------------------------------------------------+
//|                                             ExpectancyEngine.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.0.0 Cost-Aware Expectancy Engine       |
//+------------------------------------------------------------------+
#ifndef __ASEA_TRADING_EXPECTANCYENGINE_MQH__
#define __ASEA_TRADING_EXPECTANCYENGINE_MQH__

#include "../Core/Types.mqh"
#include "../Market/SymbolIntelligence.mqh"
#include "../Strategies/StrategyBase.mqh"

struct SExpectancyConfig
{
   double minRewardRiskRatio;
   double minTpToCostRatio;
   double estSlippagePoints;
   int    minSampleForExpectancy;
   bool   requireNonNegativeHistoricalExp;

   void ResetDefaults()
   {
      minRewardRiskRatio = 1.05;
      minTpToCostRatio   = 1.5;
      estSlippagePoints  = 2.0;
      minSampleForExpectancy = 20;
      requireNonNegativeHistoricalExp = true;
   }
};

class CExpectancyEngine
{
private:
   SExpectancyConfig m_cfg;

public:
   CExpectancyEngine()
   {
      m_cfg.ResetDefaults();
   }

   void Configure(const SExpectancyConfig &cfg)
   {
      m_cfg = cfg;
      m_cfg.minRewardRiskRatio     = MathMax(0.8, m_cfg.minRewardRiskRatio);
      m_cfg.minTpToCostRatio       = MathMax(1.1, m_cfg.minTpToCostRatio);
      m_cfg.estSlippagePoints      = MathMax(0.0, m_cfg.estSlippagePoints);
      m_cfg.minSampleForExpectancy = MathMax(10, m_cfg.minSampleForExpectancy);
   }

   SExpectancyEstimate Evaluate(STradeSignal &sig, const SMarketSnapshot &market,
                                const CSymbolIntelligence &symIntel, const SStrategyStats &stratStats,
                                const double proposedLots) const
   {
      SExpectancyEstimate est;
      est.Reset();

      if(!sig.isValid || sig.direction == SIGNAL_NONE || proposedLots <= 0.0)
      {
         est.economicallyViable = false;
         est.summary = "Invalid signal or zero lots";
         sig.expectancy = est;
         return est;
      }

      double slDist = MathAbs(sig.entryPrice - sig.stopLoss);
      double tpDist = MathAbs(sig.takeProfit - sig.entryPrice);
      if(slDist <= 0.0 || tpDist <= 0.0)
      {
         est.economicallyViable = false;
         est.summary = "Zero SL/TP distance";
         sig.expectancy = est;
         return est;
      }

      double effSlip     = symIntel.GetEffectiveSlippagePoints(m_cfg.estSlippagePoints, market.spreadPoints);
      double riskMoney   = symIntel.EstimateRiskMoneyForOrder(sig.direction, proposedLots, sig.entryPrice, sig.stopLoss);
      double rewardMoney = symIntel.EstimateRewardMoneyForOrder(sig.direction, proposedLots, sig.entryPrice, sig.takeProfit);
      double totalCost   = symIntel.EstimateExecutionCostMoney(proposedLots, market.spreadPoints, effSlip);

      est.avgRiskMoney       = riskMoney;
      est.avgRewardMoney     = rewardMoney;
      est.estimatedCostMoney = totalCost;
      est.riskRewardRatio    = (riskMoney > 0.0) ? (rewardMoney / riskMoney) : 0.0;
      est.sampleSize         = stratStats.totalTrades;
      est.hasSufficientSample = (stratStats.totalTrades >= m_cfg.minSampleForExpectancy);

      // Economic cost viability check: expected reward must comfortably exceed round-turn cost
      bool costCleared = (totalCost <= 0.0) || (rewardMoney >= totalCost * m_cfg.minTpToCostRatio);
      bool rrCleared   = (est.riskRewardRatio >= m_cfg.minRewardRiskRatio);

      if(est.hasSufficientSample)
      {
         double winProb  = MathMax(0.0, MathMin(1.0, stratStats.winRatePct / 100.0));
         double lossProb = 1.0 - winProb;
         est.historicalWinRate = stratStats.winRatePct;

         // Historical stats already reflect net realized spread/commission; normalize edge in R-multiples to current riskMoney
         double avgWinR = (stratStats.avgLoss > 0.0 && stratStats.avgWin > 0.0)
                          ? (stratStats.avgWin / stratStats.avgLoss)
                          : est.riskRewardRatio;
         double expR = (winProb * avgWinR) - lossProb;
         est.netExpectancyMoney   = expR * riskMoney;
         est.grossExpectancyMoney = est.netExpectancyMoney + totalCost;

         bool histCleared = (!m_cfg.requireNonNegativeHistoricalExp) || (expR >= -0.05);
         est.economicallyViable = (costCleared && rrCleared && histCleared);
         est.summary = StringFormat("R:R=%.2f | Cost=%.2f | ExpR=%.2f (n=%d)",
                                    est.riskRewardRatio, est.estimatedCostMoney, expR, est.sampleSize);
      }
      else
      {
         // Cold start: estimate break-even win rate needed after costs assuming structural R:R
         double netReward = rewardMoney - totalCost;
         double netRisk   = riskMoney + totalCost;
         double impliedProb = MathMax(0.35, MathMin(0.65, 0.42 + (sig.compositeScore - 50.0) * 0.003));
         est.historicalWinRate = 0.0;
         est.grossExpectancyMoney = (impliedProb * rewardMoney) - ((1.0 - impliedProb) * riskMoney);
         est.netExpectancyMoney   = (impliedProb * netReward) - ((1.0 - impliedProb) * netRisk);
         est.economicallyViable   = (costCleared && rrCleared);
         est.summary = StringFormat("R:R=%.2f | Cost=%.2f | StructuralNet=%.2f (Low sample n=%d)",
                                    est.riskRewardRatio, est.estimatedCostMoney, est.netExpectancyMoney, est.sampleSize);
      }

      sig.expectancy = est;
      return est;
   }
};

#endif // __ASEA_TRADING_EXPECTANCYENGINE_MQH__
