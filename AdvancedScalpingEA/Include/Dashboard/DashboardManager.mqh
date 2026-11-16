//+------------------------------------------------------------------+
//|                                             DashboardManager.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.1.0 Strictly Read-Only Terminal        |
//+------------------------------------------------------------------+
#ifndef __ASEA_DASHBOARD_MANAGER_MQH__
#define __ASEA_DASHBOARD_MANAGER_MQH__

#include "../Core/Types.mqh"
#include "DashboardComponents.mqh"
#include "DashboardLayout.mqh"
#include "DashboardCharts.mqh"
#include "DashboardStatistics.mqh"

// STRICT ARCHITECTURAL RULE:
// CDashboardManager holds ZERO mutable references to trading, risk, execution,
// or strategy objects. It ONLY accepts const snapshots for display.

class CDashboardManager
{
private:
   bool                m_enabled;
   bool                m_compactMode;
   long                m_chartId;
   ENUM_DASHBOARD_PAGE m_activePage;
   int                 m_chartMode; // 0=Equity, 1=DD, 2=Strategies, 3=ScoreBands, 4=Regimes
   CDashboardCharts    m_charts;

   void ClearContentObjects()
   {
      int total = ObjectsTotal(m_chartId, 0);
      for(int i = total - 1; i >= 0; i--)
      {
         string name = ObjectName(m_chartId, i, 0);
         if(StringFind(name, ASEA_UI_PREFIX + "BODY_") == 0)
            ObjectDelete(m_chartId, name);
      }
   }

   void DrawRow(const string id, const int x, const int y, const string label, const string value,
                const color valClr = ASEA_CLR_TEXT_PRIMARY)
   {
      CDashboardPrimitives::DrawLabel(m_chartId, "BODY_L_" + id, x, y, label, ASEA_CLR_TEXT_MUTED, 8, "Consolas");
      CDashboardPrimitives::DrawLabel(m_chartId, "BODY_V_" + id, x + 150, y, value, valClr, 8, "Consolas");
   }

   void RenderHeaderAndTabs(const SDashboardGeometry &g, const SDashboardSnapshot &snap)
   {
      CDashboardPrimitives::DrawPanel(m_chartId, "BG_MAIN", g.originX, g.originY, g.width, g.height, ASEA_CLR_BG_MAIN, ASEA_CLR_BORDER, 5);
      CDashboardPrimitives::DrawPanel(m_chartId, "BG_HDR",  g.originX + 1, g.originY + 1, g.width - 2, g.headerH, ASEA_CLR_BG_HEADER, ASEA_CLR_BORDER, 8);

      string title = StringFormat("%s v%s  |  %s (%d Sym) %s  |  Mode: %s  [READ-ONLY]",
                                  snap.eaName, snap.eaVersion, snap.symbol, snap.monitoredSymbolCount,
                                  EnumToString(snap.timeframe), OperatingModeToString(snap.operatingMode));
      CDashboardPrimitives::DrawLabel(m_chartId, "HDR_TITLE", g.originX + 12, g.originY + 8, title, ASEA_CLR_TEXT_PRIMARY, 9, "Segoe UI");

      string sub = StringFormat("Conn: %s  |  Algo: %s  |  Regime: %s (%.0f%%)  |  Status: %s",
                                snap.terminalConnected ? "Online" : "Offline",
                                snap.tradeAllowedTerminal ? "ON" : "OFF",
                                snap.regime.label, snap.regime.confidence * 100.0, snap.operationalStatus);
      color subClr = (snap.risk.lockoutActive || !snap.tradeAllowedTerminal) ? ASEA_CLR_RED : (snap.terminalConnected ? ASEA_CLR_ACCENT : ASEA_CLR_AMBER);
      CDashboardPrimitives::DrawLabel(m_chartId, "HDR_SUB", g.originX + 12, g.originY + 25, sub, subClr, 8, "Consolas");

      string tabNames[6] = {"Overview", "Market & Signals", "Strategies", "Positions & Risk", "Charts", "Intelligence"};
      int tabW = (g.width - 24 - 25) / 6;
      int tabY = g.originY + g.headerH + 6;
      for(int i = 0; i < 6; i++)
      {
         int tx = g.originX + 12 + i * (tabW + 5);
         CDashboardPrimitives::DrawNavTab(m_chartId, "TAB_" + IntegerToString(i), tx, tabY, tabW, 22,
                                          tabNames[i], ((int)m_activePage == i));
      }
   }

