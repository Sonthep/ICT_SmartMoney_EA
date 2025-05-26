//+------------------------------------------------------------------+
//| Structures.mqh                                                   |
//| Common Structure Definitions for ICT Smart Money EA             |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024 - ICT Smart Money EA"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Daily Trade Tracking Structure                                  |
//+------------------------------------------------------------------+
struct DailyTradeData {
    datetime date;
    int tradesCount;
    double totalProfit;
    int wins;
    int losses;
};

//+------------------------------------------------------------------+
//| Signal Data Structure                                           |
//+------------------------------------------------------------------+
struct SignalData {
    bool sweepDetected;
    bool bosDetected;
    bool obFound;
    bool fvgFound;
    double confidenceScore;
    datetime signalTime;
    bool isBullish;
    
    // OB data
    double obHigh;
    double obLow;
    datetime obTime;
    
    // FVG data
    double fvgHigh;
    double fvgLow;
    datetime fvgTime;
};

//+------------------------------------------------------------------+
//| Order Block Structure                                           |
//+------------------------------------------------------------------+
struct OrderBlockData {
    double high;
    double low;
    datetime time;
    bool isBullish;
    double bodyRatio;
    int age;
    bool tested;
    double strength;
};

//+------------------------------------------------------------------+
//| Break of Structure Result                                       |
//+------------------------------------------------------------------+
struct BOSResult {
    bool detected;
    bool isBullish;
    double level;
    datetime time;
    double strength;
    int confirmationBars;
};

//+------------------------------------------------------------------+
//| Fair Value Gap Structure                                        |
//+------------------------------------------------------------------+
struct FVGResult {
    bool detected;
    double high;
    double low;
    datetime time;
    bool isBullish;
    double size;
    bool filled;
    double quality;
};

//+------------------------------------------------------------------+
//| Liquidity Sweep Result                                         |
//+------------------------------------------------------------------+
struct SweepResult {
    bool detected;
    double level;
    datetime time;
    bool isBullish;
    double distance;
    double rejectionStrength;
    double quality;
};

//+------------------------------------------------------------------+
//| Confidence Score Components                                     |
//+------------------------------------------------------------------+
struct ConfidenceComponents {
    double bosStrength;      // 0-20 points
    double sweepQuality;     // 0-15 points
    double fvgPresence;      // 0-15 points
    double obQuality;        // 0-20 points
    double timingScore;      // 0-10 points
    double confluence;       // 0-10 points
    double distanceScore;    // 0-10 points
    double totalScore;       // 0-100 points
};

//+------------------------------------------------------------------+
//| Session Information                                             |
//+------------------------------------------------------------------+
struct SessionInfo {
    bool isLondonKZ;
    bool isNYKZ;
    bool isActive;
    int timeScore;
    string sessionName;
    datetime sessionStart;
    datetime sessionEnd;
};

//+------------------------------------------------------------------+
//| Risk Management Data                                            |
//+------------------------------------------------------------------+
struct RiskData {
    double riskPercent;
    double lotSize;
    double stopLoss;
    double takeProfit;
    double riskAmount;
    double rewardAmount;
    double rrRatio;
    bool marginOK;
};

//+------------------------------------------------------------------+
//| Trade Setup Information                                         |
//+------------------------------------------------------------------+
struct TradeSetup {
    bool isValid;
    bool isBullish;
    double entryPrice;
    double stopLoss;
    double takeProfit;
    double lotSize;
    double confidenceScore;
    string comment;
    OrderBlockData orderBlock;
    BOSResult bosResult;
    FVGResult fvgResult;
    SweepResult sweepResult;
}; 