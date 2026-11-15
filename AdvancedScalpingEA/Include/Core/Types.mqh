//+------------------------------------------------------------------+
//|                                                        Types.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        Shared Enumerations & Data Structures     |
//+------------------------------------------------------------------+
#ifndef __ASEA_CORE_TYPES_MQH__
#define __ASEA_CORE_TYPES_MQH__

#define EA_PROJECT_NAME    "AdvancedScalpingEA"
#define EA_PROJECT_VERSION "1.0.0"
#define EA_DATA_ROOT       "AdvancedScalpingEA"
#define EA_MAX_STRATEGIES  7
#define EA_MAX_TF_SLOTS    14

enum ENUM_EA_OPERATING_MODE
{
   EA_MODE_RESEARCH_ONLY   = 0, // Research & Signal Observation Only (No Orders)
   EA_MODE_DEMO_PAPER      = 1, // Demo Virtual Paper Tracking (No Broker Orders)
   EA_MODE_DEMO_EXECUTION  = 2, // Demo Account Order Execution
   EA_MODE_LIVE_TRADING    = 3  // Live Trading (Requires Explicit Opt-In Flags)
};

enum ENUM_ASSET_CLASS
{
   ASSET_UNKNOWN      = 0,
   ASSET_FOREX_MAJOR  = 1,
   ASSET_FOREX_MINOR  = 2,
   ASSET_FOREX_EXOTIC = 3,
   ASSET_METAL        = 4,
   ASSET_INDEX        = 5,
   ASSET_ENERGY       = 6,
   ASSET_CFD          = 7,
   ASSET_SYNTHETIC    = 8,
   ASSET_CRYPTO       = 9
};

enum ENUM_SIGNAL_DIRECTION
{
   SIGNAL_NONE = 0,
   SIGNAL_BUY  = 1,
   SIGNAL_SELL = -1
};

enum ENUM_SIGNAL_STRENGTH_BAND
{
   STRENGTH_NEUTRAL     = 0,
   STRENGTH_WEAK_BULL   = 1,
   STRENGTH_MOD_BULL    = 2,
   STRENGTH_STRONG_BULL = 3,
   STRENGTH_WEAK_BEAR   = 4,
   STRENGTH_MOD_BEAR    = 5,
   STRENGTH_STRONG_BEAR = 6
};

enum ENUM_MARKET_REGIME
{
   REGIME_UNKNOWN           = 0,
   REGIME_STRONG_BULL_TREND = 1,
   REGIME_WEAK_BULL_TREND   = 2,
   REGIME_STRONG_BEAR_TREND = 3,
   REGIME_WEAK_BEAR_TREND   = 4,
   REGIME_SIDEWAYS          = 5,
   REGIME_CONSOLIDATION     = 6,
   REGIME_HIGH_VOLATILITY   = 7,
   REGIME_LOW_VOLATILITY    = 8,
   REGIME_VOL_EXPANSION     = 9,
   REGIME_VOL_CONTRACTION   = 10,
   REGIME_UNSTABLE          = 11
};

enum ENUM_VOLATILITY_STATE
{
   VOL_LOW     = 0,
   VOL_NORMAL  = 1,
   VOL_HIGH    = 2,
   VOL_EXTREME = 3
};

enum ENUM_STRUCTURE_EVENT
{
   STRUCT_NONE           = 0,
   STRUCT_BOS_BULL       = 1,
   STRUCT_BOS_BEAR       = 2,
   STRUCT_CHOCH_BULL     = 3,
   STRUCT_CHOCH_BEAR     = 4,
   STRUCT_LIQ_SWEEP_HIGH = 5,
   STRUCT_LIQ_SWEEP_LOW  = 6,
   STRUCT_BREAKOUT_UP    = 7,
   STRUCT_BREAKOUT_DOWN  = 8,
   STRUCT_REJECTION_HIGH = 9,
   STRUCT_REJECTION_LOW  = 10
};

enum ENUM_CANDLE_PATTERN
{
   CANDLE_NONE           = 0,
   CANDLE_BULL_ENGULFING = 1,
   CANDLE_BEAR_ENGULFING = 2,
   CANDLE_HAMMER         = 3,
   CANDLE_SHOOTING_STAR  = 4,
   CANDLE_BULL_PINBAR    = 5,
   CANDLE_BEAR_PINBAR    = 6,
   CANDLE_DOJI           = 7,
   CANDLE_INSIDE_BAR     = 8,
   CANDLE_OUTSIDE_BAR    = 9,
   CANDLE_MORNING_STAR   = 10,
   CANDLE_EVENING_STAR   = 11
};