   void RenderOverviewPage(const SDashboardGeometry &g, const SDashboardSnapshot &s)
   {
      CDashboardPrimitives::DrawPanel(m_chartId, "BODY_P1", g.colLeftX,  g.contentY, g.colW, g.contentH, ASEA_CLR_BG_PANEL, ASEA_CLR_BORDER, 10);
      CDashboardPrimitives::DrawPanel(m_chartId, "BODY_P2", g.colRightX, g.contentY, g.colW, g.contentH, ASEA_CLR_BG_PANEL, ASEA_CLR_BORDER, 10);

      CDashboardPrimitives::DrawLabel(m_chartId, "BODY_H1", g.colLeftX + 10, g.contentY + 8, "System & Multi-Symbol Engine", ASEA_CLR_ACCENT, 9, "Segoe UI");
      int maxChars = MathMax(18, (g.colW - 165) / 7);
      string ccy = (s.accountCurrency != "") ? (" " + s.accountCurrency) : "";
      int y = g.contentY + 30;
      DrawRow("ov1", g.colLeftX + 10, y, "Asset / Acct:", StringFormat("%s (%s)", AssetClassToString(s.symbolProfile.assetClass), s.symbolProfile.isHedgingAccount ? "Hedging" : "Netting")); y += g.rowStep;
      DrawRow("ov2", g.colLeftX + 10, y, "Monitored Syms:", CDashboardStatistics::Truncate(s.monitoredSymbolsSummary, maxChars)); y += g.rowStep;
      DrawRow("ov3", g.colLeftX + 10, y, "Lot Min/Max/Step:", StringFormat("%.2f / %.1f / %.2f", s.symbolProfile.volumeMin, s.symbolProfile.volumeMax, s.symbolProfile.volumeStep)); y += g.rowStep;
      DrawRow("ov4", g.colLeftX + 10, y, "Stops / EstComm:", StringFormat("%d pts / %.2f%s", s.symbolProfile.stopsLevelPoints, s.symbolProfile.estCommissionPerLot, ccy)); y += g.rowStep;
      DrawRow("ov5", g.colLeftX + 10, y, "Data / Bars:", StringFormat("%s (%d bars)", s.market.dataReady ? "Ready" : "Waiting", s.symbolProfile.availableBarsPrimary), s.market.dataReady ? ASEA_CLR_GREEN : ASEA_CLR_AMBER); y += g.rowStep;
      DrawRow("ov6", g.colLeftX + 10, y, "Active Strategy:", CDashboardStatistics::Truncate(s.activeStrategyName, maxChars)); y += g.rowStep;
      DrawRow("ov7", g.colLeftX + 10, y, "Market Regime:", CDashboardStatistics::Truncate(s.regime.label, maxChars)); y += g.rowStep;
      DrawRow("ov8", g.colLeftX + 10, y, "Net Expectancy:", s.lastSignal.isValid ? StringFormat("%+.2f%s (R:R %.2f)", s.lastSignal.expectancy.netExpectancyMoney, ccy, s.lastSignal.expectancy.riskRewardRatio) : "N/A"); y += g.rowStep;
      DrawRow("ov9", g.colLeftX + 10, y, "Last Analysis:", TimeToString(s.lastAnalysisTime, TIME_SECONDS));

      CDashboardPrimitives::DrawLabel(m_chartId, "BODY_H2", g.colRightX + 10, g.contentY + 8, "Live Performance & Trade Analysis", ASEA_CLR_ACCENT, 9, "Segoe UI");
      y = g.contentY + 30;
      DrawRow("pf1", g.colRightX + 10, y, "Balance / Eq:", StringFormat("%.2f / %.2f%s", s.account.balance, s.account.equity, ccy)); y += g.rowStep;
      DrawRow("pf2", g.colRightX + 10, y, "EA Floating PnL:", CDashboardStatistics::FormatMoney(s.account.floatingPnL, s.accountCurrency), s.account.floatingPnL >= 0 ? ASEA_CLR_GREEN : ASEA_CLR_RED); y += g.rowStep;
      DrawRow("pf3", g.colRightX + 10, y, "Realized D / W:", StringFormat("%+.2f / %+.2f%s", s.account.realizedDailyPnL, s.account.realizedWeeklyPnL, ccy)); y += g.rowStep;
      DrawRow("pf4", g.colRightX + 10, y, "Total Net Profit:", CDashboardStatistics::FormatMoney(s.account.totalNetProfit, s.accountCurrency), s.account.totalNetProfit >= 0 ? ASEA_CLR_GREEN : ASEA_CLR_RED); y += g.rowStep;
      DrawRow("pf5", g.colRightX + 10, y, "Comm / Swaps:", StringFormat("%.2f / %.2f%s", s.account.totalCommissions, s.account.totalSwaps, ccy)); y += g.rowStep;
      DrawRow("pf6", g.colRightX + 10, y, "Trades (W / L):", StringFormat("%d (%d / %d)", s.account.totalTrades, s.account.winningTrades, s.account.losingTrades)); y += g.rowStep;
      DrawRow("pf7", g.colRightX + 10, y, "Win Rate / PF:", StringFormat("%.1f%% / %.2f", s.account.winRatePct, s.account.profitFactor)); y += g.rowStep;
      DrawRow("pf8", g.colRightX + 10, y, "Avg Win / Loss:", StringFormat("%.2f / -%.2f", s.account.avgWin, s.account.avgLoss)); y += g.rowStep;
      DrawRow("pf9", g.colRightX + 10, y, "Avg MFE / MAE:", StringFormat("%+.2f / %+.2f", s.account.avgMfeMoney, s.account.avgMaeMoney));
   }

