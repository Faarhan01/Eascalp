//+------------------------------------------------------------------+
//|                                                 StateManager.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.0.0 Crash/Restart State Persistence    |
//+------------------------------------------------------------------+
#ifndef __ASEA_CORE_STATEMANAGER_MQH__
#define __ASEA_CORE_STATEMANAGER_MQH__

#include "Types.mqh"
#include "Diagnostics.mqh"

struct SPersistedState
{
   int      schemaVersion;
   long     magicNumber;
   string   symbol;
   datetime lastSaveTime;
   datetime dayAnchor;
   datetime weekAnchor;
   double   dayStartBalance;
   double   weekStartBalance;
   double   peakBalance;
   double   peakEquity;
   double   maxDrawdownPct;
   int      consecutiveLosses;
   int      maxConsecutiveLosses;
   bool     lockoutActive;
   string   lockoutReason;
   datetime lastBarProcessed;
   long     observationsCount;
   long     patternsCount;
   long     regimesCount;
   long     signalsGenerated;
   long     signalsAccepted;
   long     signalsRejected;
   string   lastValidatedConfig;
   string   activeConfigVersion;
   datetime lastValidationTime;

   void Reset()
   {
      schemaVersion = 2;
      magicNumber = 0;
      symbol = "";
      lastSaveTime = 0;
      dayAnchor = 0;
      weekAnchor = 0;
      dayStartBalance = 0.0;
      weekStartBalance = 0.0;
      peakBalance = 0.0;
      peakEquity = 0.0;
      maxDrawdownPct = 0.0;
      consecutiveLosses = 0;
      maxConsecutiveLosses = 0;
      lockoutActive = false;
      lockoutReason = "";
      lastBarProcessed = 0;
      observationsCount = 0;
      patternsCount = 0;
      regimesCount = 0;
      signalsGenerated = 0;
      signalsAccepted = 0;
      signalsRejected = 0;
      lastValidatedConfig = "ReadyToTrade_v2.2.0";
      activeConfigVersion = "ReadyToTrade_v2.2.0";
      lastValidationTime = 0;
   }
};

class CStateManager
{
private:
   string        m_stateFilePath;
   CDiagnostics *m_diag;
   datetime      m_lastFlushTime;

   string SanitizeValue(const string val) const
   {
      string s = val;
      StringReplace(s, "\r", " ");
      StringReplace(s, "\n", " ");
      StringReplace(s, "=", ":");
      return s;
   }

public:
   CStateManager()
   {
      m_stateFilePath = "";
      m_diag = NULL;
      m_lastFlushTime = 0;
   }

   bool Initialize(const string symbol, const long magic, CDiagnostics *diag)
   {
      m_diag = diag;
      if(MQLInfoInteger(MQL_TESTER))
      {
         m_stateFilePath = "";
         return true;
      }
      FolderCreate(EA_DATA_ROOT);
      string stateDir = StringFormat("%s\\State", EA_DATA_ROOT);
      FolderCreate(stateDir);
      m_stateFilePath = StringFormat("%s\\state_%s_%I64d.ini", stateDir, symbol, magic);
      return true;
   }

