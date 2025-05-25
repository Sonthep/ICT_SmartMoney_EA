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

bool CheckTradeLimit(int maxTradesPerDay) {
    static int tradeCountToday = 0;
    static datetime lastTradeTime = 0;
    MqlDateTime lastTrade, current;
    TimeToStruct(lastTradeTime, lastTrade);
    TimeToStruct(TimeLocal(), current);
    if (lastTrade.day != current.day || lastTrade.mon != current.mon || lastTrade.year != current.year)
        tradeCountToday = 0;
    return (tradeCountToday < maxTradesPerDay);
}

#endif // __RISK_MANAGER_MQH__ 