   void RenderMarketPage(const SDashboardGeometry &g, const SDashboardSnapshot &s)
   {
      CDashboardPrimitives::DrawPanel(m_chartId, "BODY_P1", g.colLeftX,  g.contentY, g.colW, g.contentH, ASEA_CLR_BG_PANEL, ASEA_CLR_BORDER, 10);
      CDashboardPrimitives::DrawPanel(m_chartId, "BODY_P2", g.colRightX, g.contentY, g.colW, g.contentH, ASEA_CLR_BG_PANEL, ASEA_CLR_BORDER, 10);

      CDashboardPrimitives::DrawLabel(m_chartId, "BODY_H1", g.colLeftX + 10, g.contentY + 8, "Normalized Market & Structure", ASEA_CLR_ACCENT, 9, "Segoe UI");
      int maxChars = MathMax(18, (g.colW - 165) / 7);
      int y = g.contentY + 30;
      int d = (s.symbolProfile.digits >= 0 && s.symbolProfile.digits <= 8) ? s.symbolProfile.digits : _Digits;
      DrawRow("mk1", g.colLeftX + 10, y, "Bid / Ask:", DoubleToString(s.market.bid, d) + " / " + DoubleToString(s.market.ask, d)); y += g.rowStep;
      DrawRow("mk2", g.colLeftX + 10, y, "Spread (Cur/Avg):", StringFormat("%.1f / %.1f pts (%.2fx)", s.market.spreadPoints, s.market.avgSpreadPoints, s.market.spreadRatio)); y += g.rowStep;
      DrawRow("mk3", g.colLeftX + 10, y, "ATR / VolPctile:", StringFormat("%s (%.0f%%ile)", DoubleToString(s.indicators.atr, d), s.indicators.volatilityPercentile)); y += g.rowStep;
      DrawRow("mk4", g.colLeftX + 10, y, "RSI / ADX / Persist:", StringFormat("%.1f / %.1f / %.2f", s.indicators.rsi, s.indicators.adxMain, s.indicators.directionalPersist)); y += g.rowStep;
      DrawRow("mk5", g.colLeftX + 10, y, "Tick Vel / Edge:", StringFormat("%.1f pts/s (%s)", s.ticks.priceVelocity, s.ticks.tickProvidesNetEdge ? "NetEdge+" : "NoEdge")); y += g.rowStep;
      DrawRow("mk6", g.colLeftX + 10, y, "Structure:", CDashboardStatistics::Truncate(s.structure.summary, maxChars)); y += g.rowStep;
      DrawRow("mk7", g.colLeftX + 10, y, "Sup / Res (Rej):", StringFormat("%s(%d) / %s(%d)", DoubleToString(s.structure.nearestSupport, d), s.structure.supportRejectCount, DoubleToString(s.structure.nearestResistance, d), s.structure.resistanceRejectCount)); y += g.rowStep;
      DrawRow("mk8", g.colLeftX + 10, y, "Candle / Pattern:", CDashboardStatistics::Truncate(s.candle.name + " / " + s.chartPattern.name, maxChars)); y += g.rowStep;
      DrawRow("mk9", g.colLeftX + 10, y, "MTF Weighted:", StringFormat("%+.0f (%s)", s.mtf.weightedScore, s.mtf.hasStrongConflict ? "Conflict" : "Aligned"), s.mtf.hasStrongConflict ? ASEA_CLR_AMBER : ASEA_CLR_GREEN);

      CDashboardPrimitives::DrawLabel(m_chartId, "BODY_H2", g.colRightX + 10, g.contentY + 8, "Latest Signal & Cost Evaluation", ASEA_CLR_ACCENT, 9, "Segoe UI");
      y = g.contentY + 30;
      DrawRow("sg1", g.colRightX + 10, y, "Strategy / Suit:", s.lastSignal.isValid ? CDashboardStatistics::Truncate(s.lastSignal.strategyName + " (" + SuitabilityToString(s.lastSignal.suitability) + ")", maxChars) : "None"); y += g.rowStep;
      DrawRow("sg2", g.colRightX + 10, y, "Direction:", DirectionToString(s.lastSignal.direction)); y += g.rowStep;
      DrawRow("sg3", g.colRightX + 10, y, "Signal Score:", StringFormat("%.1f/100 [%s]", s.lastSignal.compositeScore, s.lastSignal.breakdown.isValidatedScore ? "SampleOK" : "LowSample")); y += g.rowStep;
      DrawRow("sg4", g.colRightX + 10, y, "Validation:", s.lastValidation.rejectionCode, s.lastValidation.passed ? ASEA_CLR_GREEN : ASEA_CLR_AMBER); y += g.rowStep;
      DrawRow("sg5", g.colRightX + 10, y, "Reg/Str/Trd/Mom:", StringFormat("%.0f/%.0f/%.0f/%.0f", s.lastSignal.breakdown.regimeScore, s.lastSignal.breakdown.structureScore, s.lastSignal.breakdown.trendStrengthScore, s.lastSignal.breakdown.momentumScore)); y += g.rowStep;
      DrawRow("sg6", g.colRightX + 10, y, "MTF/Tick/Cost:", StringFormat("%.0f/%.0f/%.0f", s.lastSignal.breakdown.mtfAgreementScore, s.lastSignal.breakdown.tickEdgeScore, s.lastSignal.breakdown.executionCostScore)); y += g.rowStep;
      DrawRow("sg7", g.colRightX + 10, y, "Cost / NetExp:", StringFormat("%.2f / %+.2f", s.lastSignal.expectancy.estimatedCostMoney, s.lastSignal.expectancy.netExpectancyMoney)); y += g.rowStep;
      DrawRow("sg8", g.colRightX + 10, y, "Reason:", CDashboardStatistics::Truncate(s.lastValidation.rejectionReason, maxChars));
   }

