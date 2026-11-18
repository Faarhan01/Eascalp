//+------------------------------------------------------------------+
//|                                              TradeValidation.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.9.0 Pre-Execution Validation & Stats   |
//+------------------------------------------------------------------+
#ifndef __ASEA_TRADING_TRADEVALIDATION_MQH__
#define __ASEA_TRADING_TRADEVALIDATION_MQH__

#include "../Core/Types.mqh"
#include "../Market/SymbolIntelligence.mqh"

struct SValidationConfig
{
   double minSignalScore;
   double maxSpreadPoints;
   double maxSpreadRatio;
   double maxSpreadAtrPct;
   double maxVolatilityRatio;
   double minVolatilityRatio;
   int    minRequiredBars;
   bool   requireMtfNoStrongConflict;
   bool   allowCounterTrendTrades;
   bool   requireVwapConfluence;
   int    minConsensusSignals;
   bool   requireEconomicallyViableExp;
   bool   enableSessionFilter;
   int    sessionStartHour;
   int    sessionEndHour;
   bool   avoidFridayLateHours;
   int    fridayCutoffHour;
   bool   avoidRolloverWindow;
   int    rolloverBlackoutMinutes;

   void ResetDefaults()
   {
      minSignalScore = 60.0;
      maxSpreadPoints = 0.0;
      maxSpreadRatio = 2.50;
      maxSpreadAtrPct = 28.0;
      maxVolatilityRatio = 3.20;
      minVolatilityRatio = 0.30;
      minRequiredBars = 50;
      requireMtfNoStrongConflict = true;
      allowCounterTrendTrades = false;
      requireVwapConfluence = false;
      minConsensusSignals = 1;
      requireEconomicallyViableExp = true;
      enableSessionFilter = false;
      sessionStartHour = 7;
      sessionEndHour = 21;
      avoidFridayLateHours = false;
      fridayCutoffHour = 21;
      avoidRolloverWindow = true;
      rolloverBlackoutMinutes = 20;
   }
};

struct SFilterStats
{
   long totalEvaluated;
   long totalPassed;
   long rejLowScore;
   long rejMtfConflict;
   long rejSpread;
   long rejVolatility;
   long rejSession;
   long rejRisk;
   long rejExpectancy;
   long rejStopsVolumeMargin;
   long rejOther;

   void Reset()
   {
      totalEvaluated = 0; totalPassed = 0;
      rejLowScore = 0; rejMtfConflict = 0; rejSpread = 0;
      rejVolatility = 0; rejSession = 0; rejRisk = 0;
      rejExpectancy = 0; rejStopsVolumeMargin = 0; rejOther = 0;
   }
};

class CTradeValidation
{
private:
   SValidationConfig m_cfg;
   SFilterStats      m_stats;

   bool IsWithinConfiguredHours(const datetime now, const bool is24x7) const
   {
      MqlDateTime dt;
      TimeToStruct(now, dt);

      if(!is24x7 && m_cfg.avoidRolloverWindow && m_cfg.rolloverBlackoutMinutes > 0)
      {
         int minsOfDay = dt.hour * 60 + dt.min;
         int win = MathMin(90, m_cfg.rolloverBlackoutMinutes);
         if(minsOfDay < win || minsOfDay >= (1440 - win))
            return false;
      }

      if(m_cfg.avoidFridayLateHours && !is24x7 && dt.day_of_week == FRIDAY && dt.hour >= m_cfg.fridayCutoffHour)
         return false;

      if(!m_cfg.enableSessionFilter || is24x7)
         return true;

      if(m_cfg.sessionStartHour <= m_cfg.sessionEndHour)
         return (dt.hour >= m_cfg.sessionStartHour && dt.hour < m_cfg.sessionEndHour);

      return (dt.hour >= m_cfg.sessionStartHour || dt.hour < m_cfg.sessionEndHour);
   }

public:
   CTradeValidation()
   {
      m_cfg.ResetDefaults();
      m_stats.Reset();
   }

   void Configure(const SValidationConfig &cfg)
   {
      m_cfg = cfg;
   }

