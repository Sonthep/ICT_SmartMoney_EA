//+------------------------------------------------------------------+
//| Utils.mqh                                                        |
//| Utility Functions for ICT Smart Money EA                        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024 - ICT Smart Money EA"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Utility Functions                                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Normalize lot size according to broker requirements             |
//+------------------------------------------------------------------+
double NormalizeLotSize(double lotSize) {
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    if(lotSize < minLot) return minLot;
    if(lotSize > maxLot) return maxLot;
    
    return NormalizeDouble(MathRound(lotSize / lotStep) * lotStep, 2);
}

//+------------------------------------------------------------------+
//| Normalize price according to symbol digits                      |
//+------------------------------------------------------------------+
double NormalizePrice(double price) {
    return NormalizeDouble(price, _Digits);
}

//+------------------------------------------------------------------+
//| Calculate points between two prices                             |
//+------------------------------------------------------------------+
double CalculatePoints(double price1, double price2) {
    return MathAbs(price1 - price2) / _Point;
}

//+------------------------------------------------------------------+
//| Check if price is within range                                  |
//+------------------------------------------------------------------+
bool IsPriceInRange(double price, double low, double high) {
    return (price >= low && price <= high);
}

//+------------------------------------------------------------------+
//| Get bar index by time                                           |
//+------------------------------------------------------------------+
int GetBarIndexByTime(datetime time, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
    return iBarShift(_Symbol, timeframe, time);
}

//+------------------------------------------------------------------+
//| Check if current time is within session                         |
//+------------------------------------------------------------------+
bool IsWithinSession(int startHour, int startMinute, int endHour, int endMinute) {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    int currentMinutes = dt.hour * 60 + dt.min;
    int startMinutes = startHour * 60 + startMinute;
    int endMinutes = endHour * 60 + endMinute;
    
    if(startMinutes <= endMinutes) {
        return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
    } else {
        // Session crosses midnight
        return (currentMinutes >= startMinutes || currentMinutes <= endMinutes);
    }
}

//+------------------------------------------------------------------+
//| Format double to string with specified decimals                 |
//+------------------------------------------------------------------+
string FormatDouble(double value, int decimals = 5) {
    return DoubleToString(value, decimals);
}

//+------------------------------------------------------------------+
//| Get symbol point value                                          |
//+------------------------------------------------------------------+
double GetSymbolPoint() {
    return SymbolInfoDouble(_Symbol, SYMBOL_POINT);
}

//+------------------------------------------------------------------+
//| Get symbol tick size                                            |
//+------------------------------------------------------------------+
double GetSymbolTickSize() {
    return SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
}

//+------------------------------------------------------------------+
//| Check if market is open                                         |
//+------------------------------------------------------------------+
bool IsMarketOpen() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    // Skip weekends
    if(dt.day_of_week == 0 || dt.day_of_week == 6) return false;
    
    // Check if symbol is tradeable
    return (bool)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
}

//+------------------------------------------------------------------+
//| Calculate percentage change                                      |
//+------------------------------------------------------------------+
double CalculatePercentageChange(double oldValue, double newValue) {
    if(oldValue == 0) return 0;
    return ((newValue - oldValue) / oldValue) * 100;
}

//+------------------------------------------------------------------+
//| Get high/low of specified bars                                  |
//+------------------------------------------------------------------+
void GetHighLowRange(int startBar, int endBar, ENUM_TIMEFRAMES timeframe, double &high, double &low) {
    high = -1;
    low = -1;
    
    for(int i = startBar; i <= endBar; i++) {
        double barHigh = iHigh(_Symbol, timeframe, i);
        double barLow = iLow(_Symbol, timeframe, i);
        
        if(high == -1 || barHigh > high) high = barHigh;
        if(low == -1 || barLow < low) low = barLow;
    }
}

//+------------------------------------------------------------------+
//| Check if price broke level                                      |
//+------------------------------------------------------------------+
bool IsPriceBroken(double level, double currentPrice, double previousPrice, bool checkUpBreak = true) {
    if(checkUpBreak) {
        return (previousPrice <= level && currentPrice > level);
    } else {
        return (previousPrice >= level && currentPrice < level);
    }
}

