//+------------------------------------------------------------------+
//|                                              TradeValidation.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        Pre-Execution Trade Validation Gate       |
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
   bool   enableSessionFilter;
   int    sessionStartHour;
   int    sessionEndHour;
   bool   avoidFridayLateHours;
   int    fridayCutoffHour;

   void ResetDefaults()
   {
      minSignalScore = 62.0;
      maxSpreadPoints = 60.0;
      maxSpreadRatio = 1.85;
      maxSpreadAtrPct = 25.0;
      maxVolatilityRatio = 2.6;
      minVolatilityRatio = 0.45;
      minRequiredBars = 100;
      requireMtfNoStrongConflict = true;
      enableSessionFilter = false;
      sessionStartHour = 7;
      sessionEndHour = 21;
      avoidFridayLateHours = true;
      fridayCutoffHour = 20;
   }
};

class CTradeValidation
{
private:
   SValidationConfig m_cfg;

   bool IsWithinConfiguredHours(const datetime now, const bool is24x7) const
   {
      MqlDateTime dt;
      TimeToStruct(now, dt);

      if(m_cfg.avoidFridayLateHours && !is24x7 && dt.day_of_week == FRIDAY && dt.hour >= m_cfg.fridayCutoffHour)
         return false;

      if(!m_cfg.enableSessionFilter || is24x7)
         return true;

      if(m_cfg.sessionStartHour <= m_cfg.sessionEndHour)
         return (dt.hour >= m_cfg.sessionStartHour && dt.hour < m_cfg.sessionEndHour);

      // Overnight wrap
      return (dt.hour >= m_cfg.sessionStartHour || dt.hour < m_cfg.sessionEndHour);
   }

public:
   CTradeValidation()
   {
      m_cfg.ResetDefaults();
   }

   void Configure(const SValidationConfig &cfg)
   {
      m_cfg = cfg;
   }

   SValidationResult Validate(const STradeSignal &sig, const SSymbolProfile &prof, const SMarketSnapshot &market,
                              const SRegimeState &regime, const SMTFAnalysis &mtf, const SRiskStatus &risk,
                              const CSymbolIntelligence &symIntel, const double proposedLots,
                              const bool allowExecMode) const
   {
      SValidationResult res;
      res.Reset();

      // 1. Signal direction and validity
      if(!sig.isValid || sig.direction == SIGNAL_NONE)
      {
         res.rejectionCode = "INVALID_SIGNAL";
         res.rejectionReason = "Signal direction is NONE or signal struct invalid.";
         return res;
      }

      // 2. Signal quality score threshold
      if(sig.compositeScore < m_cfg.minSignalScore)
      {
         res.rejectionCode = "LOW_SIGNAL_SCORE";
         res.rejectionReason = StringFormat("Composite score %.1f below threshold %.1f.", sig.compositeScore, m_cfg.minSignalScore);
         return res;
      }

      // 3. MTF strong conflict guard
      if(m_cfg.requireMtfNoStrongConflict && mtf.hasStrongConflict)
      {
         res.rejectionCode = "MTF_CONFLICT";
         res.rejectionReason = "Multi-timeframe conflict: " + mtf.conflictReason;
         return res;
      }

      // 4. Historical data & market data readiness
      if(!market.dataReady || prof.availableBarsPrimary < m_cfg.minRequiredBars)
      {
         res.rejectionCode = "DATA_INSUFFICIENT";
         res.rejectionReason = StringFormat("Insufficient historical bars (%d < %d) or market snapshot stale.", prof.availableBarsPrimary, m_cfg.minRequiredBars);
         return res;
      }

      // 5. Spread checks (absolute, relative spike, and spread-to-ATR cost)
      if(market.spreadPoints > m_cfg.maxSpreadPoints)
      {
         res.rejectionCode = "SPREAD_TOO_WIDE";
         res.rejectionReason = StringFormat("Spread %.1f pts exceeds max %.1f pts.", market.spreadPoints, m_cfg.maxSpreadPoints);
         return res;
      }
      if(market.spreadRatio > m_cfg.maxSpreadRatio)
      {
         res.rejectionCode = "SPREAD_SPIKE";
         res.rejectionReason = StringFormat("Spread ratio %.2fx exceeds limit %.2fx.", market.spreadRatio, m_cfg.maxSpreadRatio);
         return res;
      }

      // 6. Volatility bounds & unstable market guard
      if(regime.isUnstable)
      {
         res.rejectionCode = "UNSTABLE_MARKET";
         res.rejectionReason = "Market regime classified as Unstable / Abnormal.";
         return res;
      }
      if(regime.volatilityRatio > m_cfg.maxVolatilityRatio || regime.volatilityRatio < m_cfg.minVolatilityRatio)
      {
         res.rejectionCode = "VOLATILITY_OUT_OF_BOUNDS";
         res.rejectionReason = StringFormat("Volatility ratio %.2f outside [%.2f, %.2f].", regime.volatilityRatio, m_cfg.minVolatilityRatio, m_cfg.maxVolatilityRatio);
         return res;
      }

      // 7. Market session & trading hours
      if(!symIntel.IsTradingPermittedBySymbol())
      {
         res.rejectionCode = "SYMBOL_SESSION_CLOSED";
         res.rejectionReason = "Symbol trade mode disabled or market session closed.";
         return res;
      }
      if(!IsWithinConfiguredHours(market.tickTime, prof.isSynthetic24x7))
      {
         res.rejectionCode = "SESSION_FILTER_BLOCKED";
         res.rejectionReason = "Outside configured active trading hours or Friday cutoff.";
         return res;
      }

      // 8. Risk & exposure permissions
      if(risk.lockoutActive || !risk.tradingAllowed)
      {
         res.rejectionCode = "RISK_LOCKOUT";
         res.rejectionReason = "Risk engine blocked entry: " + risk.lockoutReason;
         return res;
      }

      // 9. Stop-loss validity vs broker minimum stop distance
      double minStopDist = symIntel.GetMinStopDistancePrice();
      double slDist = MathAbs(sig.entryPrice - sig.stopLoss);
      double tpDist = MathAbs(sig.takeProfit - sig.entryPrice);
      if(slDist < minStopDist || tpDist < minStopDist)
      {
         res.rejectionCode = "STOP_DISTANCE_INVALID";
         res.rejectionReason = StringFormat("SL/TP distance below broker minimum stop level (%.5f).", minStopDist);
         return res;
      }

      // 10. Lot size & Margin availability
      if(proposedLots < prof.volumeMin)
      {
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
            res.rejectionCode = "INSUFFICIENT_MARGIN";
            res.rejectionReason = StringFormat("Required margin %.2f exceeds safe free margin allocation (%.2f).", reqMargin, risk.freeMargin);
            return res;
         }
      }

      // 11. Terminal permission check if live/demo order execution is enabled
      if(allowExecMode)
      {
         if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
         {
            res.rejectionCode = "TERMINAL_AUTO_DISABLED";
            res.rejectionReason = "Algo trading is disabled in MT5 terminal or EA properties.";
            return res;
         }
      }

      res.passed = true;
      res.rejectionCode = "PASSED";
      res.rejectionReason = "All validation checks passed.";
      return res;
   }
};

#endif // __ASEA_TRADING_TRADEVALIDATION_MQH__
