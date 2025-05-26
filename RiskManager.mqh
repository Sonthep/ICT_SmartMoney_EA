#ifndef __RISK_MANAGER_MQH__
#define __RISK_MANAGER_MQH__

double CalculateLot(double riskPercent, int slPoints, string symbol) {
    // คำนวณเงินที่เสี่ยงได้ (เช่น 1% ของ account balance)
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * (riskPercent / 100.0);
    
    // ได้ข้อมูล symbol
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    
    // คำนวณ lot size
    double slInPrice = slPoints * _Point;
    double riskPerLot = (slInPrice / tickSize) * tickValue;
    double lotSize = riskAmount / riskPerLot;
    
    // ปรับให้อยู่ในขอบเขตที่อนุญาต
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    // ปรับ lot ให้เป็นทวีคูณของ lot step
    lotSize = MathFloor(lotSize / lotStep) * lotStep;
    
    // จำกัดขอบเขต
    if(lotSize < minLot) lotSize = minLot;
    if(lotSize > maxLot) lotSize = maxLot;
    
    Print("[DEBUG] Account Balance: ", accountBalance, 
          " Risk Amount: ", riskAmount, 
          " Risk Per Lot: ", riskPerLot, 
          " Calculated Lot: ", lotSize);
    
    return NormalizeDouble(lotSize, 2);
}

// Global variables for trade counting
static int g_tradeCountToday = 0;
static datetime g_lastTradeDate = 0;

bool CheckTradeLimit(int maxTradesPerDay) {
    // Get current date
    datetime currentTime = TimeLocal();
    MqlDateTime current;
    TimeToStruct(currentTime, current);
    
    // Reset counter if new day
    MqlDateTime lastDate;
    TimeToStruct(g_lastTradeDate, lastDate);
    if (lastDate.day != current.day || lastDate.mon != current.mon || lastDate.year != current.year) {
        g_tradeCountToday = 0;
        g_lastTradeDate = currentTime;
        Print("[DEBUG] Trade count reset for new day. Current count: ", g_tradeCountToday);
    }
    
    return (g_tradeCountToday < maxTradesPerDay);
}

void IncrementTradeCount() {
    g_tradeCountToday++;
    Print("[DEBUG] Trade count incremented to: ", g_tradeCountToday);
}

#endif // __RISK_MANAGER_MQH__ 