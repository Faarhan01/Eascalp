//+------------------------------------------------------------------+
//|                                          VolatilityExpansion.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.9.0 Strategy 6: Volatility Expansion   |
//+------------------------------------------------------------------+
#ifndef __ASEA_STRATEGIES_VOLATILITYEXPANSION_MQH__
#define __ASEA_STRATEGIES_VOLATILITYEXPANSION_MQH__

#include "StrategyBase.mqh"

class CStrategyVolatilityExpansion : public CStrategyBase
{
private:
   double m_minVolRatio;
   double m_minRvol;

public:
   CStrategyVolatilityExpansion() : CStrategyBase(STRAT_VOLATILITY_EXPANSION, "Volatility Expansion")
   {
      m_minVolRatio = 1.15;
      m_minRvol = 0.80;
   }

   void Configure(const bool enabled, const double slMult, const double tpMult, const int minSample,
                  const double minVolRatio, const double minRvol = 0.80)
   {
      ConfigureBase(enabled, slMult, tpMult, minSample);
      m_minVolRatio = MathMax(1.05, MathMin(3.0, minVolRatio));
      m_minRvol = MathMax(0.40, MathMin(3.0, minRvol));
   }

   virtual ENUM_STRATEGY_SUITABILITY GetRegimeSuitability(const ENUM_MARKET_REGIME regime) const override
   {
      if(regime == REGIME_VOL_EXPANSION || regime == REGIME_EARLY_TREND_BULL || regime == REGIME_EARLY_TREND_BEAR)
         return SUIT_SUITABLE;
      if(regime == REGIME_STRONG_BULL_TREND || regime == REGIME_STRONG_BEAR_TREND ||
         regime == REGIME_WEAK_BULL_TREND || regime == REGIME_WEAK_BEAR_TREND ||
         regime == REGIME_ABNORMAL_VOLATILITY || regime == REGIME_TIGHT_CONSOLIDATION)
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
         outRejectReason = "No volatility expansion/squeeze transition regime: " + ctx.regime.label;
         return false;
      }
      if(!ctx.ind.isReady || ctx.ind.atr <= 0.0 || ctx.symbolProfile.point <= 0.0)
      {
         outRejectReason = "Indicators or ATR unavailable";
         return false;
      }
      if(ctx.regime.volatilityRatio < m_minVolRatio && ctx.ind.shortLongVolRatio < m_minVolRatio)
      {
         outRejectReason = StringFormat("ATR ratio %.2f / short-long %.2f below expansion threshold %.2f",
                                        ctx.regime.volatilityRatio, ctx.ind.shortLongVolRatio, m_minVolRatio);
         return false;
      }
      if(ctx.market.spreadRatio > 1.85)
      {
         outRejectReason = StringFormat("Spread ratio %.2f too wide during expansion", ctx.market.spreadRatio);
         return false;
      }

      // Prevent chasing already-exhausted blow-off spikes or dead low-ADX chop
      if(ctx.ind.adxMain < 16.0)
      {
         outRejectReason = StringFormat("ADX %.1f too weak for sustained expansion move", ctx.ind.adxMain);
         return false;
      }
      if(MathAbs(ctx.ind.emaDistanceAtr) > 1.90 || ctx.ind.momentumExhaustion)
      {
         outRejectReason = StringFormat("Volatility spike overextended (%.2f ATR from EMA21)", ctx.ind.emaDistanceAtr);
         return false;
      }
      if(ctx.ticks.isReady && ctx.ticks.momentumDeteriorating)
      {
         outRejectReason = "Tick velocity decelerating on expansion bar";
         return false;
      }
      if(ctx.ind.relativeVolume < m_minRvol)
      {
         outRejectReason = StringFormat("Relative volume %.2f below %.2f for expansion entry", ctx.ind.relativeVolume, m_minRvol);
         return false;
      }

