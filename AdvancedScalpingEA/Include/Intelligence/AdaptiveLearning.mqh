//+------------------------------------------------------------------+
//|                                             AdaptiveLearning.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v3.1.0 5-Stage Controlled Research Engine |
//+------------------------------------------------------------------+
#ifndef __ASEA_INTELLIGENCE_ADAPTIVELEARNING_MQH__
#define __ASEA_INTELLIGENCE_ADAPTIVELEARNING_MQH__

#include "../Core/Types.mqh"
#include "../Core/Diagnostics.mqh"
#include "../Strategies/StrategyBase.mqh"
#include "../Trading/TradeValidation.mqh"

struct SLearningProposal
{
   datetime timestamp;
   string   strategyName;
   string   regimeLabel;
   string   finding;
   string   proposedAction;
   bool     validatedOutOfSample;
};

class CAdaptiveLearning
{
private:
   bool                 m_enableAdaptiveEvaluation;
   int                  m_minSamplePerRegime;
   double               m_deteriorationPfFloor;
   CDiagnostics        *m_diag;
   SIntelligenceSummary m_summary;
   SLearningProposal    m_lastProposal;

public:
   CAdaptiveLearning()
   {
      m_enableAdaptiveEvaluation = true;
      m_minSamplePerRegime = 15;
      m_deteriorationPfFloor = 0.92;
      m_diag = NULL;
      m_summary.Reset();
      m_lastProposal.timestamp = 0;
      m_lastProposal.strategyName = "";
      m_lastProposal.regimeLabel = "";
      m_lastProposal.finding = "";
      m_lastProposal.proposedAction = "";
      m_lastProposal.validatedOutOfSample = false;
   }

   void Initialize(const bool enableEval, const int minSample, const double pfFloor,
                   const string activeCfgVer, CDiagnostics *diag)
   {
      m_enableAdaptiveEvaluation = enableEval;
      m_minSamplePerRegime = MathMax(15, minSample);
      m_deteriorationPfFloor = MathMax(0.5, MathMin(1.2, pfFloor));
      m_diag = diag;
      m_summary.Reset();
      m_summary.learningStatus = m_enableAdaptiveEvaluation ? "5-Stage Controlled (Non-Mutating)" : "Passive Logging Only";
      m_summary.stage4ValidatedConfig = (activeCfgVer != "") ? activeCfgVer : "AutoAdaptive_v3.1";
      m_summary.stage5ActiveConfig    = m_summary.stage4ValidatedConfig;
   }

   void RestoreCounts(const long obs, const long pat, const long reg, const long sigGen,
                      const long sigAcc, const long sigRej, const string lastCfg, const datetime lastValTime)
   {
      m_summary.observationsCollected = obs;
      m_summary.patternsDetected      = pat;
      m_summary.regimesAnalyzed       = reg;
      m_summary.signalsGenerated      = sigGen;
      m_summary.signalsAccepted       = sigAcc;
      m_summary.signalsRejected       = sigRej;
      if(lastCfg != "")
      {
         m_summary.stage4ValidatedConfig = lastCfg;
         m_summary.stage5ActiveConfig    = lastCfg;
      }
      m_summary.lastValidationTime = lastValTime;
   }

   void RecordObservation(const bool hasPattern, const bool regimeAnalyzed)
   {
      m_summary.observationsCollected++;
      if(hasPattern) m_summary.patternsDetected++;
      if(regimeAnalyzed) m_summary.regimesAnalyzed++;
      m_summary.stage1RawObs = StringFormat("%I64d obs | %I64d patterns | %I64d regimes",
                                            m_summary.observationsCollected, m_summary.patternsDetected, m_summary.regimesAnalyzed);
   }

   void RecordSignalDecision(const bool accepted)
   {
      m_summary.signalsGenerated++;
      if(accepted) m_summary.signalsAccepted++;
      else         m_summary.signalsRejected++;
   }

