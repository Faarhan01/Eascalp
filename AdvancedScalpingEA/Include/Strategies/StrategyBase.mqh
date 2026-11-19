//+------------------------------------------------------------------+
//|                                                 StrategyBase.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v3.1.0 Positive-Expectancy Strategy Base|
//+------------------------------------------------------------------+
#ifndef __ASEA_STRATEGIES_STRATEGYBASE_MQH__
#define __ASEA_STRATEGIES_STRATEGYBASE_MQH__

#include "../Core/Types.mqh"

struct SAnalysisContext
{
   SSymbolProfile        symbolProfile;
   SAdaptiveAssetProfile assetProfile;
   SMarketSnapshot       market;
   STickMetrics          ticks;
   SIndicatorValues      ind;
   SStructureState       structure;
   SCandleSignal         candle;
   SChartPatternSignal   chartPattern;
   SRegimeState          regime;
   SMTFAnalysis          mtf;

   void Reset()
   {
      symbolProfile.Reset(); assetProfile.ResetDefaults(); market.Reset(); ticks.Reset(); ind.Reset();
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
   bool             m_autoAdaptBySymbol;
   bool             m_snapTpBeforeWalls;
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

   double NormalizePriceTick(const SSymbolProfile &prof, const double price) const
   {
      if(price <= 0.0) return 0.0;
      double out = price;
      if(prof.tickSize > 0.0)
         out = MathRound(out / prof.tickSize) * prof.tickSize;
      int dg = (prof.digits >= 0) ? prof.digits : 5;
      return NormalizeDouble(out, dg);
   }

   double EnsureMinStop(const SSymbolProfile &prof, const double entry, const double sl, const ENUM_SIGNAL_DIRECTION dir) const
   {
      double minStop = MathMax((double)(MathMax(prof.stopsLevelPoints, prof.freezeLevelPoints) + 4) * prof.point, prof.tickSize * 5.0);
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

   bool HasClearRoomToTarget(const SAnalysisContext &ctx, const ENUM_SIGNAL_DIRECTION dir,
                             const double slDist, const bool allowLocalBreakout = false) const
   {
      if(!ctx.structure.isReady || ctx.ind.atr <= 0.0 || slDist <= 0.0)
         return true;

      double reqRoom = MathMax(ctx.ind.atr * 0.90, slDist * 1.45);
      double refPrice = (dir == SIGNAL_BUY) ? ctx.market.ask : ctx.market.bid;
      if(refPrice <= 0.0)
         refPrice = ctx.market.close;

      if(dir == SIGNAL_BUY)
      {
         if(!allowLocalBreakout && ctx.structure.nearestResistance > refPrice && ctx.structure.resistanceRejectCount >= 2)
         {
            if((ctx.structure.nearestResistance - refPrice) < reqRoom)
               return false;
         }
         if(ctx.structure.prevDayHigh > refPrice && ctx.market.close <= ctx.structure.prevDayHigh + ctx.ind.atr * 0.08)
         {
            if((ctx.structure.prevDayHigh - refPrice) < reqRoom * 0.85)
               return false;
         }
         if(ctx.structure.htfSwingHigh > refPrice && ctx.market.close <= ctx.structure.htfSwingHigh + ctx.ind.atr * 0.12)
         {
            if((ctx.structure.htfSwingHigh - refPrice) < reqRoom * 0.90)
               return false;
         }
      }
      else if(dir == SIGNAL_SELL)
      {
         if(!allowLocalBreakout && ctx.structure.nearestSupport > 0.0 && ctx.structure.nearestSupport < refPrice && ctx.structure.supportRejectCount >= 2)
         {
            if((refPrice - ctx.structure.nearestSupport) < reqRoom)
               return false;
         }
         if(ctx.structure.prevDayLow > 0.0 && ctx.structure.prevDayLow < refPrice && ctx.market.close >= ctx.structure.prevDayLow - ctx.ind.atr * 0.08)
         {
            if((refPrice - ctx.structure.prevDayLow) < reqRoom * 0.85)
               return false;
         }
         if(ctx.structure.htfSwingLow > 0.0 && ctx.structure.htfSwingLow < refPrice && ctx.market.close >= ctx.structure.htfSwingLow - ctx.ind.atr * 0.12)
         {
            if((refPrice - ctx.structure.htfSwingLow) < reqRoom * 0.90)
               return false;
         }
      }
      return true;
   }

   double ApplyStructuralTargetSnap(const SAnalysisContext &ctx, const ENUM_SIGNAL_DIRECTION dir,
                                    const double entryPrice, const double actualSlDist,
                                    const double rawTpDist, const double minStop) const
   {
      if(!m_snapTpBeforeWalls || !ctx.structure.isReady || ctx.ind.atr <= 0.0 || entryPrice <= 0.0)
         return rawTpDist;

      double minRewardFloor = MathMax(minStop, actualSlDist * 1.55);
      if(rawTpDist <= minRewardFloor)
         return rawTpDist;

      double wallPad = MathMax(ctx.ind.atr * 0.15, (ctx.market.spreadPoints + 3.0) * ctx.symbolProfile.point);
      double snappedDist = rawTpDist;

      if(dir == SIGNAL_BUY)
      {
         if(ctx.structure.nearestResistance > entryPrice && ctx.structure.resistanceRejectCount >= 2)
         {
            double cand = (ctx.structure.nearestResistance - wallPad) - entryPrice;
            if(cand >= minRewardFloor && cand < snappedDist)
               snappedDist = cand;
         }
         if(ctx.structure.prevDayHigh > entryPrice)
         {
            double cand = (ctx.structure.prevDayHigh - wallPad) - entryPrice;
            if(cand >= minRewardFloor && cand < snappedDist)
               snappedDist = cand;
         }
         if(ctx.structure.htfSwingHigh > entryPrice)
         {
            double cand = (ctx.structure.htfSwingHigh - wallPad) - entryPrice;
            if(cand >= minRewardFloor && cand < snappedDist)
               snappedDist = cand;
         }
      }
      else if(dir == SIGNAL_SELL)
      {
         if(ctx.structure.nearestSupport > 0.0 && ctx.structure.nearestSupport < entryPrice && ctx.structure.supportRejectCount >= 2)
         {
            double cand = entryPrice - (ctx.structure.nearestSupport + wallPad);
            if(cand >= minRewardFloor && cand < snappedDist)
               snappedDist = cand;
         }
         if(ctx.structure.prevDayLow > 0.0 && ctx.structure.prevDayLow < entryPrice)
         {
            double cand = entryPrice - (ctx.structure.prevDayLow + wallPad);
            if(cand >= minRewardFloor && cand < snappedDist)
               snappedDist = cand;
         }
         if(ctx.structure.htfSwingLow > 0.0 && ctx.structure.htfSwingLow < entryPrice)
         {
            double cand = entryPrice - (ctx.structure.htfSwingLow + wallPad);
            if(cand >= minRewardFloor && cand < snappedDist)
               snappedDist = cand;
         }
      }
      return MathMax(minStop, snappedDist);
   }

   void ComputeOptimalPullbackTrigger(STradeSignal &sig, const SAnalysisContext &ctx,
                                    const double minImproveAtr = 0.20, const double customIdealPrice = 0.0) const
   {
      if(!sig.isValid || ctx.ind.atr <= 0.0 || sig.entryPrice <= 0.0)
         return;

      double atr = ctx.ind.atr;
      double midBar = (ctx.market.high + ctx.market.low) * 0.50;
      double minImprove = atr * MathMax(0.10, minImproveAtr);

      if(sig.direction == SIGNAL_BUY)
      {
         double fallbackCand = MathMin(ctx.ind.emaFast + atr * 0.10, midBar + atr * 0.08);
         double targetCand = (customIdealPrice > 0.0) ? customIdealPrice : fallbackCand;
         double minSafeFloor = sig.stopLoss + atr * 0.40;
         if(targetCand > minSafeFloor && (sig.entryPrice - targetCand) >= minImprove)
         {
            sig.optimalEntryPrice    = NormalizePriceTick(ctx.symbolProfile, targetCand);
            sig.requiresPullbackWait = true;
         }
      }
      else if(sig.direction == SIGNAL_SELL)
      {
         double fallbackCand = MathMax(ctx.ind.emaFast - atr * 0.10, midBar - atr * 0.08);
         double targetCand = (customIdealPrice > 0.0) ? customIdealPrice : fallbackCand;
         double maxSafeCeil = sig.stopLoss - atr * 0.40;
         if(targetCand < maxSafeCeil && (targetCand - sig.entryPrice) >= minImprove)
         {
            sig.optimalEntryPrice    = NormalizePriceTick(ctx.symbolProfile, targetCand);
            sig.requiresPullbackWait = true;
         }
      }
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
      sig.entryPrice   = NormalizePriceTick(ctx.symbolProfile, (dir == SIGNAL_BUY) ? ctx.market.ask : ctx.market.bid);

      double sl = (dir == SIGNAL_BUY) ? (sig.entryPrice - slDist) : (sig.entryPrice + slDist);
      sl = EnsureMinStop(ctx.symbolProfile, sig.entryPrice, sl, dir);
      sl = NormalizePriceTick(ctx.symbolProfile, sl);

      double actualSlDist = MathAbs(sig.entryPrice - sl);
      double targetRR     = (slDist > 0.0 && tpDist > 0.0) ? MathMax(1.55, tpDist / slDist) : 1.75;
      double minStop      = MathMax((double)(MathMax(ctx.symbolProfile.stopsLevelPoints, ctx.symbolProfile.freezeLevelPoints) + 4) * ctx.symbolProfile.point,
                                    ctx.symbolProfile.tickSize * 5.0);
      double effTpDist    = MathMax(MathMax(tpDist, minStop), actualSlDist * targetRR);
      effTpDist           = ApplyStructuralTargetSnap(ctx, dir, sig.entryPrice, actualSlDist, effTpDist, minStop);
      double tp           = NormalizePriceTick(ctx.symbolProfile, (dir == SIGNAL_BUY) ? (sig.entryPrice + effTpDist) : (sig.entryPrice - effTpDist));

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
      m_autoAdaptBySymbol = true;
      m_snapTpBeforeWalls = true;
      m_slAtrMult = 1.65;
      m_tpAtrMult = 3.20;
      m_minSampleSize = 15;
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

   void SetAutoAdaptBySymbol(const bool autoAdapt) { m_autoAdaptBySymbol = autoAdapt; }
   void SetSnapTpBeforeWalls(const bool snapTp)    { m_snapTpBeforeWalls = snapTp; }

   double GetEffectiveSlMult(const SAnalysisContext &ctx, const double stratScale = 1.0) const
   {
      double base = m_autoAdaptBySymbol ? MathMax(m_slAtrMult, ctx.assetProfile.slAtrMult * stratScale) : m_slAtrMult;
      return MathMax(0.6, MathMin(6.0, base));
   }

   double GetEffectiveTpMult(const SAnalysisContext &ctx, const double stratScale = 1.0) const
   {
      double base = m_autoAdaptBySymbol ? MathMax(m_tpAtrMult, ctx.assetProfile.tpAtrMult * stratScale) : m_tpAtrMult;
      return MathMax(0.8, MathMin(10.0, base));
   }

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
