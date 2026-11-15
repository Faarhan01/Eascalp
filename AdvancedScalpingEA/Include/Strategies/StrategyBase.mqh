//+------------------------------------------------------------------+
//|                                                 StrategyBase.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        Independent Strategy Interface & Context  |
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
      symbolProfile.Reset();
      market.Reset();
      ticks.Reset();
      ind.Reset();
      structure.Reset();
      candle.Reset();
      chartPattern.Reset();
      regime.Reset();
      mtf.Reset();
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
         double dist = entry - sl;
         if(dist < minStop) return entry - minStop;
      }
      else if(dir == SIGNAL_SELL)
      {
         double dist = sl - entry;
         if(dist < minStop) return entry + minStop;
      }
      return sl;
   }

   void PopulateCommonSignal(STradeSignal &sig, const SAnalysisContext &ctx, const ENUM_SIGNAL_DIRECTION dir,
                             const double slDist, const double tpDist, const double rawConf,
                             const string rationale, const string supInd, const string supStruct,
                             const string patConf, const string conflicts)
   {
      sig.Reset();
      sig.timestamp = ctx.market.tickTime;
      sig.symbol    = ctx.market.symbol;
      sig.timeframe = ctx.market.timeframe;
      sig.strategyId   = m_id;
      sig.strategyName = m_name;
      sig.direction    = dir;
      sig.entryPrice   = (dir == SIGNAL_BUY) ? ctx.market.ask : ctx.market.bid;

      double sl = (dir == SIGNAL_BUY) ? (sig.entryPrice - slDist) : (sig.entryPrice + slDist);
      sl = EnsureMinStop(ctx.symbolProfile, sig.entryPrice, sl, dir);
      double tp = (dir == SIGNAL_BUY) ? (sig.entryPrice + tpDist) : (sig.entryPrice - tpDist);

      sig.stopLoss      = sl;
      sig.takeProfit    = tp;
      sig.confidenceRaw = MathMax(0.0, MathMin(1.0, rawConf));
      sig.regime        = ctx.regime.regime;
      sig.rationale            = rationale;
      sig.supportingIndicators = supInd;
      sig.supportingStructure  = supStruct;
      sig.patternConfirmations = patConf;
      sig.conflictingConditions = conflicts;
      sig.signalId = StringFormat("S%d_%I64d_%d", (int)m_id, (long)sig.timestamp, (int)dir);
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
      m_stats.enabledByInput = enabled;
   }

   virtual bool IsSuitableForRegime(const ENUM_MARKET_REGIME regime) const = 0;
   virtual bool Evaluate(const SAnalysisContext &ctx, STradeSignal &outSignal, string &outRejectReason) = 0;

   void RecordSignalGenerated() { m_stats.signalsGenerated++; }
   void RecordSignalAccepted()  { m_stats.signalsAccepted++; }
   void RecordSignalRejected()  { m_stats.signalsRejected++; }

   void SetSelectorRecommendation(const bool rec, const bool detWarn)
   {
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
      }
      else
      {
         m_stats.losingTrades++;
         m_stats.grossLoss += MathAbs(netProfit);
      }

      m_stats.netProfit += netProfit;
      m_cumProfit += netProfit;
      if(m_cumProfit > m_equityPeak) m_equityPeak = m_cumProfit;
      double dd = m_equityPeak - m_cumProfit;
      if(dd > m_stats.maxDrawdownMoney) m_stats.maxDrawdownMoney = dd;

      m_totalHoldSec += (double)MathMax(0L, holdSeconds);
      m_stats.avgHoldingSeconds = m_totalHoldSec / (double)m_stats.totalTrades;
      m_stats.winRatePct = ((double)m_stats.winningTrades / (double)m_stats.totalTrades) * 100.0;
      m_stats.profitFactor = (m_stats.grossLoss > 0.0) ? (m_stats.grossProfit / m_stats.grossLoss) : ((m_stats.grossProfit > 0.0) ? 9.99 : 0.0);
      m_stats.expectedValue = m_stats.netProfit / (double)m_stats.totalTrades;
      m_stats.hasSufficientSample = (m_stats.totalTrades >= m_minSampleSize);

      // Recent rolling window (up to 20 trades)
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
      if(rIdx >= 0 && rIdx < 12)
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
