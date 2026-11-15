//+------------------------------------------------------------------+
//|                                              DashboardCharts.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        Native CCanvas Equity, DD & Strat Charts  |
//+------------------------------------------------------------------+
#ifndef __ASEA_DASHBOARD_CHARTS_MQH__
#define __ASEA_DASHBOARD_CHARTS_MQH__

#include <Canvas\Canvas.mqh>
#include "../Core/Types.mqh"
#include "DashboardComponents.mqh"

class CDashboardCharts
{
private:
   CCanvas m_canvas;
   bool    m_created;
   string  m_objName;

public:
   CDashboardCharts()
   {
      m_created = false;
      m_objName = ASEA_UI_PREFIX + "CHART_CANVAS";
   }

   ~CDashboardCharts()
   {
      Destroy();
   }

   void Destroy()
   {
      if(m_created)
      {
         m_canvas.Destroy();
         ObjectDelete(0, m_objName);
         m_created = false;
      }
   }

   void Render(const long chartId, const int x, const int y, const int w, const int h,
               const int chartMode, const double &eq[], const double &bal[], const double &dd[],
               const SStrategyStats &stratStats[])
   {
      if(w < 120 || h < 80) return;

      if(!m_created || ObjectFind(chartId, m_objName) < 0)
      {
         m_created = m_canvas.CreateBitmapLabel(chartId, 0, m_objName, x, y, w, h, COLOR_FORMAT_ARGB_NORMALIZE);
         if(!m_created) return;
      }
      else if(m_canvas.Width() != w || m_canvas.Height() != h)
      {
         m_canvas.Resize(w, h);
      }

      ObjectSetInteger(chartId, m_objName, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(chartId, m_objName, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(chartId, m_objName, OBJPROP_ZORDER, 22);

      m_canvas.Erase(ColorToARGB(ASEA_CLR_BG_PANEL, 255));
      m_canvas.Rectangle(0, 0, w - 1, h - 1, ColorToARGB(ASEA_CLR_BORDER, 255));

      int padL = 56, padR = 16, padT = 28, padB = 26;
      int plotW = MathMax(20, w - padL - padR);
      int plotH = MathMax(20, h - padT - padB);

      // Grid lines
      uint gridClr = ColorToARGB(C'28,39,58', 255);
      for(int g = 0; g <= 4; g++)
      {
         int gy = padT + (plotH * g) / 4;
         m_canvas.Line(padL, gy, padL + plotW, gy, gridClr);
      }

      m_canvas.FontSet("Consolas", -11);

      if(chartMode == 0) // Equity & Balance Curve
      {
         m_canvas.TextOut(12, 8, "Equity (Sky) & Balance (Slate) Curve - Live Session", ColorToARGB(ASEA_CLR_TEXT_PRIMARY, 255));
         int n = ArraySize(eq);
         if(n < 2)
         {
            m_canvas.TextOut(padL + 10, padT + plotH / 2 - 8, "Collecting live session equity samples...", ColorToARGB(ASEA_CLR_TEXT_MUTED, 255));
            m_canvas.Update(false);
            return;
         }

         double minV = eq[0], maxV = eq[0];
         for(int i = 0; i < n; i++)
         {
            minV = MathMin(minV, MathMin(eq[i], bal[i]));
            maxV = MathMax(maxV, MathMax(eq[i], bal[i]));
         }
         double span = MathMax(1.0, maxV - minV);
         minV -= span * 0.05;
         maxV += span * 0.05;
         span = maxV - minV;

         m_canvas.TextOut(6, padT - 4, DoubleToString(maxV, 2), ColorToARGB(ASEA_CLR_TEXT_MUTED, 255));
         m_canvas.TextOut(6, padT + plotH - 10, DoubleToString(minV, 2), ColorToARGB(ASEA_CLR_TEXT_MUTED, 255));

         for(int i = 1; i < n; i++)
         {
            int x1 = padL + ((i - 1) * plotW) / (n - 1);
            int x2 = padL + (i * plotW) / (n - 1);
            int bY1 = padT + plotH - (int)(((bal[i - 1] - minV) / span) * plotH);
            int bY2 = padT + plotH - (int)(((bal[i]     - minV) / span) * plotH);
            int eY1 = padT + plotH - (int)(((eq[i - 1]  - minV) / span) * plotH);
            int eY2 = padT + plotH - (int)(((eq[i]      - minV) / span) * plotH);

            m_canvas.Line(x1, bY1, x2, bY2, ColorToARGB(C'148,163,184', 255));
            m_canvas.Line(x1, eY1, x2, eY2, ColorToARGB(ASEA_CLR_ACCENT, 255));
         }
      }
      else if(chartMode == 1) // Drawdown Curve
      {
         m_canvas.TextOut(12, 8, "Drawdown History (%) - Live Session", ColorToARGB(ASEA_CLR_TEXT_PRIMARY, 255));
         int n = ArraySize(dd);
         if(n < 2)
         {
            m_canvas.TextOut(padL + 10, padT + plotH / 2 - 8, "Collecting drawdown samples...", ColorToARGB(ASEA_CLR_TEXT_MUTED, 255));
            m_canvas.Update(false);
            return;
         }

         double maxDD = 1.0;
         for(int i = 0; i < n; i++) maxDD = MathMax(maxDD, dd[i]);
         maxDD *= 1.15;

         m_canvas.TextOut(6, padT - 4, DoubleToString(maxDD, 2) + "%", ColorToARGB(ASEA_CLR_TEXT_MUTED, 255));
         m_canvas.TextOut(6, padT + plotH - 10, "0.00%", ColorToARGB(ASEA_CLR_TEXT_MUTED, 255));

         for(int i = 1; i < n; i++)
         {
            int x1 = padL + ((i - 1) * plotW) / (n - 1);
            int x2 = padL + (i * plotW) / (n - 1);
            int y1 = padT + plotH - (int)((dd[i - 1] / maxDD) * plotH);
            int y2 = padT + plotH - (int)((dd[i]     / maxDD) * plotH);
            m_canvas.Line(x1, y1, x2, y2, ColorToARGB(ASEA_CLR_RED, 255));
         }
      }
      else // Strategy Net Profit Bar Comparison
      {
         m_canvas.TextOut(12, 8, "Strategy Net Profit Comparison (Actual EA Trades)", ColorToARGB(ASEA_CLR_TEXT_PRIMARY, 255));
         double maxAbs = 10.0;
         for(int i = 0; i < EA_MAX_STRATEGIES; i++)
            maxAbs = MathMax(maxAbs, MathAbs(stratStats[i].netProfit));

         int zeroY = padT + plotH / 2;
         m_canvas.Line(padL, zeroY, padL + plotW, zeroY, ColorToARGB(ASEA_CLR_TEXT_MUTED, 255));
         m_canvas.TextOut(6, padT - 4, "+" + DoubleToString(maxAbs, 0), ColorToARGB(ASEA_CLR_TEXT_MUTED, 255));
         m_canvas.TextOut(6, padT + plotH - 10, "-" + DoubleToString(maxAbs, 0), ColorToARGB(ASEA_CLR_TEXT_MUTED, 255));

         int slotW = plotW / EA_MAX_STRATEGIES;
         int barW = MathMax(14, slotW - 18);
         string shortNames[7] = {"Pullbk", "Moment", "Break", "Revers", "Range", "VolExp", "Micro"};

         for(int i = 0; i < EA_MAX_STRATEGIES; i++)
         {
            int bx = padL + i * slotW + 9;
            double np = stratStats[i].netProfit;
            int barH = (int)((MathAbs(np) / maxAbs) * (plotH / 2 - 6));
            if(barH < 2 && stratStats[i].totalTrades > 0) barH = 2;

            uint clr = (np >= 0.0) ? ColorToARGB(ASEA_CLR_GREEN, 255) : ColorToARGB(ASEA_CLR_RED, 255);
            if(np >= 0.0)
               m_canvas.FillRectangle(bx, zeroY - barH, bx + barW, zeroY, clr);
            else
               m_canvas.FillRectangle(bx, zeroY, bx + barW, zeroY + barH, clr);

            m_canvas.TextOut(bx, padT + plotH + 6, shortNames[i], ColorToARGB(ASEA_CLR_TEXT_MUTED, 255));
         }
      }

      m_canvas.Update(false);
   }
};

#endif // __ASEA_DASHBOARD_CHARTS_MQH__