//+------------------------------------------------------------------+
//| Get ATR value                                                   |
//+------------------------------------------------------------------+
double GetATR(int period = 14, int shift = 1, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
    int atrHandle = iATR(_Symbol, timeframe, period);
    if(atrHandle == INVALID_HANDLE) return 0;
    
    double atrValue[];
    if(CopyBuffer(atrHandle, 0, shift, 1, atrValue) <= 0) return 0;
    
    IndicatorRelease(atrHandle);
    return atrValue[0];
}

//+------------------------------------------------------------------+
//| Check if new bar formed                                         |
//+------------------------------------------------------------------+
bool IsNewBar(ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT) {
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(_Symbol, timeframe, 0);
    
    if(lastBarTime != currentBarTime) {
        lastBarTime = currentBarTime;
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Get spread in points                                            |
//+------------------------------------------------------------------+
double GetSpreadPoints() {
    return (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
}

//+------------------------------------------------------------------+
//| Check if spread is acceptable                                   |
//+------------------------------------------------------------------+
bool IsSpreadAcceptable(double maxSpreadPoints = 30) {
    return (GetSpreadPoints() <= maxSpreadPoints);
}

//+------------------------------------------------------------------+
//| Convert timeframe to string                                     |
//+------------------------------------------------------------------+
string TimeframeToString(ENUM_TIMEFRAMES timeframe) {
    switch(timeframe) {
        case PERIOD_M1:  return "M1";
        case PERIOD_M5:  return "M5";
        case PERIOD_M15: return "M15";
        case PERIOD_M30: return "M30";
        case PERIOD_H1:  return "H1";
        case PERIOD_H4:  return "H4";
        case PERIOD_D1:  return "D1";
        case PERIOD_W1:  return "W1";
        case PERIOD_MN1: return "MN1";
        default:         return "Unknown";
    }
}

//+------------------------------------------------------------------+
//| Get account currency                                            |
//+------------------------------------------------------------------+
string GetAccountCurrency() {
    return AccountInfoString(ACCOUNT_CURRENCY);
}

//+------------------------------------------------------------------+
//| Get account balance                                             |
//+------------------------------------------------------------------+
double GetAccountBalance() {
    return AccountInfoDouble(ACCOUNT_BALANCE);
}

//+------------------------------------------------------------------+
//| Get account equity                                              |
//+------------------------------------------------------------------+
double GetAccountEquity() {
    return AccountInfoDouble(ACCOUNT_EQUITY);
}

//+------------------------------------------------------------------+
//| Get free margin                                                 |
//+------------------------------------------------------------------+
double GetFreeMargin() {
    return AccountInfoDouble(ACCOUNT_MARGIN_FREE);
}

//+------------------------------------------------------------------+
//| Check if enough margin for trade                               |
//+------------------------------------------------------------------+
bool HasEnoughMargin(double lotSize, string symbol = "") {
    if(symbol == "") symbol = _Symbol;
    
    double marginRequired = 0;
    if(!OrderCalcMargin(ORDER_TYPE_BUY, symbol, lotSize, SymbolInfoDouble(symbol, SYMBOL_ASK), marginRequired)) {
        return false;
    }
    
    return (GetFreeMargin() > marginRequired * 2); // 200% margin safety
}

//+------------------------------------------------------------------+
//| Log message with timestamp                                      |
//+------------------------------------------------------------------+
void LogMessage(string message, bool printToExpert = true) {
    string timestamp = TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS);
    string fullMessage = "[" + timestamp + "] " + message;
    
    if(printToExpert) {
        Print(fullMessage);
    }
}

//+------------------------------------------------------------------+
//| Create unique object name                                       |
//+------------------------------------------------------------------+
string CreateUniqueObjectName(string prefix) {
    return prefix + "_" + IntegerToString(TimeCurrent()) + "_" + IntegerToString(MathRand());
} 