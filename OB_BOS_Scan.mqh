#ifndef __OB_BOS_SCAN_MQH__
#define __OB_BOS_SCAN_MQH__

#include "SessionUtils.mqh"

struct SymbolStatus {
    string symbol;
    bool inLondon;
    bool inNY;
    
    // M15 Analysis (Filter)
    bool hasSweep_M15;
    bool hasOB_M15;
    bool hasBOS_M15;
    double obHigh_M15;
    double obLow_M15;
    bool priceInOB_M15;
    bool isBullishBOS_M15;
    
    // M5 Analysis (Entry)
    bool hasSweep_M5;
    bool hasOB_M5;
    bool hasBOS_M5;
    double obHigh_M5;
    double obLow_M5;
    bool isBullishBOS_M5;
    
    int tradesToday;
    bool canEntry;
    datetime lastSignalTime;
};

// Static variables for tracking
static datetime lastProcessedTime_M15 = 0;
static datetime lastProcessedTime_M5 = 0;
static bool m15FilterPassed = false;

void ScanSymbol(SymbolStatus &status, ENUM_TIMEFRAMES tf, int bosLookback, int gmtOffset) {
    status.inLondon = InKillzone("14:00-17:00", gmtOffset, status.symbol);
    status.inNY     = InKillzone("19:30-23:00", gmtOffset, status.symbol);
    
    // Step 1: Analyze M15 for Filter
    AnalyzeM15Filter(status, bosLookback);
    
    // Step 2: If M15 filter passed, analyze M5 for Entry
    if(m15FilterPassed) {
        AnalyzeM5Entry(status, bosLookback);
    } else {
        // Reset M5 analysis if M15 filter not passed
        status.hasSweep_M5 = false;
        status.hasOB_M5 = false;
        status.hasBOS_M5 = false;
        status.canEntry = false;
    }
    
    status.tradesToday = 0;
}

// ฟังก์ชันวิเคราะห์ M15 เป็น Filter
void AnalyzeM15Filter(SymbolStatus &status, int bosLookback) {
    ENUM_TIMEFRAMES tf = PERIOD_M15;
    
    datetime currentBarTime = iTime(status.symbol, tf, 0);
    double currentHigh = iHigh(status.symbol, tf, 0);
    double currentLow = iLow(status.symbol, tf, 0);
    double currentClose = iClose(status.symbol, tf, 0);
    
    // 1. BOS Detection on M15
    double highestHigh = 0, lowestLow = 999999;
    for(int i=1; i<=bosLookback; i++) {
        double h = iHigh(status.symbol, tf, i);
        double l = iLow(status.symbol, tf, i);
        if(h > highestHigh) highestHigh = h;
        if(l < lowestLow) lowestLow = l;
    }
    
    bool bosUp = (currentHigh > highestHigh);
    bool bosDown = (currentLow < lowestLow);
    status.hasBOS_M15 = bosUp || bosDown;
    status.isBullishBOS_M15 = bosUp;
    
    // 2. Sweep Detection on M15
    double prevHigh = iHigh(status.symbol, tf, 1);
    double prevLow = iLow(status.symbol, tf, 1);
    status.hasSweep_M15 = (currentHigh > prevHigh) || (currentLow < prevLow);
    
    // 3. Order Block Detection on M15
    status.hasOB_M15 = false;
    status.obHigh_M15 = 0;
    status.obLow_M15 = 0;
    
    if(status.hasBOS_M15) {
        for(int i=1; i<=bosLookback; i++) {
            double open = iOpen(status.symbol, tf, i);
            double close = iClose(status.symbol, tf, i);
            double high = iHigh(status.symbol, tf, i);
            double low = iLow(status.symbol, tf, i);
            
            bool isBearishCandle = (close < open);
            bool isBullishCandle = (close > open);
            
            // หา OB ตรงข้ามกับทิศทาง BOS
            if((status.isBullishBOS_M15 && isBearishCandle) || (!status.isBullishBOS_M15 && isBullishCandle)) {
                status.hasOB_M15 = true;
                status.obHigh_M15 = high;
                status.obLow_M15 = low;
                break;
            }
        }
    }
    
    // 4. Check if price returned to OB zone on M15
    status.priceInOB_M15 = false;
    if(status.hasOB_M15) {
        status.priceInOB_M15 = (currentLow <= status.obHigh_M15 && currentHigh >= status.obLow_M15);
    }
    
    // M15 Filter: BOS + OB + Sweep + Price in OB
    bool newM15Bar = (currentBarTime != lastProcessedTime_M15);
    m15FilterPassed = status.hasBOS_M15 && status.hasOB_M15 && status.hasSweep_M15 && status.priceInOB_M15;
    
    if(m15FilterPassed && newM15Bar) {
        lastProcessedTime_M15 = currentBarTime;
        Print("[M15 FILTER] PASSED - BOS:", status.isBullishBOS_M15 ? "UP" : "DOWN", 
              " OB Zone:", status.obLow_M15, "-", status.obHigh_M15, " Price in OB: YES");
    }
}