   bool SaveState(const SPersistedState &state, const bool force = false)
   {
      if(MQLInfoInteger(MQL_TESTER))
         return true;

      datetime now = TimeCurrent();
      if(!force && (now - m_lastFlushTime) < 15)
         return true;

      if(m_stateFilePath == "")
         return false;

      int handle = FileOpen(m_stateFilePath, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
      if(handle == INVALID_HANDLE)
      {
         if(m_diag != NULL)
            m_diag.Log(LOG_ERROR, "StateManager", StringFormat("Failed to open state file: %s (err=%d)", m_stateFilePath, GetLastError()), "state_write_err", 60);
         return false;
      }

      FileWriteString(handle, StringFormat("schemaVersion=%d\r\n", state.schemaVersion));
      FileWriteString(handle, StringFormat("magicNumber=%I64d\r\n", state.magicNumber));
      FileWriteString(handle, StringFormat("symbol=%s\r\n", SanitizeValue(state.symbol)));
      FileWriteString(handle, StringFormat("lastSaveTime=%I64d\r\n", (long)now));
      FileWriteString(handle, StringFormat("dayAnchor=%I64d\r\n", (long)state.dayAnchor));
      FileWriteString(handle, StringFormat("weekAnchor=%I64d\r\n", (long)state.weekAnchor));
      FileWriteString(handle, StringFormat("dayStartBalance=%.8f\r\n", state.dayStartBalance));
      FileWriteString(handle, StringFormat("weekStartBalance=%.8f\r\n", state.weekStartBalance));
      FileWriteString(handle, StringFormat("peakBalance=%.8f\r\n", state.peakBalance));
      FileWriteString(handle, StringFormat("peakEquity=%.8f\r\n", state.peakEquity));
      FileWriteString(handle, StringFormat("maxDrawdownPct=%.6f\r\n", state.maxDrawdownPct));
      FileWriteString(handle, StringFormat("consecutiveLosses=%d\r\n", state.consecutiveLosses));
      FileWriteString(handle, StringFormat("maxConsecutiveLosses=%d\r\n", state.maxConsecutiveLosses));
      FileWriteString(handle, StringFormat("lockoutActive=%d\r\n", state.lockoutActive ? 1 : 0));
      FileWriteString(handle, StringFormat("lockoutReason=%s\r\n", SanitizeValue(state.lockoutReason)));
      FileWriteString(handle, StringFormat("lastBarProcessed=%I64d\r\n", (long)state.lastBarProcessed));
      FileWriteString(handle, StringFormat("observationsCount=%I64d\r\n", state.observationsCount));
      FileWriteString(handle, StringFormat("patternsCount=%I64d\r\n", state.patternsCount));
      FileWriteString(handle, StringFormat("regimesCount=%I64d\r\n", state.regimesCount));
      FileWriteString(handle, StringFormat("signalsGenerated=%I64d\r\n", state.signalsGenerated));
      FileWriteString(handle, StringFormat("signalsAccepted=%I64d\r\n", state.signalsAccepted));
      FileWriteString(handle, StringFormat("signalsRejected=%I64d\r\n", state.signalsRejected));
      FileWriteString(handle, StringFormat("lastValidatedConfig=%s\r\n", SanitizeValue(state.lastValidatedConfig)));
      FileWriteString(handle, StringFormat("activeConfigVersion=%s\r\n", SanitizeValue(state.activeConfigVersion)));
      FileWriteString(handle, StringFormat("lastValidationTime=%I64d\r\n", (long)state.lastValidationTime));

      FileClose(handle);
      m_lastFlushTime = now;
      return true;
   }

   bool LoadState(SPersistedState &state)
   {
      state.Reset();
      if(MQLInfoInteger(MQL_TESTER))
         return false;
      if(m_stateFilePath == "" || !FileIsExist(m_stateFilePath))
         return false;

      int handle = FileOpen(m_stateFilePath, FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
      if(handle == INVALID_HANDLE)
         return false;

      while(!FileIsEnding(handle))
      {
         string line = FileReadString(handle);
         int sep = StringFind(line, "=");
         if(sep <= 0)
            continue;
         string key = StringSubstr(line, 0, sep);
         string val = StringSubstr(line, sep + 1);

         if(key == "schemaVersion")           state.schemaVersion = (int)StringToInteger(val);
         else if(key == "magicNumber")        state.magicNumber = StringToInteger(val);
         else if(key == "symbol")             state.symbol = val;
         else if(key == "lastSaveTime")       state.lastSaveTime = (datetime)StringToInteger(val);
         else if(key == "dayAnchor")          state.dayAnchor = (datetime)StringToInteger(val);
         else if(key == "weekAnchor")         state.weekAnchor = (datetime)StringToInteger(val);
         else if(key == "dayStartBalance")    state.dayStartBalance = StringToDouble(val);
         else if(key == "weekStartBalance")   state.weekStartBalance = StringToDouble(val);
         else if(key == "peakBalance")        state.peakBalance = StringToDouble(val);
         else if(key == "peakEquity")         state.peakEquity = StringToDouble(val);
         else if(key == "maxDrawdownPct")     state.maxDrawdownPct = StringToDouble(val);
         else if(key == "consecutiveLosses")  state.consecutiveLosses = (int)StringToInteger(val);
         else if(key == "maxConsecutiveLosses") state.maxConsecutiveLosses = (int)StringToInteger(val);
         else if(key == "lockoutActive")      state.lockoutActive = (StringToInteger(val) != 0);
         else if(key == "lockoutReason")      state.lockoutReason = val;
         else if(key == "lastBarProcessed")   state.lastBarProcessed = (datetime)StringToInteger(val);
         else if(key == "observationsCount")  state.observationsCount = StringToInteger(val);
         else if(key == "patternsCount")      state.patternsCount = StringToInteger(val);
         else if(key == "regimesCount")       state.regimesCount = StringToInteger(val);
         else if(key == "signalsGenerated")   state.signalsGenerated = StringToInteger(val);
         else if(key == "signalsAccepted")    state.signalsAccepted = StringToInteger(val);
         else if(key == "signalsRejected")    state.signalsRejected = StringToInteger(val);
         else if(key == "lastValidatedConfig") state.lastValidatedConfig = val;
         else if(key == "activeConfigVersion") state.activeConfigVersion = val;
         else if(key == "lastValidationTime") state.lastValidationTime = (datetime)StringToInteger(val);
      }
      FileClose(handle);

      if(m_diag != NULL)
         m_diag.Log(LOG_INFO, "StateManager", StringFormat("Restored v2 state from %s (PeakEq=%.2f, ConsecLoss=%d)", m_stateFilePath, state.peakEquity, state.consecutiveLosses));
      return true;
   }
};

#endif // __ASEA_CORE_STATEMANAGER_MQH__
