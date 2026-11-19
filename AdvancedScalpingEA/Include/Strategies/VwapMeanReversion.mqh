//+------------------------------------------------------------------+
//|                                            VwapMeanReversion.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v3.1.0 Strategy 9: VWAP Band Reversion    |
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
      m_minStretchAtr = 1.60;
   }

   void Configure(const bool enabled, const double slMult, const double tpMult, const int minSample,
                  const double minStretchAtr = 1.60)
   {
      ConfigureBase(enabled, slMult, tpMult, minSample);
      m_minStretchAtr = MathMax(1.10, MathMin(3.5, minStretchAtr));
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
      if(ctx.ind.adxMain > 22.0 && !ctx.ind.bullDivergence && !ctx.ind.bearDivergence)
      {
         outRejectReason = StringFormat("ADX %.1f too strongly directional for VWAP fade", ctx.ind.adxMain);
         return false;
      }
      if(ctx.market.spreadRatio > 1.70)
      {
         outRejectReason = StringFormat("Spread ratio %.2f too wide for VWAP reversion", ctx.market.spreadRatio);
         return false;
      }

      double vwapDistAtr = (ctx.market.close - ctx.ind.vwap) / ctx.ind.atr;
      double barRange = MathMax(ctx.market.high - ctx.market.low, ctx.symbolProfile.point);
      double body = MathAbs(ctx.market.close - ctx.market.open);
      double effSlMult = GetEffectiveSlMult(ctx, 0.95);
      double effTpMult = GetEffectiveTpMult(ctx, 0.95);

      // Oversold stretch below Session VWAP + lower Bollinger outer envelope + sigma & discount check
      bool bullZOk = (ctx.ind.vwapStdDev <= 0.0 || ctx.ind.vwapZScore <= -1.25);
      bool bearZOk = (ctx.ind.vwapStdDev <= 0.0 || ctx.ind.vwapZScore >= 1.25);
      bool bullLocOk = (!ctx.structure.isReady || ctx.structure.isDiscountZone || ctx.ind.donchianPos01 <= 0.25);
      bool bearLocOk = (!ctx.structure.isReady || ctx.structure.isPremiumZone || ctx.ind.donchianPos01 >= 0.75);

      bool bullStretch = (vwapDistAtr <= -m_minStretchAtr) && bullZOk && bullLocOk &&
                         (ctx.market.low <= ctx.ind.bbLower + ctx.ind.atr * 0.10) &&
                         (ctx.ind.rsi <= 35.0 || ctx.ind.cci <= -120.0 || ctx.ind.bullDivergence);
      bool bullReversalBar = (ctx.market.close > ctx.market.open) &&
                             (body >= barRange * 0.25) &&
                             ((ctx.market.close - ctx.market.low) >= barRange * 0.58) &&
                             (ctx.ind.rsi > ctx.ind.prevRsi || ctx.ind.macdHist > ctx.ind.prevMacdHist) &&
                             (ctx.candle.bias != SIGNAL_SELL);
      bool bullHtfAllowed = (ctx.mtf.higherBias != SIGNAL_SELL) || (ctx.ind.bullDivergence && vwapDistAtr <= -1.95);

      if(bullStretch && bullReversalBar && bullHtfAllowed)
      {
         double slDist = ComputeStructuralSLDist(ctx, SIGNAL_BUY, effSlMult, effSlMult * 1.25);
         if(!HasClearRoomToTarget(ctx, SIGNAL_BUY, slDist, false))
         {
            outRejectReason = "VWAP reversion BUY blocked near active overhead resistance";
            return false;
         }
         double vwapRoom = (ctx.ind.vwap - ctx.market.ask) * 0.95;
         if(vwapRoom < slDist * 1.55)
         {
            outRejectReason = "Distance back to Session VWAP insufficient for >=1.55 R:R";
            return false;
         }
         double tpDist = MathMax(slDist * 1.55, MathMin(ctx.ind.atr * effTpMult, vwapRoom));
         double rawConf = (MathAbs(vwapDistAtr) >= 1.95 || ctx.ind.vwapZScore <= -1.8) ? 0.86 : 0.80;
         PopulateCommonSignal(outSignal, ctx, SIGNAL_BUY, slDist, tpDist, rawConf,
                              StringFormat("Bullish VWAP reversion stretch (%.2f ATR, Z=%.1f) + discount BB curl", MathAbs(vwapDistAtr), ctx.ind.vwapZScore),
                              StringFormat("VWAP_Dist=%.2fATR, Z=%.2f, RSI=%.1f, CCI=%.0f, ADX=%.1f", vwapDistAtr, ctx.ind.vwapZScore, ctx.ind.rsi, ctx.ind.cci, ctx.ind.adxMain),
                              ctx.structure.summary, ctx.candle.name,
                              ctx.mtf.higherBias == SIGNAL_SELL ? "Counter-HTF reversion" : "None");
         return true;
      }

      // Overbought stretch above Session VWAP + upper Bollinger outer envelope + sigma & premium check
      bool bearStretch = (vwapDistAtr >= m_minStretchAtr) && bearZOk && bearLocOk &&
                         (ctx.market.high >= ctx.ind.bbUpper - ctx.ind.atr * 0.10) &&
                         (ctx.ind.rsi >= 65.0 || ctx.ind.cci >= 120.0 || ctx.ind.bearDivergence);
      bool bearReversalBar = (ctx.market.close < ctx.market.open) &&
                             (body >= barRange * 0.25) &&
                             ((ctx.market.high - ctx.market.close) >= barRange * 0.58) &&
                             (ctx.ind.rsi < ctx.ind.prevRsi || ctx.ind.macdHist < ctx.ind.prevMacdHist) &&
                             (ctx.candle.bias != SIGNAL_BUY);
      bool bearHtfAllowed = (ctx.mtf.higherBias != SIGNAL_BUY) || (ctx.ind.bearDivergence && vwapDistAtr >= 1.95);

      if(bearStretch && bearReversalBar && bearHtfAllowed)
      {
         double slDist = ComputeStructuralSLDist(ctx, SIGNAL_SELL, effSlMult, effSlMult * 1.25);
         if(!HasClearRoomToTarget(ctx, SIGNAL_SELL, slDist, false))
         {
            outRejectReason = "VWAP reversion SELL blocked near active floor support";
            return false;
         }
         double vwapRoom = (ctx.market.bid - ctx.ind.vwap) * 0.95;
         if(vwapRoom < slDist * 1.55)
         {
            outRejectReason = "Distance back to Session VWAP insufficient for >=1.55 R:R";
            return false;
         }
         double tpDist = MathMax(slDist * 1.55, MathMin(ctx.ind.atr * effTpMult, vwapRoom));
         double rawConf = (MathAbs(vwapDistAtr) >= 1.95 || ctx.ind.vwapZScore >= 1.8) ? 0.86 : 0.80;
         PopulateCommonSignal(outSignal, ctx, SIGNAL_SELL, slDist, tpDist, rawConf,
                              StringFormat("Bearish VWAP reversion stretch (+%.2f ATR, Z=%.1f) + premium BB curl", vwapDistAtr, ctx.ind.vwapZScore),
                              StringFormat("VWAP_Dist=%.2fATR, Z=%.2f, RSI=%.1f, CCI=%.0f, ADX=%.1f", vwapDistAtr, ctx.ind.vwapZScore, ctx.ind.rsi, ctx.ind.cci, ctx.ind.adxMain),
                              ctx.structure.summary, ctx.candle.name,
                              ctx.mtf.higherBias == SIGNAL_BUY ? "Counter-HTF reversion" : "None");
         return true;
      }

      outRejectReason = "Price not sufficiently stretched from VWAP with outer BB + reversal inflection";
      return false;
   }

   virtual bool ShouldExitPosition(const SManagedPosition &pos, const SAnalysisContext &ctx, string &outExitReason) const override
   {
      if(pos.holdingSeconds < 300 || !ctx.ind.isReady || !ctx.ind.vwapAvailable || ctx.ind.vwap <= 0.0 || pos.floatingPnL <= 0.0) return false;
      double initSlDist = (pos.initialSL > 0.0) ? MathAbs(pos.openPrice - pos.initialSL) : ctx.ind.atr * 1.65;
      double profitDist = (pos.direction == SIGNAL_BUY) ? (pos.currentPrice - pos.openPrice) : (pos.openPrice - pos.currentPrice);
      if(profitDist < initSlDist * 1.40) return false;

      if(pos.direction == SIGNAL_BUY && (ctx.market.close >= ctx.ind.bbUpper || ctx.ind.rsi >= 72.0))
      {
         outExitReason = "VWAPReversion exit: >=1.4R reversion reached opposing OB/BB extreme";
         return true;
      }
      if(pos.direction == SIGNAL_SELL && (ctx.market.close <= ctx.ind.bbLower || ctx.ind.rsi <= 28.0))
      {
         outExitReason = "VWAPReversion exit: >=1.4R reversion reached opposing OS/BB extreme";
         return true;
      }
      return false;
   }
};

#endif // __ASEA_STRATEGIES_VWAPMEANREVERSION_MQH__
