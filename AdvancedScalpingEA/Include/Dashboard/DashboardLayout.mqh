//+------------------------------------------------------------------+
//|                                              DashboardLayout.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        Responsive Chart Geometry Calculator      |
//+------------------------------------------------------------------+
#ifndef __ASEA_DASHBOARD_LAYOUT_MQH__
#define __ASEA_DASHBOARD_LAYOUT_MQH__

struct SDashboardGeometry
{
   int originX;
   int originY;
   int width;
   int height;
   int headerH;
   int tabBarH;
   int contentX;
   int contentY;
   int contentW;
   int contentH;
   int colLeftX;
   int colRightX;
   int colW;
   int rowStep;
};

class CDashboardLayout
{
public:
   static void Compute(const long chartId, const bool compactMode, SDashboardGeometry &g)
   {
      int chartW = (int)ChartGetInteger(chartId, CHART_WIDTH_IN_PIXELS);
      int chartH = (int)ChartGetInteger(chartId, CHART_HEIGHT_IN_PIXELS);

      g.originX = 12;
      g.originY = 22;
      int maxW = compactMode ? 680 : 880;
      int maxH = compactMode ? 430 : 540;

      g.width  = MathMax(520, MathMin(maxW, chartW - 24));
      g.height = MathMax(360, MathMin(maxH, chartH - 40));

      g.headerH = 44;
      g.tabBarH = 28;
      g.contentX = g.originX + 12;
      g.contentY = g.originY + g.headerH + g.tabBarH + 12;
      g.contentW = g.width - 24;
      g.contentH = g.height - g.headerH - g.tabBarH - 24;

      int gap = 12;
      g.colW = (g.contentW - gap) / 2;
      g.colLeftX  = g.contentX;
      g.colRightX = g.contentX + g.colW + gap;
      g.rowStep   = 18;
   }
};

#endif // __ASEA_DASHBOARD_LAYOUT_MQH__