   void RenderStrategiesPage(const SDashboardGeometry &g, const SDashboardSnapshot &s)
   {
      CDashboardPrimitives::DrawPanel(m_chartId, "BODY_PFULL", g.contentX, g.contentY, g.contentW, g.contentH, ASEA_CLR_BG_PANEL, ASEA_CLR_BORDER, 10);
      CDashboardPrimitives::DrawLabel(m_chartId, "BODY_SHDR", g.contentX + 10, g.contentY + 10,
                                      "Strategy              Suitability  Trades  WinRate   NetPnL      PF     EV     Sample", ASEA_CLR_ACCENT, 8, "Consolas");
      int y = g.contentY + 34;
      for(int i = 0; i < EA_MAX_STRATEGIES; i++)
      {
         SStrategyStats st = s.strategyStats[i];
         string status = !st.enabledByInput ? "Disabled" : (st.deteriorationWarning ? "Deterior." : SuitabilityToString(st.suitability));
         int target = (st.minSampleTarget > 0) ? st.minSampleTarget : 20;
         string sample = st.hasSufficientSample ? StringFormat("OK(%d)", st.totalTrades) : StringFormat("%d/%d", st.totalTrades, target);
         string row = StringFormat("%-20s  %-11s  %5d   %5.1f%%   %+8.2f  %5.2f  %+6.2f  %s",
                                   CDashboardStatistics::Truncate(st.strategyName, 20), status, st.totalTrades,
                                   st.winRatePct, st.netProfit, st.profitFactor, st.expectedValue, sample);
         color clr = !st.enabledByInput ? ASEA_CLR_TEXT_MUTED : (st.deteriorationWarning ? ASEA_CLR_AMBER : ASEA_CLR_TEXT_PRIMARY);
         CDashboardPrimitives::DrawLabel(m_chartId, "BODY_SR_" + IntegerToString(i), g.contentX + 10, y, row, clr, 8, "Consolas");
         y += 22;
      }
   }

