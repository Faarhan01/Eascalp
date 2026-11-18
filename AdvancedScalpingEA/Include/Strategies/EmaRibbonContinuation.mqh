//+------------------------------------------------------------------+
//|                                        EmaRibbonContinuation.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.9.0 Strategy 10: Ribbon Trend Thrust   |
//+------------------------------------------------------------------+
#ifndef __ASEA_STRATEGIES_EMARIBBONCONTINUATION_MQH__
#define __ASEA_STRATEGIES_EMARIBBONCONTINUATION_MQH__

#include "StrategyBase.mqh"

class CStrategyEmaRibbonContinuation : public CStrategyBase
{
private:
   double m_minAdx;
   double m_maxAdx;
   double m_minRvol;

public:
   CStrategyEmaRibbonContinuation() : CStrategyBase(STRAT_EMA_RIBBON, "EMA Ribbon Cont.")
   {
      m_minAdx = 20.0;
      m_maxAdx = 46.0;
      m_minRvol = 0.80;
   }

   void Configure(const bool enabled, const double slMult, const double tpMult, const int minSample,
                  const double minAdx = 20.0, const double maxAdx = 46.0, const double minRvol = 0.80)
   {
      ConfigureBase(enabled, slMult, tpMult, minSample);
      m_minAdx = MathMax(14.0, minAdx);
      m_maxAdx = MathMax(m_minAdx + 8.0, maxAdx);
      m_minRvol = MathMax(0.40, MathMin(3.0, minRvol));
   }

   virtual ENUM_STRATEGY_SUITABILITY GetRegimeSuitability(const ENUM_MARKET_REGIME regime) const override
   {
      if(regime == REGIME_STRONG_BULL_TREND || regime == REGIME_STRONG_BEAR_TREND ||
         regime == REGIME_ESTABLISHED_BULL || regime == REGIME_ESTABLISHED_BEAR ||
         regime == REGIME_EARLY_TREND_BULL || regime == REGIME_EARLY_TREND_BEAR)
         return SUIT_SUITABLE;
      if(regime == REGIME_VOL_EXPANSION || regime == REGIME_WEAK_BULL_TREND || regime == REGIME_WEAK_BEAR_TREND)
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
         outRejectReason = "Regime unsuitable for EMA Ribbon Continuation: " + ctx.regime.label;
         return false;
      }
      if(!ctx.ind.isReady || !ctx.structure.isReady || ctx.ind.atr <= 0.0 || ctx.symbolProfile.point <= 0.0)
      {
         outRejectReason = "Indicators or structure not ready";
         return false;
      }
      if(ctx.ind.adxMain < m_minAdx || ctx.ind.adxMain > m_maxAdx)
      {
         outRejectReason = StringFormat("ADX %.1f outside optimal continuation corridor [%.0f..%.0f]", ctx.ind.adxMain, m_minAdx, m_maxAdx);
         return false;
      }
      if(ctx.ind.momentumExhaustion || MathAbs(ctx.ind.emaDistanceAtr) > 1.65)
      {
         outRejectReason = StringFormat("Overextended (%.2f ATR from EMA21) — refusing chase", ctx.ind.emaDistanceAtr);
         return false;
      }
      if(ctx.ind.relativeVolume < m_minRvol)
      {
         outRejectReason = StringFormat("Relative volume %.2f below %.2f for ribbon continuation", ctx.ind.relativeVolume, m_minRvol);
         return false;
      }

      double barRange = MathMax(ctx.market.high - ctx.market.low, ctx.symbolProfile.point);
      double body = MathAbs(ctx.market.close - ctx.market.open);
      double effSlMult = GetEffectiveSlMult(ctx, 1.0);
      double effTpMult = GetEffectiveTpMult(ctx, 1.12);

      // Pause/compression inflection (inside bars, BB compression, or fresh MACD histogram flip/thrust)
      bool pauseRelease = (ctx.candle.insideBarCount >= 1) ||
                          (ctx.candle.pattern == CANDLE_MOMENTUM_BAR) ||
                          (ctx.candle.pattern == CANDLE_EXPANSION_BAR) ||
                          (ctx.market.normalizedBarRangeAtr >= 0.85 && body >= barRange * 0.45);

      // Full fanned EMA ribbon + macro SMA alignment
      bool bullRibbon = (ctx.ind.emaFast > ctx.ind.emaMedium &&
                         ctx.ind.emaMedium > ctx.ind.emaSlow &&
                         ctx.ind.emaSlow >= ctx.ind.smaTrend - ctx.ind.atr * 0.25 &&
                         ctx.market.close > ctx.ind.emaFast &&
                         ctx.ind.adxPlusDI >= ctx.ind.adxMinusDI + 4.0);
      bool bearRibbon = (ctx.ind.emaFast < ctx.ind.emaMedium &&
                         ctx.ind.emaMedium < ctx.ind.emaSlow &&
                         ctx.ind.emaSlow <= ctx.ind.smaTrend + ctx.ind.atr * 0.25 &&
                         ctx.market.close < ctx.ind.emaFast &&
                         ctx.ind.adxMinusDI >= ctx.ind.adxPlusDI + 4.0);

