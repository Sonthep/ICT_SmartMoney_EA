//+------------------------------------------------------------------+
//| ICT_SmartMoney_EA_v4_Fixed.mq5                                  |
//| Professional ICT Smart Money EA - Fixed Version                 |
//| Copyright 2024 - ICT Smart Money EA                             |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024 - ICT Smart Money EA"
#property link      "https://github.com/ict-smartmoney-ea"
#property version   "4.01"
#property description "Professional ICT Smart Money EA with modular architecture"

#include <Trade\Trade.mqh>
#include "Structures.mqh"
#include "ConfidenceScoring.mqh"
#include "OB_BOS_Detection.mqh"
#include "LiquiditySweep.mqh"
#include "KillzoneManager.mqh"
#include "RiskManager_v2.mqh"
#include "TradeManager_v2.mqh"
#include "Dashboard.mqh"
#include "Utils.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== RISK MANAGEMENT ==="
input double RiskPercent = 2.0;                    // Risk per trade (%)
input double RR_Ratio = 2.0;                       // Risk:Reward ratio
input double RR_Ratio_Alt = 1.5;                   // Alternative RR for high confidence
input int SL_Buffer = 30;                          // Stop loss buffer (points)

input group "=== CONFIDENCE SCORING ==="
input int MinConfidenceScore = 85;                 // Minimum confidence score (0-100)
input int HighConfidenceScore = 90;                // High confidence threshold

input group "=== DETECTION PARAMETERS ==="
input int SwingLookback = 5;                       // Swing points lookback
input int BOS_Lookback_M5 = 20;                    // BOS lookback on M5
input int BOS_Lookback_M15 = 30;                   // BOS lookback on M15
input int OB_Lookback = 15;                        // Order Block lookback
input bool RequireFVG = true;                      // Require Fair Value Gap

input group "=== KILLZONE SETTINGS ==="
input bool UseLondonKZ = true;                     // Use London Killzone (08:00-10:30 GMT)
input bool UseNYKZ = true;                         // Use NY Killzone (13:00-16:00 GMT)
input int TimezoneOffset = 0;                      // Timezone offset from GMT

input group "=== TRADE MANAGEMENT ==="
input int MaxTradesPerDay = 2;                     // Maximum trades per day
input bool AllowExtraTrade = true;                 // Allow extra trade for high confidence
input bool EnableBreakEven = true;                 // Enable break-even
input bool EnableTrailing = true;                  // Enable trailing stop

input group "=== VISUAL SETTINGS ==="
input bool ShowDashboard = true;                   // Show dashboard
input bool ShowOBZones = true;                     // Show Order Block zones
input bool ShowBOSLines = true;                    // Show BOS lines
input bool ShowSweepLevels = true;                 // Show sweep levels

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CTrade g_trade;
int g_magicNumber;

// Module instances
CConfidenceScoring* g_confidenceScoring = NULL;
COB_BOS_Detection* g_obBosDetection = NULL;
CLiquiditySweep* g_liquiditySweep = NULL;
CKillzoneManager* g_killzoneManager = NULL;
CRiskManager_v2* g_riskManager = NULL;
CTradeManager_v2* g_tradeManager = NULL;
CDashboard* g_dashboard = NULL;