enum ENUM_CHART_PATTERN
{
   PATTERN_NONE               = 0,
   PATTERN_DOUBLE_TOP         = 1,
   PATTERN_DOUBLE_BOTTOM      = 2,
   PATTERN_HEAD_SHOULDERS     = 3,
   PATTERN_INV_HEAD_SHOULDERS = 4,
   PATTERN_ASC_TRIANGLE       = 5,
   PATTERN_DESC_TRIANGLE      = 6,
   PATTERN_SYM_TRIANGLE       = 7,
   PATTERN_RISING_WEDGE       = 8,
   PATTERN_FALLING_WEDGE      = 9,
   PATTERN_BULL_FLAG          = 10,
   PATTERN_BEAR_FLAG          = 11,
   PATTERN_PENNANT            = 12,
   PATTERN_RECTANGLE          = 13,
   PATTERN_UP_CHANNEL         = 14,
   PATTERN_DOWN_CHANNEL       = 15
};

enum ENUM_STRATEGY_ID
{
   STRAT_TREND_PULLBACK       = 0,
   STRAT_MOMENTUM_SCALPING    = 1,
   STRAT_BREAKOUT_SCALPING    = 2,
   STRAT_REVERSAL_SCALPING    = 3,
   STRAT_RANGE_SCALPING       = 4,
   STRAT_VOLATILITY_EXPANSION = 5,
   STRAT_MICRO_MOMENTUM       = 6
};

enum ENUM_LOG_SEVERITY
{
   LOG_DEBUG    = 0,
   LOG_INFO     = 1,
   LOG_WARN     = 2,
   LOG_ERROR    = 3,
   LOG_CRITICAL = 4
};

enum ENUM_TRADING_SESSION
{
   SESSION_OFF_HOURS      = 0,
   SESSION_ASIAN          = 1,
   SESSION_LONDON         = 2,
   SESSION_NEWYORK        = 3,
   SESSION_OVERLAP_LDN_NY = 4,
   SESSION_CONTINUOUS     = 5
};

enum ENUM_DASHBOARD_PAGE
{
   PAGE_OVERVIEW       = 0,
   PAGE_MARKET         = 1,
   PAGE_STRATEGIES     = 2,
   PAGE_POSITIONS_RISK = 3,
   PAGE_CHARTS         = 4,
   PAGE_INTELLIGENCE   = 5
};

struct SSymbolProfile
{
   string                symbol;
   string                baseSymbol;
   string                prefix;
   string                suffix;
   string                currencyBase;
   string                currencyProfit;
   string                currencyMargin;
   ENUM_ASSET_CLASS      assetClass;
   int                   digits;
   double                point;
   double                tickSize;
   double                tickValue;
   double                tickValueProfit;
   double                tickValueLoss;
   double                contractSize;
   double                volumeMin;
   double                volumeMax;
   double                volumeStep;
   int                   volumeDigits;
   int                   stopsLevelPoints;
   int                   freezeLevelPoints;
   int                   spreadPoints;
   ENUM_SYMBOL_TRADE_MODE tradeMode;
   ENUM_SYMBOL_TRADE_EXECUTION execMode;
   int                   fillingFlags;
   ENUM_ORDER_TYPE_FILLING preferredFilling;
   double                swapLong;
   double                swapShort;
   int                   swapMode;
   double                marginInitial;
   double                marginMaintenance;
   bool                  sessionOpenNow;
   bool                  isSynthetic24x7;
   bool                  hasRealVolume;
   int                   availableBarsPrimary;
   datetime              lastInspected;
   bool                  isValid;

