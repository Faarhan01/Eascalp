//+------------------------------------------------------------------+
//|                                                        Types.mqh |
//|                        Advanced Multi-Market MT5 Scalping EA     |
//|                        v2.0.0 Shared Enumerations & Structures   |
//+------------------------------------------------------------------+
#ifndef __ASEA_CORE_TYPES_MQH__
#define __ASEA_CORE_TYPES_MQH__

#define EA_PROJECT_NAME       "AdvancedScalpingEA"
#define EA_PROJECT_VERSION    "2.2.0"
#define EA_DATA_ROOT          "AdvancedScalpingEA"
#define EA_MAX_STRATEGIES     7
#define EA_MAX_TF_SLOTS       14
#define EA_MAX_SYMBOLS        8
#define EA_MAX_REGIMES        17
#define EA_MIN_SHARPE_TRADES  10

enum ENUM_EA_OPERATING_MODE
{
   EA_MODE_RESEARCH_ONLY   = 0, // Research & Signal Observation Only (No Orders)
   EA_MODE_DEMO_EXECUTION  = 2, // Demo Account Order Execution
   EA_MODE_LIVE_TRADING    = 3  // Live & Strategy Tester Order Execution
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
   REGIME_UNKNOWN               = 0,
   REGIME_STRONG_BULL_TREND     = 1,
   REGIME_WEAK_BULL_TREND       = 2,
   REGIME_STRONG_BEAR_TREND     = 3,
   REGIME_WEAK_BEAR_TREND       = 4,
   REGIME_EARLY_TREND_BULL      = 5,
   REGIME_EARLY_TREND_BEAR      = 6,
   REGIME_ESTABLISHED_BULL      = 7,
   REGIME_ESTABLISHED_BEAR      = 8,
   REGIME_TREND_EXHAUSTION      = 9,
   REGIME_POTENTIAL_REVERSAL    = 10,
   REGIME_SIDEWAYS              = 11,
   REGIME_TIGHT_CONSOLIDATION   = 12,
   REGIME_WIDE_CONSOLIDATION    = 13,
   REGIME_VOL_EXPANSION         = 14,
   REGIME_VOL_CONTRACTION       = 15,
   REGIME_ABNORMAL_VOLATILITY   = 16,
   REGIME_UNSTABLE              = 17
};

enum ENUM_VOLATILITY_STATE
{
   VOL_LOW      = 0,
   VOL_NORMAL   = 1,
   VOL_HIGH     = 2,
   VOL_ABNORMAL = 3
};

enum ENUM_STRUCTURE_EVENT
{
   STRUCT_NONE                 = 0,
   STRUCT_BOS_BULL             = 1,
   STRUCT_BOS_BEAR             = 2,
   STRUCT_CHOCH_BULL           = 3,
   STRUCT_CHOCH_BEAR           = 4,
   STRUCT_LIQ_SWEEP_HIGH       = 5,
   STRUCT_LIQ_SWEEP_LOW        = 6,
   STRUCT_BREAKOUT_UP          = 7,
   STRUCT_BREAKOUT_DOWN        = 8,
   STRUCT_FAILED_BREAKOUT_UP   = 9,
   STRUCT_FAILED_BREAKOUT_DOWN = 10,
   STRUCT_RETEST_BULL          = 11,
   STRUCT_RETEST_BEAR          = 12,
   STRUCT_REJECTION_HIGH       = 13,
   STRUCT_REJECTION_LOW        = 14
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
   CANDLE_EVENING_STAR   = 11,
   CANDLE_MOMENTUM_BAR   = 12,
   CANDLE_EXPANSION_BAR  = 13,
   CANDLE_COMPRESSION_BAR= 14
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

enum ENUM_STRATEGY_SUITABILITY
{
   SUIT_UNSUITABLE           = 0,
   SUIT_INSUFFICIENT_DATA    = 1,
   SUIT_CONDITIONAL          = 2,
   SUIT_SUITABLE             = 3
};

enum ENUM_MTF_ASSESSMENT
{
   MTF_NEUTRAL           = 0,
   MTF_PARTIAL_AGREEMENT = 1,
   MTF_STRONG_AGREEMENT  = 2,
   MTF_CONFLICTING       = 3
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
   double                typicalAtrPrice;
   double                typicalSpreadPoints;
   double                estCommissionPerLot;
   double                pipSize;
   double                autoMaxSpreadPts;
   int                   recommendedSlippagePts;
   double                measuredAvgSlippagePts;
   int                   measuredFillCount;
   bool                  isHedgingAccount;
   bool                  sessionOpenNow;
   bool                  isSynthetic24x7;
   bool                  hasRealVolume;
   int                   availableBarsPrimary;
   datetime              lastInspected;
   bool                  isValid;

