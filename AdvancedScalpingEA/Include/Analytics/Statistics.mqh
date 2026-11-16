//+------------------------------------------------------------------+
//|                                                   Statistics.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.0.0 Quantitative & Segmented Helpers   |
//+------------------------------------------------------------------+
#ifndef __ASEA_ANALYTICS_STATISTICS_MQH__
#define __ASEA_ANALYTICS_STATISTICS_MQH__

#include "../Core/Types.mqh"

struct SSegmentedBucket
{
   string key;
   int    trades;
   int    wins;
   double grossProfit;
   double grossLoss;
   double netProfit;
   double mfeSum;
   double maeSum;

   void Reset()
   {
      key = "";
      trades = 0;
      wins = 0;
      grossProfit = 0.0;
      grossLoss = 0.0;
      netProfit = 0.0;
      mfeSum = 0.0;
      maeSum = 0.0;
   }
};

class CStatisticsUtil
{
public:
   static bool ComputeSharpeAndSortino(const double &returns[], const int count, double &outSharpe, double &outSortino)
   {
      outSharpe = 0.0;
      outSortino = 0.0;
      if(count < 10) return false;

      double sum = 0.0;
      for(int i = 0; i < count; i++) sum += returns[i];
      double mean = sum / (double)count;

      double varSum = 0.0;
      double downVarSum = 0.0;
      int downCount = 0;

      for(int i = 0; i < count; i++)
      {
         double diff = returns[i] - mean;
         varSum += diff * diff;
         if(returns[i] < 0.0)
         {
            downVarSum += returns[i] * returns[i];
            downCount++;
         }
      }

      double stdDev = MathSqrt(varSum / (double)(count - 1));
      if(stdDev > 1e-12)
         outSharpe = (mean / stdDev) * MathSqrt((double)count);

      if(downCount >= 2)
      {
         double downDev = MathSqrt(downVarSum / (double)downCount);
         if(downDev > 1e-12)
            outSortino = (mean / downDev) * MathSqrt((double)count);
      }
      return (stdDev > 1e-12);
   }

   static ENUM_TRADING_SESSION ClassifySession(const datetime t, const bool is24x7)
   {
      if(is24x7) return SESSION_CONTINUOUS;
      MqlDateTime dt;
      TimeToStruct(t, dt);
      int h = dt.hour;
      if(h >= 13 && h < 17) return SESSION_OVERLAP_LDN_NY;
      if(h >= 8  && h < 13) return SESSION_LONDON;
      if(h >= 17 && h < 22) return SESSION_NEWYORK;
      if(h >= 0  && h < 8)  return SESSION_ASIAN;
      return SESSION_OFF_HOURS;
   }

   static void UpdateBucket(SSegmentedBucket &buckets[], int &bucketCount, const string key,
                            const double netPnL, const double mfe = 0.0, const double mae = 0.0)
   {
      for(int i = 0; i < bucketCount; i++)
      {
         if(buckets[i].key == key)
         {
            buckets[i].trades++;
            if(netPnL >= 0.0) { buckets[i].wins++; buckets[i].grossProfit += netPnL; }
            else              { buckets[i].grossLoss += MathAbs(netPnL); }
            buckets[i].netProfit += netPnL;
            buckets[i].mfeSum    += mfe;
            buckets[i].maeSum    += mae;
            return;
         }
      }
      if(bucketCount < 64)
      {
         ArrayResize(buckets, bucketCount + 1);
         buckets[bucketCount].Reset();
         buckets[bucketCount].key = key;
         buckets[bucketCount].trades = 1;
         if(netPnL >= 0.0) { buckets[bucketCount].wins = 1; buckets[bucketCount].grossProfit = netPnL; }
         else              { buckets[bucketCount].grossLoss = MathAbs(netPnL); }
         buckets[bucketCount].netProfit = netPnL;
         buckets[bucketCount].mfeSum    = mfe;
         buckets[bucketCount].maeSum    = mae;
         bucketCount++;
      }
   }
};

#endif // __ASEA_ANALYTICS_STATISTICS_MQH__