   void Reset()
   {
      symbol = "";
      baseSymbol = "";
      prefix = "";
      suffix = "";
      currencyBase = "";
      currencyProfit = "";
      currencyMargin = "";
      assetClass = ASSET_UNKNOWN;
      digits = 5;
      point = 0.00001;
      tickSize = 0.00001;
      tickValue = 1.0;
      tickValueProfit = 1.0;
      tickValueLoss = 1.0;
      contractSize = 100000.0;
      volumeMin = 0.01;
      volumeMax = 100.0;
      volumeStep = 0.01;
      volumeDigits = 2;
      stopsLevelPoints = 0;
      freezeLevelPoints = 0;
      spreadPoints = 0;
      tradeMode = SYMBOL_TRADE_MODE_FULL;
      execMode = SYMBOL_TRADE_EXECUTION_MARKET;
      fillingFlags = 0;
      preferredFilling = ORDER_FILLING_IOC;
      swapLong = 0.0;
      swapShort = 0.0;
      swapMode = 0;
      marginInitial = 0.0;
      marginMaintenance = 0.0;
      sessionOpenNow = false;
      isSynthetic24x7 = false;
      hasRealVolume = false;
      availableBarsPrimary = 0;
      lastInspected = 0;
      isValid = false;
   }
};

struct SMarketSnapshot
{
   string   symbol;
   ENUM_TIMEFRAMES timeframe;
   datetime tickTime;
   datetime barTime;
   double   bid;
   double   ask;
   double   lastPrice;
   double   midPrice;
   double   spreadPoints;
   double   avgSpreadPoints;
   double   spreadRatio;
   double   open;
   double   high;
   double   low;
   double   close;
   long     tickVolume;
   long     realVolume;
   double   barRange;
   double   priceChange;
   double   priceChangePct;
   bool     dataReady;

   void Reset()
   {
      symbol = "";
      timeframe = PERIOD_CURRENT;
      tickTime = 0;
      barTime = 0;
      bid = 0.0;
      ask = 0.0;
      lastPrice = 0.0;
      midPrice = 0.0;
      spreadPoints = 0.0;
      avgSpreadPoints = 0.0;
      spreadRatio = 1.0;
      open = 0.0;
      high = 0.0;
      low = 0.0;
      close = 0.0;
      tickVolume = 0;
      realVolume = 0;
      barRange = 0.0;
      priceChange = 0.0;
      priceChangePct = 0.0;
      dataReady = false;
   }
};

struct STickMetrics
{
   int      sampleCount;
   int      consecutiveUpTicks;
   int      consecutiveDownTicks;
   double   ticksPerSecond;
   double   priceVelocity;      // points per second
   double   priceAcceleration;  // delta velocity per second
   double   shortTermMomentum;  // net points over window
   double   microTrendBias;     // -1.0 to +1.0
   double   bidAskImbalance;
   double   spreadExpansionRatio;
   double   activityRatio;      // current ticks/sec vs baseline
   bool     suddenMoveDetected;
   bool     spreadSpikeDetected;
   bool     isReady;

   void Reset()
   {
      sampleCount = 0;
      consecutiveUpTicks = 0;
      consecutiveDownTicks = 0;
      ticksPerSecond = 0.0;
      priceVelocity = 0.0;
      priceAcceleration = 0.0;
      shortTermMomentum = 0.0;
      microTrendBias = 0.0;
      bidAskImbalance = 0.0;
      spreadExpansionRatio = 1.0;
      activityRatio = 1.0;
      suddenMoveDetected = false;
      spreadSpikeDetected = false;
      isReady = false;
   }
};

struct SIndicatorValues
{
   double   emaFast;
   double   emaMedium;
   double   emaSlow;
   double   smaTrend;
   double   rsi;
   double   macdMain;
   double   macdSignal;
   double   macdHist;
   double   atr;
   double   atrBaseline;
   double   adxMain;
   double   adxPlusDI;
   double   adxMinusDI;
   double   bbUpper;
   double   bbMiddle;
   double   bbLower;
   double   bbWidthPct;
   double   stochK;
   double   stochD;
   double   cci;
   double   wpr;
   double   psar;
   double   momentum;
   double   roc;
   double   vwap;
   bool     vwapAvailable;
   bool     isReady;

   void Reset()
   {
      emaFast = 0.0; emaMedium = 0.0; emaSlow = 0.0; smaTrend = 0.0;
      rsi = 50.0;
      macdMain = 0.0; macdSignal = 0.0; macdHist = 0.0;
      atr = 0.0; atrBaseline = 0.0;
      adxMain = 0.0; adxPlusDI = 0.0; adxMinusDI = 0.0;
      bbUpper = 0.0; bbMiddle = 0.0; bbLower = 0.0; bbWidthPct = 0.0;
      stochK = 50.0; stochD = 50.0;
      cci = 0.0; wpr = -50.0; psar = 0.0;
      momentum = 100.0; roc = 0.0;
      vwap = 0.0; vwapAvailable = false;
      isReady = false;
   }
};

