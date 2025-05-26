#property copyright "Copyright 2024"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

// Simple test parameters
input double TestRisk = 1.0;
input int TestLookback = 5;

int OnInit() {
    Print("[TEST] ICT EA Test version started");
    return INIT_SUCCEEDED;
}

void OnTick() {
    static datetime lastTest = 0;
    datetime currentTime = TimeCurrent();
    
    // Test every 30 seconds
    if(currentTime - lastTest < 30) return;
    lastTest = currentTime;
    
    // Simple BOS detection test
    double currentHigh = iHigh(_Symbol, PERIOD_M15, 0);
    double currentLow = iLow(_Symbol, PERIOD_M15, 0);
    
    double highestHigh = 0;
    double lowestLow = 999999;
    
    for(int i = 1; i <= TestLookback; i++) {
        double h = iHigh(_Symbol, PERIOD_M15, i);
        double l = iLow(_Symbol, PERIOD_M15, i);
        if(h > highestHigh) highestHigh = h;
        if(l < lowestLow) lowestLow = l;
    }
    
    bool bosUp = (currentHigh > highestHigh);
    bool bosDown = (currentLow < lowestLow);
    
    if(bosUp || bosDown) {
        Print("[TEST] BOS detected! Direction: ", bosUp ? "UP" : "DOWN", 
              " Current H/L: ", currentHigh, "/", currentLow,
              " Highest/Lowest: ", highestHigh, "/", lowestLow);
    }
    
    // Simple sweep detection
    double prevHigh = iHigh(_Symbol, PERIOD_M15, 1);
    double prevLow = iLow(_Symbol, PERIOD_M15, 1);
    
    bool sweepUp = (currentHigh > prevHigh);
    bool sweepDown = (currentLow < prevLow);
    
    if(sweepUp || sweepDown) {
        Print("[TEST] Sweep detected! Direction: ", sweepUp ? "UP" : "DOWN");
    }
    
    // Test basic info
    Print("[TEST] Time: ", TimeToString(currentTime), 
          " BOS: ", (bosUp || bosDown), 
          " Sweep: ", (sweepUp || sweepDown));
} 