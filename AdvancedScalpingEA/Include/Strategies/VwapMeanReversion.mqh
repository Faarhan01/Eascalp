//+------------------------------------------------------------------+
//|                                            VwapMeanReversion.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.9.0 Strategy 9: VWAP Band Reversion    |
//+------------------------------------------------------------------+
#ifndef __ASEA_STRATEGIES_VWAPMEANREVERSION_MQH__
#define __ASEA_STRATEGIES_VWAPMEANREVERSION_MQH__

#include "StrategyBase.mqh"

class CStrategyVwapMeanReversion : public CStrategyBase
{
private:
   double m_minStretchAtr;

public:
   CStrategyVwapMeanReversion() : CStrategyBase(STRAT_VWAP_REVERSION, "VWAP Reversion")
   {
      m_minStretchAtr = 1.45;
   }

   void Configure(const bool enabled, const double slMult, const double tpMult, const int minSample,
                  const double minStretchAtr = 1.45)
   {
      ConfigureBase(enabled, slMult, tpMult, minSample);
      m_minStretchAtr = MathMax(0.95, MathMin(3.0, minStretchAtr));
   }

   virtual ENUM_STRATEGY_SUITABILITY GetRegimeSuitability(const ENUM_MARKET_REGIME regime) const override
   {
      if(regime == REGIME_SIDEWAYS || regime == REGIME_WIDE_CONSOLIDATION ||
         regime == REGIME_TREND_EXHAUSTION || regime == REGIME_POTENTIAL_REVERSAL)
         return SUIT_SUITABLE;
      if(regime == REGIME_WEAK_BULL_TREND || regime == REGIME_WEAK_BEAR_TREND ||
         regime == REGIME_VOL_CONTRACTION)
         return SUIT_CONDITIONAL;
      return SUIT_UNSUITABLE;
   }

