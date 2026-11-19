//+------------------------------------------------------------------+
//|                                          VolatilityExpansion.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v3.1.0 Strategy 6: Volatility Expansion   |
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
      m_minRvol = 1.15;
   }

   void Configure(const bool enabled, const double slMult, const double tpMult, const int minSample,
                  const double minVolRatio, const double minRvol = 1.15)
   {
      ConfigureBase(enabled, slMult, tpMult, minSample);
      m_minVolRatio = MathMax(1.05, MathMin(2.35, minVolRatio));
      m_minRvol = MathMax(0.50, MathMin(3.0, minRvol));
   }

   virtual ENUM_STRATEGY_SUITABILITY GetRegimeSuitability(const ENUM_MARKET_REGIME regime) const override
   {
      if(regime == REGIME_VOL_EXPANSION || regime == REGIME_EARLY_TREND_BULL || regime == REGIME_EARLY_TREND_BEAR)
         return SUIT_SUITABLE;
      if(regime == REGIME_STRONG_BULL_TREND || regime == REGIME_STRONG_BEAR_TREND ||
         regime == REGIME_WEAK_BULL_TREND || regime == REGIME_WEAK_BEAR_TREND ||
         regime == REGIME_TIGHT_CONSOLIDATION)
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
         outRejectReason = "No clean volatility expansion/squeeze transition regime: " + ctx.regime.label;
         return false;
      }
      if(!ctx.ind.isReady || !ctx.structure.isReady || ctx.ind.atr <= 0.0 || ctx.symbolProfile.point <= 0.0)
      {
         outRejectReason = "Indicators, structure, or ATR unavailable";
         return false;
      }
      double effVol = MathMax(ctx.regime.volatilityRatio, ctx.ind.shortLongVolRatio);
      if(effVol < m_minVolRatio || ctx.regime.volatilityRatio > 2.35)
      {
         outRejectReason = StringFormat("Volatility ratio %.2f outside expansion corridor [%.2f..2.35]",
                                        ctx.regime.volatilityRatio, m_minVolRatio);
         return false;
      }
      if(ctx.market.spreadRatio > 1.75)
      {
         outRejectReason = StringFormat("Spread ratio %.2f too wide during expansion", ctx.market.spreadRatio);
         return false;
      }
      if(ctx.ind.adxMain < 18.0)
      {
         outRejectReason = StringFormat("ADX %.1f too weak for sustained expansion move", ctx.ind.adxMain);
         return false;
      }
      if(MathAbs(ctx.ind.emaDistanceAtr) > 1.35 || ctx.ind.momentumExhaustion)
      {
         outRejectReason = StringFormat("Volatility expansion overextended (%.2f ATR > 1.35 from EMA21)", ctx.ind.emaDistanceAtr);
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

      // Require expanding BB width out of squeeze/inside compression + non-exhausted structural break
      bool bbExpanding = (ctx.ind.bbWidthPct > ctx.ind.prevBbWidthPct * 1.02) ||
                         (ctx.structure.tightConsolidation || ctx.candle.insideBarCount >= 1);
      bool impulseBar = (ctx.candle.bodyRatio >= 0.48) && (ctx.candle.relSizeAtr >= 0.85);
      double barRange = MathMax(ctx.market.high - ctx.market.low, ctx.symbolProfile.point);
      bool bullCloseConv = ((ctx.market.close - ctx.market.low) >= barRange * 0.62);
      bool bearCloseConv = ((ctx.market.high - ctx.market.close) >= barRange * 0.62);
      bool bullMtfTailwind = (ctx.mtf.higherBias == SIGNAL_BUY && ctx.mtf.intermediateBias != SIGNAL_SELL);
      bool bearMtfTailwind = (ctx.mtf.higherBias == SIGNAL_SELL && ctx.mtf.intermediateBias != SIGNAL_BUY);
      double effSlMult = GetEffectiveSlMult(ctx, 1.08);
      double effTpMult = GetEffectiveTpMult(ctx, 1.15);

      bool bullBreakRoom = (ctx.market.close > ctx.ind.bbMiddle) &&
                           (ctx.structure.swingRangePos01 <= 0.80 || ctx.structure.lastEvent == STRUCT_BOS_BULL || ctx.structure.lastEvent == STRUCT_BREAKOUT_UP) &&
                           (ctx.market.close > ctx.structure.lastSwingHigh || ctx.market.close > ctx.structure.rangeHigh || ctx.structure.lastEvent == STRUCT_BOS_BULL || ctx.structure.lastEvent == STRUCT_BREAKOUT_UP);
      bool bearBreakRoom = (ctx.market.close < ctx.ind.bbMiddle) &&
                           (ctx.structure.swingRangePos01 >= 0.20 || ctx.structure.lastEvent == STRUCT_BOS_BEAR || ctx.structure.lastEvent == STRUCT_BREAKOUT_DOWN) &&
                           (ctx.market.close < ctx.structure.lastSwingLow || (ctx.structure.rangeLow > 0.0 && ctx.market.close < ctx.structure.rangeLow) || ctx.structure.lastEvent == STRUCT_BOS_BEAR || ctx.structure.lastEvent == STRUCT_BREAKOUT_DOWN);

      if(bbExpanding && impulseBar && bullCloseConv && ctx.market.close > ctx.market.open &&
         bullBreakRoom && ctx.ind.rsi >= 50.0 && ctx.ind.rsi < 68.0 &&
         ctx.ind.macdHist > 0.0 && ctx.ind.emaFast > ctx.ind.emaMedium &&
         bullMtfTailwind)
      {
         double slDist = ComputeStructuralSLDist(ctx, SIGNAL_BUY, effSlMult, effSlMult * 1.25);
         if(!HasClearRoomToTarget(ctx, SIGNAL_BUY, slDist, true))
         {
            outRejectReason = "Volatility expansion blocked directly below PDH / HTF ceiling";
            return false;
         }
         double tpMultEff = ctx.mtf.alignedBullish ? (effTpMult * 1.15) : effTpMult;
         double tpDist = MathMax(slDist * 1.65, ctx.ind.atr * tpMultEff);
         PopulateCommonSignal(outSignal, ctx, SIGNAL_BUY, slDist, tpDist, 0.83,
                              "Bullish volatility expansion out of compression aligned with HTF",
                              StringFormat("VolRatio=%.2f, ADX=%.1f, BB_W=%.2f%%, RVOL=%.2f, Ext=%.2fATR",
                                           ctx.regime.volatilityRatio, ctx.ind.adxMain, ctx.ind.bbWidthPct, ctx.ind.relativeVolume, ctx.ind.emaDistanceAtr),
                              ctx.structure.summary, ctx.candle.name,
                              ctx.mtf.hasStrongConflict ? ctx.mtf.conflictReason : "None");
         ComputeOptimalPullbackTrigger(outSignal, ctx, 0.22);
         return true;
      }

      if(bbExpanding && impulseBar && bearCloseConv && ctx.market.close < ctx.market.open &&
         bearBreakRoom && ctx.ind.rsi <= 50.0 && ctx.ind.rsi > 32.0 &&
         ctx.ind.macdHist < 0.0 && ctx.ind.emaFast < ctx.ind.emaMedium &&
         bearMtfTailwind)
      {
         double slDist = ComputeStructuralSLDist(ctx, SIGNAL_SELL, effSlMult, effSlMult * 1.25);
         if(!HasClearRoomToTarget(ctx, SIGNAL_SELL, slDist, true))
         {
            outRejectReason = "Volatility expansion blocked directly above PDL / HTF floor";
            return false;
         }
         double tpMultEff = ctx.mtf.alignedBearish ? (effTpMult * 1.15) : effTpMult;
         double tpDist = MathMax(slDist * 1.65, ctx.ind.atr * tpMultEff);
         PopulateCommonSignal(outSignal, ctx, SIGNAL_SELL, slDist, tpDist, 0.83,
                              "Bearish volatility expansion out of compression aligned with HTF",
                              StringFormat("VolRatio=%.2f, ADX=%.1f, BB_W=%.2f%%, RVOL=%.2f, Ext=%.2fATR",
                                           ctx.regime.volatilityRatio, ctx.ind.adxMain, ctx.ind.bbWidthPct, ctx.ind.relativeVolume, ctx.ind.emaDistanceAtr),
                              ctx.structure.summary, ctx.candle.name,
                              ctx.mtf.hasStrongConflict ? ctx.mtf.conflictReason : "None");
         ComputeOptimalPullbackTrigger(outSignal, ctx, 0.22);
         return true;
      }

      outRejectReason = "Volatility expansion lacking compression breakout + HTF alignment";
      return false;
   }

   virtual bool ShouldExitPosition(const SManagedPosition &pos, const SAnalysisContext &ctx, string &outExitReason) const override
   {
      if(pos.holdingSeconds < 600 || !ctx.ind.isReady) return false;
      if(pos.direction == SIGNAL_BUY && ctx.market.close < ctx.ind.emaSlow && ctx.ind.macdHist < 0.0 && ctx.mtf.higherBias == SIGNAL_SELL)
      {
         outExitReason = "VolExpansion exit: close below EMA55 + HTF & MACD bearish flip";
         return true;
      }
      if(pos.direction == SIGNAL_SELL && ctx.market.close > ctx.ind.emaSlow && ctx.ind.macdHist > 0.0 && ctx.mtf.higherBias == SIGNAL_BUY)
      {
         outExitReason = "VolExpansion exit: close above EMA55 + HTF & MACD bullish flip";
         return true;
      }
      return false;
   }
};

#endif // __ASEA_STRATEGIES_VOLATILITYEXPANSION_MQH__
