//+------------------------------------------------------------------+
//|                                                 StrategyBase.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.0.0 Independent Strategy Interface     |
//+------------------------------------------------------------------+
#ifndef __ASEA_STRATEGIES_STRATEGYBASE_MQH__
#define __ASEA_STRATEGIES_STRATEGYBASE_MQH__

#include "../Core/Types.mqh"

struct SAnalysisContext
{
   SSymbolProfile      symbolProfile;
   SMarketSnapshot     market;
   STickMetrics        ticks;
   SIndicatorValues    ind;
   SStructureState     structure;
   SCandleSignal       candle;
   SChartPatternSignal chartPattern;
   SRegimeState        regime;
   SMTFAnalysis        mtf;

   void Reset()
   {
      symbolProfile.Reset(); market.Reset(); ticks.Reset(); ind.Reset();
      structure.Reset(); candle.Reset(); chartPattern.Reset();
      regime.Reset(); mtf.Reset();
   }
};

class CStrategyBase
{
protected:
   ENUM_STRATEGY_ID m_id;
   string           m_name;
   bool             m_enabled;
   double           m_slAtrMult;
   double           m_tpAtrMult;
   int              m_minSampleSize;
   SStrategyStats   m_stats;

   double           m_recentPnLs[20];
   int              m_recentHead;
   int              m_recentCount;
   double           m_equityPeak;
   double           m_cumProfit;
   double           m_totalHoldSec;

   double EnsureMinStop(const SSymbolProfile &prof, const double entry, const double sl, const ENUM_SIGNAL_DIRECTION dir) const
   {
      double minStop = MathMax((double)(prof.stopsLevelPoints + 4) * prof.point, prof.tickSize * 5.0);
      if(dir == SIGNAL_BUY)
      {
         if((entry - sl) < minStop) return entry - minStop;
      }
      else if(dir == SIGNAL_SELL)
      {
         if((sl - entry) < minStop) return entry + minStop;
      }
      return sl;
   }

   double ComputeStructuralSLDist(const SAnalysisContext &ctx, const ENUM_SIGNAL_DIRECTION dir,
                                  const double baseAtrMult, const double maxAtrMult) const
   {
      double atr = ctx.ind.atr;
      if(atr <= 0.0) return 0.0;

      double baseDist = atr * baseAtrMult;
      double maxDist  = atr * MathMax(baseAtrMult, maxAtrMult);
      double spreadPad = (ctx.symbolProfile.point > 0.0) ? (ctx.market.spreadPoints * ctx.symbolProfile.point * 1.1) : 0.0;
      double structDist = baseDist;

      if(ctx.structure.isReady)
      {
         if(dir == SIGNAL_BUY)
         {
            double anchor = (ctx.structure.nearestSupport > 0.0 && ctx.structure.nearestSupport < ctx.market.ask)
                            ? ctx.structure.nearestSupport
                            : ctx.structure.lastSwingLow;
            if(anchor > 0.0 && anchor < ctx.market.ask)
            {
               double cand = (ctx.market.ask - anchor) + atr * 0.22 + spreadPad;
               if(cand >= baseDist * 0.85 && cand <= maxDist)
                  structDist = MathMax(baseDist, cand);
            }
         }
         else if(dir == SIGNAL_SELL)
         {
            double anchor = (ctx.structure.nearestResistance > 0.0 && ctx.structure.nearestResistance > ctx.market.bid)
                            ? ctx.structure.nearestResistance
                            : ctx.structure.lastSwingHigh;
            if(anchor > 0.0 && anchor > ctx.market.bid)
            {
               double cand = (anchor - ctx.market.bid) + atr * 0.22 + spreadPad;
               if(cand >= baseDist * 0.85 && cand <= maxDist)
                  structDist = MathMax(baseDist, cand);
            }
         }
      }

      double minStop = MathMax((double)(ctx.symbolProfile.stopsLevelPoints + 4) * ctx.symbolProfile.point,
                               ctx.symbolProfile.tickSize * 5.0);
      return MathMax(minStop, MathMin(maxDist, structDist));
   }