struct SStructureState
{
   double   lastSwingHigh;
   double   prevSwingHigh;
   double   lastSwingLow;
   double   prevSwingLow;
   datetime lastSwingHighTime;
   datetime lastSwingLowTime;
   double   nearestSupport;
   double   nearestResistance;
   double   rangeHigh;
   double   rangeLow;
   bool     hasHH;
   bool     hasHL;
   bool     hasLH;
   bool     hasLL;
   bool     inConsolidation;
   bool     trendContinuation;
   bool     trendExhaustion;
   int      structureBias; // +1 bull, -1 bear, 0 neutral
   ENUM_STRUCTURE_EVENT lastEvent;
   string   summary;
   bool     isReady;

   void Reset()
   {
      lastSwingHigh = 0.0; prevSwingHigh = 0.0;
      lastSwingLow = 0.0; prevSwingLow = 0.0;
      lastSwingHighTime = 0; lastSwingLowTime = 0;
      nearestSupport = 0.0; nearestResistance = 0.0;
      rangeHigh = 0.0; rangeLow = 0.0;
      hasHH = false; hasHL = false; hasLH = false; hasLL = false;
      inConsolidation = false; trendContinuation = false; trendExhaustion = false;
      structureBias = 0;
      lastEvent = STRUCT_NONE;
      summary = "Uninitialized";
      isReady = false;
   }
};

struct SCandleSignal
{
   ENUM_CANDLE_PATTERN pattern;
   ENUM_SIGNAL_DIRECTION bias;
   double   strength; // 0.0 - 1.0
   bool     contextValidated;
   string   name;
   string   contextNote;

   void Reset()
   {
      pattern = CANDLE_NONE;
      bias = SIGNAL_NONE;
      strength = 0.0;
      contextValidated = false;
      name = "None";
      contextNote = "";
   }
};

struct SChartPatternSignal
{
   ENUM_CHART_PATTERN pattern;
   ENUM_SIGNAL_DIRECTION bias;
   double   confidence; // 0.0 - 1.0
   double   breakoutLevel;
   double   invalidationLevel;
   string   name;
   string   note;

   void Reset()
   {
      pattern = PATTERN_NONE;
      bias = SIGNAL_NONE;
      confidence = 0.0;
      breakoutLevel = 0.0;
      invalidationLevel = 0.0;
      name = "None";
      note = "";
   }
};

struct SRegimeState
{
   ENUM_MARKET_REGIME    regime;
   ENUM_VOLATILITY_STATE volatilityState;
   double                trendStrength;
   double                volatilityRatio;
   double                efficiencyRatio;
   bool                  isTrending;
   bool                  isRanging;
   bool                  isVolatile;
   bool                  isUnstable;
   string                label;

   void Reset()
   {
      regime = REGIME_UNKNOWN;
      volatilityState = VOL_NORMAL;
      trendStrength = 0.0;
      volatilityRatio = 1.0;
      efficiencyRatio = 0.0;
      isTrending = false;
      isRanging = false;
      isVolatile = false;
      isUnstable = false;
      label = "Unknown";
   }
};

struct SMTFAnalysis
{
   ENUM_TIMEFRAMES       higherTF;
   ENUM_TIMEFRAMES       intermediateTF;
   ENUM_TIMEFRAMES       lowerTF;
   ENUM_SIGNAL_DIRECTION higherBias;
   ENUM_SIGNAL_DIRECTION intermediateBias;
   ENUM_SIGNAL_DIRECTION lowerBias;
   double                agreementScore; // 0.0 - 100.0
   bool                  hasStrongConflict;
   bool                  alignedBullish;
   bool                  alignedBearish;
   string                conflictReason;
   bool                  isReady;

   void Reset()
   {
      higherTF = PERIOD_H1;
      intermediateTF = PERIOD_M15;
      lowerTF = PERIOD_M5;
      higherBias = SIGNAL_NONE;
      intermediateBias = SIGNAL_NONE;
      lowerBias = SIGNAL_NONE;
      agreementScore = 0.0;
      hasStrongConflict = false;
      alignedBullish = false;
      alignedBearish = false;
      conflictReason = "";
      isReady = false;
   }
};