// Daily trade tracking and signal data (using structures from Structures.mqh)
DailyTradeData g_dailyData;
SignalData g_currentSignal;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    Print("=== ICT Smart Money EA v4.01 Initializing ===");
    
    // Initialize magic number
    g_magicNumber = 20241201 + (int)StringToInteger(StringSubstr(_Symbol, 0, 3));
    g_trade.SetExpertMagicNumber(g_magicNumber);
    
    // Initialize modules
    g_confidenceScoring = new CConfidenceScoring();
    g_obBosDetection = new COB_BOS_Detection();
    g_liquiditySweep = new CLiquiditySweep();
    g_killzoneManager = new CKillzoneManager();
    g_riskManager = new CRiskManager_v2();
    g_tradeManager = new CTradeManager_v2();
    g_dashboard = new CDashboard();
    
    // Configure modules
    g_obBosDetection.SetParameters(BOS_Lookback_M5, BOS_Lookback_M15, OB_Lookback, SwingLookback);
    g_liquiditySweep.SetParameters(SwingLookback, RequireFVG);
    g_killzoneManager.SetParameters(UseLondonKZ, UseNYKZ, TimezoneOffset);
    g_riskManager.SetParameters(RiskPercent, RR_Ratio, RR_Ratio_Alt, SL_Buffer);
    g_tradeManager.SetParameters(EnableBreakEven, EnableTrailing, g_magicNumber);
    
    // Initialize dashboard
    if(ShowDashboard) {
        g_dashboard.Initialize(_Symbol);
    }
    
    // Initialize daily data
    ResetDailyData();
    
    // Initialize signal data
    ResetSignalData();
    
    Print("[INIT] EA initialized successfully");
    Print("[INIT] Symbol: ", _Symbol, " | Magic: ", g_magicNumber);
    Print("[INIT] Min Confidence: ", MinConfidenceScore, " | High Confidence: ", HighConfidenceScore);
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    // Clean up modules
    if(g_confidenceScoring != NULL) { delete g_confidenceScoring; g_confidenceScoring = NULL; }
    if(g_obBosDetection != NULL) { delete g_obBosDetection; g_obBosDetection = NULL; }
    if(g_liquiditySweep != NULL) { delete g_liquiditySweep; g_liquiditySweep = NULL; }
    if(g_killzoneManager != NULL) { delete g_killzoneManager; g_killzoneManager = NULL; }
    if(g_riskManager != NULL) { delete g_riskManager; g_riskManager = NULL; }
    if(g_tradeManager != NULL) { delete g_tradeManager; g_tradeManager = NULL; }
    if(g_dashboard != NULL) { delete g_dashboard; g_dashboard = NULL; }
    
    // Clean up chart objects
    ObjectsDeleteAll(0, "ICT_");
    
    Print("=== ICT Smart Money EA v4.01 Stopped ===");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // Update daily data if new day
    CheckNewDay();
    
    // Update dashboard
    if(ShowDashboard && g_dashboard != NULL) {
        g_dashboard.Update(g_dailyData, g_currentSignal);
    }
    
    // Manage existing trades
    if(g_tradeManager != NULL) {
        g_tradeManager.ManageTrades();
    }
    
    // Check killzone
    if(g_killzoneManager != NULL && !g_killzoneManager.IsInKillzone()) {
        return;
    }
    
    // Check trade limits
    if(!CheckTradeLimit()) {
        return;
    }
    
    // Check if already have position/order
    if(HasActivePosition() || HasPendingOrder()) {
        return;
    }
    
    // Execute main strategy
    ExecuteStrategy();
}

//+------------------------------------------------------------------+
//| Main Strategy Execution                                         |
//+------------------------------------------------------------------+
void ExecuteStrategy() {
    // Reset signal for new analysis
    ResetSignalData();
    
    // Step 1: Multi-timeframe OB/BOS Detection
    if(g_obBosDetection != NULL) {
        if(!g_obBosDetection.AnalyzeMultiTimeframe(_Symbol, g_currentSignal)) {
            return; // No valid OB/BOS setup
        }
    }
    
    // Step 2: Liquidity Sweep + FVG Detection
    if(g_liquiditySweep != NULL) {
        if(!g_liquiditySweep.DetectSweepAndFVG(_Symbol, g_currentSignal)) {
            return; // No valid sweep/FVG
        }
    }
    
    // Step 3: Calculate Confidence Score
    if(g_confidenceScoring != NULL) {
        g_currentSignal.confidenceScore = g_confidenceScoring.CalculateScore(g_currentSignal);
    }
    
    // Step 4: Check confidence threshold
    if(g_currentSignal.confidenceScore < MinConfidenceScore) {
        if(ShowDashboard) {
            Print("[SIGNAL] Low confidence score: ", g_currentSignal.confidenceScore, " < ", MinConfidenceScore);
        }
        return;
    }
    
    // Step 5: Execute trade
    ExecuteTrade();
}

//+------------------------------------------------------------------+
//| Execute Trade                                                   |
//+------------------------------------------------------------------+
void ExecuteTrade() {
    if(g_riskManager == NULL) return;
    
    // Determine RR ratio based on confidence
    double rrRatio = (g_currentSignal.confidenceScore >= HighConfidenceScore) ? RR_Ratio_Alt : RR_Ratio;
    
    // Calculate trade parameters
    double entryPrice = (g_currentSignal.obHigh + g_currentSignal.obLow) / 2;
    double stopLoss, takeProfit, lotSize;
    
    if(g_currentSignal.isBullish) {
        stopLoss = g_currentSignal.obLow - (SL_Buffer * _Point);
        takeProfit = entryPrice + ((entryPrice - stopLoss) * rrRatio);
    } else {
        stopLoss = g_currentSignal.obHigh + (SL_Buffer * _Point);
        takeProfit = entryPrice - ((stopLoss - entryPrice) * rrRatio);
    }
    
    // Calculate lot size
    lotSize = g_riskManager.CalculateLotSize(entryPrice, stopLoss);
    
    // Place order
    bool success = false;
    string comment = StringFormat("ICT_Score%.0f_RR%.1f", g_currentSignal.confidenceScore, rrRatio);
    
    if(g_currentSignal.isBullish) {
        success = g_trade.Buy(lotSize, _Symbol, 0, stopLoss, takeProfit, comment);
    } else {
        success = g_trade.Sell(lotSize, _Symbol, 0, stopLoss, takeProfit, comment);
    }
    
    if(success) {
        // Update daily data
        g_dailyData.tradesCount++;
        
        // Add to trade manager
        if(g_tradeManager != NULL) {
            g_tradeManager.AddTrade(g_trade.ResultOrder(), entryPrice, stopLoss, takeProfit);
        }
        
        // Draw visual elements
        DrawTradeElements();
        
        Print("🚀 [TRADE] ", (g_currentSignal.isBullish ? "BUY" : "SELL"), 
              " | Score: ", g_currentSignal.confidenceScore,
              " | RR: 1:", rrRatio,
              " | Lot: ", lotSize);
    } else {
        Print("❌ [ERROR] Failed to place order: ", g_trade.ResultRetcodeDescription());
    }
}

