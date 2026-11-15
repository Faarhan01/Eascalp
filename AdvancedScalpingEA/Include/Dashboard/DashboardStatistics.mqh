//+------------------------------------------------------------------+
//|                                          DashboardStatistics.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        Read-Only Metric Formatting Helpers       |
//+------------------------------------------------------------------+
#ifndef __ASEA_DASHBOARD_STATISTICS_MQH__
#define __ASEA_DASHBOARD_STATISTICS_MQH__

#include "../Core/Types.mqh"

class CDashboardStatistics
{
public:
   static string FormatMoney(const double val, const string ccy = "")
   {
      string sign = (val > 0.0) ? "+" : "";
      if(ccy != "")
         return StringFormat("%s%.2f %s", sign, val, ccy);
      return StringFormat("%s%.2f", sign, val);
   }

   static string FormatPlainMoney(const double val)
   {
      return StringFormat("%.2f", val);
   }

   static string FormatPct(const double pct)
   {
      return StringFormat("%.2f%%", pct);
   }

   static string FormatDuration(const long seconds)
   {
      if(seconds < 60) return StringFormat("%I64ds", seconds);
      if(seconds < 3600) return StringFormat("%I64dm %I64ds", seconds / 60, seconds % 60);
      return StringFormat("%I64dh %I64dm", seconds / 3600, (seconds % 3600) / 60);
   }

   static string Truncate(const string s, const int maxLen)
   {
      if(StringLen(s) <= maxLen) return s;
      return StringSubstr(s, 0, MathMax(1, maxLen - 3)) + "...";
   }
};

#endif // __ASEA_DASHBOARD_STATISTICS_MQH__