   void PopulateCommonSignal(STradeSignal &sig, const SAnalysisContext &ctx, const ENUM_SIGNAL_DIRECTION dir,
                             const double slDist, const double tpDist, const double rawConf,
                             const string rationale, const string supInd, const string supStruct,
                             const string patConf, const string conflicts)
   {
      sig.Reset();
      sig.timestamp    = ctx.market.tickTime;
      sig.symbol       = ctx.market.symbol;
      sig.timeframe    = ctx.market.timeframe;
      sig.strategyId   = m_id;
      sig.strategyName = m_name;
      sig.direction    = dir;
      sig.entryPrice   = (dir == SIGNAL_BUY) ? ctx.market.ask : ctx.market.bid;

      double sl = (dir == SIGNAL_BUY) ? (sig.entryPrice - slDist) : (sig.entryPrice + slDist);
      sl = EnsureMinStop(ctx.symbolProfile, sig.entryPrice, sl, dir);
      double minStop = MathMax((double)(MathMax(ctx.symbolProfile.stopsLevelPoints, ctx.symbolProfile.freezeLevelPoints) + 4) * ctx.symbolProfile.point,
                               ctx.symbolProfile.tickSize * 5.0);
      double effTpDist = MathMax(tpDist, minStop);
      double tp = (dir == SIGNAL_BUY) ? (sig.entryPrice + effTpDist) : (sig.entryPrice - effTpDist);

      sig.stopLoss      = sl;
      sig.takeProfit    = tp;
      sig.confidenceRaw = MathMax(0.0, MathMin(1.0, rawConf));
      sig.regime        = ctx.regime.regime;
      sig.suitability   = GetRegimeSuitability(ctx.regime.regime);
      sig.rationale             = rationale;
      sig.supportingIndicators  = supInd;
      sig.supportingStructure   = supStruct;
      sig.patternConfirmations  = patConf;
      sig.conflictingConditions = conflicts;
      sig.signalId = StringFormat("%s_S%d_%I64d_%d", ctx.market.symbol, (int)m_id, (long)sig.timestamp, (int)dir);
      sig.isValid  = true;
   }

public:
   CStrategyBase(const ENUM_STRATEGY_ID id, const string name)
   {
      m_id = id;
      m_name = name;
      m_enabled = true;
      m_slAtrMult = 1.5;
      m_tpAtrMult = 2.2;
      m_minSampleSize = 20;
      m_recentHead = 0;
      m_recentCount = 0;
      m_equityPeak = 0.0;
      m_cumProfit = 0.0;
      m_totalHoldSec = 0.0;
      ArrayInitialize(m_recentPnLs, 0.0);
      m_stats.Reset();
      m_stats.strategyId = id;
      m_stats.strategyName = name;
   }

   virtual ~CStrategyBase() {}

   virtual void ConfigureBase(const bool enabled, const double slAtrMult, const double tpAtrMult, const int minSampleSize)
   {
      m_enabled       = enabled;
      m_slAtrMult     = MathMax(0.5, MathMin(6.0, slAtrMult));
      m_tpAtrMult     = MathMax(0.5, MathMin(10.0, tpAtrMult));
      m_minSampleSize = MathMax(10, minSampleSize);
      m_stats.enabledByInput  = enabled;
      m_stats.minSampleTarget = m_minSampleSize;
   }

   virtual ENUM_STRATEGY_SUITABILITY GetRegimeSuitability(const ENUM_MARKET_REGIME regime) const = 0;

   virtual bool IsSuitableForRegime(const ENUM_MARKET_REGIME regime) const
   {
      ENUM_STRATEGY_SUITABILITY s = GetRegimeSuitability(regime);
      return (s == SUIT_SUITABLE || s == SUIT_CONDITIONAL);
   }

   virtual bool Evaluate(const SAnalysisContext &ctx, STradeSignal &outSignal, string &outRejectReason) = 0;

   // Independent strategy-specific exit rule hook
   virtual bool ShouldExitPosition(const SManagedPosition &pos, const SAnalysisContext &ctx, string &outExitReason) const
   {
      outExitReason = "";
      return false;
   }

