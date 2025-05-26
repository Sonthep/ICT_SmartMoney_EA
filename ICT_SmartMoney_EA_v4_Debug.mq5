//+------------------------------------------------------------------+
//| ICT_SmartMoney_EA_v4_Debug.mq5                                  |
//| Debug Version with Relaxed Conditions and Detailed Logging     |
//| Copyright 2024 - ICT Smart Money EA                             |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024 - ICT Smart Money EA"
#property link      "https://github.com/ict-smartmoney-ea"
#property version   "4.02"
#property description "Debug ICT Smart Money EA with relaxed conditions"

#include <Trade\Trade.mqh>
#include "Structures.mqh"
#include "Utils.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== RISK MANAGEMENT ==="
input double RiskPercent = 1.0;                    // Risk per trade (%)
input double RR_Ratio = 1.5;                       // Risk:Reward ratio
input int SL_Buffer = 20;                          // Stop loss buffer (points)

input group "=== CONFIDENCE SCORING ==="
input int MinConfidenceScore = 50;                 // Minimum confidence score (RELAXED)
input int HighConfidenceScore = 70;                // High confidence threshold (RELAXED)

input group "=== DETECTION PARAMETERS ==="
input int SwingLookback = 3;                       // Swing points lookback (RELAXED)
input int BOS_Lookback = 10;                       // BOS lookback (RELAXED)
input int OB_Lookback = 8;                         // Order Block lookback (RELAXED)
input bool RequireFVG = false;                     // Require Fair Value Gap (DISABLED)

input group "=== KILLZONE SETTINGS ==="
input bool UseLondonKZ = false;                    // Use London Killzone (DISABLED)
input bool UseNYKZ = false;                        // Use NY Killzone (DISABLED)
input int TimezoneOffset = 0;                      // Timezone offset from GMT

input group "=== TRADE MANAGEMENT ==="
input int MaxTradesPerDay = 20;                    // Maximum trades per day (TESTING)
input bool AllowExtraTrade = true;                 // Allow extra trade for high confidence
input bool EnableBreakEven = false;                // Enable break-even (DISABLED)
input bool EnableTrailing = false;                 // Enable trailing stop (DISABLED)

input group "=== VISUAL SETTINGS ==="
input bool ShowDashboard = true;                   // Show dashboard
input bool ShowDebugInfo = true;                   // Show debug information
input bool ShowOBZones = true;                     // Show Order Block zones

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CTrade g_trade;
int g_magicNumber;

// Simplified signal data
struct SimpleSignal {
    bool valid;
    bool isBullish;
    double entryPrice;
    double stopLoss;
    double takeProfit;
    double confidence;
    string reason;
};

SimpleSignal g_currentSignal;
DailyTradeData g_dailyData;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    Print("=== ICT Smart Money EA v4.02 DEBUG Initializing ===");
    
    // Initialize magic number
    g_magicNumber = 20241202;
    g_trade.SetExpertMagicNumber(g_magicNumber);
    
    // Initialize daily data
    ResetDailyData();
    
    // Initialize signal data
    ResetSignalData();
    
    Print("[INIT] DEBUG EA initialized successfully");
    Print("[INIT] Symbol: ", _Symbol, " | Magic: ", g_magicNumber);
    Print("[INIT] Min Confidence: ", MinConfidenceScore, " (RELAXED)");
    Print("[INIT] Killzones: DISABLED for testing");
    Print("[INIT] FVG Requirement: DISABLED for testing");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    ObjectsDeleteAll(0, "ICT_");
    Print("=== ICT Smart Money EA v4.02 DEBUG Stopped ===");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // Update daily data if new day
    CheckNewDay();
    
    // Update simple dashboard
    if(ShowDashboard) {
        UpdateSimpleDashboard();
    }
    
    // Check trade limits
    if(!CheckTradeLimit()) {
        if(ShowDebugInfo) Print("[DEBUG] Trade limit reached: ", g_dailyData.tradesCount, "/", MaxTradesPerDay);
        return;
    }
    
    // Check if already have position/order
    if(HasActivePosition() || HasPendingOrder()) {
        if(ShowDebugInfo) Print("[DEBUG] Already have active position or pending order");
        return;
    }
    
    // Execute simplified strategy
    ExecuteSimplifiedStrategy();
}

