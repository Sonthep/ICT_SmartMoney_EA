#property copyright "Copyright 2024"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>
#include "SimpleSession.mqh"
#include "RiskManager.mqh"
#include "OB_BOS_Scan.mqh"
#include "TradeManager.mqh"
#include "DrawUtils.mqh"

// Core ICT Parameters
input double RiskPercent = 1.0; // ความเสี่ยงต่อการเทรดเป็นเปอร์เซ็นต์
input int BOS_Lookback = 10; // จำนวนแท่งย้อนหลังสำหรับ BOS/OB
input int OB_Buffer_Points = 30; // Buffer สำหรับ SL (3 pips)
input int MaxTradesPerDay = 2; // จำกัดจำนวนเทรดต่อวัน

// Session Parameters (now using simple GMT-based sessions)
// London: 08:00-17:00 GMT, NY: 13:00-22:00 GMT
input int GMT_Offset = 0; // ปรับชดเชยเวลา (ไม่ใช้แล้ว)

// Optional Features
input bool EnableTradeManagement = true; // เปิดใช้ Break Even + Trailing
input bool ShowStats = true; // แสดงสถิติบนชาร์ต
input bool IgnoreSessionFilter = true; // สำหรับการทดสอบ - ข้าม session filter

// Global Statistics Variables
int totalTrades = 0;
int winTrades = 0;
int lossTrades = 0;
double totalProfit = 0;
double totalLoss = 0;
double maxDrawdown = 0;
double peakBalance = 0;

int OnInit() {
    // Disable session box drawing to avoid string parsing errors
    // DrawSessionBox("LondonKZ", London_KZ, clrBlue, "London");
    // DrawSessionBox("NYKZ", NY_KZ, clrRed, "NY");
    
    // Initialize statistics
    peakBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    
    if(ShowStats) {
        CreateStatsPanel();
    }
    
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
    // Clean up stats panel
    if(ShowStats) {
        ObjectDelete(0, "StatsPanel");
        ObjectDelete(0, "StatsText");
    }
}

