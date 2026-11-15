//+------------------------------------------------------------------+
//|                                                TrendPullback.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        Strategy 1: Trend Pullback Scalping       |
//+------------------------------------------------------------------+
#ifndef __ASEA_STRATEGIES_TRENDPULLBACK_MQH__
#define __ASEA_STRATEGIES_TRENDPULLBACK_MQH__

#include "StrategyBase.mqh"

class CStrategyTrendPullback : public CStrategyBase
{
private:
   double m_minAdx;
   double m_pullbackAtrTol;

public:
   CStrategyTrendPullback() : CStrategyBase(STRAT_TREND_PULLBACK, "Trend Pullback")
   {
      m_minAdx = 18.0;
      m_pullbackAtrTol = 0.65;
   }

   void Configure(const bool enabled, const double slMult, const double tpMult, const int minSample,
                  const double minAdx, const double pullbackAtrTol)
   {
      ConfigureBase(enabled, slMult, tpMult, minSample);
      m_minAdx = MathMax(12.0, minAdx);
      m_pullbackAtrTol = MathMax(0.2, MathMin(1.5, pullbackAtrTol));
   }

   virtual bool IsSuitableForRegime(const ENUM_MARKET_REGIME regime) const override
   {
      return (regime == REGIME_STRONG_BULL_TREND || regime == REGIME_WEAK_BULL_TREND ||
              regime == REGIME_STRONG_BEAR_TREND || regime == REGIME_WEAK_BEAR_TREND);
   }

   virtual bool Evaluate(const SAnalysisContext &ctx, STradeSignal &outSignal, string &outRejectReason) override
   {
      outSignal.Reset();
      outRejectReason = "";

      if(!m_enabled) { outRejectReason = "Strategy disabled by input"; return false; }
      if(!IsSuitableForRegime(ctx.regime.regime))
      {
         outRejectReason = "Regime not trending: " + ctx.regime.label;
         return false;
      }
      if(!ctx.ind.isReady || !ctx.structure.isReady || ctx.ind.atr <= 0.0)
      {
         outRejectReason = "Indicators or structure not ready";
         return false;
      }
      if(ctx.ind.adxMain < m_minAdx)
      {
         outRejectReason = StringFormat("ADX %.1f below minimum %.1f", ctx.ind.adxMain, m_minAdx);
         return false;
      }

      double tol = ctx.ind.atr * m_pullbackAtrTol;
      bool bullTrend = (ctx.ind.emaFast > ctx.ind.emaMedium && ctx.ind.emaMedium > ctx.ind.emaSlow);
      bool bearTrend = (ctx.ind.emaFast < ctx.ind.emaMedium && ctx.ind.emaMedium < ctx.ind.emaSlow);

      if(bullTrend && ctx.mtf.higherBias != SIGNAL_SELL)
      {
         bool touchedZone = (ctx.market.low <= ctx.ind.emaMedium + tol) && (ctx.market.close > ctx.ind.emaSlow);
         bool momentumResume = (ctx.market.close > ctx.market.open) && (ctx.ind.rsi >= 42.0 && ctx.ind.rsi <= 65.0) && (ctx.ind.stochK > ctx.ind.stochD);
         bool structOk = (ctx.structure.structureBias >= 0);

         if(touchedZone && momentumResume && structOk)
         {
            double slDist = MathMax(ctx.ind.atr * m_slAtrMult, (ctx.market.ask - ctx.structure.nearestSupport) + ctx.ind.atr * 0.25);
            slDist = MathMin(slDist, ctx.ind.atr * (m_slAtrMult * 1.6));
            double tpDist = ctx.ind.atr * m_tpAtrMult;
            string conflict = (ctx.mtf.hasStrongConflict) ? ctx.mtf.conflictReason : "None";
            PopulateCommonSignal(outSignal, ctx, SIGNAL_BUY, slDist, tpDist, 0.78,
                                 "Bullish trend pullback to EMA21/structure with stochastic turn",
                                 StringFormat("EMA9>21>55, ADX=%.1f, RSI=%.1f", ctx.ind.adxMain, ctx.ind.rsi),
                                 ctx.structure.summary,
                                 ctx.candle.name, conflict);
            return true;
         }
         outRejectReason = "Bull trend active but pullback/turn conditions incomplete";
         return false;
      }

      if(bearTrend && ctx.mtf.higherBias != SIGNAL_BUY)
      {
         bool touchedZone = (ctx.market.high >= ctx.ind.emaMedium - tol) && (ctx.market.close < ctx.ind.emaSlow);
         bool momentumResume = (ctx.market.close < ctx.market.open) && (ctx.ind.rsi <= 58.0 && ctx.ind.rsi >= 35.0) && (ctx.ind.stochK < ctx.ind.stochD);
         bool structOk = (ctx.structure.structureBias <= 0);

         if(touchedZone && momentumResume && structOk)
         {
            double slDist = MathMax(ctx.ind.atr * m_slAtrMult, (ctx.structure.nearestResistance - ctx.market.bid) + ctx.ind.atr * 0.25);
            slDist = MathMin(slDist, ctx.ind.atr * (m_slAtrMult * 1.6));
            double tpDist = ctx.ind.atr * m_tpAtrMult;
            string conflict = (ctx.mtf.hasStrongConflict) ? ctx.mtf.conflictReason : "None";
            PopulateCommonSignal(outSignal, ctx, SIGNAL_SELL, slDist, tpDist, 0.78,
                                 "Bearish trend pullback to EMA21/structure with stochastic turn",
                                 StringFormat("EMA9<21<55, ADX=%.1f, RSI=%.1f", ctx.ind.adxMain, ctx.ind.rsi),
                                 ctx.structure.summary,
                                 ctx.candle.name, conflict);
            return true;
         }
         outRejectReason = "Bear trend active but pullback/turn conditions incomplete";
         return false;
      }

      outRejectReason = "No aligned EMA stack or HTF conflict";
      return false;
   }
};

#endif // __ASEA_STRATEGIES_TRENDPULLBACK_MQH__