//+------------------------------------------------------------------+
//| Simplified Strategy Execution                                   |
//+------------------------------------------------------------------+
void ExecuteSimplifiedStrategy() {
    ResetSignalData();
    
    if(ShowDebugInfo) Print("[DEBUG] === Starting Strategy Analysis ===");
    
    // Step 1: Simple BOS Detection
    bool bosDetected = DetectSimpleBOS();
    if(!bosDetected) {
        if(ShowDebugInfo) Print("[DEBUG] No BOS detected");
        return;
    }
    
    // Step 2: Simple Order Block Detection
    bool obDetected = DetectSimpleOrderBlock();
    if(!obDetected) {
        if(ShowDebugInfo) Print("[DEBUG] No Order Block detected");
        return;
    }
    
    // Step 3: Calculate Simple Confidence
    g_currentSignal.confidence = CalculateSimpleConfidence();
    if(ShowDebugInfo) Print("[DEBUG] Confidence Score: ", g_currentSignal.confidence);
    
    // Step 4: Check confidence threshold
    if(g_currentSignal.confidence < MinConfidenceScore) {
        if(ShowDebugInfo) Print("[DEBUG] Low confidence: ", g_currentSignal.confidence, " < ", MinConfidenceScore);
        return;
    }
    
    // Step 5: Execute trade
    g_currentSignal.valid = true;
    ExecuteSimpleTrade();
}

