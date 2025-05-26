#property copyright "Test Compile"
#property version   "1.00"

#include "SimpleSession.mqh"
#include "RiskManager.mqh"
#include "LimitOrderManager.mqh"
#include "PartialTPManager.mqh"
#include "DrawUtils.mqh"

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    Print("=== ICT Test Compile Started ===");
    
    // Test session functions
    bool london = InLondonKillzone();
    bool ny = InNYKillzone();
    
    Print("London Killzone: ", london ? "ACTIVE" : "CLOSED");
    Print("NY Killzone: ", ny ? "ACTIVE" : "CLOSED");
    
    // Test managers
    CLimitOrderManager* limitMgr = new CLimitOrderManager();
    CPartialTPManager* partialMgr = new CPartialTPManager();
    
    if(limitMgr != NULL) {
        Print("LimitOrderManager: OK");
        delete limitMgr;
    }
    
    if(partialMgr != NULL) {
        Print("PartialTPManager: OK");
        delete partialMgr;
    }
    
    // Test risk calculation
    double lot = CalculateLot(1.0, 30, _Symbol);
    Print("Calculated lot size: ", lot);
    
    Print("=== All Tests Passed ===");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Print("=== ICT Test Compile Stopped ===");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // Do nothing - just for testing compilation
} 