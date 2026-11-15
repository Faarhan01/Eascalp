//+------------------------------------------------------------------+
//|                                          DashboardComponents.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        Native MQL5 Dark Terminal UI Primitives   |
//+------------------------------------------------------------------+
#ifndef __ASEA_DASHBOARD_COMPONENTS_MQH__
#define __ASEA_DASHBOARD_COMPONENTS_MQH__

#define ASEA_UI_PREFIX "ASEA_RO_"

// Dark Quantitative Terminal Palette
#define ASEA_CLR_BG_MAIN      C'11,17,32'
#define ASEA_CLR_BG_PANEL     C'17,24,39'
#define ASEA_CLR_BG_HEADER    C'15,23,42'
#define ASEA_CLR_BORDER       C'38,50,68'
#define ASEA_CLR_TEXT_PRIMARY C'226,232,240'
#define ASEA_CLR_TEXT_MUTED   C'148,163,184'
#define ASEA_CLR_ACCENT       C'56,189,248'
#define ASEA_CLR_TAB_ACTIVE   C'30,58,95'
#define ASEA_CLR_TAB_IDLE     C'20,29,47'
#define ASEA_CLR_GREEN        C'22,163,74'
#define ASEA_CLR_AMBER        C'217,119,6'
#define ASEA_CLR_RED          C'220,38,38'

class CDashboardPrimitives
{
public:
   static void CleanupAll(const long chartId = 0)
   {
      ObjectsDeleteAll(chartId, ASEA_UI_PREFIX);
   }

   static void DrawPanel(const long chartId, const string name, const int x, const int y,
                         const int w, const int h, const color bgClr, const color borderClr,
                         const int zOrder = 10)
   {
      string objName = ASEA_UI_PREFIX + name;
      if(ObjectFind(chartId, objName) < 0)
         ObjectCreate(chartId, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);

      ObjectSetInteger(chartId, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(chartId, objName, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(chartId, objName, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(chartId, objName, OBJPROP_XSIZE, w);
      ObjectSetInteger(chartId, objName, OBJPROP_YSIZE, h);
      ObjectSetInteger(chartId, objName, OBJPROP_BGCOLOR, bgClr);
      ObjectSetInteger(chartId, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(chartId, objName, OBJPROP_COLOR, borderClr);
      ObjectSetInteger(chartId, objName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(chartId, objName, OBJPROP_BACK, false);
      ObjectSetInteger(chartId, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(chartId, objName, OBJPROP_HIDDEN, true);
      ObjectSetInteger(chartId, objName, OBJPROP_ZORDER, zOrder);
   }

   static void DrawLabel(const long chartId, const string name, const int x, const int y,
                         const string text, const color clr, const int fontSize = 9,
                         const string fontName = "Consolas", const int zOrder = 20)
   {
      string objName = ASEA_UI_PREFIX + name;
      if(ObjectFind(chartId, objName) < 0)
         ObjectCreate(chartId, objName, OBJ_LABEL, 0, 0, 0);

      ObjectSetInteger(chartId, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(chartId, objName, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(chartId, objName, OBJPROP_YDISTANCE, y);
      ObjectSetString(chartId,  objName, OBJPROP_TEXT, text);
      ObjectSetString(chartId,  objName, OBJPROP_FONT, fontName);
      ObjectSetInteger(chartId, objName, OBJPROP_FONTSIZE, fontSize);
      ObjectSetInteger(chartId, objName, OBJPROP_COLOR, clr);
      ObjectSetInteger(chartId, objName, OBJPROP_BACK, false);
      ObjectSetInteger(chartId, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(chartId, objName, OBJPROP_HIDDEN, true);
      ObjectSetInteger(chartId, objName, OBJPROP_ZORDER, zOrder);
   }

   // Strictly for passive read-only page navigation & chart view filtering
   static void DrawNavTab(const long chartId, const string name, const int x, const int y,
                          const int w, const int h, const string label, const bool active,
                          const int zOrder = 25)
   {
      string objName = ASEA_UI_PREFIX + name;
      if(ObjectFind(chartId, objName) < 0)
         ObjectCreate(chartId, objName, OBJ_BUTTON, 0, 0, 0);

      ObjectSetInteger(chartId, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(chartId, objName, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(chartId, objName, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(chartId, objName, OBJPROP_XSIZE, w);
      ObjectSetInteger(chartId, objName, OBJPROP_YSIZE, h);
      ObjectSetString(chartId,  objName, OBJPROP_TEXT, label);
      ObjectSetString(chartId,  objName, OBJPROP_FONT, "Segoe UI");
      ObjectSetInteger(chartId, objName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(chartId, objName, OBJPROP_BGCOLOR, active ? ASEA_CLR_TAB_ACTIVE : ASEA_CLR_TAB_IDLE);
      ObjectSetInteger(chartId, objName, OBJPROP_COLOR, active ? ASEA_CLR_ACCENT : ASEA_CLR_TEXT_MUTED);
      ObjectSetInteger(chartId, objName, OBJPROP_BORDER_COLOR, active ? ASEA_CLR_ACCENT : ASEA_CLR_BORDER);
      ObjectSetInteger(chartId, objName, OBJPROP_STATE, false);
      ObjectSetInteger(chartId, objName, OBJPROP_BACK, false);
      ObjectSetInteger(chartId, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(chartId, objName, OBJPROP_HIDDEN, true);
      ObjectSetInteger(chartId, objName, OBJPROP_ZORDER, zOrder);
   }
};

#endif // __ASEA_DASHBOARD_COMPONENTS_MQH__