struct SScoreBreakdown
{
   double directionScore;      // 0..10
   double structureScore;      // 0..12
   double trendStrengthScore;  // 0..10
   double momentumScore;       // 0..10
   double volatilityScore;     // 0..8
   double candleScore;         // 0..8
   double patternScore;        // 0..8
   double mtfAgreementScore;   // 0..12
   double tickBehaviorScore;   // 0..8
   double spreadScore;         // 0..6
   double strategyPerfScore;   // 0..4
   double regimeSuitScore;     // 0..4
   double totalScore;          // 0..100
   ENUM_SIGNAL_STRENGTH_BAND band;

   void Reset()
   {
      directionScore = 0.0; structureScore = 0.0; trendStrengthScore = 0.0;
      momentumScore = 0.0; volatilityScore = 0.0; candleScore = 0.0;
      patternScore = 0.0; mtfAgreementScore = 0.0; tickBehaviorScore = 0.0;
      spreadScore = 0.0; strategyPerfScore = 0.0; regimeSuitScore = 0.0;
      totalScore = 0.0;
      band = STRENGTH_NEUTRAL;
   }
};

struct STradeSignal
{
   string                signalId;
   datetime              timestamp;
   string                symbol;
   ENUM_TIMEFRAMES       timeframe;
   ENUM_STRATEGY_ID      strategyId;
   string                strategyName;
   ENUM_SIGNAL_DIRECTION direction;
   double                entryPrice;
   double                stopLoss;
   double                takeProfit;
   double                confidenceRaw;
   double                compositeScore;
   SScoreBreakdown       breakdown;
   ENUM_MARKET_REGIME    regime;
   string                rationale;
   string                supportingIndicators;
   string                supportingStructure;
   string                patternConfirmations;
   string                conflictingConditions;
   bool                  isValid;

   void Reset()
   {
      signalId = "";
      timestamp = 0;
      symbol = "";
      timeframe = PERIOD_CURRENT;
      strategyId = STRAT_TREND_PULLBACK;
      strategyName = "";
      direction = SIGNAL_NONE;
      entryPrice = 0.0;
      stopLoss = 0.0;
      takeProfit = 0.0;
      confidenceRaw = 0.0;
      compositeScore = 0.0;
      breakdown.Reset();
      regime = REGIME_UNKNOWN;
      rationale = "";
      supportingIndicators = "";
      supportingStructure = "";
      patternConfirmations = "";
      conflictingConditions = "";
      isValid = false;
   }
};

struct SValidationResult
{
   bool   passed;
   string rejectionCode;
   string rejectionReason;

   void Reset()
   {
      passed = false;
      rejectionCode = "";
      rejectionReason = "";
   }
};

struct SRiskStatus
{
   bool     tradingAllowed;
   bool     lockoutActive;
   string   lockoutReason;
   double   dailyPnL;
   double   dailyLossLimitMoney;
   double   dailyLossUsedPct;
   double   weeklyPnL;
   double   weeklyLossLimitMoney;
   double   weeklyLossUsedPct;
   double   balanceDrawdownPct;
   double   equityDrawdownPct;
   double   maxHistoricalDrawdownPct;
   double   currentOpenRiskMoney;
   double   currentOpenRiskPct;
   double   totalOpenExposureLots;
   int      openPositionsCount;
   int      symbolPositionsCount;
   int      consecutiveLosses;
   int      maxConsecutiveLosses;
   double   marginLevelPct;
   double   freeMargin;
   string   statusLabel;

   void Reset()
   {
      tradingAllowed = false;
      lockoutActive = false;
      lockoutReason = "";
      dailyPnL = 0.0;
      dailyLossLimitMoney = 0.0;
      dailyLossUsedPct = 0.0;
      weeklyPnL = 0.0;
      weeklyLossLimitMoney = 0.0;
      weeklyLossUsedPct = 0.0;
      balanceDrawdownPct = 0.0;
      equityDrawdownPct = 0.0;
      maxHistoricalDrawdownPct = 0.0;
      currentOpenRiskMoney = 0.0;
      currentOpenRiskPct = 0.0;
      totalOpenExposureLots = 0.0;
      openPositionsCount = 0;
      symbolPositionsCount = 0;
      consecutiveLosses = 0;
      maxConsecutiveLosses = 0;
      marginLevelPct = 0.0;
      freeMargin = 0.0;
      statusLabel = "Initializing";
   }
};