   void RenderPositionsRiskPage(const SDashboardGeometry &g, const SDashboardSnapshot &s,
                                const SManagedPosition &pos[], const int posCount)
   {
      int topH = 160;
      CDashboardPrimitives::DrawPanel(m_chartId, "BODY_PR1", g.contentX, g.contentY, g.contentW, topH, ASEA_CLR_BG_PANEL, ASEA_CLR_BORDER, 10);
      CDashboardPrimitives::DrawLabel(m_chartId, "BODY_RH", g.contentX + 10, g.contentY + 8, "Portfolio Risk & Currency Exposure Controls", ASEA_CLR_ACCENT, 9, "Segoe UI");

      int y = g.contentY + 30;
      DrawRow("rk1", g.colLeftX + 10, y, "Bal / Eq DD:", StringFormat("%.2f%% / %.2f%% (Max %.2f%%)", s.risk.balanceDrawdownPct, s.risk.equityDrawdownPct, s.risk.maxHistoricalDrawdownPct));
      DrawRow("rk2", g.colRightX + 10, y, "Daily / Weekly:", StringFormat("%+.2f (%.0f%%) / %+.2f", s.risk.dailyPnL, s.risk.dailyLossUsedPct, s.risk.weeklyPnL)); y += g.rowStep;
      DrawRow("rk3", g.colLeftX + 10, y, "Portfolio Risk:", StringFormat("%.2f (%.2f%%)", s.risk.currentOpenRiskMoney, s.risk.currentOpenRiskPct));
      DrawRow("rk4", g.colRightX + 10, y, "Top Ccy Exp:", StringFormat("%s (%.2f lots)", s.risk.topExposedCurrency, s.risk.maxCurrencyExposureLots)); y += g.rowStep;
      DrawRow("rk5", g.colLeftX + 10, y, "Open Lots / Pos:", StringFormat("%.2f lots (%d pos)", s.risk.totalOpenExposureLots, s.risk.openPositionsCount));
      DrawRow("rk6", g.colRightX + 10, y, "Consec Loss:", StringFormat("%d / Max %d", s.risk.consecutiveLosses, s.risk.maxConsecutiveLosses)); y += g.rowStep;
      DrawRow("rk7", g.colLeftX + 10, y, "Margin Lvl / Util:", StringFormat("%.0f%% / %.1f%%", s.risk.marginLevelPct, s.risk.marginUtilizationPct));
      DrawRow("rk8", g.colRightX + 10, y, "Risk Status:", CDashboardStatistics::Truncate(s.risk.statusLabel, 24), s.risk.lockoutActive ? ASEA_CLR_RED : ASEA_CLR_GREEN);

      int botY = g.contentY + topH + 10;
      int botH = MathMax(90, g.contentH - topH - 10);
      CDashboardPrimitives::DrawPanel(m_chartId, "BODY_PR2", g.contentX, botY, g.contentW, botH, ASEA_CLR_BG_PANEL, ASEA_CLR_BORDER, 10);
      CDashboardPrimitives::DrawLabel(m_chartId, "BODY_PH", g.contentX + 10, botY + 8,
                                      "EA-Owned Open Positions (MFE/MAE Tracked)", ASEA_CLR_ACCENT, 9, "Segoe UI");
      int py = botY + 30;
      if(posCount <= 0)
      {
         CDashboardPrimitives::DrawLabel(m_chartId, "BODY_PEMPTY", g.contentX + 10, py, "No open positions managed by this EA.", ASEA_CLR_TEXT_MUTED, 8, "Consolas");
      }
      else
      {
         int limit = MathMin(posCount, 6);
         for(int i = 0; i < limit; i++)
         {
            string line = StringFormat("#%I64u %s %s %.2f PnL:%+.2f MFE:%+.2f MAE:%+.2f (%s)",
                                       pos[i].ticket, pos[i].symbol, DirectionToString(pos[i].direction),
                                       pos[i].volume, pos[i].floatingPnL, pos[i].mfeMoney, pos[i].maeMoney,
                                       CDashboardStatistics::FormatDuration(pos[i].holdingSeconds));
            CDashboardPrimitives::DrawLabel(m_chartId, "BODY_POS_" + IntegerToString(i), g.contentX + 10, py,
                                            line, pos[i].floatingPnL >= 0 ? ASEA_CLR_GREEN : ASEA_CLR_RED, 8, "Consolas");
            py += 18;
         }
      }
   }