      // Require expanding BB width from prior compression or strong ATR expansion candle
      bool bbExpanding = (ctx.ind.bbWidthPct > ctx.ind.prevBbWidthPct * 1.01) ||
                         (ctx.structure.tightConsolidation || ctx.candle.insideBarCount >= 1);
      bool impulseBar = (ctx.candle.bodyRatio >= 0.46) && (ctx.candle.relSizeAtr >= 0.85);
      double barRange = MathMax(ctx.market.high - ctx.market.low, MathMax(ctx.symbolProfile.point, 0.0000001));
      bool bullCloseConv = ((ctx.market.close - ctx.market.low) >= barRange * 0.60);
      bool bearCloseConv = ((ctx.market.high - ctx.market.close) >= barRange * 0.60);
      bool bullMtfTailwind = (ctx.mtf.higherBias == SIGNAL_BUY) || (ctx.mtf.higherBias == SIGNAL_NONE && ctx.mtf.intermediateBias == SIGNAL_BUY);
      bool bearMtfTailwind = (ctx.mtf.higherBias == SIGNAL_SELL) || (ctx.mtf.higherBias == SIGNAL_NONE && ctx.mtf.intermediateBias == SIGNAL_SELL);
      double effSlMult = GetEffectiveSlMult(ctx, 1.08);
      double effTpMult = GetEffectiveTpMult(ctx, 1.15);

      if(bbExpanding && impulseBar && bullCloseConv && ctx.market.close > ctx.market.open &&
         ctx.market.close > ctx.ind.bbUpper && ctx.ind.rsi < 71.0 &&
         ctx.ind.macdHist > 0.0 && ctx.ind.emaFast > ctx.ind.emaMedium &&
         bullMtfTailwind)
      {
         double slDist = ComputeStructuralSLDist(ctx, SIGNAL_BUY, effSlMult, effSlMult * 1.35);
         double tpMultEff = ctx.mtf.alignedBullish ? (effTpMult * 1.15) : effTpMult;
         double tpDist = MathMax(slDist * 1.55, ctx.ind.atr * tpMultEff);
         PopulateCommonSignal(outSignal, ctx, SIGNAL_BUY, slDist, tpDist, 0.80,
                              "Bullish volatility expansion out of compression aligned with HTF",
                              StringFormat("VolRatio=%.2f, ADX=%.1f, BB_W=%.2f%%, RVOL=%.2f, TickAct=%.2f",
                                           ctx.regime.volatilityRatio, ctx.ind.adxMain, ctx.ind.bbWidthPct, ctx.ind.relativeVolume, ctx.ticks.activityRatio),
                              ctx.structure.summary, ctx.candle.name,
                              ctx.mtf.hasStrongConflict ? ctx.mtf.conflictReason : "None");
         return true;
      }

      if(bbExpanding && impulseBar && bearCloseConv && ctx.market.close < ctx.market.open &&
         ctx.market.close < ctx.ind.bbLower && ctx.ind.rsi > 29.0 &&
         ctx.ind.macdHist < 0.0 && ctx.ind.emaFast < ctx.ind.emaMedium &&
         bearMtfTailwind)
      {
         double slDist = ComputeStructuralSLDist(ctx, SIGNAL_SELL, effSlMult, effSlMult * 1.35);
         double tpMultEff = ctx.mtf.alignedBearish ? (effTpMult * 1.15) : effTpMult;
         double tpDist = MathMax(slDist * 1.55, ctx.ind.atr * tpMultEff);
         PopulateCommonSignal(outSignal, ctx, SIGNAL_SELL, slDist, tpDist, 0.80,
                              "Bearish volatility expansion out of compression aligned with HTF",
                              StringFormat("VolRatio=%.2f, ADX=%.1f, BB_W=%.2f%%, RVOL=%.2f, TickAct=%.2f",
                                           ctx.regime.volatilityRatio, ctx.ind.adxMain, ctx.ind.bbWidthPct, ctx.ind.relativeVolume, ctx.ticks.activityRatio),
                              ctx.structure.summary, ctx.candle.name,
                              ctx.mtf.hasStrongConflict ? ctx.mtf.conflictReason : "None");
         return true;
      }

      outRejectReason = "Volatility expansion lacking compression transition + close conviction + MTF tailwind";
      return false;
   }

   virtual bool ShouldExitPosition(const SManagedPosition &pos, const SAnalysisContext &ctx, string &outExitReason) const override
   {
      if(pos.holdingSeconds < 120 || !ctx.ind.isReady) return false;
      if(pos.direction == SIGNAL_BUY && ctx.market.close < ctx.ind.bbMiddle && ctx.ind.macdHist < 0.0)
      {
         outExitReason = "VolExpansion exit: expansion failed back below BB midline";
         return true;
      }
      if(pos.direction == SIGNAL_SELL && ctx.market.close > ctx.ind.bbMiddle && ctx.ind.macdHist > 0.0)
      {
         outExitReason = "VolExpansion exit: expansion failed back above BB midline";
         return true;
      }
      return false;
   }
};

#endif // __ASEA_STRATEGIES_VOLATILITYEXPANSION_MQH__