   void Reset()
   {
      symbol = ""; baseSymbol = ""; prefix = ""; suffix = "";
      currencyBase = ""; currencyProfit = ""; currencyMargin = "";
      assetClass = ASSET_UNKNOWN;
      digits = 5; point = 0.00001; tickSize = 0.00001;
      tickValue = 1.0; tickValueProfit = 1.0; tickValueLoss = 1.0;
      contractSize = 100000.0;
      volumeMin = 0.01; volumeMax = 100.0; volumeStep = 0.01; volumeDigits = 2;
      stopsLevelPoints = 0; freezeLevelPoints = 0; spreadPoints = 0;
      tradeMode = SYMBOL_TRADE_MODE_FULL; execMode = SYMBOL_TRADE_EXECUTION_MARKET;
      fillingFlags = 0; preferredFilling = ORDER_FILLING_IOC;
      swapLong = 0.0; swapShort = 0.0; swapMode = 0;
      marginInitial = 0.0; marginMaintenance = 0.0;
      typicalAtrPrice = 0.0; typicalSpreadPoints = 0.0; estCommissionPerLot = 0.0;
      pipSize = 0.0001; autoMaxSpreadPts = 350.0; recommendedSlippagePts = 25;
      measuredAvgSlippagePts = 0.0; measuredFillCount = 0;
      isHedgingAccount = true;
      sessionOpenNow = false; isSynthetic24x7 = false; hasRealVolume = false;
      availableBarsPrimary = 0; lastInspected = 0; isValid = false;
   }
};

struct SMarketSnapshot
{
   string          symbol;
   ENUM_TIMEFRAMES timeframe;
   datetime        tickTime;
   datetime        barTime;
   double          bid;
   double          ask;
   double          lastPrice;
   double          midPrice;
   double          spreadPoints;
   double          avgSpreadPoints;
   double          spreadRatio;
   double          open;
   double          high;
   double          low;
   double          close;
   long            tickVolume;
   long            realVolume;
   double          barRange;
   double          priceChange;
   double          priceChangePct;
   double          normalizedBarRangeAtr;
   bool            dataReady;

   void Reset()
   {
      symbol = ""; timeframe = PERIOD_CURRENT; tickTime = 0; barTime = 0;
      bid = 0.0; ask = 0.0; lastPrice = 0.0; midPrice = 0.0;
      spreadPoints = 0.0; avgSpreadPoints = 0.0; spreadRatio = 1.0;
      open = 0.0; high = 0.0; low = 0.0; close = 0.0;
      tickVolume = 0; realVolume = 0; barRange = 0.0;
      priceChange = 0.0; priceChangePct = 0.0; normalizedBarRangeAtr = 1.0;
      dataReady = false;
   }
};

struct STickMetrics
{
   int      sampleCount;
   int      consecutiveUpTicks;
   int      consecutiveDownTicks;
   double   directionalPersistence; // 0.0 - 1.0
   double   ticksPerSecond;
   double   priceVelocity;          // points per second
   double   priceAcceleration;      // delta velocity per second
   double   shortTermDisplacement;  // net points over window
   double   shortTermVolatilityPts; // stddev of tick deltas in points
   double   bidDeltaPts;
   double   askDeltaPts;
   double   microTrendBias;         // -1.0 to +1.0
   double   spreadExpansionRatio;
   double   activityRatio;          // current ticks/sec vs baseline
   bool     suddenActivitySurge;
   bool     momentumDeteriorating;
   bool     spreadSpikeDetected;
   bool     tickProvidesNetEdge;    // true only if displacement > spread cost * safety factor
   bool     isReady;

