//+------------------------------------------------------------------+
//|                                             AdaptiveLearning.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        Controlled Non-Mutating Research Engine   |
//+------------------------------------------------------------------+
#ifndef __ASEA_INTELLIGENCE_ADAPTIVELEARNING_MQH__
#define __ASEA_INTELLIGENCE_ADAPTIVELEARNING_MQH__

#include "../Core/Types.mqh"
#include "../Core/Diagnostics.mqh"
#include "../Strategies/StrategyBase.mqh"

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
   bool          m_enableAdaptiveEvaluation;
   int           m_minSamplePerRegime;
   double        m_deteriorationPfFloor;
   CDiagnostics *m_diag;
   SIntelligenceSummary m_summary;
   SLearningProposal    m_lastProposal;

public:
   CAdaptiveLearning()
   {
      m_enableAdaptiveEvaluation = true;
      m_minSamplePerRegime = 20;
      m_deteriorationPfFloor = 0.85;
      m_diag = NULL;
      m_summary.Reset();
      m_lastProposal.timestamp = 0;
      m_lastProposal.strategyName = "";
      m_lastProposal.regimeLabel = "";
      m_lastProposal.finding = "";
      m_lastProposal.proposedAction = "";
      m_lastProposal.validatedOutOfSample = false;
   }

   void Initialize(const bool enableEval, const int minSample, const double pfFloor, CDiagnostics *diag)
   {
      m_enableAdaptiveEvaluation = enableEval;
      m_minSamplePerRegime = MathMax(15, minSample);
      m_deteriorationPfFloor = MathMax(0.5, MathMin(1.2, pfFloor));
      m_diag = diag;
      m_summary.Reset();
      m_summary.learningStatus = m_enableAdaptiveEvaluation ? "Active (Non-Mutating Research)" : "Passive Logging Only";
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
      if(lastCfg != "") m_summary.lastValidatedConfig = lastCfg;
      m_summary.lastValidationTime    = lastValTime;
   }

   void RecordObservation(const bool hasPattern, const bool regimeAnalyzed)
   {
      m_summary.observationsCollected++;
      if(hasPattern) m_summary.patternsDetected++;
      if(regimeAnalyzed) m_summary.regimesAnalyzed++;
   }

   void RecordSignalDecision(const bool accepted)
   {
      m_summary.signalsGenerated++;
      if(accepted) m_summary.signalsAccepted++;
      else         m_summary.signalsRejected++;
   }

   // Controlled evaluation: detects deterioration and records proposals WITHOUT mutating risk limits
   bool EvaluateStrategies(CStrategyBase *&strategies[], const int count, const ENUM_MARKET_REGIME curRegime,
                           SLearningProposal &outNewProposal)
   {
      outNewProposal.timestamp = 0;
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
            outNewProposal.timestamp = TimeCurrent();
            outNewProposal.strategyName = st.strategyName;
            outNewProposal.regimeLabel = RegimeToString(curRegime);
            outNewProposal.finding = StringFormat("PF %.2f < %.2f across %d trades (Recent WR=%.1f%%)",
                                                  st.profitFactor, m_deteriorationPfFloor, st.totalTrades, st.recentWinRatePct);
            outNewProposal.proposedAction = "Flagged for walk-forward review; risk parameters unchanged";
            outNewProposal.validatedOutOfSample = false;
            m_lastProposal = outNewProposal;
            emittedProposal = true;

            if(m_diag != NULL)
               m_diag.Log(LOG_WARN, "AdaptiveLearning",
                          StringFormat("Deterioration detected on %s: %s", st.strategyName, outNewProposal.finding),
                          "det_" + st.strategyName, 300);
         }
      }

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