struct SExecutionResult
{
   bool     executed;
   bool     isPaperTrade;
   ulong    orderTicket;
   ulong    dealTicket;
   ulong    positionTicket;
   uint     retcode;
   string   retcodeDesc;
   double   requestedPrice;
   double   filledPrice;
   double   requestedVolume;
   double   filledVolume;
   double   slippagePoints;
   datetime executionTime;

   void Reset()
   {
      executed = false;
      isPaperTrade = false;
      orderTicket = 0;
      dealTicket = 0;
      positionTicket = 0;
      retcode = 0;
      retcodeDesc = "";
      requestedPrice = 0.0;
      filledPrice = 0.0;
      requestedVolume = 0.0;
      filledVolume = 0.0;
      slippagePoints = 0.0;
      executionTime = 0;
   }
};

struct SManagedPosition
{
   ulong                 ticket;
   string                symbol;
   ENUM_STRATEGY_ID      strategyId;
   string                strategyName;
   ENUM_SIGNAL_DIRECTION direction;
   double                volume;
   double                openPrice;
   double                currentPrice;
   double                initialSL;
   double                currentSL;
   double                takeProfit;
   double                floatingPnL;
   double                currentRiskMoney;
   datetime              openTime;
   long                  holdingSeconds;
   bool                  breakEvenApplied;
   double                signalScore;
   ENUM_MARKET_REGIME    entryRegime;

   void Reset()
   {
      ticket = 0;
      symbol = "";
      strategyId = STRAT_TREND_PULLBACK;
      strategyName = "";
      direction = SIGNAL_NONE;
      volume = 0.0;
      openPrice = 0.0;
      currentPrice = 0.0;
      initialSL = 0.0;
      currentSL = 0.0;
      takeProfit = 0.0;
      floatingPnL = 0.0;
      currentRiskMoney = 0.0;
      openTime = 0;
      holdingSeconds = 0;
      breakEvenApplied = false;
      signalScore = 0.0;
      entryRegime = REGIME_UNKNOWN;
   }
};

struct SStrategyStats
{
   ENUM_STRATEGY_ID strategyId;
   string           strategyName;
   bool             enabledByInput;
   bool             recommendedBySelector;
   bool             deteriorationWarning;
   int              totalTrades;
   int              winningTrades;
   int              losingTrades;
   double           grossProfit;
   double           grossLoss;
   double           netProfit;
   double           winRatePct;
   double           profitFactor;
   double           expectedValue;
   double           avgHoldingSeconds;
   double           maxDrawdownMoney;
   double           recentWinRatePct;
   double           recentNetProfit;
   int              signalsGenerated;
   int              signalsAccepted;
   int              signalsRejected;
   bool             hasSufficientSample;
   double           regimeNetProfit[12];
   int              regimeTrades[12];
   int              regimeWins[12];

   void Reset()
   {
      strategyId = STRAT_TREND_PULLBACK;
      strategyName = "";
      enabledByInput = false;
      recommendedBySelector = false;
      deteriorationWarning = false;
      totalTrades = 0;
      winningTrades = 0;
      losingTrades = 0;
      grossProfit = 0.0;
      grossLoss = 0.0;
      netProfit = 0.0;
      winRatePct = 0.0;
      profitFactor = 0.0;
      expectedValue = 0.0;
      avgHoldingSeconds = 0.0;
      maxDrawdownMoney = 0.0;
      recentWinRatePct = 0.0;
      recentNetProfit = 0.0;
      signalsGenerated = 0;
      signalsAccepted = 0;
      signalsRejected = 0;
      hasSufficientSample = false;
      for(int i = 0; i < 12; i++)
      {
         regimeNetProfit[i] = 0.0;
         regimeTrades[i] = 0;
         regimeWins[i] = 0;
      }
   }
};

