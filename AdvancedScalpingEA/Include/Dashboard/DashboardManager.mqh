//+------------------------------------------------------------------+
//|                                             DashboardManager.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        Strictly Read-Only Presentation Terminal  |
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
   int                 m_chartMode; // 0=Equity/Balance, 1=Drawdown, 2=Strategy Comparison
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

      string title = StringFormat("%s v%s  |  %s %s  |  Mode: %s  [READ-ONLY]",
                                  snap.eaName, snap.eaVersion, snap.symbol,
                                  EnumToString(snap.timeframe), OperatingModeToString(snap.operatingMode));
      CDashboardPrimitives::DrawLabel(m_chartId, "HDR_TITLE", g.originX + 12, g.originY + 8, title, ASEA_CLR_TEXT_PRIMARY, 9, "Segoe UI");

      string sub = StringFormat("Conn: %s  |  Regime: %s  |  Status: %s",
                                snap.terminalConnected ? "Connected" : "Offline",
                                snap.regime.label, snap.operationalStatus);
      color subClr = snap.risk.lockoutActive ? ASEA_CLR_RED : (snap.terminalConnected ? ASEA_CLR_ACCENT : ASEA_CLR_AMBER);
      CDashboardPrimitives::DrawLabel(m_chartId, "HDR_SUB", g.originX + 12, g.originY + 25, sub, subClr, 8, "Consolas");

      // 6 Passive Navigation Tabs (Strictly presentation switching)
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

      CDashboardPrimitives::DrawLabel(m_chartId, "BODY_H1", g.colLeftX + 10, g.contentY + 8, "System & Symbol Specification", ASEA_CLR_ACCENT, 9, "Segoe UI");
      int y = g.contentY + 30;
      DrawRow("ov1", g.colLeftX + 10, y, "Asset Class:", AssetClassToString(s.symbolProfile.assetClass)); y += g.rowStep;
      DrawRow("ov2", g.colLeftX + 10, y, "Digits / Point:", StringFormat("%d / %.5f", s.symbolProfile.digits, s.symbolProfile.point)); y += g.rowStep;
      DrawRow("ov3", g.colLeftX + 10, y, "Lot Min/Max/Step:", StringFormat("%.2f / %.1f / %.2f", s.symbolProfile.volumeMin, s.symbolProfile.volumeMax, s.symbolProfile.volumeStep)); y += g.rowStep;
      DrawRow("ov4", g.colLeftX + 10, y, "Tick Size / Val:", StringFormat("%.5f / %.2f", s.symbolProfile.tickSize, s.symbolProfile.tickValue)); y += g.rowStep;
      DrawRow("ov5", g.colLeftX + 10, y, "Stops / Freeze:", StringFormat("%d / %d pts", s.symbolProfile.stopsLevelPoints, s.symbolProfile.freezeLevelPoints)); y += g.rowStep;
      DrawRow("ov6", g.colLeftX + 10, y, "Data / Bars:", StringFormat("%s (%d bars)", s.market.dataReady ? "Ready" : "Waiting", s.symbolProfile.availableBarsPrimary), s.market.dataReady ? ASEA_CLR_GREEN : ASEA_CLR_AMBER); y += g.rowStep;
      DrawRow("ov7", g.colLeftX + 10, y, "Active Strategy:", CDashboardStatistics::Truncate(s.activeStrategyName, 24)); y += g.rowStep;
      DrawRow("ov8", g.colLeftX + 10, y, "Market Regime:", s.regime.label); y += g.rowStep;
      DrawRow("ov9", g.colLeftX + 10, y, "Last Analysis:", TimeToString(s.lastAnalysisTime, TIME_SECONDS));

      CDashboardPrimitives::DrawLabel(m_chartId, "BODY_H2", g.colRightX + 10, g.contentY + 8, "Live Performance Summary", ASEA_CLR_ACCENT, 9, "Segoe UI");
      y = g.contentY + 30;
      DrawRow("pf1", g.colRightX + 10, y, "Balance:", CDashboardStatistics::FormatPlainMoney(s.account.balance)); y += g.rowStep;
      DrawRow("pf2", g.colRightX + 10, y, "Equity:", CDashboardStatistics::FormatPlainMoney(s.account.equity)); y += g.rowStep;
      DrawRow("pf3", g.colRightX + 10, y, "EA Floating PnL:", CDashboardStatistics::FormatMoney(s.account.floatingPnL), s.account.floatingPnL >= 0 ? ASEA_CLR_GREEN : ASEA_CLR_RED); y += g.rowStep;
      DrawRow("pf4", g.colRightX + 10, y, "Realized Daily:", CDashboardStatistics::FormatMoney(s.account.realizedDailyPnL), s.account.realizedDailyPnL >= 0 ? ASEA_CLR_GREEN : ASEA_CLR_RED); y += g.rowStep;
      DrawRow("pf5", g.colRightX + 10, y, "Realized Weekly:", CDashboardStatistics::FormatMoney(s.account.realizedWeeklyPnL)); y += g.rowStep;
      DrawRow("pf6", g.colRightX + 10, y, "Total Net Profit:", CDashboardStatistics::FormatMoney(s.account.totalNetProfit), s.account.totalNetProfit >= 0 ? ASEA_CLR_GREEN : ASEA_CLR_RED); y += g.rowStep;
      DrawRow("pf7", g.colRightX + 10, y, "Trades (W / L):", StringFormat("%d (%d / %d)", s.account.totalTrades, s.account.winningTrades, s.account.losingTrades)); y += g.rowStep;
      DrawRow("pf8", g.colRightX + 10, y, "Win Rate / PF:", StringFormat("%.1f%% / %.2f", s.account.winRatePct, s.account.profitFactor)); y += g.rowStep;
      DrawRow("pf9", g.colRightX + 10, y, "Avg Win / Loss:", StringFormat("%.2f / -%.2f", s.account.avgWin, s.account.avgLoss));
   }

   void RenderMarketPage(const SDashboardGeometry &g, const SDashboardSnapshot &s)
   {
      CDashboardPrimitives::DrawPanel(m_chartId, "BODY_P1", g.colLeftX,  g.contentY, g.colW, g.contentH, ASEA_CLR_BG_PANEL, ASEA_CLR_BORDER, 10);
      CDashboardPrimitives::DrawPanel(m_chartId, "BODY_P2", g.colRightX, g.contentY, g.colW, g.contentH, ASEA_CLR_BG_PANEL, ASEA_CLR_BORDER, 10);

      CDashboardPrimitives::DrawLabel(m_chartId, "BODY_H1", g.colLeftX + 10, g.contentY + 8, "Live Market & Structure", ASEA_CLR_ACCENT, 9, "Segoe UI");
      int y = g.contentY + 30;
      int d = s.symbolProfile.digits;
      DrawRow("mk1", g.colLeftX + 10, y, "Bid / Ask:", StringFormat("%.*f / %.*f", d, s.market.bid, d, s.market.ask)); y += g.rowStep;
      DrawRow("mk2", g.colLeftX + 10, y, "Spread (Cur/Avg):", StringFormat("%.1f / %.1f pts (%.2fx)", s.market.spreadPoints, s.market.avgSpreadPoints, s.market.spreadRatio)); y += g.rowStep;
      DrawRow("mk3", g.colLeftX + 10, y, "ATR / Vol Ratio:", StringFormat("%.*f / %.2fx", d, s.indicators.atr, s.regime.volatilityRatio)); y += g.rowStep;
      DrawRow("mk4", g.colLeftX + 10, y, "RSI / ADX:", StringFormat("%.1f / %.1f", s.indicators.rsi, s.indicators.adxMain)); y += g.rowStep;
      DrawRow("mk5", g.colLeftX + 10, y, "Tick Velocity:", StringFormat("%.2f pts/s (Bias %.2f)", s.ticks.priceVelocity, s.ticks.microTrendBias)); y += g.rowStep;
      DrawRow("mk6", g.colLeftX + 10, y, "Structure:", CDashboardStatistics::Truncate(s.structure.summary, 24)); y += g.rowStep;
      DrawRow("mk7", g.colLeftX + 10, y, "Sup / Res:", StringFormat("%.*f / %.*f", d, s.structure.nearestSupport, d, s.structure.nearestResistance)); y += g.rowStep;
      DrawRow("mk8", g.colLeftX + 10, y, "Candle Pattern:", CDashboardStatistics::Truncate(s.candle.name, 24)); y += g.rowStep;
      DrawRow("mk9", g.colLeftX + 10, y, "Chart Pattern:", CDashboardStatistics::Truncate(s.chartPattern.name, 24)); y += g.rowStep;
      DrawRow("mk10",g.colLeftX + 10, y, "MTF Agreement:", StringFormat("%.0f%% (%s)", s.mtf.agreementScore, s.mtf.hasStrongConflict ? "Conflict" : "Aligned"), s.mtf.hasStrongConflict ? ASEA_CLR_AMBER : ASEA_CLR_GREEN);

      CDashboardPrimitives::DrawLabel(m_chartId, "BODY_H2", g.colRightX + 10, g.contentY + 8, "Latest Signal Evaluation", ASEA_CLR_ACCENT, 9, "Segoe UI");
      y = g.contentY + 30;
      DrawRow("sg1", g.colRightX + 10, y, "Strategy:", s.lastSignal.isValid ? s.lastSignal.strategyName : "None"); y += g.rowStep;
      DrawRow("sg2", g.colRightX + 10, y, "Direction:", DirectionToString(s.lastSignal.direction)); y += g.rowStep;
      DrawRow("sg3", g.colRightX + 10, y, "Signal Score:", StringFormat("%.1f / 100 (%s)", s.lastSignal.compositeScore, StrengthBandToString(s.lastSignal.breakdown.band))); y += g.rowStep;
      DrawRow("sg4", g.colRightX + 10, y, "Validation:", s.lastValidation.rejectionCode, s.lastValidation.passed ? ASEA_CLR_GREEN : ASEA_CLR_AMBER); y += g.rowStep;
      DrawRow("sg5", g.colRightX + 10, y, "Dir/Struct/MTF:", StringFormat("%.0f/%.0f/%.0f", s.lastSignal.breakdown.directionScore, s.lastSignal.breakdown.structureScore, s.lastSignal.breakdown.mtfAgreementScore)); y += g.rowStep;
      DrawRow("sg6", g.colRightX + 10, y, "Mom/Vol/Tick:", StringFormat("%.0f/%.0f/%.0f", s.lastSignal.breakdown.momentumScore, s.lastSignal.breakdown.volatilityScore, s.lastSignal.breakdown.tickBehaviorScore)); y += g.rowStep;
      DrawRow("sg7", g.colRightX + 10, y, "Reason:", CDashboardStatistics::Truncate(s.lastValidation.rejectionReason, 26)); y += g.rowStep;
      DrawRow("sg8", g.colRightX + 10, y, "Indicators:", CDashboardStatistics::Truncate(s.lastSignal.supportingIndicators, 26));
   }

   void RenderStrategiesPage(const SDashboardGeometry &g, const SDashboardSnapshot &s)
   {
      CDashboardPrimitives::DrawPanel(m_chartId, "BODY_PFULL", g.contentX, g.contentY, g.contentW, g.contentH, ASEA_CLR_BG_PANEL, ASEA_CLR_BORDER, 10);
      CDashboardPrimitives::DrawLabel(m_chartId, "BODY_SHDR", g.contentX + 10, g.contentY + 10,
                                      "Strategy              Status     Trades  WinRate   NetPnL      PF     EV     Sample", ASEA_CLR_ACCENT, 8, "Consolas");
      int y = g.contentY + 34;
      for(int i = 0; i < EA_MAX_STRATEGIES; i++)
      {
         SStrategyStats st = s.strategyStats[i];
         string status = !st.enabledByInput ? "Disabled" : (st.deteriorationWarning ? "Deterior." : (st.recommendedBySelector ? "Active/Rec" : "Active"));
         string sample = st.hasSufficientSample ? "Sufficient" : "Low(<N)";
         string row = StringFormat("%-20s  %-9s  %5d   %5.1f%%   %+8.2f  %5.2f  %+6.2f  %s",
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
      int topH = 155;
      CDashboardPrimitives::DrawPanel(m_chartId, "BODY_PR1", g.contentX, g.contentY, g.contentW, topH, ASEA_CLR_BG_PANEL, ASEA_CLR_BORDER, 10);
      CDashboardPrimitives::DrawLabel(m_chartId, "BODY_RH", g.contentX + 10, g.contentY + 8, "Risk Analytics & Exposure Controls", ASEA_CLR_ACCENT, 9, "Segoe UI");

      int y = g.contentY + 30;
      DrawRow("rk1", g.colLeftX + 10, y, "Bal / Eq DD:", StringFormat("%.2f%% / %.2f%% (Max %.2f%%)", s.risk.balanceDrawdownPct, s.risk.equityDrawdownPct, s.risk.maxHistoricalDrawdownPct));
      DrawRow("rk2", g.colRightX + 10, y, "Daily Loss Used:", StringFormat("%.1f%% (%+.2f)", s.risk.dailyLossUsedPct, s.risk.dailyPnL)); y += g.rowStep;
      DrawRow("rk3", g.colLeftX + 10, y, "Open Risk:", StringFormat("%.2f (%.2f%%)", s.risk.currentOpenRiskMoney, s.risk.currentOpenRiskPct));
      DrawRow("rk4", g.colRightX + 10, y, "Weekly Loss Used:", StringFormat("%.1f%% (%+.2f)", s.risk.weeklyLossUsedPct, s.risk.weeklyPnL)); y += g.rowStep;
      DrawRow("rk5", g.colLeftX + 10, y, "Open Lots / Pos:", StringFormat("%.2f lots (%d pos)", s.risk.totalOpenExposureLots, s.risk.openPositionsCount));
      DrawRow("rk6", g.colRightX + 10, y, "Consec Loss (Cur/Max):", StringFormat("%d / %d", s.risk.consecutiveLosses, s.risk.maxConsecutiveLosses)); y += g.rowStep;
      DrawRow("rk7", g.colLeftX + 10, y, "Margin Level:", StringFormat("%.1f%%", s.risk.marginLevelPct));
      DrawRow("rk8", g.colRightX + 10, y, "Risk Status:", CDashboardStatistics::Truncate(s.risk.statusLabel, 24), s.risk.lockoutActive ? ASEA_CLR_RED : ASEA_CLR_GREEN);

      int botY = g.contentY + topH + 10;
      int botH = MathMax(90, g.contentH - topH - 10);
      CDashboardPrimitives::DrawPanel(m_chartId, "BODY_PR2", g.contentX, botY, g.contentW, botH, ASEA_CLR_BG_PANEL, ASEA_CLR_BORDER, 10);
      CDashboardPrimitives::DrawLabel(m_chartId, "BODY_PH", g.contentX + 10, botY + 8,
                                      "EA-Owned Open Positions (Magic Isolated)", ASEA_CLR_ACCENT, 9, "Segoe UI");
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
            string line = StringFormat("#%I64u %s %s %.2f @%.5f SL:%.5f TP:%.5f PnL:%+.2f (%s)",
                                       pos[i].ticket, pos[i].symbol, DirectionToString(pos[i].direction),
                                       pos[i].volume, pos[i].openPrice, pos[i].currentSL, pos[i].takeProfit,
                                       pos[i].floatingPnL, CDashboardStatistics::FormatDuration(pos[i].holdingSeconds));
            CDashboardPrimitives::DrawLabel(m_chartId, "BODY_POS_" + IntegerToString(i), g.contentX + 10, py,
                                            line, pos[i].floatingPnL >= 0 ? ASEA_CLR_GREEN : ASEA_CLR_RED, 8, "Consolas");
            py += 18;
         }
      }
   }

   void RenderChartsPage(const SDashboardGeometry &g, const SDashboardSnapshot &s,
                         const double &eq[], const double &bal[], const double &dd[])
   {
      // Passive chart filter buttons (do not alter trading behavior)
      string modes[3] = {"Equity / Balance", "Drawdown %", "Strategy Comparison"};
      for(int i = 0; i < 3; i++)
         CDashboardPrimitives::DrawNavTab(m_chartId, "BODY_CMODE_" + IntegerToString(i),
                                          g.contentX + i * 145, g.contentY, 140, 22, modes[i], (m_chartMode == i));

      m_charts.Render(m_chartId, g.contentX, g.contentY + 28, g.contentW, g.contentH - 28,
                      m_chartMode, eq, bal, dd, s.strategyStats);
   }

   void RenderIntelligencePage(const SDashboardGeometry &g, const SDashboardSnapshot &s)
   {
      CDashboardPrimitives::DrawPanel(m_chartId, "BODY_PI", g.contentX, g.contentY, g.contentW, g.contentH, ASEA_CLR_BG_PANEL, ASEA_CLR_BORDER, 10);
      CDashboardPrimitives::DrawLabel(m_chartId, "BODY_IH", g.contentX + 10, g.contentY + 8, "Market Intelligence & Decision Audit", ASEA_CLR_ACCENT, 9, "Segoe UI");

      int y = g.contentY + 32;
      DrawRow("in1", g.colLeftX + 10, y, "Observations:", IntegerToString(s.intelligence.observationsCollected));
      DrawRow("in2", g.colRightX + 10, y, "Patterns Detected:", IntegerToString(s.intelligence.patternsDetected)); y += g.rowStep;
      DrawRow("in3", g.colLeftX + 10, y, "Regimes Analyzed:", IntegerToString(s.intelligence.regimesAnalyzed));
      DrawRow("in4", g.colRightX + 10, y, "Signals Gen/Acc/Rej:", StringFormat("%I64d / %I64d / %I64d", s.intelligence.signalsGenerated, s.intelligence.signalsAccepted, s.intelligence.signalsRejected)); y += g.rowStep;
      DrawRow("in5", g.colLeftX + 10, y, "Det. Warnings:", IntegerToString(s.intelligence.deteriorationWarnings), s.intelligence.deteriorationWarnings > 0 ? ASEA_CLR_AMBER : ASEA_CLR_GREEN);
      DrawRow("in6", g.colRightX + 10, y, "Learning Status:", CDashboardStatistics::Truncate(s.intelligence.learningStatus, 26)); y += g.rowStep;
      DrawRow("in7", g.colLeftX + 10, y, "Last Validated Cfg:", CDashboardStatistics::Truncate(s.intelligence.lastValidatedConfig, 24));
      DrawRow("in8", g.colRightX + 10, y, "Sharpe / Sortino:", s.account.sharpeValid ? StringFormat("%.2f / %.2f", s.account.sharpeRatio, s.account.sortinoRatio) : "N/A (<10 trades)"); y += g.rowStep + 8;

      CDashboardPrimitives::DrawLabel(m_chartId, "BODY_EXP_H", g.contentX + 10, y, "Recorded Decision Explanation (Latest Evaluated Opportunity):", ASEA_CLR_ACCENT, 8, "Segoe UI"); y += 20;
      CDashboardPrimitives::DrawLabel(m_chartId, "BODY_EXP_1", g.contentX + 10, y,
                                      "Rationale: " + CDashboardStatistics::Truncate(s.lastSignal.rationale, 85), ASEA_CLR_TEXT_PRIMARY, 8, "Consolas"); y += 18;
      CDashboardPrimitives::DrawLabel(m_chartId, "BODY_EXP_2", g.contentX + 10, y,
                                      "Structure/Patterns: " + CDashboardStatistics::Truncate(s.lastSignal.supportingStructure + " | " + s.lastSignal.patternConfirmations, 80), ASEA_CLR_TEXT_MUTED, 8, "Consolas"); y += 18;
      CDashboardPrimitives::DrawLabel(m_chartId, "BODY_EXP_3", g.contentX + 10, y,
                                      "Validation Outcome: " + CDashboardStatistics::Truncate(s.lastValidation.rejectionReason, 80), s.lastValidation.passed ? ASEA_CLR_GREEN : ASEA_CLR_AMBER, 8, "Consolas");
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

   // Handles ONLY passive presentation clicks (tabs & chart view mode). Never touches trading state.
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
      for(int c = 0; c < 3; c++)
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
               const double &eq[], const double &bal[], const double &dd[])
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
         case PAGE_CHARTS:         RenderChartsPage(g, snap, eq, bal, dd); break;
         case PAGE_INTELLIGENCE:   RenderIntelligencePage(g, snap); break;
      }

      ChartRedraw(m_chartId);
   }
};

#endif // __ASEA_DASHBOARD_MANAGER_MQH__
