#property copyright "Copyright 2024 - ICT Smart Money EA"
#property version   "3.00"
#property strict

#include <Trade\Trade.mqh>
#include "SimpleSession.mqh"
#include "RiskManager.mqh"
#include "LimitOrderManager.mqh"
#include "PartialTPManager.mqh"
#include "DrawUtils.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
// === ICT Strategy Parameters ===
input group "=== ICT Strategy Settings ==="
input double RiskPercent = 1.0;                    // Risk per trade (%)
input int SwingLookback = 5;                       // Swing High/Low lookback (3-5 bars)
input int BOS_Lookback = 20;                       // BOS detection lookback (20-50 bars)
input int SL_Buffer = 30;                          // SL buffer points (3 pips)
input double RR_Ratio = 2.0;                       // Risk:Reward ratio
input bool EnablePartialTP = true;                 // Enable 50% TP at 1:1 RR

// === Session & Time Settings ===
input group "=== Killzone Settings ==="
input bool UseLondonKZ = true;                     // Use London Killzone (14:00-17:00 Thai)
input bool UseNYKZ = true;                         // Use NY Killzone (19:30-23:00 Thai)
input int TimezoneOffset = 7;                      // Timezone offset from GMT (Thai = +7)

// === Risk Management ===
input group "=== Risk Management ==="
input int MaxTradesPerDay = 2;                     // Max trades per day per symbol
input int MaxOrdersPerSymbol = 1;                  // Max pending orders per symbol
input bool EnableTradeManagement = true;           // Enable break-even & trailing

// === Display Settings ===
input group "=== Display Settings ==="
input bool ShowKillzoneStatus = true;              // Show killzone status on chart
input bool ShowOrderBlocks = true;                 // Draw Order Blocks
input bool ShowSweepMarkers = true;                // Show Sweep markers
input bool ShowBOSLines = true;                    // Show BOS lines
input bool ShowStats = true;                       // Show statistics panel

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CLimitOrderManager* g_limitManager;
CPartialTPManager* g_partialTPManager;
CTrade g_trade;

// Magic Numbers (per symbol)
int g_magicBase = 20241201;

// Statistics
int g_totalTrades = 0;
int g_winTrades = 0;
int g_lossTrades = 0;
double g_totalProfit = 0;
double g_totalLoss = 0;

// Tracking variables
datetime g_lastSweepTime = 0;
datetime g_lastBOSTime = 0;
datetime g_lastOBTime = 0;
bool g_sweepDetected = false;
bool g_bosDetected = false;
double g_obHigh = 0, g_obLow = 0;
bool g_isBullishSetup = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    Print("=== ICT Smart Money EA v3.0 Started ===");
    
    // Initialize managers
    g_limitManager = new CLimitOrderManager();
    g_partialTPManager = new CPartialTPManager();
    
    // Set magic number
    int magicNumber = g_magicBase + StringToInteger(StringSubstr(_Symbol, 0, 3));
    g_trade.SetExpertMagicNumber(magicNumber);
    
    // Create UI elements
    if(ShowStats) CreateStatsPanel();
    if(ShowKillzoneStatus) CreateKillzonePanel();
    
    Print("[INIT] EA initialized for ", _Symbol);
    Print("[INIT] Magic Number: ", magicNumber);
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    // Clean up
    if(g_limitManager != NULL) {
        delete g_limitManager;
        g_limitManager = NULL;
    }
    if(g_partialTPManager != NULL) {
        delete g_partialTPManager;
        g_partialTPManager = NULL;
    }
    
    // Remove UI elements
    ObjectsDeleteAll(0, "ICT_");
    
    Print("=== ICT Smart Money EA Stopped ===");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // Update UI
    if(ShowStats) UpdateStatsPanel();
    if(ShowKillzoneStatus) UpdateKillzonePanel();
    
    // Manage pending orders and partial TPs
    if(g_limitManager != NULL) {
        g_limitManager.ManagePendingOrders();
    }
    if(g_partialTPManager != NULL && EnablePartialTP) {
        g_partialTPManager.ManagePartialTPs();
    }
    
    // Check if in killzone
    if(!CheckKillzone()) {
        return;
    }
    
    // Check trade limits
    if(!CheckTradeLimit()) {
        return;
    }
    
    // Check if we already have orders/positions
    if(HasActiveOrdersOrPositions()) {
        return;
    }
    
    // Main ICT Strategy Logic
    ExecuteICTStrategy();
}