   void Reset()
   {
      sampleCount = 0; consecutiveUpTicks = 0; consecutiveDownTicks = 0;
      directionalPersistence = 0.0; ticksPerSecond = 0.0;
      priceVelocity = 0.0; priceAcceleration = 0.0;
      shortTermDisplacement = 0.0; shortTermVolatilityPts = 0.0;
      bidDeltaPts = 0.0; askDeltaPts = 0.0; microTrendBias = 0.0;
      spreadExpansionRatio = 1.0; activityRatio = 1.0;
      suddenActivitySurge = false; momentumDeteriorating = false;
      spreadSpikeDetected = false; tickProvidesNetEdge = false;
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
   double   prevRsi;
   double   macdMain;
   double   macdSignal;
   double   macdHist;
   double   prevMacdHist;
   double   atr;
   double   atrShort;
   double   atrBaseline;
   double   relativeAtr;         // atr / atrBaseline
   double   shortLongVolRatio;   // atrShort / atrBaseline
   double   rollingStdDev;       // price close stddev
   double   volatilityPercentile;// 0..100 over 100 bars
   double   adxMain;
   double   adxPlusDI;
   double   adxMinusDI;
   double   bbUpper;
   double   bbMiddle;
   double   bbLower;
   double   bbWidthPct;
   double   prevBbWidthPct;
   double   donchianHigh;
   double   donchianMid;
   double   donchianLow;
   double   stochK;
   double   stochD;
   double   cci;
   double   wpr;
   double   psar;
   double   momentum;
   double   roc;
   double   prevRoc;
   double   momentumAccel;       // roc - prevRoc
   double   directionalPersist;  // -1.0 .. +1.0 over last 10 closed bars
   double   priceDisplacementAtr;// (close[0] - close[10]) / atr
   double   emaDistanceAtr;      // (close[0] - emaMedium) / atr
   double   vwap;
   bool     vwapAvailable;
   bool     bullDivergence;
   bool     bearDivergence;
   bool     momentumExhaustion;
   bool     isReady;

   void Reset()
   {
      emaFast = 0.0; emaMedium = 0.0; emaSlow = 0.0; smaTrend = 0.0;
      rsi = 50.0; prevRsi = 50.0;
      macdMain = 0.0; macdSignal = 0.0; macdHist = 0.0; prevMacdHist = 0.0;
      atr = 0.0; atrShort = 0.0; atrBaseline = 0.0;
      relativeAtr = 1.0; shortLongVolRatio = 1.0;
      rollingStdDev = 0.0; volatilityPercentile = 50.0;
      adxMain = 0.0; adxPlusDI = 0.0; adxMinusDI = 0.0;
      bbUpper = 0.0; bbMiddle = 0.0; bbLower = 0.0; bbWidthPct = 0.0; prevBbWidthPct = 0.0;
      donchianHigh = 0.0; donchianMid = 0.0; donchianLow = 0.0;
      stochK = 50.0; stochD = 50.0; cci = 0.0; wpr = -50.0; psar = 0.0;
      momentum = 100.0; roc = 0.0; prevRoc = 0.0; momentumAccel = 0.0;
      directionalPersist = 0.0; priceDisplacementAtr = 0.0; emaDistanceAtr = 0.0;
      vwap = 0.0; vwapAvailable = false;
      bullDivergence = false; bearDivergence = false; momentumExhaustion = false;
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
   double   developingHigh;
   double   developingLow;
   double   nearestSupport;
   double   nearestResistance;
   int      supportRejectCount;
   int      resistanceRejectCount;
   double   rangeHigh;
   double   rangeLow;
   double   rangeWidthAtr;
   bool     hasHH;
   bool     hasHL;
   bool     hasLH;
   bool     hasLL;
   bool     tightConsolidation;
   bool     wideConsolidation;
   bool     inConsolidation;
   bool     trendContinuation;
   bool     trendExhaustion;
   bool     structuralReversal;
   bool     failedBreakout;
   bool     breakoutRetest;
   int      structureBias; // +1 bull, -1 bear, 0 neutral
   ENUM_STRUCTURE_EVENT lastEvent;
   string   summary;
   bool     isReady;

   void Reset()
   {
      lastSwingHigh = 0.0; prevSwingHigh = 0.0;
      lastSwingLow = 0.0; prevSwingLow = 0.0;
      lastSwingHighTime = 0; lastSwingLowTime = 0;
      developingHigh = 0.0; developingLow = 0.0;
      nearestSupport = 0.0; nearestResistance = 0.0;
      supportRejectCount = 0; resistanceRejectCount = 0;
      rangeHigh = 0.0; rangeLow = 0.0; rangeWidthAtr = 0.0;
      hasHH = false; hasHL = false; hasLH = false; hasLL = false;
      tightConsolidation = false; wideConsolidation = false; inConsolidation = false;
      trendContinuation = false; trendExhaustion = false; structuralReversal = false;
      failedBreakout = false; breakoutRetest = false;
      structureBias = 0; lastEvent = STRUCT_NONE;
      summary = "Uninitialized"; isReady = false;
   }
};

struct SCandleSignal
{
   ENUM_CANDLE_PATTERN   pattern;
   ENUM_SIGNAL_DIRECTION bias;
   double   strength;
   double   bodyRatio;
   double   upperWickRatio;
   double   lowerWickRatio;
   double   relSizeAtr;
   int      consecutiveDirBars;
   int      insideBarCount;
   bool     contextValidated;
   string   name;
   string   contextNote;

   void Reset()
   {
      pattern = CANDLE_NONE; bias = SIGNAL_NONE; strength = 0.0;
      bodyRatio = 0.0; upperWickRatio = 0.0; lowerWickRatio = 0.0;
      relSizeAtr = 1.0; consecutiveDirBars = 0; insideBarCount = 0;
      contextValidated = false; name = "None"; contextNote = "";
   }
};

struct SChartPatternSignal
{
   ENUM_CHART_PATTERN    pattern;
   ENUM_SIGNAL_DIRECTION bias;
   double   confidence;
   double   breakoutLevel;
   double   invalidationLevel;
   string   name;
   string   note;

   void Reset()
   {
      pattern = PATTERN_NONE; bias = SIGNAL_NONE; confidence = 0.0;
      breakoutLevel = 0.0; invalidationLevel = 0.0;
      name = "None"; note = "";
   }
};

struct SRegimeState
{
   ENUM_MARKET_REGIME    regime;
   ENUM_MARKET_REGIME    previousRegime;
   ENUM_VOLATILITY_STATE volatilityState;
   double                confidence; // 0.0 - 1.0
   double                trendStrength;
   double                volatilityRatio;
   double                volatilityPercentile;
   double                efficiencyRatio;
   double                directionalPersistence;
   bool                  transitionDetected;
   bool                  isTrending;
   bool                  isRanging;
   bool                  isVolatile;
   bool                  isUnstable;
   string                label;
   string                supportingMeasurements;

   void Reset()
   {
      regime = REGIME_UNKNOWN; previousRegime = REGIME_UNKNOWN;
      volatilityState = VOL_NORMAL;
      confidence = 0.0; trendStrength = 0.0; volatilityRatio = 1.0;
      volatilityPercentile = 50.0; efficiencyRatio = 0.0; directionalPersistence = 0.0;
      transitionDetected = false; isTrending = false; isRanging = false;
      isVolatile = false; isUnstable = false;
      label = "Unknown"; supportingMeasurements = "";
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
   ENUM_MTF_ASSESSMENT   assessment;
   double                weightedScore; // -100 (strong bear) to +100 (strong bull)
   double                agreementScore; // 0..100
   bool                  hasStrongConflict;
   bool                  ltfContradictsHtfStructure;
   bool                  alignedBullish;
   bool                  alignedBearish;
   string                conflictReason;
   string                assessmentSummary;
   bool                  isReady;

   void Reset()
   {
      higherTF = PERIOD_H1; intermediateTF = PERIOD_M15; lowerTF = PERIOD_M5;
      higherBias = SIGNAL_NONE; intermediateBias = SIGNAL_NONE; lowerBias = SIGNAL_NONE;
      assessment = MTF_NEUTRAL; weightedScore = 0.0; agreementScore = 0.0;
      hasStrongConflict = false; ltfContradictsHtfStructure = false;
      alignedBullish = false; alignedBearish = false;
      conflictReason = ""; assessmentSummary = "Neutral"; isReady = false;
   }
};

struct SExpectancyEstimate
{
   double grossExpectancyMoney;
   double estimatedCostMoney;
   double netExpectancyMoney;
   double avgRewardMoney;
   double avgRiskMoney;
   double riskRewardRatio;
   double historicalWinRate;
   int    sampleSize;
   bool   hasSufficientSample;
   bool   economicallyViable;
   string summary;

   void Reset()
   {
      grossExpectancyMoney = 0.0; estimatedCostMoney = 0.0; netExpectancyMoney = 0.0;
      avgRewardMoney = 0.0; avgRiskMoney = 0.0; riskRewardRatio = 0.0;
      historicalWinRate = 0.0; sampleSize = 0;
      hasSufficientSample = false; economicallyViable = true;
      summary = "Insufficient sample";
   }
};

struct SScoreBreakdown
{
   double regimeScore;         // 0..10
   double structureScore;      // 0..14
   double trendStrengthScore;  // 0..10
   double momentumScore;       // 0..12
   double volatilityScore;     // 0..8
   double patternConfluence;   // 0..10 (non-duplicated candle + chart pattern)
   double mtfAgreementScore;   // 0..12
   double tickEdgeScore;       // 0..8 (0 if tickProvidesNetEdge == false)
   double executionCostScore;  // 0..8 (spread + cost margin)
   double strategySuitScore;   // 0..8
   double totalScore;          // 0..100
   bool   isValidatedScore;    // true only if historical OOS/sample is adequate
   ENUM_SIGNAL_STRENGTH_BAND band;

   void Reset()
   {
      regimeScore = 0.0; structureScore = 0.0; trendStrengthScore = 0.0;
      momentumScore = 0.0; volatilityScore = 0.0; patternConfluence = 0.0;
      mtfAgreementScore = 0.0; tickEdgeScore = 0.0; executionCostScore = 0.0;
      strategySuitScore = 0.0; totalScore = 0.0;
      isValidatedScore = false; band = STRENGTH_NEUTRAL;
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
   SExpectancyEstimate   expectancy;
   ENUM_MARKET_REGIME    regime;
   ENUM_STRATEGY_SUITABILITY suitability;
   string                rationale;
   string                supportingIndicators;
   string                supportingStructure;
   string                patternConfirmations;
   string                conflictingConditions;
   int                   consensusCount;
   bool                  hasOppositeConflict;
   bool                  isValid;

   void Reset()
   {
      signalId = ""; timestamp = 0; symbol = ""; timeframe = PERIOD_CURRENT;
      strategyId = STRAT_TREND_PULLBACK; strategyName = ""; direction = SIGNAL_NONE;
      entryPrice = 0.0; stopLoss = 0.0; takeProfit = 0.0;
      confidenceRaw = 0.0; compositeScore = 0.0;
      breakdown.Reset(); expectancy.Reset();
      regime = REGIME_UNKNOWN; suitability = SUIT_INSUFFICIENT_DATA;
      rationale = ""; supportingIndicators = ""; supportingStructure = "";
      patternConfirmations = ""; conflictingConditions = "";
      consensusCount = 1; hasOppositeConflict = false;
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

struct SCurrencyExposure
{
   string currency;
   double netLots;
   double riskMoney;
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
   double   maxCurrencyExposureLots;
   string   topExposedCurrency;
   int      openPositionsCount;
   int      symbolPositionsCount;
   int      consecutiveLosses;
   int      maxConsecutiveLosses;
   double   marginLevelPct;
   double   marginUtilizationPct;
   double   freeMargin;
   string   statusLabel;

   void Reset()
   {
      tradingAllowed = false; lockoutActive = false; lockoutReason = "";
      dailyPnL = 0.0; dailyLossLimitMoney = 0.0; dailyLossUsedPct = 0.0;
      weeklyPnL = 0.0; weeklyLossLimitMoney = 0.0; weeklyLossUsedPct = 0.0;
      balanceDrawdownPct = 0.0; equityDrawdownPct = 0.0; maxHistoricalDrawdownPct = 0.0;
      currentOpenRiskMoney = 0.0; currentOpenRiskPct = 0.0; totalOpenExposureLots = 0.0;
      maxCurrencyExposureLots = 0.0; topExposedCurrency = "NONE";
      openPositionsCount = 0; symbolPositionsCount = 0;
      consecutiveLosses = 0; maxConsecutiveLosses = 0;
      marginLevelPct = 0.0; marginUtilizationPct = 0.0; freeMargin = 0.0;
      statusLabel = "Initializing";
   }
};

struct SExecutionResult
{
   bool     executed;
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
   double   estimatedCostMoney;
   datetime executionTime;

   void Reset()
   {
      executed = false;
      orderTicket = 0; dealTicket = 0; positionTicket = 0;
      retcode = 0; retcodeDesc = "";
      requestedPrice = 0.0; filledPrice = 0.0;
      requestedVolume = 0.0; filledVolume = 0.0;
      slippagePoints = 0.0; estimatedCostMoney = 0.0; executionTime = 0;
   }
};

struct SManagedPosition
{
   ulong                 ticket;
   string                symbol;
   string                signalId;
   ENUM_STRATEGY_ID      strategyId;
   string                strategyName;
   ENUM_SIGNAL_DIRECTION direction;
   double                volume;
   double                initialVolume;
   double                openPrice;
   double                currentPrice;
   double                initialSL;
   double                currentSL;
   double                takeProfit;
   double                floatingPnL;
   double                currentRiskMoney;
   double                mfeMoney;
   double                maeMoney;
   datetime              openTime;
   long                  holdingSeconds;
   bool                  breakEvenApplied;
   bool                  partialExitTaken;
   double                signalScore;
   ENUM_MARKET_REGIME    entryRegime;
   string                lastExitReason;

   void Reset()
   {
      ticket = 0; symbol = ""; signalId = "";
      strategyId = STRAT_TREND_PULLBACK; strategyName = ""; direction = SIGNAL_NONE;
      volume = 0.0; initialVolume = 0.0; openPrice = 0.0; currentPrice = 0.0;
      initialSL = 0.0; currentSL = 0.0; takeProfit = 0.0;
      floatingPnL = 0.0; currentRiskMoney = 0.0; mfeMoney = 0.0; maeMoney = 0.0;
      openTime = 0; holdingSeconds = 0;
      breakEvenApplied = false; partialExitTaken = false;
      signalScore = 0.0; entryRegime = REGIME_UNKNOWN; lastExitReason = "";
   }
};

struct SStrategyStats
{
   ENUM_STRATEGY_ID          strategyId;
   string                    strategyName;
   bool                      enabledByInput;
   ENUM_STRATEGY_SUITABILITY suitability;
   double                    suitabilityScore;
   bool                      recommendedBySelector;
   bool                      deteriorationWarning;
   int                       totalTrades;
   int                       winningTrades;
   int                       losingTrades;
   double                    grossProfit;
   double                    grossLoss;
   double                    netProfit;
   double                    avgWin;
   double                    avgLoss;
   double                    winRatePct;
   double                    profitFactor;
   double                    expectedValue;
   double                    avgHoldingSeconds;
   double                    maxDrawdownMoney;
   int                       currentConsecutiveLosses;
   int                       maxConsecutiveLosses;
   double                    recentWinRatePct;
   double                    recentNetProfit;
   int                       signalsGenerated;
   int                       signalsAccepted;
   int                       signalsRejected;
   int                       minSampleTarget;
   bool                      hasSufficientSample;
   double                    regimeNetProfit[EA_MAX_REGIMES + 1];
   int                       regimeTrades[EA_MAX_REGIMES + 1];
   int                       regimeWins[EA_MAX_REGIMES + 1];

   void Reset()
   {
      strategyId = STRAT_TREND_PULLBACK; strategyName = "";
      enabledByInput = false; suitability = SUIT_INSUFFICIENT_DATA; suitabilityScore = 0.0;
      recommendedBySelector = false; deteriorationWarning = false;
      totalTrades = 0; winningTrades = 0; losingTrades = 0;
      grossProfit = 0.0; grossLoss = 0.0; netProfit = 0.0;
      avgWin = 0.0; avgLoss = 0.0;
      winRatePct = 0.0; profitFactor = 0.0; expectedValue = 0.0;
      avgHoldingSeconds = 0.0; maxDrawdownMoney = 0.0;
      currentConsecutiveLosses = 0; maxConsecutiveLosses = 0;
      recentWinRatePct = 0.0; recentNetProfit = 0.0;
      signalsGenerated = 0; signalsAccepted = 0; signalsRejected = 0;
      minSampleTarget = 20;
      hasSufficientSample = false;
      for(int i = 0; i <= EA_MAX_REGIMES; i++)
      {
         regimeNetProfit[i] = 0.0;
         regimeTrades[i] = 0;
         regimeWins[i] = 0;
      }
   }
};

struct SAccountMetrics
{
   double   initialBalance;
   double   balance;
   double   equity;
   double   floatingPnL;
   double   realizedDailyPnL;
   double   realizedWeeklyPnL;
   double   realizedMonthlyPnL;
   double   totalNetProfit;
   double   grossProfit;
   double   grossLoss;
   double   totalCommissions;
   double   totalSwaps;
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
   double   avgMfeMoney;
   double   avgMaeMoney;
   double   recoveryFactor;
   double   sharpeRatio;
   double   sortinoRatio;
   bool     sharpeValid;
   bool     sortinoValid;

   void Reset()
   {
      initialBalance = 0.0; balance = 0.0; equity = 0.0; floatingPnL = 0.0;
      realizedDailyPnL = 0.0; realizedWeeklyPnL = 0.0; realizedMonthlyPnL = 0.0;
      totalNetProfit = 0.0; grossProfit = 0.0; grossLoss = 0.0;
      totalCommissions = 0.0; totalSwaps = 0.0;
      totalTrades = 0; winningTrades = 0; losingTrades = 0;
      winRatePct = 0.0; profitFactor = 0.0; expectedValue = 0.0;
      avgWin = 0.0; avgLoss = 0.0; largestWin = 0.0; largestLoss = 0.0;
      maxDrawdownMoney = 0.0; maxDrawdownPct = 0.0;
      relativeDrawdownPct = 0.0; absoluteDrawdownMoney = 0.0;
      currentConsecutiveWins = 0; currentConsecutiveLosses = 0;
      maxConsecutiveWins = 0; maxConsecutiveLosses = 0;
      avgHoldingSeconds = 0.0; avgMfeMoney = 0.0; avgMaeMoney = 0.0;
      recoveryFactor = 0.0; sharpeRatio = 0.0; sortinoRatio = 0.0;
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
   string   stage1RawObs;
   string   stage2HistoricalFinding;
   string   stage3Recommendation;
   string   stage4ValidatedConfig;
   string   stage5ActiveConfig;
   datetime lastValidationTime;
   string   researchSummary;

   void Reset()
   {
      observationsCollected = 0; patternsDetected = 0; regimesAnalyzed = 0;
      signalsGenerated = 0; signalsAccepted = 0; signalsRejected = 0;
      deteriorationWarnings = 0;
      learningStatus = "Observing (Non-Mutating)";
      stage1RawObs = "0 observations";
      stage2HistoricalFinding = "Awaiting minimum sample";
      stage3Recommendation = "None";
      stage4ValidatedConfig = "ReadyToTrade_v2.2.0";
      stage5ActiveConfig = "ReadyToTrade_v2.2.0";
      lastValidationTime = 0;
      researchSummary = "Collecting minimum sample sizes";
   }
};

struct SDashboardSnapshot
{
   string                eaName;
   string                eaVersion;
   string                symbol;
   string                accountCurrency;
   string                monitoredSymbolsSummary;
   int                   monitoredSymbolCount;
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
      eaName = EA_PROJECT_NAME; eaVersion = EA_PROJECT_VERSION;
      symbol = ""; accountCurrency = ""; monitoredSymbolsSummary = ""; monitoredSymbolCount = 1;
      timeframe = PERIOD_CURRENT; operatingMode = EA_MODE_LIVE_TRADING;
      terminalConnected = false; tradeAllowedTerminal = false;
      initialized = false; operationalStatus = "Booting";
      lastAnalysisTime = 0; activeStrategyName = "None";

      symbolProfile.Reset(); market.Reset(); ticks.Reset();
      indicators.Reset(); structure.Reset(); candle.Reset();
      chartPattern.Reset(); regime.Reset(); mtf.Reset();
      lastSignal.Reset(); lastValidation.Reset(); risk.Reset();
      account.Reset(); intelligence.Reset();
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
      case EA_MODE_DEMO_EXECUTION: return "DEMO_EXECUTION";
      case EA_MODE_LIVE_TRADING:   return "LIVE_TRADING";
   }
   return "UNKNOWN";
}

string RegimeToString(const ENUM_MARKET_REGIME regime)
{
   switch(regime)
   {
      case REGIME_STRONG_BULL_TREND:   return "Strong Bull Trend";
      case REGIME_WEAK_BULL_TREND:     return "Weak Bull Trend";
      case REGIME_STRONG_BEAR_TREND:   return "Strong Bear Trend";
      case REGIME_WEAK_BEAR_TREND:     return "Weak Bear Trend";
      case REGIME_EARLY_TREND_BULL:    return "Early Bull Trend";
      case REGIME_EARLY_TREND_BEAR:    return "Early Bear Trend";
      case REGIME_ESTABLISHED_BULL:    return "Established Bull Trend";
      case REGIME_ESTABLISHED_BEAR:    return "Established Bear Trend";
      case REGIME_TREND_EXHAUSTION:    return "Trend Exhaustion";
      case REGIME_POTENTIAL_REVERSAL:  return "Potential Reversal";
      case REGIME_SIDEWAYS:            return "Sideways";
      case REGIME_TIGHT_CONSOLIDATION: return "Tight Consolidation";
      case REGIME_WIDE_CONSOLIDATION:  return "Wide Consolidation";
      case REGIME_VOL_EXPANSION:       return "Volatility Expansion";
      case REGIME_VOL_CONTRACTION:     return "Volatility Contraction";
      case REGIME_ABNORMAL_VOLATILITY: return "Abnormal Volatility";
      case REGIME_UNSTABLE:            return "Unstable / Abnormal";
      default:                         return "Unknown";
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

string SuitabilityToString(const ENUM_STRATEGY_SUITABILITY s)
{
   switch(s)
   {
      case SUIT_SUITABLE:          return "Suitable";
      case SUIT_CONDITIONAL:       return "Conditional";
      case SUIT_INSUFFICIENT_DATA: return "Low Sample";
      default:                     return "Unsuitable";
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