   SFilterStats GetFilterStats() const { return m_stats; }

   SValidationResult Validate(const STradeSignal &sig, const SSymbolProfile &prof, const SMarketSnapshot &market,
                              const SIndicatorValues &ind, const SRegimeState &regime, const SMTFAnalysis &mtf,
                              const SRiskStatus &risk, const CSymbolIntelligence &symIntel,
                              const double proposedLots, const bool allowExecMode,
                              const bool autoAdaptBySymbol = true)
   {
      SValidationResult res;
      res.Reset();
      m_stats.totalEvaluated++;

      SAdaptiveAssetProfile ap = symIntel.GetAdaptiveAssetProfile();
      double effMinScore    = autoAdaptBySymbol ? MathMax(m_cfg.minSignalScore, ap.minSignalScore) : m_cfg.minSignalScore;
      double effMaxSprRatio = autoAdaptBySymbol ? MathMax(m_cfg.maxSpreadRatio, ap.maxSpreadRatio) : m_cfg.maxSpreadRatio;
      double effMaxSprAtr   = autoAdaptBySymbol ? MathMax(m_cfg.maxSpreadAtrPct, ap.maxSpreadAtrPct) : m_cfg.maxSpreadAtrPct;
      double effMaxVolRatio = autoAdaptBySymbol ? MathMax(m_cfg.maxVolatilityRatio, ap.maxVolatilityRatio) : m_cfg.maxVolatilityRatio;
      double effMinVolRatio = autoAdaptBySymbol ? MathMin(m_cfg.minVolatilityRatio, ap.minVolatilityRatio) : m_cfg.minVolatilityRatio;

      // 1. Signal direction and validity
      if(!sig.isValid || sig.direction == SIGNAL_NONE)
      {
         m_stats.rejOther++;
         res.rejectionCode = "INVALID_SIGNAL";
         res.rejectionReason = "Signal direction is NONE or signal struct invalid.";
         return res;
      }

      // 2. Signal quality score threshold
      if(sig.compositeScore < effMinScore)
      {
         m_stats.rejLowScore++;
         res.rejectionCode = "LOW_SIGNAL_SCORE";
         res.rejectionReason = StringFormat("Composite score %.1f below threshold %.1f.", sig.compositeScore, effMinScore);
         return res;
      }

      // 2b. Minimum multi-strategy consensus count
      if(m_cfg.minConsensusSignals > 1 && sig.consensusCount < m_cfg.minConsensusSignals)
      {
         m_stats.rejOther++;
         res.rejectionCode = "INSUFFICIENT_CONSENSUS";
         res.rejectionReason = StringFormat("Strategy consensus %d below required minimum %d.", sig.consensusCount, m_cfg.minConsensusSignals);
         return res;
      }

      // 3. MTF strong conflict guard & Counter-HTF policy
      if(m_cfg.requireMtfNoStrongConflict && mtf.hasStrongConflict)
      {
         m_stats.rejMtfConflict++;
         res.rejectionCode = "MTF_CONFLICT";
         res.rejectionReason = "Multi-timeframe conflict: " + mtf.conflictReason;
         return res;
      }

      bool counterHtf = ((sig.direction == SIGNAL_BUY && mtf.higherBias == SIGNAL_SELL) ||
                         (sig.direction == SIGNAL_SELL && mtf.higherBias == SIGNAL_BUY));
      if(!m_cfg.allowCounterTrendTrades && counterHtf)
      {
         bool isMeanRevOrSweep = (sig.strategyId == STRAT_REVERSAL_SCALPING ||
                                  sig.strategyId == STRAT_RANGE_SCALPING ||
                                  sig.strategyId == STRAT_LIQUIDITY_SWEEP ||
                                  sig.strategyId == STRAT_VWAP_REVERSION);
         if(!isMeanRevOrSweep || sig.compositeScore < (effMinScore + 8.0))
         {
            m_stats.rejMtfConflict++;
            res.rejectionCode = "COUNTER_HTF_BLOCKED";
            res.rejectionReason = "Counter-HTF direction blocked by trend-alignment discipline.";
            return res;
         }
      }

      // 3b. Optional Session VWAP directional confluence for trend/breakout strategies
      if(m_cfg.requireVwapConfluence && ind.vwapAvailable && ind.vwap > 0.0)
      {
         bool isTrendMomentumStrat = (sig.strategyId == STRAT_TREND_PULLBACK ||
                                      sig.strategyId == STRAT_MOMENTUM_SCALPING ||
                                      sig.strategyId == STRAT_BREAKOUT_SCALPING ||
                                      sig.strategyId == STRAT_VOLATILITY_EXPANSION ||
                                      sig.strategyId == STRAT_MICRO_MOMENTUM ||
                                      sig.strategyId == STRAT_EMA_RIBBON);
         if(isTrendMomentumStrat &&
            ((sig.direction == SIGNAL_BUY && market.close < ind.vwap) ||
             (sig.direction == SIGNAL_SELL && market.close > ind.vwap)))
         {
            m_stats.rejOther++;
            res.rejectionCode = "VWAP_ALIGNMENT_REQUIRED";
            res.rejectionReason = "Trend/momentum entry blocked on unfavorable side of Session VWAP.";
            return res;
         }
      }

      // 4. Historical data & market data readiness
      if(!market.dataReady || prof.availableBarsPrimary < m_cfg.minRequiredBars)
      {
         m_stats.rejOther++;
         res.rejectionCode = "DATA_INSUFFICIENT";
         res.rejectionReason = StringFormat("Insufficient historical bars (%d < %d) or market snapshot stale.", prof.availableBarsPrimary, m_cfg.minRequiredBars);
         return res;
      }

      // 5. Spread checks (auto-adaptive or manual point cap, relative spike, and spread-to-ATR cost)
      double spreadCap = (m_cfg.maxSpreadPoints > 0.0) ? m_cfg.maxSpreadPoints
                         : symIntel.GetAutoMaxSpreadPoints(ind.isReady ? ind.atr : 0.0);
      if(spreadCap > 0.0 && market.spreadPoints > spreadCap)
      {
         m_stats.rejSpread++;
         res.rejectionCode = "SPREAD_TOO_WIDE";
         res.rejectionReason = StringFormat("Spread %.1f pts exceeds cap %.1f pts.", market.spreadPoints, spreadCap);
         return res;
      }
      double pipPts = (prof.point > 0.0 && prof.pipSize > 0.0) ? MathMax(1.0, prof.pipSize / prof.point) : 1.0;
      double sprFloorPts = MathMax(3.0, pipPts * 1.2);
      if(market.spreadRatio > effMaxSprRatio && market.spreadPoints > sprFloorPts)
      {
         m_stats.rejSpread++;
         res.rejectionCode = "SPREAD_SPIKE";
         res.rejectionReason = StringFormat("Spread %.1f pts (ratio %.2fx) exceeds limit %.2fx.", market.spreadPoints, market.spreadRatio, effMaxSprRatio);
         return res;
      }
      if(ind.isReady && ind.atr > 0.0 && prof.point > 0.0)
      {
         double spreadAtrPct = ((market.spreadPoints * prof.point) / ind.atr) * 100.0;
         if(spreadAtrPct > effMaxSprAtr)
         {
            m_stats.rejSpread++;
            res.rejectionCode = "SPREAD_TO_ATR_HIGH";
            res.rejectionReason = StringFormat("Spread consumes %.1f%% of ATR (limit %.1f%%).", spreadAtrPct, effMaxSprAtr);
            return res;
         }
      }

      // 6. Volatility bounds & unstable market guard
      if(regime.isUnstable)
      {
         m_stats.rejVolatility++;
         res.rejectionCode = "UNSTABLE_MARKET";
         res.rejectionReason = "Market regime classified as Unstable / Abnormal.";
         return res;
      }
      if(regime.volatilityRatio > effMaxVolRatio || regime.volatilityRatio < effMinVolRatio)
      {
         m_stats.rejVolatility++;
         res.rejectionCode = "VOLATILITY_OUT_OF_BOUNDS";
         res.rejectionReason = StringFormat("Volatility ratio %.2f outside [%.2f, %.2f].", regime.volatilityRatio, effMinVolRatio, effMaxVolRatio);
         return res;
      }

      // 7. Market session & trading hours
      if(!symIntel.IsTradingPermittedBySymbol())
      {
         m_stats.rejSession++;
         res.rejectionCode = "SYMBOL_SESSION_CLOSED";
         res.rejectionReason = "Symbol trade mode disabled or market session closed.";
         return res;
      }
      if(!IsWithinConfiguredHours(market.tickTime, prof.isSynthetic24x7))
      {
         m_stats.rejSession++;
         res.rejectionCode = "SESSION_FILTER_BLOCKED";
         res.rejectionReason = "Outside active trading hours, Friday cutoff, or midnight rollover blackout.";
         return res;
      }

      // 8. Risk & exposure permissions
      if(risk.lockoutActive || !risk.tradingAllowed)
      {
         m_stats.rejRisk++;
         res.rejectionCode = "RISK_LOCKOUT";
         res.rejectionReason = "Risk engine blocked entry: " + risk.lockoutReason;
         return res;
      }

      // 9. Cost-aware Expectancy & R:R viability
      if(m_cfg.requireEconomicallyViableExp && !sig.expectancy.economicallyViable)
      {
         m_stats.rejExpectancy++;
         res.rejectionCode = "EXPECTANCY_UNVIABLE";
         res.rejectionReason = "Expectancy/cost viability failed: " + sig.expectancy.summary;
         return res;
      }

      // 10. Stop-loss validity vs broker minimum stop distance
      double minStopDist = symIntel.GetMinStopDistancePrice();
      double slDist = MathAbs(sig.entryPrice - sig.stopLoss);
      double tpDist = MathAbs(sig.takeProfit - sig.entryPrice);
      if(slDist < minStopDist || tpDist < minStopDist)
      {
         m_stats.rejStopsVolumeMargin++;
         res.rejectionCode = "STOP_DISTANCE_INVALID";
         res.rejectionReason = StringFormat("SL/TP distance below broker minimum stop level (%.5f).", minStopDist);
         return res;
      }

      // 11. Lot size & Margin availability
      if(proposedLots < prof.volumeMin)
      {
         m_stats.rejStopsVolumeMargin++;
         res.rejectionCode = "VOLUME_BELOW_MIN";
         res.rejectionReason = StringFormat("Calculated volume %.4f below broker min %.4f.", proposedLots, prof.volumeMin);
         return res;
      }

      double reqMargin = 0.0;
      ENUM_ORDER_TYPE oType = (sig.direction == SIGNAL_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      if(symIntel.EstimateMargin(oType, proposedLots, sig.entryPrice, reqMargin))
      {
         if(reqMargin > risk.freeMargin * 0.85)
         {
            m_stats.rejStopsVolumeMargin++;
            res.rejectionCode = "INSUFFICIENT_MARGIN";
            res.rejectionReason = StringFormat("Required margin %.2f exceeds safe free margin allocation (%.2f).", reqMargin, risk.freeMargin);
            return res;
         }
      }

      // 12. Terminal permission check if live/demo order execution is enabled
      // Note: TERMINAL_TRADE_ALLOWED reflects the live terminal Algo Trading button and may be false during Strategy Tester runs.
      if(allowExecMode)
      {
         bool isTester = (MQLInfoInteger(MQL_TESTER) != 0);
         if((!isTester && !TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
         {
            m_stats.rejOther++;
            res.rejectionCode = "TERMINAL_AUTO_DISABLED";
            res.rejectionReason = "Algo trading is disabled in MT5 terminal or EA properties.";
            return res;
         }
      }

      m_stats.totalPassed++;
      res.passed = true;
      res.rejectionCode = "PASSED";
      res.rejectionReason = "All validation checks passed.";
      return res;
   }
};

#endif // __ASEA_TRADING_TRADEVALIDATION_MQH__
