//+------------------------------------------------------------------+
//|                                                    CSVLogger.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.0.0 Buffered 12-File CSV Exporter      |
//+------------------------------------------------------------------+
#ifndef __ASEA_ANALYTICS_CSVLOGGER_MQH__
#define __ASEA_ANALYTICS_CSVLOGGER_MQH__

#include "../Core/Types.mqh"
#include "../Core/Diagnostics.mqh"
#include "../Intelligence/AdaptiveLearning.mqh"
#include "../Intelligence/HistoricalResearch.mqh"

#define ASEA_CSV_FILE_COUNT 12

class CCSVLogger
{
private:
   bool          m_enabled;
   bool          m_isTester;
   string        m_exportDir;
   CDiagnostics *m_diag;
   string        m_fileNames[ASEA_CSV_FILE_COUNT];
   string        m_headers[ASEA_CSV_FILE_COUNT];
   string        m_buffers[ASEA_CSV_FILE_COUNT];
   int           m_bufferLines[ASEA_CSV_FILE_COUNT];
   datetime      m_lastFlushTime;
   int           m_flushBatchSize;

   string CleanCSV(const string s) const
   {
      string out = s;
      StringReplace(out, ",", ";");
      StringReplace(out, "\r", " ");
      StringReplace(out, "\n", " ");
      return out;
   }

