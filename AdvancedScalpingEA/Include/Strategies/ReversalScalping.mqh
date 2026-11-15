//+------------------------------------------------------------------+
//|                                             ReversalScalping.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        Strategy 4: Structural Reversal Scalping  |
//+------------------------------------------------------------------+
#ifndef __ASEA_STRATEGIES_REVERSALSCALPING_MQH__
#define __ASEA_STRATEGIES_REVERSALSCALPING_MQH__

#include "StrategyBase.mqh"

class CStrategyReversalScalping : public CStrategyBase
{
private:
   double m_rsiOversold;
   double m_rsiOverbought;

public:
   CStrategyReversalScalping() : CStrategyBase(STRAT_REVERSAL_SCALPING, "Reversal Scalping")
   {
      m_rsiOversold = 32.0;
      m_rsiOverbought = 68.0;
   }

   void Configure(const bool enabled, const double slMult, const double tpMult, const int minSample,
                  const double rsiOS, const double rsiOB)
   {
      ConfigureBase(enabled, slMult, tpMult, minSample);
      m_rsiOversold = MathMax(15.0, MathMin(40.0, rsiOS));
      m_rsiOverbought = MathMin(85.0, MathMax(60.0, rsiOB));
   }

   virtual bool IsSuitableForRegime(const ENUM_MARKET_REGIME regime) const override
   {
      return (regime != REGIME_UNSTABLE);
   }

   virtual bool Evaluate(const SAnalysisContext &ctx, STradeSignal &outSignal, string &outRejectReason) override
   {
      outSignal.Reset();
      outRejectReason = "";

      if(!m_enabled) { outRejectReason = "Strategy disabled by input"; return false; }
      if(!IsSuitableForRegime(ctx.regime.regime))
      {
         outRejectReason = "Unstable market condition";
         return false;
      }
      if(!ctx.ind.isReady || !ctx.structure.isReady || ctx.ind.atr <= 0.0)
      {
         outRejectReason = "Indicators/structure not ready";
         return false;
      }

      // Avoid fading strong runaway trends without liquidity sweep or CHoCH
      bool strongBullRun = (ctx.regime.regime == REGIME_STRONG_BULL_TREND);
      bool strongBearRun = (ctx.regime.regime == REGIME_STRONG_BEAR_TREND);

      bool bullStructRev = (ctx.structure.lastEvent == STRUCT_CHOCH_BULL ||
                            ctx.structure.lastEvent == STRUCT_LIQ_SWEEP_LOW ||
                            ctx.structure.lastEvent == STRUCT_REJECTION_LOW);
      bool bullCandleRev = (ctx.candle.bias == SIGNAL_BUY && ctx.candle.contextValidated);
      bool bullOscExtreme = (ctx.ind.rsi <= m_rsiOversold || ctx.ind.cci <= -110.0 || ctx.market.low <= ctx.ind.bbLower);

      if(!strongBearRun && bullStructRev && bullCandleRev && bullOscExtreme)
      {
         double slDist = ctx.ind.atr * m_slAtrMult;
         double tpDist = ctx.ind.atr * m_tpAtrMult;
         PopulateCommonSignal(outSignal, ctx, SIGNAL_BUY, slDist, tpDist, 0.74,
                              "Bullish reversal: liquidity sweep/CHoCH + context-validated candle + oscillator extreme",
                              StringFormat("RSI=%.1f, CCI=%.1f, WPR=%.1f", ctx.ind.rsi, ctx.ind.cci, ctx.ind.wpr),
                              ctx.structure.summary, ctx.candle.name,
                              strongBearRun ? "Counter-trend warning" : "None");
         return true;
      }

      bool bearStructRev = (ctx.structure.lastEvent == STRUCT_CHOCH_BEAR ||
                            ctx.structure.lastEvent == STRUCT_LIQ_SWEEP_HIGH ||
                            ctx.structure.lastEvent == STRUCT_REJECTION_HIGH);
      bool bearCandleRev = (ctx.candle.bias == SIGNAL_SELL && ctx.candle.contextValidated);
      bool bearOscExtreme = (ctx.ind.rsi >= m_rsiOverbought || ctx.ind.cci >= 110.0 || ctx.market.high >= ctx.ind.bbUpper);

      if(!strongBullRun && bearStructRev && bearCandleRev && bearOscExtreme)
      {
         double slDist = ctx.ind.atr * m_slAtrMult;
         double tpDist = ctx.ind.atr * m_tpAtrMult;
         PopulateCommonSignal(outSignal, ctx, SIGNAL_SELL, slDist, tpDist, 0.74,
                              "Bearish reversal: liquidity sweep/CHoCH + context-validated candle + oscillator extreme",
                              StringFormat("RSI=%.1f, CCI=%.1f, WPR=%.1f", ctx.ind.rsi, ctx.ind.cci, ctx.ind.wpr),
                              ctx.structure.summary, ctx.candle.name,
                              strongBullRun ? "Counter-trend warning" : "None");
         return true;
      }

      outRejectReason = "Missing combined structure event + validated reversal candle + oscillator extreme";
      return false;
   }
};

#endif // __ASEA_STRATEGIES_REVERSALSCALPING_MQH__