      bool bullCloseConv = (ctx.market.close > ctx.market.open) && ((ctx.market.close - ctx.market.low) >= barRange * 0.60);
      bool bearCloseConv = (ctx.market.close < ctx.market.open) && ((ctx.market.high - ctx.market.close) >= barRange * 0.60);

      bool bullMtfStrong = (ctx.mtf.weightedScore >= 45.0 && ctx.mtf.higherBias == SIGNAL_BUY && ctx.mtf.intermediateBias != SIGNAL_SELL);
      bool bearMtfStrong = (ctx.mtf.weightedScore <= -45.0 && ctx.mtf.higherBias == SIGNAL_SELL && ctx.mtf.intermediateBias != SIGNAL_BUY);

      if(bullRibbon && pauseRelease && bullCloseConv && bullMtfStrong &&
         ctx.ind.macdHist > 0.0 && ctx.ind.macdHist >= ctx.ind.prevMacdHist &&
         ctx.ind.rsi >= 50.0 && ctx.ind.rsi <= 68.0 &&
         ctx.candle.bias != SIGNAL_SELL &&
         (!ctx.ind.vwapAvailable || ctx.market.close >= ctx.ind.vwap))
      {
         double slDist = ComputeStructuralSLDist(ctx, SIGNAL_BUY, effSlMult, effSlMult * 1.40);
         double tpDist = MathMax(slDist * 1.65, ctx.ind.atr * effTpMult * 1.15);
         double conf = (ctx.ind.relativeVolume >= 1.15) ? 0.89 : 0.86;
         PopulateCommonSignal(outSignal, ctx, SIGNAL_BUY, slDist, tpDist, conf,
                              "Bullish full EMA9/21/55/SMA200 ribbon fan continuation thrust",
                              StringFormat("ADX=%.1f, DI+=%.1f, MTF=%.0f, RVOL=%.2f, RSI=%.1f", ctx.ind.adxMain, ctx.ind.adxPlusDI, ctx.mtf.weightedScore, ctx.ind.relativeVolume, ctx.ind.rsi),
                              ctx.structure.summary, ctx.candle.name, "None");
         return true;
      }

      if(bearRibbon && pauseRelease && bearCloseConv && bearMtfStrong &&
         ctx.ind.macdHist < 0.0 && ctx.ind.macdHist <= ctx.ind.prevMacdHist &&
         ctx.ind.rsi <= 50.0 && ctx.ind.rsi >= 32.0 &&
         ctx.candle.bias != SIGNAL_BUY &&
         (!ctx.ind.vwapAvailable || ctx.market.close <= ctx.ind.vwap))
      {
         double slDist = ComputeStructuralSLDist(ctx, SIGNAL_SELL, effSlMult, effSlMult * 1.40);
         double tpDist = MathMax(slDist * 1.65, ctx.ind.atr * effTpMult * 1.15);
         double conf = (ctx.ind.relativeVolume >= 1.15) ? 0.89 : 0.86;
         PopulateCommonSignal(outSignal, ctx, SIGNAL_SELL, slDist, tpDist, conf,
                              "Bearish full EMA9/21/55/SMA200 ribbon fan continuation thrust",
                              StringFormat("ADX=%.1f, DI-=%.1f, MTF=%.0f, RVOL=%.2f, RSI=%.1f", ctx.ind.adxMain, ctx.ind.adxMinusDI, ctx.mtf.weightedScore, ctx.ind.relativeVolume, ctx.ind.rsi),
                              ctx.structure.summary, ctx.candle.name, "None");
         return true;
      }

      outRejectReason = "EMA ribbon alignment, MTF consensus, or continuation thrust unmet";
      return false;
   }

   virtual bool ShouldExitPosition(const SManagedPosition &pos, const SAnalysisContext &ctx, string &outExitReason) const override
   {
      if(pos.holdingSeconds < 240 || !ctx.ind.isReady) return false;
      if(pos.direction == SIGNAL_BUY && ctx.ind.emaFast < ctx.ind.emaMedium && ctx.ind.macdHist < 0.0)
      {
         outExitReason = "EmaRibbon exit: fast EMA crossed below medium EMA with bearish MACD";
         return true;
      }
      if(pos.direction == SIGNAL_SELL && ctx.ind.emaFast > ctx.ind.emaMedium && ctx.ind.macdHist > 0.0)
      {
         outExitReason = "EmaRibbon exit: fast EMA crossed above medium EMA with bullish MACD";
         return true;
      }
      return false;
   }
};

#endif // __ASEA_STRATEGIES_EMARIBBONCONTINUATION_MQH__