//+------------------------------------------------------------------+
//| Simple BOS Detection                                            |
//+------------------------------------------------------------------+
bool DetectSimpleBOS() {
    double currentHigh = iHigh(_Symbol, PERIOD_M5, 0);
    double currentLow = iLow(_Symbol, PERIOD_M5, 0);
    
    // Find highest high and lowest low in lookback period
    double highestHigh = 0;
    double lowestLow = 999999;
    
    for(int i = 1; i <= BOS_Lookback; i++) {
        double high = iHigh(_Symbol, PERIOD_M5, i);
        double low = iLow(_Symbol, PERIOD_M5, i);
        
        if(high > highestHigh) highestHigh = high;
        if(low < lowestLow) lowestLow = low;
    }
    
    // Check for bullish BOS
    if(currentHigh > highestHigh) {
        g_currentSignal.isBullish = true;
        g_currentSignal.reason = "Bullish BOS detected";
        if(ShowDebugInfo) Print("[DEBUG] ", g_currentSignal.reason, " - Current High: ", currentHigh, " > Previous High: ", highestHigh);
        return true;
    }
    
    // Check for bearish BOS
    if(currentLow < lowestLow) {
        g_currentSignal.isBullish = false;
        g_currentSignal.reason = "Bearish BOS detected";
        if(ShowDebugInfo) Print("[DEBUG] ", g_currentSignal.reason, " - Current Low: ", currentLow, " < Previous Low: ", lowestLow);
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Simple Order Block Detection                                    |
//+------------------------------------------------------------------+
bool DetectSimpleOrderBlock() {
    // Look for the last strong candle before BOS
    for(int i = 1; i <= OB_Lookback; i++) {
        double open = iOpen(_Symbol, PERIOD_M5, i);
        double close = iClose(_Symbol, PERIOD_M5, i);
        double high = iHigh(_Symbol, PERIOD_M5, i);
        double low = iLow(_Symbol, PERIOD_M5, i);
        
        double bodySize = MathAbs(close - open);
        double totalRange = high - low;
        
        // Check for strong candle (body > 60% of total range)
        if(totalRange > 0 && bodySize / totalRange > 0.6) {
            bool isBullishCandle = (close > open);
            
            // For bullish signal, look for bearish OB (last bearish candle before bullish BOS)
            if(g_currentSignal.isBullish && !isBullishCandle) {
                g_currentSignal.entryPrice = (high + low) / 2;
                g_currentSignal.stopLoss = low - (SL_Buffer * _Point);
                g_currentSignal.takeProfit = g_currentSignal.entryPrice + ((g_currentSignal.entryPrice - g_currentSignal.stopLoss) * RR_Ratio);
                
                if(ShowDebugInfo) Print("[DEBUG] Bullish OB found at bar ", i, " - Entry: ", g_currentSignal.entryPrice);
                return true;
            }
            
            // For bearish signal, look for bullish OB (last bullish candle before bearish BOS)
            if(!g_currentSignal.isBullish && isBullishCandle) {
                g_currentSignal.entryPrice = (high + low) / 2;
                g_currentSignal.stopLoss = high + (SL_Buffer * _Point);
                g_currentSignal.takeProfit = g_currentSignal.entryPrice - ((g_currentSignal.stopLoss - g_currentSignal.entryPrice) * RR_Ratio);
                
                if(ShowDebugInfo) Print("[DEBUG] Bearish OB found at bar ", i, " - Entry: ", g_currentSignal.entryPrice);
                return true;
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Calculate Simple Confidence Score                               |
//+------------------------------------------------------------------+
double CalculateSimpleConfidence() {
    double score = 50; // Base score
    
    // Add points for strong momentum
    double close0 = iClose(_Symbol, PERIOD_M5, 0);
    double close3 = iClose(_Symbol, PERIOD_M5, 3);
    
    if(g_currentSignal.isBullish && close0 > close3) score += 20;
    if(!g_currentSignal.isBullish && close0 < close3) score += 20;
    
    // Add points for good risk/reward
    double slDistance = MathAbs(g_currentSignal.entryPrice - g_currentSignal.stopLoss);
    double tpDistance = MathAbs(g_currentSignal.takeProfit - g_currentSignal.entryPrice);
    
    if(tpDistance >= slDistance * 1.5) score += 15;
    
    // Add points for recent volatility
    double atr = CalculateATR(_Symbol, PERIOD_M5, 14);
    if(slDistance <= atr * 2) score += 15; // Good SL size relative to volatility
    
    return MathMin(100.0, score);
}

//+------------------------------------------------------------------+
//| Execute Simple Trade                                            |
//+------------------------------------------------------------------+
void ExecuteSimpleTrade() {
    if(ShowDebugInfo) {
        Print("[DEBUG] === EXECUTING TRADE ===");
        Print("[DEBUG] Direction: ", g_currentSignal.isBullish ? "BUY" : "SELL");
        Print("[DEBUG] Entry: ", g_currentSignal.entryPrice);
        Print("[DEBUG] SL: ", g_currentSignal.stopLoss);
        Print("[DEBUG] TP: ", g_currentSignal.takeProfit);
        Print("[DEBUG] Confidence: ", g_currentSignal.confidence);
    }
    
    // Calculate lot size (simple fixed risk)
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * (RiskPercent / 100.0);
    double slDistance = MathAbs(g_currentSignal.entryPrice - g_currentSignal.stopLoss);
    
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    double lotSize = riskAmount / ((slDistance / tickSize) * tickValue);
    
    // Normalize lot size
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lotSize = MathRound(lotSize / lotStep) * lotStep;
    lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
    
    if(ShowDebugInfo) Print("[DEBUG] Calculated Lot Size: ", lotSize);
    
    // Place order
    bool success = false;
    string comment = StringFormat("ICT_Debug_%.0f", g_currentSignal.confidence);
    
    if(g_currentSignal.isBullish) {
        success = g_trade.Buy(lotSize, _Symbol, 0, g_currentSignal.stopLoss, g_currentSignal.takeProfit, comment);
    } else {
        success = g_trade.Sell(lotSize, _Symbol, 0, g_currentSignal.stopLoss, g_currentSignal.takeProfit, comment);
    }
    
    if(success) {
        g_dailyData.tradesCount++;
        
        Print("🚀 [TRADE EXECUTED] ", (g_currentSignal.isBullish ? "BUY" : "SELL"), 
              " | Confidence: ", g_currentSignal.confidence,
              " | Lot: ", lotSize,
              " | Entry: ", g_currentSignal.entryPrice);
              
        // Draw visual elements
        DrawSimpleElements();
    } else {
        Print("❌ [ERROR] Failed to place order: ", g_trade.ResultRetcodeDescription());
        if(ShowDebugInfo) {
            Print("[DEBUG] Last Error: ", GetLastError());
            Print("[DEBUG] Account Free Margin: ", AccountInfoDouble(ACCOUNT_MARGIN_FREE));
        }
    }
}

//+------------------------------------------------------------------+
//| Helper Functions                                                |
//+------------------------------------------------------------------+
bool CheckTradeLimit() {
    return (g_dailyData.tradesCount < MaxTradesPerDay);
}

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

void CheckNewDay() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    datetime currentDate = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
    
    if(g_dailyData.date != currentDate) {
        ResetDailyData();
        g_dailyData.date = currentDate;
        if(ShowDebugInfo) Print("[DEBUG] New day detected, resetting daily data");
    }
}

void ResetDailyData() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    g_dailyData.date = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
    g_dailyData.tradesCount = 0;
    g_dailyData.totalProfit = 0;
    g_dailyData.wins = 0;
    g_dailyData.losses = 0;
}

void ResetSignalData() {
    g_currentSignal.valid = false;
    g_currentSignal.isBullish = false;
    g_currentSignal.entryPrice = 0;
    g_currentSignal.stopLoss = 0;
    g_currentSignal.takeProfit = 0;
    g_currentSignal.confidence = 0;
    g_currentSignal.reason = "";
}

double CalculateATR(string symbol, ENUM_TIMEFRAMES tf, int period) {
    double atr = 0;
    for(int i = 1; i <= period; i++) {
        double high = iHigh(symbol, tf, i);
        double low = iLow(symbol, tf, i);
        double prevClose = iClose(symbol, tf, i+1);
        
        double tr = MathMax(high - low, MathMax(MathAbs(high - prevClose), MathAbs(low - prevClose)));
        atr += tr;
    }
    return atr / period;
}

void UpdateSimpleDashboard() {
    string prefix = "ICT_Debug_";
    
    // Clear old labels
    ObjectsDeleteAll(0, prefix);
    
    // Create simple dashboard
    int yPos = 50;
    int lineHeight = 18;
    
    CreateLabel(prefix + "Header", "=== ICT DEBUG EA v4.02 ===", 20, yPos, clrYellow);
    yPos += lineHeight;
    
    CreateLabel(prefix + "Symbol", "Symbol: " + _Symbol, 20, yPos, clrWhite);
    yPos += lineHeight;
    
    CreateLabel(prefix + "Trades", StringFormat("Trades Today: %d/%d", g_dailyData.tradesCount, MaxTradesPerDay), 20, yPos, clrWhite);
    yPos += lineHeight;
    
    if(g_currentSignal.valid) {
        CreateLabel(prefix + "Signal", "Signal: " + g_currentSignal.reason, 20, yPos, clrLimeGreen);
        yPos += lineHeight;
        CreateLabel(prefix + "Confidence", StringFormat("Confidence: %.0f", g_currentSignal.confidence), 20, yPos, clrYellow);
    } else {
        CreateLabel(prefix + "Signal", "Signal: Scanning...", 20, yPos, clrGray);
    }
    
    ChartRedraw();
}

void CreateLabel(string name, string text, int x, int y, color clr) {
    ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
    ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void DrawSimpleElements() {
    if(!ShowOBZones) return;
    
    string prefix = "ICT_Trade_" + IntegerToString(TimeCurrent()) + "_";
    
    // Draw entry level
    string entryName = prefix + "Entry";
    ObjectCreate(0, entryName, OBJ_HLINE, 0, 0, g_currentSignal.entryPrice);
    ObjectSetInteger(0, entryName, OBJPROP_COLOR, clrYellow);
    ObjectSetInteger(0, entryName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, entryName, OBJPROP_WIDTH, 2);
    
    // Draw SL level
    string slName = prefix + "SL";
    ObjectCreate(0, slName, OBJ_HLINE, 0, 0, g_currentSignal.stopLoss);
    ObjectSetInteger(0, slName, OBJPROP_COLOR, clrRed);
    ObjectSetInteger(0, slName, OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(0, slName, OBJPROP_WIDTH, 1);
    
    // Draw TP level
    string tpName = prefix + "TP";
    ObjectCreate(0, tpName, OBJ_HLINE, 0, 0, g_currentSignal.takeProfit);
    ObjectSetInteger(0, tpName, OBJPROP_COLOR, clrLimeGreen);
    ObjectSetInteger(0, tpName, OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(0, tpName, OBJPROP_WIDTH, 1);
} 