   void RecordSignalGenerated() { m_stats.signalsGenerated++; }
   void RecordSignalAccepted()  { m_stats.signalsAccepted++; }
   void RecordSignalRejected()  { m_stats.signalsRejected++; }

   void SetSelectorStatus(const ENUM_STRATEGY_SUITABILITY suit, const double suitScore, const bool rec, const bool detWarn)
   {
      m_stats.suitability           = suit;
      m_stats.suitabilityScore      = suitScore;
      m_stats.recommendedBySelector = rec;
      m_stats.deteriorationWarning  = detWarn;
   }

   void RecordTradeOutcome(const double netProfit, const long holdSeconds, const ENUM_MARKET_REGIME entryRegime)
   {
      m_stats.totalTrades++;
      if(netProfit >= 0.0)
      {
         m_stats.winningTrades++;
         m_stats.grossProfit += netProfit;
         m_stats.currentConsecutiveLosses = 0;
      }
      else
      {
         m_stats.losingTrades++;
         m_stats.grossLoss += MathAbs(netProfit);
         m_stats.currentConsecutiveLosses++;
         if(m_stats.currentConsecutiveLosses > m_stats.maxConsecutiveLosses)
            m_stats.maxConsecutiveLosses = m_stats.currentConsecutiveLosses;
      }

      m_stats.netProfit += netProfit;
      m_cumProfit += netProfit;
      if(m_cumProfit > m_equityPeak) m_equityPeak = m_cumProfit;
      double dd = m_equityPeak - m_cumProfit;
      if(dd > m_stats.maxDrawdownMoney) m_stats.maxDrawdownMoney = dd;

      m_totalHoldSec += (double)MathMax(0L, holdSeconds);
      m_stats.avgHoldingSeconds   = m_totalHoldSec / (double)m_stats.totalTrades;
      m_stats.avgWin              = (m_stats.winningTrades > 0) ? (m_stats.grossProfit / (double)m_stats.winningTrades) : 0.0;
      m_stats.avgLoss             = (m_stats.losingTrades  > 0) ? (m_stats.grossLoss   / (double)m_stats.losingTrades)  : 0.0;
      m_stats.winRatePct          = ((double)m_stats.winningTrades / (double)m_stats.totalTrades) * 100.0;
      m_stats.profitFactor        = (m_stats.grossLoss > 0.0) ? (m_stats.grossProfit / m_stats.grossLoss) : ((m_stats.grossProfit > 0.0) ? 9.99 : 0.0);
      m_stats.expectedValue       = m_stats.netProfit / (double)m_stats.totalTrades;
      m_stats.hasSufficientSample = (m_stats.totalTrades >= m_minSampleSize);

      m_recentPnLs[m_recentHead] = netProfit;
      m_recentHead = (m_recentHead + 1) % 20;
      if(m_recentCount < 20) m_recentCount++;

      int rWins = 0;
      double rNet = 0.0;
      for(int i = 0; i < m_recentCount; i++)
      {
         rNet += m_recentPnLs[i];
         if(m_recentPnLs[i] >= 0.0) rWins++;
      }
      m_stats.recentNetProfit  = rNet;
      m_stats.recentWinRatePct = (m_recentCount > 0) ? ((double)rWins / (double)m_recentCount) * 100.0 : 0.0;

      int rIdx = (int)entryRegime;
      if(rIdx >= 0 && rIdx <= EA_MAX_REGIMES)
      {
         m_stats.regimeTrades[rIdx]++;
         m_stats.regimeNetProfit[rIdx] += netProfit;
         if(netProfit >= 0.0) m_stats.regimeWins[rIdx]++;
      }
   }

   ENUM_STRATEGY_ID GetId() const   { return m_id; }
   string           GetName() const { return m_name; }
   bool             IsEnabled() const { return m_enabled; }
   SStrategyStats   GetStats() const  { return m_stats; }
};

#endif // __ASEA_STRATEGIES_STRATEGYBASE_MQH__