void CreateStatsPanel() {
    // Create stats display panel
    if(ObjectFind(0, "StatsPanel") == -1) {
        ObjectCreate(0, "StatsPanel", OBJ_RECTANGLE_LABEL, 0, 0, 0);
        ObjectSetInteger(0, "StatsPanel", OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, "StatsPanel", OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(0, "StatsPanel", OBJPROP_YDISTANCE, 50);
        ObjectSetInteger(0, "StatsPanel", OBJPROP_XSIZE, 250);
        ObjectSetInteger(0, "StatsPanel", OBJPROP_YSIZE, 150);
        ObjectSetInteger(0, "StatsPanel", OBJPROP_BGCOLOR, clrDarkBlue);
        ObjectSetInteger(0, "StatsPanel", OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, "StatsPanel", OBJPROP_COLOR, clrWhite);
    }
    
    if(ObjectFind(0, "StatsText") == -1) {
        ObjectCreate(0, "StatsText", OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, "StatsText", OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, "StatsText", OBJPROP_XDISTANCE, 20);
        ObjectSetInteger(0, "StatsText", OBJPROP_YDISTANCE, 60);
        ObjectSetInteger(0, "StatsText", OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, "StatsText", OBJPROP_FONTSIZE, 10);
    }
}

void UpdateStats() {
    if(!ShowStats) return;
    
    double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    if(currentBalance > peakBalance) peakBalance = currentBalance;
    
    double currentDrawdown = (peakBalance - currentBalance) / peakBalance * 100;
    if(currentDrawdown > maxDrawdown) maxDrawdown = currentDrawdown;
    
    double winRate = (totalTrades > 0) ? (double)winTrades / totalTrades * 100 : 0;
    double avgWin = (winTrades > 0) ? totalProfit / winTrades : 0;
    double avgLoss = (lossTrades > 0) ? totalLoss / lossTrades : 0;
    double profitFactor = (totalLoss != 0) ? totalProfit / MathAbs(totalLoss) : 0;
    
    string sessionStatus = "";
    if(IgnoreSessionFilter) {
        sessionStatus = "Session: DISABLED";
    } else {
        sessionStatus = StringFormat("Session: %s", 
            InAnyTradingSession() ? "ACTIVE" : "CLOSED");
    }
    
    string statsText = StringFormat(
        "ICT EA Statistics\n" +
        "─────────────────\n" +
        "%s\n" +
        "Total Trades: %d\n" +
        "Win Rate: %.1f%%\n" +
        "Wins: %d | Loss: %d\n" +
        "Avg Win: $%.2f\n" +
        "Avg Loss: $%.2f\n" +
        "Profit Factor: %.2f\n" +
        "Max DD: %.2f%%\n" +
        "Risk: %.1f%% per trade",
        sessionStatus, totalTrades, winRate, winTrades, lossTrades,
        avgWin, avgLoss, profitFactor, maxDrawdown, RiskPercent
    );
    
    ObjectSetString(0, "StatsText", OBJPROP_TEXT, statsText);
}

void OnTick() {
    // Update statistics
    UpdateStats();
    
    // เช็คว่า position ถูกปิดแล้วหรือไม่
    static int lastPositionCount = 0;
    static double lastAccountBalance = 0;
    int currentPositionCount = PositionsTotal();
    double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    
    // Track closed positions and update statistics
    if(lastPositionCount > 0 && currentPositionCount == 0) {
        // Position ถูกปิดแล้ว - อัพเดทสถิติ
        double profit = currentBalance - lastAccountBalance;
        if(profit > 0) {
            winTrades++;
            totalProfit += profit;
        } else if(profit < 0) {
            lossTrades++;
            totalLoss += profit;
        }
        
        // รีเซ็ต signal tracking
        ResetSignalTracking();
        Print("[DEBUG] Position closed - Profit: ", profit, " Win/Loss: ", winTrades, "/", lossTrades);
    }
    
    // Update balance tracking
    if(currentPositionCount == 0) {
        lastAccountBalance = currentBalance;
    }
    
    lastPositionCount = currentPositionCount;
    
    // Simple Trade Management (Break Even + Trailing)
    if(EnableTradeManagement && PositionsTotal() > 0) {
        ManageOpenTrades(200, 50, 100); // Fixed values: Trail start, Trail step, Break even
    }
    
    // เช็คว่ามี position เปิดอยู่แล้วหรือไม่
    if(PositionsTotal() > 0) {
        return;
    }
    
    if(!CheckTradeLimit(MaxTradesPerDay)) {
        Print("[DEBUG] Trade limit reached");
        return;
    }
    
    // Session filter (can be disabled for testing)
    if(!IgnoreSessionFilter) {
        bool inSession = InAnyTradingSession();
        if(!inSession) {
            static datetime lastSessionDebug = 0;
            if(TimeCurrent() - lastSessionDebug > 300) { // Debug every 5 minutes
                PrintSessionInfo();
                lastSessionDebug = TimeCurrent();
            }
            return;
        } else {
            static bool sessionStartLogged = false;
            if(!sessionStartLogged) {
                Print("[DEBUG] Trading session ACTIVE. Starting analysis...");
                PrintSessionInfo();
                sessionStartLogged = true;
            }
        }
    } else {
        static datetime lastIgnoreDebug = 0;
        if(TimeCurrent() - lastIgnoreDebug > 300) { // Debug every 5 minutes
            Print("[DEBUG] Session filter DISABLED for testing");
            PrintSessionInfo();
            lastIgnoreDebug = TimeCurrent();
        }
    }

    SymbolStatus status;
    status.symbol = _Symbol;
    ScanSymbol(status, PERIOD_M15, BOS_Lookback, GMT_Offset); // Fixed M15 timeframe
    
    // Debug basic status
    static datetime lastBasicDebug = 0;
    if(TimeCurrent() - lastBasicDebug > 60) { // Every minute
        Print("[MAIN DEBUG] Time: ", TimeToString(TimeCurrent()));
        Print("[MAIN DEBUG] M15 - BOS: ", status.hasBOS_M15, " Sweep: ", status.hasSweep_M15);
        Print("[MAIN DEBUG] M5 - BOS: ", status.hasBOS_M5, " Sweep: ", status.hasSweep_M5);
        Print("[MAIN DEBUG] Can Entry: ", status.canEntry, " Positions: ", PositionsTotal());
        lastBasicDebug = TimeCurrent();
    }
    
    // Debug info
    if(status.hasSweep_M15 || status.hasOB_M15 || status.hasBOS_M15 || status.hasSweep_M5 || status.hasOB_M5 || status.hasBOS_M5) {
        Print("[DEBUG] M15 Filter - BOS:", status.hasBOS_M15, " OB:", status.hasOB_M15, " Sweep:", status.hasSweep_M15, " PriceInOB:", status.priceInOB_M15);
        Print("[DEBUG] M5 Entry - BOS:", status.hasBOS_M5, " OB:", status.hasOB_M5, " Sweep:", status.hasSweep_M5, " CanEntry:", status.canEntry);
    }
    
    // วาด M15 Sweep
    if(status.hasSweep_M15) {
        datetime currentTime = iTime(_Symbol, PERIOD_M15, 0);
        double currentHigh = iHigh(_Symbol, PERIOD_M15, 0);
        double currentLow = iLow(_Symbol, PERIOD_M15, 0);
        double prevHigh = iHigh(_Symbol, PERIOD_M15, 1);
        double prevLow = iLow(_Symbol, PERIOD_M15, 1);
        
        if(currentHigh > prevHigh) {
            DrawSweep("M15_Sweep_High_" + TimeToString(currentTime), currentTime, currentHigh, clrYellow, 233);
        }
        if(currentLow < prevLow) {
            DrawSweep("M15_Sweep_Low_" + TimeToString(currentTime), currentTime, currentLow, clrOrange, 234);
        }
    }
    
    // วาด M15 BOS
    if(status.hasBOS_M15) {
        datetime currentTime = iTime(_Symbol, PERIOD_M15, 0);
        datetime prevTime = iTime(_Symbol, PERIOD_M15, 1);
        double currentHigh = iHigh(_Symbol, PERIOD_M15, 0);
        double currentLow = iLow(_Symbol, PERIOD_M15, 0);
        
        if(status.isBullishBOS_M15) {
            DrawBOS("M15_BOS_High_" + TimeToString(currentTime), prevTime, currentHigh, currentTime, currentHigh, clrLime);
        } else {
            DrawBOS("M15_BOS_Low_" + TimeToString(currentTime), prevTime, currentLow, currentTime, currentLow, clrRed);
        }
    }
    
    // วาด M15 Order Block
    if(status.hasOB_M15) {
        datetime currentTime = iTime(_Symbol, PERIOD_M15, 0);
        datetime obEndTime = currentTime + PeriodSeconds(PERIOD_M15);
        
        if(status.isBullishBOS_M15) {
            DrawOrderBlock("M15_OB_Bear_" + TimeToString(currentTime), currentTime, obEndTime, status.obHigh_M15, status.obLow_M15, clrMaroon);
        } else {
            DrawOrderBlock("M15_OB_Bull_" + TimeToString(currentTime), currentTime, obEndTime, status.obHigh_M15, status.obLow_M15, clrDarkGreen);
        }
    }
    
    // วาด M5 Sweep
    if(status.hasSweep_M5) {
        datetime currentTime = iTime(_Symbol, PERIOD_M5, 0);
        double currentHigh = iHigh(_Symbol, PERIOD_M5, 0);
        double currentLow = iLow(_Symbol, PERIOD_M5, 0);
        double prevHigh = iHigh(_Symbol, PERIOD_M5, 1);
        double prevLow = iLow(_Symbol, PERIOD_M5, 1);
        
        if(currentHigh > prevHigh && status.isBullishBOS_M15) {
            DrawSweep("M5_Sweep_High_" + TimeToString(currentTime), currentTime, currentHigh, clrGold, 241);
        }
        if(currentLow < prevLow && !status.isBullishBOS_M15) {
            DrawSweep("M5_Sweep_Low_" + TimeToString(currentTime), currentTime, currentLow, clrOrangeRed, 242);
        }
    }
    
    // วาด M5 Order Block
    if(status.hasOB_M5) {
        datetime currentTime = iTime(_Symbol, PERIOD_M5, 0);
        datetime obEndTime = currentTime + PeriodSeconds(PERIOD_M5);
        
        if(status.isBullishBOS_M5) {
            DrawOrderBlock("M5_OB_Bear_" + TimeToString(currentTime), currentTime, obEndTime, status.obHigh_M5, status.obLow_M5, clrDarkRed);
        } else {
            DrawOrderBlock("M5_OB_Bull_" + TimeToString(currentTime), currentTime, obEndTime, status.obHigh_M5, status.obLow_M5, clrForestGreen);
        }
    }
    
    if(status.canEntry) {
        Print("🚀 [ENTRY SIGNAL] 🚀");
        Print("M15 Filter: BOS=", status.hasBOS_M15, " Sweep=", status.hasSweep_M15);
        Print("M5 Trigger: BOS=", status.hasBOS_M5, " Sweep=", status.hasSweep_M5);
        Print("Direction: ", status.isBullishBOS_M5 ? "BUY" : "SELL");
        
        double lot = CalculateLot(RiskPercent, 300, status.symbol); // Fixed SL points for lot calculation
        Print("[ENTRY] Placing order with lot:", lot, " at time:", TimeToString(status.lastSignalTime));
        PlaceEntryOrder(status, lot, PERIOD_M5, 300, 600, OB_Buffer_Points); // Fixed values
        
        // Update trade statistics and increment trade count
        totalTrades++;
        IncrementTradeCount(); // Add this function call
    }
    
    // Disable session drawing to avoid string parsing errors
    // DrawSessionText("LondonKZ", London_KZ, clrBlue, "London");
    // DrawSessionText("NYKZ", NY_KZ, clrRed, "NY");
} 