struct SAccountMetrics
{
   double   balance;
   double   equity;
   double   floatingPnL;
   double   realizedDailyPnL;
   double   realizedWeeklyPnL;
   double   realizedMonthlyPnL;
   double   totalNetProfit;
   double   grossProfit;
   double   grossLoss;
   int      totalTrades;
   int      winningTrades;
   int      losingTrades;
   double   winRatePct;
   double   profitFactor;
   double   expectedValue;
   double   avgWin;
   double   avgLoss;
   double   largestWin;
   double   largestLoss;
   double   maxDrawdownMoney;
   double   maxDrawdownPct;
   double   relativeDrawdownPct;
   double   absoluteDrawdownMoney;
   int      currentConsecutiveWins;
   int      currentConsecutiveLosses;
   int      maxConsecutiveWins;
   int      maxConsecutiveLosses;
   double   avgHoldingSeconds;
   double   recoveryFactor;
   double   sharpeRatio;
   double   sortinoRatio;
   bool     sharpeValid;
   bool     sortinoValid;

   void Reset()
   {
      balance = 0.0; equity = 0.0; floatingPnL = 0.0;
      realizedDailyPnL = 0.0; realizedWeeklyPnL = 0.0; realizedMonthlyPnL = 0.0;
      totalNetProfit = 0.0; grossProfit = 0.0; grossLoss = 0.0;
      totalTrades = 0; winningTrades = 0; losingTrades = 0;
      winRatePct = 0.0; profitFactor = 0.0; expectedValue = 0.0;
      avgWin = 0.0; avgLoss = 0.0; largestWin = 0.0; largestLoss = 0.0;
      maxDrawdownMoney = 0.0; maxDrawdownPct = 0.0;
      relativeDrawdownPct = 0.0; absoluteDrawdownMoney = 0.0;
      currentConsecutiveWins = 0; currentConsecutiveLosses = 0;
      maxConsecutiveWins = 0; maxConsecutiveLosses = 0;
      avgHoldingSeconds = 0.0; recoveryFactor = 0.0;
      sharpeRatio = 0.0; sortinoRatio = 0.0;
      sharpeValid = false; sortinoValid = false;
   }
};

struct SIntelligenceSummary
{
   long     observationsCollected;
   long     patternsDetected;
   long     regimesAnalyzed;
   long     signalsGenerated;
   long     signalsAccepted;
   long     signalsRejected;
   int      deteriorationWarnings;
   string   learningStatus;
   string   lastValidatedConfig;
   datetime lastValidationTime;
   string   researchSummary;

   void Reset()
   {
      observationsCollected = 0;
      patternsDetected = 0;
      regimesAnalyzed = 0;
      signalsGenerated = 0;
      signalsAccepted = 0;
      signalsRejected = 0;
      deteriorationWarnings = 0;
      learningStatus = "Observing";
      lastValidatedConfig = "Default Baseline";
      lastValidationTime = 0;
      researchSummary = "Collecting minimum sample sizes";
   }
};

struct SDashboardSnapshot
{
   string                eaName;
   string                eaVersion;
   string                symbol;
   ENUM_TIMEFRAMES       timeframe;
   ENUM_EA_OPERATING_MODE operatingMode;
   bool                  terminalConnected;
   bool                  tradeAllowedTerminal;
   bool                  initialized;
   string                operationalStatus;
   datetime              lastAnalysisTime;
   string                activeStrategyName;

   SSymbolProfile        symbolProfile;
   SMarketSnapshot       market;
   STickMetrics          ticks;
   SIndicatorValues      indicators;
   SStructureState       structure;
   SCandleSignal         candle;
   SChartPatternSignal   chartPattern;
   SRegimeState          regime;
   SMTFAnalysis          mtf;
   STradeSignal          lastSignal;
   SValidationResult     lastValidation;
   SRiskStatus           risk;
   SAccountMetrics       account;
   SIntelligenceSummary  intelligence;
   SStrategyStats        strategyStats[EA_MAX_STRATEGIES];

   void Reset()
   {
      eaName = EA_PROJECT_NAME;
      eaVersion = EA_PROJECT_VERSION;
      symbol = "";
      timeframe = PERIOD_CURRENT;
      operatingMode = EA_MODE_RESEARCH_ONLY;
      terminalConnected = false;
      tradeAllowedTerminal = false;
      initialized = false;
      operationalStatus = "Booting";
      lastAnalysisTime = 0;
      activeStrategyName = "None";

      symbolProfile.Reset();
      market.Reset();
      ticks.Reset();
      indicators.Reset();
      structure.Reset();
      candle.Reset();
      chartPattern.Reset();
      regime.Reset();
      mtf.Reset();
      lastSignal.Reset();
      lastValidation.Reset();
      risk.Reset();
      account.Reset();
      intelligence.Reset();
      for(int i = 0; i < EA_MAX_STRATEGIES; i++)
         strategyStats[i].Reset();
   }
};