// ฟังก์ชันวิเคราะห์ M5 สำหรับ Entry
void AnalyzeM5Entry(SymbolStatus &status, int bosLookback) {
    ENUM_TIMEFRAMES tf = PERIOD_M5;
    
    datetime currentBarTime = iTime(status.symbol, tf, 0);
    double currentHigh = iHigh(status.symbol, tf, 0);
    double currentLow = iLow(status.symbol, tf, 0);
    double currentClose = iClose(status.symbol, tf, 0);
    
    // 1. Sweep Detection on M5 (same direction as M15)
    double prevHigh = iHigh(status.symbol, tf, 1);
    double prevLow = iLow(status.symbol, tf, 1);
    
    bool sweepUp = (currentHigh > prevHigh);
    bool sweepDown = (currentLow < prevLow);
    
    // Sweep ต้องเป็นทิศทางเดียวกับ M15 BOS
    if(status.isBullishBOS_M15) {
        status.hasSweep_M5 = sweepUp;  // Bullish BOS ต้องมี Sweep ขึ้น
    } else {
        status.hasSweep_M5 = sweepDown; // Bearish BOS ต้องมี Sweep ลง
    }
    
    // 2. BOS Detection on M5
    double highestHigh = 0, lowestLow = 999999;
    for(int i=1; i<=bosLookback; i++) {
        double h = iHigh(status.symbol, tf, i);
        double l = iLow(status.symbol, tf, i);
        if(h > highestHigh) highestHigh = h;
        if(l < lowestLow) lowestLow = l;
    }
    
    bool bosUp = (currentHigh > highestHigh);
    bool bosDown = (currentLow < lowestLow);
    status.hasBOS_M5 = bosUp || bosDown;
    status.isBullishBOS_M5 = bosUp;
    
    // BOS M5 ต้องเป็นทิศทางเดียวกับ M15
    bool sameDirBOS = (status.isBullishBOS_M15 == status.isBullishBOS_M5);
    
    // 3. Order Block Detection on M5
    status.hasOB_M5 = false;
    status.obHigh_M5 = 0;
    status.obLow_M5 = 0;
    
    if(status.hasBOS_M5 && sameDirBOS) {
        for(int i=1; i<=bosLookback; i++) {
            double open = iOpen(status.symbol, tf, i);
            double close = iClose(status.symbol, tf, i);
            double high = iHigh(status.symbol, tf, i);
            double low = iLow(status.symbol, tf, i);
            
            bool isBearishCandle = (close < open);
            bool isBullishCandle = (close > open);
            
            // หา OB ตรงข้ามกับทิศทาง BOS
            if((status.isBullishBOS_M5 && isBearishCandle) || (!status.isBullishBOS_M5 && isBullishCandle)) {
                status.hasOB_M5 = true;
                status.obHigh_M5 = high;
                status.obLow_M5 = low;
                break;
            }
        }
    }
    
    // 4. Entry Signal
    bool newM5Bar = (currentBarTime != lastProcessedTime_M5);
    bool validSession = status.inLondon || status.inNY;
    
    status.canEntry = status.hasSweep_M5 && 
                     status.hasBOS_M5 && 
                     status.hasOB_M5 && 
                     sameDirBOS &&
                     newM5Bar &&
                     validSession;
    
    if(status.canEntry) {
        lastProcessedTime_M5 = currentBarTime;
        status.lastSignalTime = currentBarTime;
        
        string direction = status.isBullishBOS_M5 ? "BUY" : "SELL";
        Print("[M5 ENTRY] ", direction, " Signal - M5 BOS + OB + Sweep confirmed");
        Print("M5 OB Zone: ", status.obLow_M5, " - ", status.obHigh_M5);
    }
    
    // Debug info
    if(status.hasSweep_M5 || status.hasBOS_M5 || status.hasOB_M5) {
        Print("[M5 SCAN] Sweep:", status.hasSweep_M5, " BOS:", status.hasBOS_M5, 
              " OB:", status.hasOB_M5, " SameDir:", sameDirBOS, " CanEntry:", status.canEntry);
    }
}

// Reset function
void ResetSignalTracking() {
    m15FilterPassed = false;
    lastProcessedTime_M15 = 0;
    lastProcessedTime_M5 = 0;
    Print("[SIGNAL] Multi-timeframe tracking reset");
}

#endif // __OB_BOS_SCAN_MQH__ 