   void EnsureHeader(const int idx)
   {
      string path = m_exportDir + "\\" + m_fileNames[idx];
      if(!FileIsExist(path))
      {
         int h = FileOpen(path, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
         if(h != INVALID_HANDLE)
         {
            FileWriteString(h, m_headers[idx] + "\r\n");
            FileClose(h);
         }
      }
   }

   void AppendBuffered(const int idx, const string row)
   {
      if(!m_enabled || idx < 0 || idx >= ASEA_CSV_FILE_COUNT) return;
      m_buffers[idx] += row + "\r\n";
      m_bufferLines[idx]++;
      if(m_bufferLines[idx] >= m_flushBatchSize)
         FlushFile(idx);
   }

   void FlushFile(const int idx)
   {
      if(m_buffers[idx] == "" || m_bufferLines[idx] <= 0) return;
      EnsureHeader(idx);
      string path = m_exportDir + "\\" + m_fileNames[idx];
      int h = FileOpen(path, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
      if(h != INVALID_HANDLE)
      {
         FileSeek(h, 0, SEEK_END);
         FileWriteString(h, m_buffers[idx]);
         FileClose(h);
         m_buffers[idx] = "";
         m_bufferLines[idx] = 0;
      }
      else if(m_diag != NULL)
      {
         m_diag.Log(LOG_WARN, "CSVLogger", StringFormat("Failed to flush %s (err=%d)", path, GetLastError()), "csv_err", 60);
      }
   }

public:
   CCSVLogger()
   {
      m_enabled = true;
      m_isTester = false;
      m_exportDir = "";
      m_diag = NULL;
      m_lastFlushTime = 0;
      m_flushBatchSize = 12;
      for(int i = 0; i < ASEA_CSV_FILE_COUNT; i++)
      {
         m_buffers[i] = "";
         m_bufferLines[i] = 0;
      }
   }

   bool Initialize(const bool enabled, const int batchSize, CDiagnostics *diag)
   {
      m_enabled = enabled;
      m_isTester = (MQLInfoInteger(MQL_TESTER) != 0);
      m_flushBatchSize = m_isTester ? MathMax(200, MathMin(500, batchSize * 10)) : MathMax(1, MathMin(100, batchSize));
      m_diag = diag;
      m_lastFlushTime = (TimeCurrent() > 0) ? TimeCurrent() : TimeLocal();

      if(m_enabled)
      {
         FolderCreate(EA_DATA_ROOT);
         m_exportDir = StringFormat("%s\\Exports", EA_DATA_ROOT);
         FolderCreate(m_exportDir);
      }

      m_fileNames[0]  = "market_observations.csv";
      m_headers[0]    = "timestamp,symbol,timeframe,bid,ask,spread_pts,avg_spread_pts,atr,rsi,adx,macd_hist,vol_ratio,vol_pctile,regime,structure_bias";

      m_fileNames[1]  = "tick_analysis.csv";
      m_headers[1]    = "timestamp,symbol,samples,consec_up,consec_down,persistence,ticks_per_sec,velocity_pts_sec,acceleration,micro_bias,spread_exp_ratio,activity_ratio,spread_spike,net_edge";

      m_fileNames[2]  = "market_regimes.csv";
      m_headers[2]    = "timestamp,symbol,timeframe,regime,confidence,volatility_state,trend_strength,volatility_ratio,efficiency_ratio,is_trending,is_ranging,is_unstable";

      m_fileNames[3]  = "detected_patterns.csv";
      m_headers[3]    = "timestamp,symbol,timeframe,candle_pattern,candle_bias,candle_validated,chart_pattern,chart_bias,chart_confidence,breakout_level,note";

      m_fileNames[4]  = "strategy_signals.csv";
      m_headers[4]    = "timestamp,signal_id,symbol,timeframe,strategy,direction,score,validated_score,band,regime,entry_price,sl,tp,est_cost,net_expectancy,rr_ratio,rationale,supporting_indicators,supporting_structure,split_tag";

      m_fileNames[5]  = "rejected_signals.csv";
      m_headers[5]    = "timestamp,symbol,timeframe,strategy,direction,score,regime,rejection_code,rejection_reason";

      m_fileNames[6]  = "trade_history.csv";
      m_headers[6]    = "timestamp,ticket,signal_id,symbol,timeframe,strategy,direction,volume,entry_price,sl,tp,slippage_pts,execution_cost,score,regime,status,exit_reason,net_pnl,mfe_money,mae_money,hold_seconds,split_tag";

      m_fileNames[7]  = "strategy_performance.csv";
      m_headers[7]    = "timestamp,symbol,strategy,enabled,suitability,total_trades,wins,losses,win_rate_pct,net_profit,profit_factor,expected_value,max_dd_money,avg_hold_sec,sufficient_sample,deterioration_warn";

      m_fileNames[8]  = "risk_events.csv";
      m_headers[8]    = "timestamp,symbol,event_type,status_label,daily_pnl,weekly_pnl,balance_dd_pct,equity_dd_pct,open_risk_pct,top_currency,max_ccy_lots,consecutive_losses,details";

      m_fileNames[9]  = "learning_history.csv";
      m_headers[9]    = "timestamp,strategy,regime,finding,proposed_action,validated_oos";

      m_fileNames[10] = "configuration_history.csv";
      m_headers[10]   = "timestamp,symbol,timeframe,operating_mode,risk_pct,min_score,max_spread_pts,config_label";

      m_fileNames[11] = "session_summary.csv";
      m_headers[11]   = "timestamp,symbol,balance,equity,floating_pnl,realized_net_pnl,commissions,swaps,total_trades,win_rate_pct,profit_factor,max_dd_pct,avg_mfe,avg_mae,sharpe,sortino,observations,signals_gen,signals_acc,signals_rej";

      return true;
   }

   void LogObservation(const SMarketSnapshot &m, const SIndicatorValues &ind, const SRegimeState &reg, const SStructureState &st)
   {
      string row = StringFormat("%s,%s,%s,%.5f,%.5f,%.1f,%.1f,%.5f,%.2f,%.2f,%.5f,%.2f,%.1f,%s,%d",
                                TimeToString(m.tickTime, TIME_DATE | TIME_SECONDS), m.symbol, EnumToString(m.timeframe),
                                m.bid, m.ask, m.spreadPoints, m.avgSpreadPoints, ind.atr, ind.rsi, ind.adxMain,
                                ind.macdHist, reg.volatilityRatio, ind.volatilityPercentile, CleanCSV(reg.label), st.structureBias);
      AppendBuffered(0, row);
   }

   void LogTickAnalysis(const string sym, const datetime t, const STickMetrics &tk)
   {
      string row = StringFormat("%s,%s,%d,%d,%d,%.3f,%.2f,%.2f,%.2f,%.3f,%.2f,%.2f,%d,%d",
                                TimeToString(t, TIME_DATE | TIME_SECONDS), sym, tk.sampleCount,
                                tk.consecutiveUpTicks, tk.consecutiveDownTicks, tk.directionalPersistence, tk.ticksPerSecond,
                                tk.priceVelocity, tk.priceAcceleration, tk.microTrendBias,
                                tk.spreadExpansionRatio, tk.activityRatio, tk.spreadSpikeDetected ? 1 : 0, tk.tickProvidesNetEdge ? 1 : 0);
      AppendBuffered(1, row);
   }

   void LogRegime(const string sym, const ENUM_TIMEFRAMES tf, const datetime t, const SRegimeState &reg)
   {
      string row = StringFormat("%s,%s,%s,%s,%.2f,%d,%.2f,%.2f,%.3f,%d,%d,%d",
                                TimeToString(t, TIME_DATE | TIME_SECONDS), sym, EnumToString(tf),
                                CleanCSV(reg.label), reg.confidence, (int)reg.volatilityState, reg.trendStrength,
                                reg.volatilityRatio, reg.efficiencyRatio,
                                reg.isTrending ? 1 : 0, reg.isRanging ? 1 : 0, reg.isUnstable ? 1 : 0);
      AppendBuffered(2, row);
   }

   void LogPatterns(const string sym, const ENUM_TIMEFRAMES tf, const datetime t, const SCandleSignal &c, const SChartPatternSignal &p)
   {
      if(c.pattern == CANDLE_NONE && p.pattern == PATTERN_NONE) return;
      string row = StringFormat("%s,%s,%s,%s,%s,%d,%s,%s,%.2f,%.5f,%s",
                                TimeToString(t, TIME_DATE | TIME_SECONDS), sym, EnumToString(tf),
                                CleanCSV(c.name), DirectionToString(c.bias), c.contextValidated ? 1 : 0,
                                CleanCSV(p.name), DirectionToString(p.bias), p.confidence, p.breakoutLevel, CleanCSV(p.note));
      AppendBuffered(3, row);
   }

   void LogAcceptedSignal(const STradeSignal &s, const string splitTag)
   {
      string row = StringFormat("%s,%s,%s,%s,%s,%s,%.1f,%d,%s,%s,%.5f,%.5f,%.5f,%.2f,%.2f,%.2f,%s,%s,%s,%s",
                                TimeToString(s.timestamp, TIME_DATE | TIME_SECONDS), s.signalId, s.symbol,
                                EnumToString(s.timeframe), CleanCSV(s.strategyName), DirectionToString(s.direction),
                                s.compositeScore, s.breakdown.isValidatedScore ? 1 : 0,
                                CleanCSV(StrengthBandToString(s.breakdown.band)),
                                CleanCSV(RegimeToString(s.regime)), s.entryPrice, s.stopLoss, s.takeProfit,
                                s.expectancy.estimatedCostMoney, s.expectancy.netExpectancyMoney, s.expectancy.riskRewardRatio,
                                CleanCSV(s.rationale), CleanCSV(s.supportingIndicators), CleanCSV(s.supportingStructure), splitTag);
      AppendBuffered(4, row);
   }

   void LogRejectedSignal(const string sym, const ENUM_TIMEFRAMES tf, const string stratName,
                          const ENUM_SIGNAL_DIRECTION dir, const double score, const ENUM_MARKET_REGIME reg,
                          const string code, const string reason)
   {
      string row = StringFormat("%s,%s,%s,%s,%s,%.1f,%s,%s,%s",
                                TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), sym, EnumToString(tf),
                                CleanCSV(stratName), DirectionToString(dir), score, CleanCSV(RegimeToString(reg)),
                                CleanCSV(code), CleanCSV(reason));
      AppendBuffered(5, row);
   }

   void LogTradeExecutionOrClose(const string sym, const ENUM_TIMEFRAMES tf, const ulong ticket, const string signalId,
                                 const string stratName, const ENUM_SIGNAL_DIRECTION dir, const double vol, const double entry,
                                 const double sl, const double tp, const double slipPts, const double execCost,
                                 const double score, const ENUM_MARKET_REGIME reg, const string status, const string exitReason,
                                 const double netPnL, const double mfeMoney, const double maeMoney,
                                 const long holdSec, const string splitTag)
   {
      string row = StringFormat("%s,%I64u,%s,%s,%s,%s,%s,%.2f,%.5f,%.5f,%.5f,%.1f,%.2f,%.1f,%s,%s,%s,%.2f,%.2f,%.2f,%I64d,%s",
                                TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), ticket, CleanCSV(signalId), sym, EnumToString(tf),
                                CleanCSV(stratName), DirectionToString(dir), vol, entry, sl, tp, slipPts, execCost, score,
                                CleanCSV(RegimeToString(reg)), CleanCSV(status), CleanCSV(exitReason),
                                netPnL, mfeMoney, maeMoney, holdSec, splitTag);
      AppendBuffered(6, row);
   }