   virtual bool Evaluate(const SAnalysisContext &ctx, STradeSignal &outSignal, string &outRejectReason) override
   {
      outSignal.Reset();
      outRejectReason = "";

      if(!m_enabled) { outRejectReason = "Strategy disabled by input"; return false; }
      if(!IsSuitableForRegime(ctx.regime.regime))
      {
         outRejectReason = "Regime unsuitable for VWAP mean-reversion: " + ctx.regime.label;
         return false;
      }
      if(!ctx.ind.isReady || ctx.ind.atr <= 0.0 || !ctx.ind.vwapAvailable || ctx.ind.vwap <= 0.0 || ctx.symbolProfile.point <= 0.0)
      {
         outRejectReason = "VWAP or indicators unavailable";
         return false;
      }
      if(ctx.ind.adxMain > 27.5 && !ctx.ind.bullDivergence && !ctx.ind.bearDivergence)
      {
         outRejectReason = StringFormat("ADX %.1f too strongly directional for VWAP fade", ctx.ind.adxMain);
         return false;
      }
      if(ctx.market.spreadRatio > 1.75)
      {
         outRejectReason = StringFormat("Spread ratio %.2f too wide for VWAP reversion", ctx.market.spreadRatio);
         return false;
      }

      double vwapDistAtr = (ctx.market.close - ctx.ind.vwap) / ctx.ind.atr;
      double barRange = MathMax(ctx.market.high - ctx.market.low, ctx.symbolProfile.point);
      double body = MathAbs(ctx.market.close - ctx.market.open);
      double effSlMult = GetEffectiveSlMult(ctx, 0.95);
      double effTpMult = GetEffectiveTpMult(ctx, 0.92);

      // Oversold stretch below Session VWAP + lower Bollinger outer envelope
      bool bullStretch = (vwapDistAtr <= -m_minStretchAtr) &&
                         (ctx.market.low <= ctx.ind.bbLower + ctx.ind.atr * 0.15) &&
                         (ctx.ind.rsi <= 39.0 || ctx.ind.cci <= -105.0 || ctx.ind.wpr <= -68.0);
      bool bullReversalBar = (ctx.market.close > ctx.market.open) &&
                             (body >= barRange * 0.22) &&
                             ((ctx.market.close - ctx.market.low) >= barRange * 0.56) &&
                             (ctx.ind.rsi > ctx.ind.prevRsi || ctx.ind.macdHist > ctx.ind.prevMacdHist) &&
                             (ctx.candle.bias != SIGNAL_SELL);
      bool bullHtfAllowed = (ctx.mtf.higherBias != SIGNAL_SELL) || (ctx.ind.bullDivergence || ctx.regime.efficiencyRatio < 0.28);

      if(bullStretch && bullReversalBar && bullHtfAllowed)
      {
         double slDist = ComputeStructuralSLDist(ctx, SIGNAL_BUY, effSlMult, effSlMult * 1.25);
         double vwapRoom = (ctx.ind.vwap - ctx.market.ask) * 0.92;
         if(vwapRoom < slDist * 1.35)
         {
            outRejectReason = "Distance back to Session VWAP insufficient for positive R:R";
            return false;
         }
         double tpDist = MathMax(slDist * 1.45, MathMin(ctx.ind.atr * effTpMult, vwapRoom));
         double rawConf = (MathAbs(vwapDistAtr) >= 1.85) ? 0.83 : 0.77;
         PopulateCommonSignal(outSignal, ctx, SIGNAL_BUY, slDist, tpDist, rawConf,
                              StringFormat("Bullish VWAP reversion stretch (%.2f ATR below VWAP) + outer BB curl", MathAbs(vwapDistAtr)),
                              StringFormat("VWAP_Dist=%.2fATR, RSI=%.1f, CCI=%.0f, ADX=%.1f", vwapDistAtr, ctx.ind.rsi, ctx.ind.cci, ctx.ind.adxMain),
                              ctx.structure.summary, ctx.candle.name,
                              ctx.mtf.higherBias == SIGNAL_SELL ? "Counter-HTF reversion" : "None");
         return true;
      }

      // Overbought stretch above Session VWAP + upper Bollinger outer envelope
      bool bearStretch = (vwapDistAtr >= m_minStretchAtr) &&
                         (ctx.market.high >= ctx.ind.bbUpper - ctx.ind.atr * 0.15) &&
                         (ctx.ind.rsi >= 61.0 || ctx.ind.cci >= 105.0 || ctx.ind.wpr >= -32.0);
      bool bearReversalBar = (ctx.market.close < ctx.market.open) &&
                             (body >= barRange * 0.22) &&
                             ((ctx.market.high - ctx.market.close) >= barRange * 0.56) &&
                             (ctx.ind.rsi < ctx.ind.prevRsi || ctx.ind.macdHist < ctx.ind.prevMacdHist) &&
                             (ctx.candle.bias != SIGNAL_BUY);
      bool bearHtfAllowed = (ctx.mtf.higherBias != SIGNAL_BUY) || (ctx.ind.bearDivergence || ctx.regime.efficiencyRatio < 0.28);

      if(bearStretch && bearReversalBar && bearHtfAllowed)
      {
         double slDist = ComputeStructuralSLDist(ctx, SIGNAL_SELL, effSlMult, effSlMult * 1.25);
         double vwapRoom = (ctx.market.bid - ctx.ind.vwap) * 0.92;
         if(vwapRoom < slDist * 1.35)
         {
            outRejectReason = "Distance back to Session VWAP insufficient for positive R:R";
            return false;
         }
         double tpDist = MathMax(slDist * 1.45, MathMin(ctx.ind.atr * effTpMult, vwapRoom));
         double rawConf = (MathAbs(vwapDistAtr) >= 1.85) ? 0.83 : 0.77;
         PopulateCommonSignal(outSignal, ctx, SIGNAL_SELL, slDist, tpDist, rawConf,
                              StringFormat("Bearish VWAP reversion stretch (+%.2f ATR above VWAP) + outer BB curl", vwapDistAtr),
                              StringFormat("VWAP_Dist=%.2fATR, RSI=%.1f, CCI=%.0f, ADX=%.1f", vwapDistAtr, ctx.ind.rsi, ctx.ind.cci, ctx.ind.adxMain),
                              ctx.structure.summary, ctx.candle.name,
                              ctx.mtf.higherBias == SIGNAL_BUY ? "Counter-HTF reversion" : "None");
         return true;
      }

      outRejectReason = "Price not sufficiently stretched from VWAP with outer BB + reversal inflection";
      return false;
   }

   virtual bool ShouldExitPosition(const SManagedPosition &pos, const SAnalysisContext &ctx, string &outExitReason) const override
   {
      if(pos.holdingSeconds < 120 || !ctx.ind.isReady || !ctx.ind.vwapAvailable || ctx.ind.vwap <= 0.0) return false;
      if(pos.direction == SIGNAL_BUY && pos.floatingPnL > 0.0 && ctx.market.close >= ctx.ind.vwap + ctx.ind.atr * 0.10)
      {
         outExitReason = "VWAPReversion exit: profitable mean reversion completed above VWAP";
         return true;
      }
      if(pos.direction == SIGNAL_SELL && pos.floatingPnL > 0.0 && ctx.market.close <= ctx.ind.vwap - ctx.ind.atr * 0.10)
      {
         outExitReason = "VWAPReversion exit: profitable mean reversion completed below VWAP";
         return true;
      }
      return false;
   }
};

#endif // __ASEA_STRATEGIES_VWAPMEANREVERSION_MQH__