   void RenderChartsPage(const SDashboardGeometry &g, const SDashboardSnapshot &s,
                         const double &eq[], const double &bal[], const double &dd[],
                         const double &scoreNet[], const int &scoreTrades[],
                         const double &regNet[], const int &regTrades[])
   {
      string modes[5] = {"Equity/Bal", "Drawdown %", "Strategies", "Score Bands", "Regimes"};
      int btnW = (g.contentW - 20) / 5;
      for(int i = 0; i < 5; i++)
         CDashboardPrimitives::DrawNavTab(m_chartId, "BODY_CMODE_" + IntegerToString(i),
                                          g.contentX + i * (btnW + 5), g.contentY, btnW, 22, modes[i], (m_chartMode == i));

      m_charts.Render(m_chartId, g.contentX, g.contentY + 28, g.contentW, g.contentH - 28,
                      m_chartMode, eq, bal, dd, s.strategyStats, scoreNet, scoreTrades, regNet, regTrades);
   }

   void RenderIntelligencePage(const SDashboardGeometry &g, const SDashboardSnapshot &s)
   {
      CDashboardPrimitives::DrawPanel(m_chartId, "BODY_PI", g.contentX, g.contentY, g.contentW, g.contentH, ASEA_CLR_BG_PANEL, ASEA_CLR_BORDER, 10);
      CDashboardPrimitives::DrawLabel(m_chartId, "BODY_IH", g.contentX + 10, g.contentY + 8, "5-Stage Controlled Learning & Decision Audit", ASEA_CLR_ACCENT, 9, "Segoe UI");

      int maxChars = MathMax(18, (g.colW - 165) / 7);
      int fullChars = MathMax(45, (g.contentW - 40) / 7);
      int y = g.contentY + 30;
      DrawRow("in1", g.colLeftX + 10, y, "Stage 1 Raw Obs:", CDashboardStatistics::Truncate(s.intelligence.stage1RawObs, maxChars));
      DrawRow("in2", g.colRightX + 10, y, "Det. Warnings:", IntegerToString(s.intelligence.deteriorationWarnings), s.intelligence.deteriorationWarnings > 0 ? ASEA_CLR_AMBER : ASEA_CLR_GREEN); y += g.rowStep;
      DrawRow("in3", g.colLeftX + 10, y, "Stage 2 Findings:", CDashboardStatistics::Truncate(s.intelligence.stage2HistoricalFinding, fullChars)); y += g.rowStep;
      DrawRow("in4", g.colLeftX + 10, y, "Stage 3 Recommend:", CDashboardStatistics::Truncate(s.intelligence.stage3Recommendation, fullChars)); y += g.rowStep;
      DrawRow("in5", g.colLeftX + 10, y, "Stage 4 Validated:", CDashboardStatistics::Truncate(s.intelligence.stage4ValidatedConfig, maxChars));
      DrawRow("in6", g.colRightX + 10, y, "Stage 5 Active:", CDashboardStatistics::Truncate(s.intelligence.stage5ActiveConfig, maxChars)); y += g.rowStep;
      DrawRow("in7", g.colLeftX + 10, y, "Sharpe / Sortino:", s.account.sharpeValid ? StringFormat("%.2f / %.2f", s.account.sharpeRatio, s.account.sortinoRatio) : StringFormat("Need %d+ trades (n=%d)", EA_MIN_SHARPE_TRADES, s.account.totalTrades));
      DrawRow("in8", g.colRightX + 10, y, "Learning Mode:", CDashboardStatistics::Truncate(s.intelligence.learningStatus, maxChars)); y += g.rowStep + 6;

      CDashboardPrimitives::DrawLabel(m_chartId, "BODY_EXP_H", g.contentX + 10, y, "Latest Decision Audit:", ASEA_CLR_ACCENT, 8, "Segoe UI"); y += 18;
      CDashboardPrimitives::DrawLabel(m_chartId, "BODY_EXP_1", g.contentX + 10, y,
                                      "Rationale: " + CDashboardStatistics::Truncate(s.lastSignal.rationale, fullChars + 10), ASEA_CLR_TEXT_PRIMARY, 8, "Consolas"); y += 17;
      CDashboardPrimitives::DrawLabel(m_chartId, "BODY_EXP_2", g.contentX + 10, y,
                                      "Expectancy: " + CDashboardStatistics::Truncate(s.lastSignal.expectancy.summary, fullChars + 10), ASEA_CLR_TEXT_MUTED, 8, "Consolas"); y += 17;
      CDashboardPrimitives::DrawLabel(m_chartId, "BODY_EXP_3", g.contentX + 10, y,
                                      "Validation: " + CDashboardStatistics::Truncate(s.lastValidation.rejectionReason, fullChars + 10), s.lastValidation.passed ? ASEA_CLR_GREEN : ASEA_CLR_AMBER, 8, "Consolas");
   }

public:
   CDashboardManager()
   {
      m_enabled = true;
      m_compactMode = false;
      m_chartId = 0;
      m_activePage = PAGE_OVERVIEW;
      m_chartMode = 0;
   }