   // Controlled 5-stage evaluation: records findings & recommendations WITHOUT silently altering live risk caps
   bool EvaluateStrategies(CStrategyBase *&strategies[], const int count, const ENUM_MARKET_REGIME curRegime,
                           const SFilterStats &fStats, const int totalClosedTrades,
                           const string scoreBandSummary, SLearningProposal &outNewProposal,
                           const string researchExtras = "")
   {
      outNewProposal.timestamp = 0;
      m_summary.stage1RawObs = StringFormat("%I64d obs | %I64d sig (%I64d acc / %I64d rej)",
                                            m_summary.observationsCollected, m_summary.signalsGenerated,
                                            m_summary.signalsAccepted, m_summary.signalsRejected);

      if(!m_enableAdaptiveEvaluation) return false;

      int warnings = 0;
      bool emittedProposal = false;

      for(int i = 0; i < count; i++)
      {
         if(strategies[i] == NULL) continue;
         SStrategyStats st = strategies[i].GetStats();
         if(st.deteriorationWarning) warnings++;

         if(st.totalTrades >= m_minSamplePerRegime && st.profitFactor < m_deteriorationPfFloor &&
            m_lastProposal.strategyName != st.strategyName)
         {
            outNewProposal.timestamp    = SafeCurrentTime();
            outNewProposal.strategyName = st.strategyName;
            outNewProposal.regimeLabel  = RegimeToString(curRegime);
            outNewProposal.finding      = StringFormat("PF %.2f < %.2f across %d trades (Recent WR=%.1f%%)",
                                                       st.profitFactor, m_deteriorationPfFloor, st.totalTrades, st.recentWinRatePct);
            outNewProposal.proposedAction = "Recommend regime exclusion or walk-forward review; risk caps locked";
            outNewProposal.validatedOutOfSample = false;
            m_lastProposal = outNewProposal;
            emittedProposal = true;

            if(m_diag != NULL)
               m_diag.Log(LOG_WARN, "AdaptiveLearning",
                          StringFormat("Deterioration detected on %s: %s", st.strategyName, outNewProposal.finding),
                          "det_" + st.strategyName, 300);
         }
      }

      // Stage 2: Historical Findings
      if(totalClosedTrades < m_minSamplePerRegime)
      {
         m_summary.stage2HistoricalFinding = StringFormat("Collecting min sample (%d/%d closed trades); filters: Score=%I64d, Spread=%I64d, Exp=%I64d",
                                                          totalClosedTrades, m_minSamplePerRegime,
                                                          fStats.rejLowScore, fStats.rejSpread, fStats.rejExpectancy);
      }
      else
      {
         m_summary.stage2HistoricalFinding = StringFormat("n=%d | %s | Rej[Score:%I64d Spread:%I64d Exp:%I64d]%s",
                                                          totalClosedTrades, scoreBandSummary,
                                                          fStats.rejLowScore, fStats.rejSpread, fStats.rejExpectancy,
                                                          (researchExtras != "") ? (" | " + researchExtras) : "");
      }

      // Stage 3: Recommendations
      if(m_lastProposal.timestamp > 0)
         m_summary.stage3Recommendation = m_lastProposal.strategyName + ": " + m_lastProposal.proposedAction;
      else if(fStats.totalEvaluated > 20 && fStats.rejExpectancy > fStats.totalPassed)
         m_summary.stage3Recommendation = "High expectancy/cost rejections; review broker spread or TP/SL ratio";
      else
         m_summary.stage3Recommendation = "No parameter change recommended";

      m_summary.deteriorationWarnings = warnings;
      m_summary.researchSummary = (warnings > 0)
         ? StringFormat("%d strategy deterioration warning(s) flagged for review", warnings)
         : StringFormat("All strategies within baseline bounds (%I64d obs)", m_summary.observationsCollected);

      return emittedProposal;
   }

   SIntelligenceSummary GetSummary() const { return m_summary; }
   SLearningProposal    GetLastProposal() const { return m_lastProposal; }
};

#endif // __ASEA_INTELLIGENCE_ADAPTIVELEARNING_MQH__