//+------------------------------------------------------------------+
//| Check if in active killzone                                     |
//+------------------------------------------------------------------+
bool CheckKillzone() {
    bool inKillzone = false;
    
    if(UseLondonKZ && InLondonKillzone()) {
        inKillzone = true;
    }
    
    if(UseNYKZ && InNYKillzone()) {
        inKillzone = true;
    }
    
    return inKillzone;
}

//+------------------------------------------------------------------+
//| Check trade limits                                               |
//+------------------------------------------------------------------+
bool CheckTradeLimit() {
    return CheckTradeLimit(MaxTradesPerDay);
}

//+------------------------------------------------------------------+
//| Check if has active orders or positions                         |
//+------------------------------------------------------------------+
bool HasActiveOrdersOrPositions() {
    // Check positions
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionGetSymbol(i) == _Symbol) {
            return true;
        }
    }
    
    // Check pending orders
    if(g_limitManager != NULL) {
        if(g_limitManager.GetActiveOrdersCount(_Symbol) >= MaxOrdersPerSymbol) {
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Main ICT Strategy Execution                                     |
//+------------------------------------------------------------------+
void ExecuteICTStrategy() {
    // Step 1: Detect Liquidity Sweep
    if(DetectSweep()) {
        if(ShowSweepMarkers) DrawSweepMarker();
        g_sweepDetected = true;
        g_lastSweepTime = iTime(_Symbol, PERIOD_CURRENT, 0);
        Print("[SWEEP] Liquidity sweep detected at ", TimeToString(g_lastSweepTime));
    }
    
    // Step 2: Detect BOS (Break of Structure)
    if(g_sweepDetected && DetectBOS()) {
        if(ShowBOSLines) DrawBOSLine();
        g_bosDetected = true;
        g_lastBOSTime = iTime(_Symbol, PERIOD_CURRENT, 0);
        Print("[BOS] Break of Structure detected at ", TimeToString(g_lastBOSTime));
    }
    
    // Step 3: Find Order Block
    if(g_bosDetected && FindOrderBlock()) {
        if(ShowOrderBlocks) DrawOrderBlock();
        g_lastOBTime = iTime(_Symbol, PERIOD_CURRENT, 0);
        Print("[OB] Order Block found: ", g_obLow, " - ", g_obHigh);
        
        // Step 4: Place Limit Order
        PlaceLimitOrder();
    }
}

//+------------------------------------------------------------------+
//| Detect Liquidity Sweep                                          |
//+------------------------------------------------------------------+
bool DetectSweep() {
    // Get current and previous bars
    double currentHigh = iHigh(_Symbol, PERIOD_CURRENT, 0);
    double currentLow = iLow(_Symbol, PERIOD_CURRENT, 0);
    double currentClose = iClose(_Symbol, PERIOD_CURRENT, 0);
    
    // Find swing high/low in lookback period
    double swingHigh = 0, swingLow = 999999;
    for(int i = 1; i <= SwingLookback; i++) {
        double high = iHigh(_Symbol, PERIOD_CURRENT, i);
        double low = iLow(_Symbol, PERIOD_CURRENT, i);
        if(high > swingHigh) swingHigh = high;
        if(low < swingLow) swingLow = low;
    }
    
    // Check for sweep (false breakout)
    bool sweepHigh = (currentHigh > swingHigh) && (currentClose < swingHigh);
    bool sweepLow = (currentLow < swingLow) && (currentClose > swingLow);
    
    if(sweepHigh) {
        g_isBullishSetup = false; // Bearish setup after high sweep
        return true;
    }
    
    if(sweepLow) {
        g_isBullishSetup = true;  // Bullish setup after low sweep
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Detect Break of Structure                                       |
//+------------------------------------------------------------------+
bool DetectBOS() {
    double currentHigh = iHigh(_Symbol, PERIOD_CURRENT, 0);
    double currentLow = iLow(_Symbol, PERIOD_CURRENT, 0);
    
    // Find highest high and lowest low in BOS lookback
    double highestHigh = 0, lowestLow = 999999;
    for(int i = 1; i <= BOS_Lookback; i++) {
        double high = iHigh(_Symbol, PERIOD_CURRENT, i);
        double low = iLow(_Symbol, PERIOD_CURRENT, i);
        if(high > highestHigh) highestHigh = high;
        if(low < lowestLow) lowestLow = low;
    }
    
    // Check for BOS in opposite direction of sweep
    if(g_isBullishSetup) {
        // After low sweep, look for bullish BOS (break above previous high)
        return (currentHigh > highestHigh);
    } else {
        // After high sweep, look for bearish BOS (break below previous low)
        return (currentLow < lowestLow);
    }
}

//+------------------------------------------------------------------+
//| Find Order Block                                                |
//+------------------------------------------------------------------+
bool FindOrderBlock() {
    // Look for the last opposite candle before BOS
    for(int i = 1; i <= BOS_Lookback; i++) {
        double open = iOpen(_Symbol, PERIOD_CURRENT, i);
        double close = iClose(_Symbol, PERIOD_CURRENT, i);
        double high = iHigh(_Symbol, PERIOD_CURRENT, i);
        double low = iLow(_Symbol, PERIOD_CURRENT, i);
        
        bool isBearishCandle = (close < open);
        bool isBullishCandle = (close > open);
        
        // Find opposite candle to BOS direction
        if(g_isBullishSetup && isBearishCandle) {
            // Bullish setup needs bearish OB
            g_obHigh = high;
            g_obLow = low;
            return true;
        } else if(!g_isBullishSetup && isBullishCandle) {
            // Bearish setup needs bullish OB
            g_obHigh = high;
            g_obLow = low;
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Place Limit Order at Order Block                                |
//+------------------------------------------------------------------+
void PlaceLimitOrder() {
    if(g_limitManager == NULL) return;
    
    double lotSize = CalculateLot(RiskPercent, SL_Buffer + 50, _Symbol); // Estimate SL distance
    
    if(g_isBullishSetup) {
        // Place Buy Limit in bearish OB
        double entryPrice = (g_obHigh + g_obLow) / 2; // Middle of OB
        
        bool result = g_limitManager.PlaceBuyLimit(_Symbol, entryPrice, g_obLow, 
                                                  lotSize, SL_Buffer, RR_Ratio, 
                                                  "ICT_BullishSetup");
        if(result) {
            Print("🚀 [ENTRY] Buy Limit placed at OB: ", entryPrice);
            g_totalTrades++;
            IncrementTradeCount();
            ResetSignals();
        }
    } else {
        // Place Sell Limit in bullish OB
        double entryPrice = (g_obHigh + g_obLow) / 2; // Middle of OB
        
        bool result = g_limitManager.PlaceSellLimit(_Symbol, entryPrice, g_obHigh,
                                                   lotSize, SL_Buffer, RR_Ratio,
                                                   "ICT_BearishSetup");
        if(result) {
            Print("🚀 [ENTRY] Sell Limit placed at OB: ", entryPrice);
            g_totalTrades++;
            IncrementTradeCount();
            ResetSignals();
        }
    }
}

//+------------------------------------------------------------------+
//| Reset signals after order placement                             |
//+------------------------------------------------------------------+
void ResetSignals() {
    g_sweepDetected = false;
    g_bosDetected = false;
    g_obHigh = 0;
    g_obLow = 0;
}

//+------------------------------------------------------------------+
//| Draw Sweep Marker                                               |
//+------------------------------------------------------------------+
void DrawSweepMarker() {
    string name = "ICT_Sweep_" + TimeToString(TimeCurrent());
    datetime time = iTime(_Symbol, PERIOD_CURRENT, 0);
    double price = g_isBullishSetup ? iLow(_Symbol, PERIOD_CURRENT, 0) : iHigh(_Symbol, PERIOD_CURRENT, 0);
    
    DrawSweep(name, time, price, g_isBullishSetup ? clrLime : clrRed, 
              g_isBullishSetup ? 241 : 242);
}

//+------------------------------------------------------------------+
//| Draw BOS Line                                                   |
//+------------------------------------------------------------------+
void DrawBOSLine() {
    string name = "ICT_BOS_" + TimeToString(TimeCurrent());
    datetime time1 = iTime(_Symbol, PERIOD_CURRENT, 1);
    datetime time2 = iTime(_Symbol, PERIOD_CURRENT, 0);
    double price = g_isBullishSetup ? iHigh(_Symbol, PERIOD_CURRENT, 0) : iLow(_Symbol, PERIOD_CURRENT, 0);
    
    DrawBOS(name, time1, price, time2, price, g_isBullishSetup ? clrLime : clrRed);
}

//+------------------------------------------------------------------+
//| Draw Order Block                                                |
//+------------------------------------------------------------------+
void DrawOrderBlock() {
    string name = "ICT_OB_" + TimeToString(TimeCurrent());
    datetime time1 = g_lastOBTime;
    datetime time2 = time1 + PeriodSeconds(PERIOD_CURRENT) * 10; // Extend 10 bars
    
    DrawOrderBlock(name, time1, time2, g_obHigh, g_obLow, 
                   g_isBullishSetup ? clrDarkGreen : clrDarkRed);
}

//+------------------------------------------------------------------+
//| Create Statistics Panel                                         |
//+------------------------------------------------------------------+
void CreateStatsPanel() {
    // Create background panel
    ObjectCreate(0, "ICT_StatsPanel", OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "ICT_StatsPanel", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "ICT_StatsPanel", OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, "ICT_StatsPanel", OBJPROP_YDISTANCE, 50);
    ObjectSetInteger(0, "ICT_StatsPanel", OBJPROP_XSIZE, 320);
    ObjectSetInteger(0, "ICT_StatsPanel", OBJPROP_YSIZE, 220);
    ObjectSetInteger(0, "ICT_StatsPanel", OBJPROP_BGCOLOR, clrDarkBlue);
    ObjectSetInteger(0, "ICT_StatsPanel", OBJPROP_BORDER_TYPE, BORDER_FLAT);
    
    // Create text label
    ObjectCreate(0, "ICT_StatsText", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "ICT_StatsText", OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, "ICT_StatsText", OBJPROP_XDISTANCE, 20);
    ObjectSetInteger(0, "ICT_StatsText", OBJPROP_YDISTANCE, 60);
    ObjectSetInteger(0, "ICT_StatsText", OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, "ICT_StatsText", OBJPROP_FONTSIZE, 9);
}

//+------------------------------------------------------------------+
//| Update Statistics Panel                                         |
//+------------------------------------------------------------------+
void UpdateStatsPanel() {
    if(!ShowStats) return;
    
    double winRate = (g_totalTrades > 0) ? (double)g_winTrades / g_totalTrades * 100 : 0;
    double profitFactor = (g_totalLoss != 0) ? g_totalProfit / MathAbs(g_totalLoss) : 0;
    
    // Get position info
    string positionInfo = "No Active Position";
    if(g_partialTPManager != NULL) {
        positionInfo = g_partialTPManager.GetPositionInfo(_Symbol);
    }
    
    string statsText = StringFormat(
        "ICT Smart Money EA v3.0\n" +
        "═══════════════════════\n" +
        "Symbol: %s\n" +
        "Total Trades: %d\n" +
        "Win Rate: %.1f%%\n" +
        "Wins: %d | Loss: %d\n" +
        "Profit Factor: %.2f\n" +
        "Risk per Trade: %.1f%%\n" +
        "RR Ratio: %.1f:1\n" +
        "═══════════════════════\n" +
        "Signals Status:\n" +
        "Sweep: %s\n" +
        "BOS: %s\n" +
        "OB Ready: %s\n" +
        "═══════════════════════\n" +
        "%s",
        _Symbol, g_totalTrades, winRate, g_winTrades, g_lossTrades,
        profitFactor, RiskPercent, RR_Ratio,
        g_sweepDetected ? "✓" : "✗",
        g_bosDetected ? "✓" : "✗",
        (g_obHigh > 0) ? "✓" : "✗",
        positionInfo
    );
    
    ObjectSetString(0, "ICT_StatsText", OBJPROP_TEXT, statsText);
}

//+------------------------------------------------------------------+
//| Create Killzone Panel                                           |
//+------------------------------------------------------------------+
void CreateKillzonePanel() {
    ObjectCreate(0, "ICT_KZPanel", OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "ICT_KZPanel", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
    ObjectSetInteger(0, "ICT_KZPanel", OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, "ICT_KZPanel", OBJPROP_YDISTANCE, 50);
    ObjectSetInteger(0, "ICT_KZPanel", OBJPROP_XSIZE, 200);
    ObjectSetInteger(0, "ICT_KZPanel", OBJPROP_YSIZE, 100);
    ObjectSetInteger(0, "ICT_KZPanel", OBJPROP_BGCOLOR, clrDarkGreen);
    ObjectSetInteger(0, "ICT_KZPanel", OBJPROP_BORDER_TYPE, BORDER_FLAT);
    
    ObjectCreate(0, "ICT_KZText", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "ICT_KZText", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
    ObjectSetInteger(0, "ICT_KZText", OBJPROP_XDISTANCE, 190);
    ObjectSetInteger(0, "ICT_KZText", OBJPROP_YDISTANCE, 60);
    ObjectSetInteger(0, "ICT_KZText", OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, "ICT_KZText", OBJPROP_FONTSIZE, 10);
}

//+------------------------------------------------------------------+
//| Update Killzone Panel                                           |
//+------------------------------------------------------------------+
void UpdateKillzonePanel() {
    if(!ShowKillzoneStatus) return;
    
    bool londonActive = InLondonKillzone();
    bool nyActive = InNYKillzone();
    bool anyActive = londonActive || nyActive;
    
    // Update panel color
    color panelColor = anyActive ? clrDarkGreen : clrDarkRed;
    ObjectSetInteger(0, "ICT_KZPanel", OBJPROP_BGCOLOR, panelColor);
    
    MqlDateTime dt;
    TimeToStruct(TimeCurrent() + TimezoneOffset*3600, dt);
    
    string kzText = StringFormat(
        "KILLZONE STATUS\n" +
        "Thai Time: %02d:%02d\n" +
        "London: %s\n" +
        "NY: %s\n" +
        "Trading: %s",
        dt.hour, dt.min,
        londonActive ? "ACTIVE" : "CLOSED",
        nyActive ? "ACTIVE" : "CLOSED",
        anyActive ? "ALLOWED" : "BLOCKED"
    );
    
    ObjectSetString(0, "ICT_KZText", OBJPROP_TEXT, kzText);
}

//+------------------------------------------------------------------+
//| Trade transaction function                                       |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                       const MqlTradeRequest& request,
                       const MqlTradeResult& result) {
    
    // Handle order execution (limit order filled)
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD) {
        
        // Check if it's our order
        if(trans.symbol == _Symbol) {
            
            ulong positionTicket = trans.position;
            
            // Select the position
            if(PositionSelectByTicket(positionTicket)) {
                
                double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double sl = PositionGetDouble(POSITION_SL);
                double tp = PositionGetDouble(POSITION_TP);
                double lot = PositionGetDouble(POSITION_VOLUME);
                ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                
                // Calculate partial TP levels if enabled
                if(EnablePartialTP && g_partialTPManager != NULL) {
                    
                    double slDistance = MathAbs(entryPrice - sl);
                    double tp1, tp2;
                    
                    if(posType == POSITION_TYPE_BUY) {
                        tp1 = entryPrice + slDistance;      // 1:1 RR
                        tp2 = entryPrice + (slDistance * 2); // 1:2 RR
                    } else {
                        tp1 = entryPrice - slDistance;      // 1:1 RR
                        tp2 = entryPrice - (slDistance * 2); // 1:2 RR
                    }
                    
                    // Add to partial TP management
                    g_partialTPManager.AddPosition(positionTicket, _Symbol, 
                                                  entryPrice, sl, tp1, tp2, lot);
                    
                    Print("🎯 [PARTIAL TP] Position added for management");
                    Print("   Entry: ", entryPrice, " | SL: ", sl);
                    Print("   TP1 (1:1): ", tp1, " | TP2 (1:2): ", tp2);
                }
            }
        }
    }
    
    // Handle position close
    if(trans.type == TRADE_TRANSACTION_HISTORY_ADD) {
        if(trans.symbol == _Symbol) {
            
            // Get deal profit
            double dealProfit = 0;
            if(HistoryDealSelect(trans.deal)) {
                dealProfit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
            }
            
            // Update statistics
            if(dealProfit > 0) {
                g_winTrades++;
                g_totalProfit += dealProfit;
            } else if(dealProfit < 0) {
                g_lossTrades++;
                g_totalLoss += dealProfit;
            }
            
            Print("📊 [TRADE CLOSED] P/L: ", dealProfit, " | Total Trades: ", g_totalTrades);
        }
    }
} 