   void LogStrategyPerformanceSnapshot(const string sym, const SStrategyStats &st)
   {
      string row = StringFormat("%s,%s,%s,%d,%s,%d,%d,%d,%.2f,%.2f,%.2f,%.2f,%.2f,%.1f,%d,%d",
                                TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), sym, CleanCSV(st.strategyName),
                                st.enabledByInput ? 1 : 0, CleanCSV(SuitabilityToString(st.suitability)),
                                st.totalTrades, st.winningTrades, st.losingTrades,
                                st.winRatePct, st.netProfit, st.profitFactor, st.expectedValue, st.maxDrawdownMoney,
                                st.avgHoldingSeconds, st.hasSufficientSample ? 1 : 0, st.deteriorationWarning ? 1 : 0);
      AppendBuffered(7, row);
   }

   void LogRiskEvent(const string sym, const string eventType, const SRiskStatus &rk, const string details)
   {
      string row = StringFormat("%s,%s,%s,%s,%.2f,%.2f,%.2f,%.2f,%.2f,%s,%.2f,%d,%s",
                                TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), sym, CleanCSV(eventType),
                                CleanCSV(rk.statusLabel), rk.dailyPnL, rk.weeklyPnL, rk.balanceDrawdownPct,
                                rk.equityDrawdownPct, rk.currentOpenRiskPct, rk.topExposedCurrency,
                                rk.maxCurrencyExposureLots, rk.consecutiveLosses, CleanCSV(details));
      AppendBuffered(8, row);
   }

   void LogLearningProposal(const SLearningProposal &p)
   {
      if(p.timestamp <= 0) return;
      string row = StringFormat("%s,%s,%s,%s,%s,%d",
                                TimeToString(p.timestamp, TIME_DATE | TIME_SECONDS), CleanCSV(p.strategyName),
                                CleanCSV(p.regimeLabel), CleanCSV(p.finding), CleanCSV(p.proposedAction),
                                p.validatedOutOfSample ? 1 : 0);
      AppendBuffered(9, row);
   }

   void LogConfiguration(const string sym, const ENUM_TIMEFRAMES tf, const ENUM_EA_OPERATING_MODE mode,
                         const double riskPct, const double minScore, const double maxSpread, const string label)
   {
      string row = StringFormat("%s,%s,%s,%s,%.2f,%.1f,%.1f,%s",
                                TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), sym, EnumToString(tf),
                                OperatingModeToString(mode), riskPct, minScore, maxSpread, CleanCSV(label));
      AppendBuffered(10, row);
      FlushFile(10);
   }

   void LogSessionSummary(const string sym, const SAccountMetrics &acc, const SIntelligenceSummary &intel)
   {
      string row = StringFormat("%s,%s,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%d,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%I64d,%I64d,%I64d,%I64d",
                                TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), sym, acc.balance, acc.equity,
                                acc.floatingPnL, acc.totalNetProfit, acc.totalCommissions, acc.totalSwaps,
                                acc.totalTrades, acc.winRatePct, acc.profitFactor, acc.maxDrawdownPct,
                                acc.avgMfeMoney, acc.avgMaeMoney, acc.sharpeRatio, acc.sortinoRatio,
                                intel.observationsCollected, intel.signalsGenerated, intel.signalsAccepted, intel.signalsRejected);
      AppendBuffered(11, row);
   }

   void FlushAll(const bool force = false)
   {
      if(!m_enabled) return;
      datetime now = (TimeCurrent() > 0) ? TimeCurrent() : TimeLocal();
      int flushSec = m_isTester ? 3600 : 30;
      if(!force && (now - m_lastFlushTime) < flushSec) return;
      for(int i = 0; i < ASEA_CSV_FILE_COUNT; i++)
         FlushFile(i);
      m_lastFlushTime = now;
   }
};

#endif // __ASEA_ANALYTICS_CSVLOGGER_MQH__
