//+------------------------------------------------------------------+
//|                                                  Diagnostics.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.9.0 Structured Logging & Diagnostics   |
//+------------------------------------------------------------------+
#ifndef __ASEA_CORE_DIAGNOSTICS_MQH__
#define __ASEA_CORE_DIAGNOSTICS_MQH__

#include "Types.mqh"

class CDiagnostics
{
private:
   ENUM_LOG_SEVERITY m_minLevel;
   bool              m_logToFile;
   bool              m_printToJournal;
   string            m_logFilePath;
   int               m_errorCount;
   int               m_warningCount;
   datetime          m_lastLogTimeByKey[];
   string            m_throttleKeys[];
   int               m_throttleCursor;

   string SeverityToStr(const ENUM_LOG_SEVERITY level) const
   {
      switch(level)
      {
         case LOG_DEBUG:    return "DEBUG";
         case LOG_INFO:     return "INFO";
         case LOG_WARN:     return "WARN";
         case LOG_ERROR:    return "ERROR";
         case LOG_CRITICAL: return "CRITICAL";
      }
      return "INFO";
   }

   bool ShouldThrottle(const string key, const int cooldownSeconds)
   {
      if(cooldownSeconds <= 0 || key == "")
         return false;
      datetime now = SafeCurrentTime();
      int count = ArraySize(m_throttleKeys);
      for(int i = 0; i < count; i++)
      {
         if(m_throttleKeys[i] == key)
         {
            if((now - m_lastLogTimeByKey[i]) < cooldownSeconds)
               return true;
            m_lastLogTimeByKey[i] = now;
            return false;
         }
      }
      if(count < 128)
      {
         ArrayResize(m_throttleKeys, count + 1);
         ArrayResize(m_lastLogTimeByKey, count + 1);
         m_throttleKeys[count] = key;
         m_lastLogTimeByKey[count] = now;
      }
      else
      {
         int slot = m_throttleCursor % 128;
         m_throttleKeys[slot] = key;
         m_lastLogTimeByKey[slot] = now;
         m_throttleCursor = (m_throttleCursor + 1) % 128;
      }
      return false;
   }

public:
   CDiagnostics()
   {
      m_minLevel = LOG_INFO;
      m_logToFile = true;
      m_printToJournal = true;
      m_logFilePath = "";
      m_errorCount = 0;
      m_warningCount = 0;
      m_throttleCursor = 0;
   }

   bool Initialize(const string symbol, const long magic, const ENUM_LOG_SEVERITY minLevel, const bool logToFile, const bool printToJournal)
   {
      m_minLevel = minLevel;
      m_logToFile = logToFile;
      m_printToJournal = printToJournal;
      m_errorCount = 0;
      m_warningCount = 0;
      m_throttleCursor = 0;
      ArrayResize(m_throttleKeys, 0);
      ArrayResize(m_lastLogTimeByKey, 0);
      m_logFilePath = "";

      if(!MQLInfoInteger(MQL_TESTER))
      {
         string folder = StringFormat("%s\\Logs", EA_DATA_ROOT);
         FolderCreate(EA_DATA_ROOT);
         FolderCreate(folder);

         datetime tsRef = SafeCurrentTime();
         MqlDateTime dt;
         TimeToStruct(tsRef, dt);
         m_logFilePath = StringFormat("%s\\asea_%s_%I64d_%04d%02d%02d.log",
                                      folder, symbol, magic, dt.year, dt.mon, dt.day);
      }
      Log(LOG_INFO, "Diagnostics", "Diagnostic logger initialized.");
      return true;
   }

   void Log(const ENUM_LOG_SEVERITY level, const string module, const string message, const string throttleKey = "", const int cooldownSec = 0)
   {
      if(level < m_minLevel)
         return;
      if(ShouldThrottle(throttleKey, cooldownSec))
         return;

      if(level == LOG_WARN)
         m_warningCount++;
      else if(level >= LOG_ERROR)
         m_errorCount++;

      string ts = TimeToString(SafeCurrentTime(), TIME_DATE | TIME_SECONDS);
      string line = StringFormat("[%s] [%s] [%s] %s", ts, SeverityToStr(level), module, message);

      if(m_printToJournal)
         Print(line);

      if(m_logToFile && m_logFilePath != "" && !MQLInfoInteger(MQL_TESTER))
      {
         int handle = FileOpen(m_logFilePath, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
         if(handle != INVALID_HANDLE)
         {
            FileSeek(handle, 0, SEEK_END);
            FileWriteString(handle, line + "\r\n");
            FileClose(handle);
         }
      }
   }

   bool IsLevelEnabled(const ENUM_LOG_SEVERITY level) const { return (level >= m_minLevel); }
   int  GetErrorCount() const   { return m_errorCount; }
   int  GetWarningCount() const { return m_warningCount; }
};

#endif // __ASEA_CORE_DIAGNOSTICS_MQH__