// Helper conversion functions
string OperatingModeToString(const ENUM_EA_OPERATING_MODE mode)
{
   switch(mode)
   {
      case EA_MODE_RESEARCH_ONLY:  return "RESEARCH_ONLY";
      case EA_MODE_DEMO_PAPER:     return "DEMO_PAPER";
      case EA_MODE_DEMO_EXECUTION: return "DEMO_EXECUTION";
      case EA_MODE_LIVE_TRADING:   return "LIVE_TRADING";
   }
   return "UNKNOWN";
}

string RegimeToString(const ENUM_MARKET_REGIME regime)
{
   switch(regime)
   {
      case REGIME_STRONG_BULL_TREND: return "Strong Bull Trend";
      case REGIME_WEAK_BULL_TREND:   return "Weak Bull Trend";
      case REGIME_STRONG_BEAR_TREND: return "Strong Bear Trend";
      case REGIME_WEAK_BEAR_TREND:   return "Weak Bear Trend";
      case REGIME_SIDEWAYS:          return "Sideways";
      case REGIME_CONSOLIDATION:     return "Consolidation";
      case REGIME_HIGH_VOLATILITY:   return "High Volatility";
      case REGIME_LOW_VOLATILITY:    return "Low Volatility";
      case REGIME_VOL_EXPANSION:     return "Volatility Expansion";
      case REGIME_VOL_CONTRACTION:   return "Volatility Contraction";
      case REGIME_UNSTABLE:          return "Unstable / Abnormal";
      default:                       return "Unknown";
   }
}

string DirectionToString(const ENUM_SIGNAL_DIRECTION dir)
{
   if(dir == SIGNAL_BUY)  return "BUY";
   if(dir == SIGNAL_SELL) return "SELL";
   return "NONE";
}

string StrengthBandToString(const ENUM_SIGNAL_STRENGTH_BAND band)
{
   switch(band)
   {
      case STRENGTH_STRONG_BULL: return "Strong Bullish";
      case STRENGTH_MOD_BULL:    return "Moderate Bullish";
      case STRENGTH_WEAK_BULL:   return "Weak Bullish";
      case STRENGTH_WEAK_BEAR:   return "Weak Bearish";
      case STRENGTH_MOD_BEAR:    return "Moderate Bearish";
      case STRENGTH_STRONG_BEAR: return "Strong Bearish";
      default:                   return "Neutral";
   }
}

string StrategyIdToName(const ENUM_STRATEGY_ID id)
{
   switch(id)
   {
      case STRAT_TREND_PULLBACK:       return "Trend Pullback";
      case STRAT_MOMENTUM_SCALPING:    return "Momentum Scalping";
      case STRAT_BREAKOUT_SCALPING:    return "Breakout Scalping";
      case STRAT_REVERSAL_SCALPING:    return "Reversal Scalping";
      case STRAT_RANGE_SCALPING:       return "Range Scalping";
      case STRAT_VOLATILITY_EXPANSION: return "Volatility Expansion";
      case STRAT_MICRO_MOMENTUM:       return "Micro-Momentum";
   }
   return "Unknown";
}

string AssetClassToString(const ENUM_ASSET_CLASS ac)
{
   switch(ac)
   {
      case ASSET_FOREX_MAJOR:  return "Forex Major";
      case ASSET_FOREX_MINOR:  return "Forex Minor";
      case ASSET_FOREX_EXOTIC: return "Forex Exotic";
      case ASSET_METAL:        return "Metals";
      case ASSET_INDEX:        return "Stock Index";
      case ASSET_ENERGY:       return "Energy";
      case ASSET_CFD:          return "Broker CFD";
      case ASSET_SYNTHETIC:    return "Synthetic Index";
      case ASSET_CRYPTO:       return "Crypto CFD";
      default:                 return "Unknown";
   }
}

#endif // __ASEA_CORE_TYPES_MQH__