//+------------------------------------------------------------------+
//| Check Trade Limit                                               |
//+------------------------------------------------------------------+
bool CheckTradeLimit() {
    int maxTrades = MaxTradesPerDay;
    
    // Allow extra trade for high confidence
    if(AllowExtraTrade && g_currentSignal.confidenceScore >= HighConfidenceScore) {
        maxTrades++;
    }
    
    return (g_dailyData.tradesCount < maxTrades);
}

//+------------------------------------------------------------------+
//| Check if has active position                                    |
//+------------------------------------------------------------------+
bool HasActivePosition() {
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionGetSymbol(i) == _Symbol) {
            ulong magic = PositionGetInteger(POSITION_MAGIC);
            if(magic == g_magicNumber) {
                return true;
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Check if has pending order                                      |
//+------------------------------------------------------------------+
bool HasPendingOrder() {
    for(int i = 0; i < OrdersTotal(); i++) {
        if(OrderGetTicket(i)) {
            if(OrderGetString(ORDER_SYMBOL) == _Symbol) {
                ulong magic = OrderGetInteger(ORDER_MAGIC);
                if(magic == g_magicNumber) {
                    return true;
                }
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Check for new day                                               |
//+------------------------------------------------------------------+
void CheckNewDay() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    datetime currentDate = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
    
    if(g_dailyData.date != currentDate) {
        ResetDailyData();
        g_dailyData.date = currentDate;
    }
}

//+------------------------------------------------------------------+
//| Reset daily data                                                |
//+------------------------------------------------------------------+
void ResetDailyData() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    g_dailyData.date = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
    g_dailyData.tradesCount = 0;
    g_dailyData.totalProfit = 0;
    g_dailyData.wins = 0;
    g_dailyData.losses = 0;
}

//+------------------------------------------------------------------+
//| Reset signal data                                               |
//+------------------------------------------------------------------+
void ResetSignalData() {
    g_currentSignal.sweepDetected = false;
    g_currentSignal.bosDetected = false;
    g_currentSignal.obFound = false;
    g_currentSignal.fvgFound = false;
    g_currentSignal.confidenceScore = 0;
    g_currentSignal.signalTime = 0;
    g_currentSignal.isBullish = false;
    g_currentSignal.obHigh = 0;
    g_currentSignal.obLow = 0;
    g_currentSignal.obTime = 0;
    g_currentSignal.fvgHigh = 0;
    g_currentSignal.fvgLow = 0;
    g_currentSignal.fvgTime = 0;
}

//+------------------------------------------------------------------+
//| Draw trade elements on chart                                    |
//+------------------------------------------------------------------+
void DrawTradeElements() {
    if(!ShowOBZones && !ShowBOSLines && !ShowSweepLevels) return;
    
    string prefix = "ICT_Trade_" + IntegerToString(TimeCurrent()) + "_";
    
    // Draw Order Block zone
    if(ShowOBZones && g_currentSignal.obFound) {
        string obName = prefix + "OB";
        ObjectCreate(0, obName, OBJ_RECTANGLE, 0, 
                    g_currentSignal.obTime, g_currentSignal.obLow,
                    TimeCurrent() + PeriodSeconds(PERIOD_H1), g_currentSignal.obHigh);
        ObjectSetInteger(0, obName, OBJPROP_COLOR, g_currentSignal.isBullish ? clrBlue : clrRed);
        ObjectSetInteger(0, obName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, obName, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, obName, OBJPROP_FILL, true);
        ObjectSetInteger(0, obName, OBJPROP_BACK, true);
    }
    
    // Draw FVG zone
    if(ShowOBZones && g_currentSignal.fvgFound) {
        string fvgName = prefix + "FVG";
        ObjectCreate(0, fvgName, OBJ_RECTANGLE, 0,
                    g_currentSignal.fvgTime, g_currentSignal.fvgLow,
                    TimeCurrent() + PeriodSeconds(PERIOD_H1), g_currentSignal.fvgHigh);
        ObjectSetInteger(0, fvgName, OBJPROP_COLOR, clrYellow);
        ObjectSetInteger(0, fvgName, OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, fvgName, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, fvgName, OBJPROP_FILL, true);
        ObjectSetInteger(0, fvgName, OBJPROP_BACK, true);
    }
} 