   ~CDashboardManager()
   {
      Deinit();
   }

   void Initialize(const bool enabled, const bool compactMode)
   {
      m_enabled = enabled;
      m_compactMode = compactMode;
      m_chartId = ChartID();
      CDashboardPrimitives::CleanupAll(m_chartId);
      m_charts.Destroy();
   }

   void Deinit()
   {
      m_charts.Destroy();
      CDashboardPrimitives::CleanupAll(m_chartId);
      ChartRedraw(m_chartId);
   }

   void OnChartEvent(const int id, const string &sparam)
   {
      if(!m_enabled || id != CHARTEVENT_OBJECT_CLICK) return;
      if(StringFind(sparam, ASEA_UI_PREFIX) != 0) return;

      for(int i = 0; i < 6; i++)
      {
         if(sparam == ASEA_UI_PREFIX + "TAB_" + IntegerToString(i))
         {
            m_activePage = (ENUM_DASHBOARD_PAGE)i;
            ObjectSetInteger(m_chartId, sparam, OBJPROP_STATE, false);
            return;
         }
      }
      for(int c = 0; c < 5; c++)
      {
         if(sparam == ASEA_UI_PREFIX + "BODY_CMODE_" + IntegerToString(c))
         {
            m_chartMode = c;
            ObjectSetInteger(m_chartId, sparam, OBJPROP_STATE, false);
            return;
         }
      }
   }

   void Render(const SDashboardSnapshot &snap, const SManagedPosition &positions[], const int posCount,
               const double &eq[], const double &bal[], const double &dd[],
               const double &scoreNet[], const int &scoreTrades[],
               const double &regNet[], const int &regTrades[])
   {
      if(!m_enabled) return;
      if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE))
         return;

      SDashboardGeometry g;
      CDashboardLayout::Compute(m_chartId, m_compactMode, g);

      RenderHeaderAndTabs(g, snap);
      ClearContentObjects();
      if(m_activePage != PAGE_CHARTS)
         m_charts.Destroy();

      switch(m_activePage)
      {
         case PAGE_OVERVIEW:       RenderOverviewPage(g, snap); break;
         case PAGE_MARKET:         RenderMarketPage(g, snap); break;
         case PAGE_STRATEGIES:     RenderStrategiesPage(g, snap); break;
         case PAGE_POSITIONS_RISK: RenderPositionsRiskPage(g, snap, positions, posCount); break;
         case PAGE_CHARTS:         RenderChartsPage(g, snap, eq, bal, dd, scoreNet, scoreTrades, regNet, regTrades); break;
         case PAGE_INTELLIGENCE:   RenderIntelligencePage(g, snap); break;
      }

      ChartRedraw(m_chartId);
   }
};

#endif // __ASEA_DASHBOARD_MANAGER_MQH__
