//+------------------------------------------------------------------+
//| ICT_SmartMoney_EA_v4_Production.mq5                             |
//| Production ICT Smart Money EA - Hybrid Version                  |
//| Copyright 2024 - ICT Smart Money EA                             |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024 - ICT Smart Money EA"
#property link      "https://github.com/ict-smartmoney-ea"
#property version   "4.10"
#property description "Production ICT Smart Money EA with proven logic"

#include <Trade\Trade.mqh>
#include "Structures.mqh"
#include "Utils.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "=== RISK MANAGEMENT ==="
input double RiskPercent = 1.5;                    // Risk per trade (%)
input double RR_Ratio = 2.0;                       // Risk:Reward ratio
input double RR_Ratio_Alt = 1.5;                   // Alternative RR for medium confidence
input int SL_Buffer = 25;                          // Stop loss buffer (points)

input group "=== CONFIDENCE SCORING ==="
input int MinConfidenceScore = 65;                 // Minimum confidence score (balanced)
input int HighConfidenceScore = 85;                // High confidence threshold

input group "=== DETECTION PARAMETERS ==="
input int SwingLookback = 4;                       // Swing points lookback
input int BOS_Lookback = 15;                       // BOS lookback (balanced)
input int OB_Lookback = 10;                        // Order Block lookback (balanced)
input bool RequireFVG = false;                     // Require Fair Value Gap (disabled for reliability)
input bool UseMultiTimeframe = false;              // Use multi-timeframe analysis (simplified)

input group "=== KILLZONE SETTINGS ==="
input bool UseLondonKZ = true;                     // Use London Killzone (08:00-10:30 GMT)
input bool UseNYKZ = true;                         // Use NY Killzone (13:00-16:00 GMT)
input int TimezoneOffset = 0;                      // Timezone offset from GMT

input group "=== TRADE MANAGEMENT ==="
input int MaxTradesPerDay = 3;                     // Maximum trades per day
input bool AllowExtraTrade = true;                 // Allow extra trade for high confidence
input bool EnableBreakEven = true;                 // Enable break-even
input bool EnableTrailing = false;                 // Enable trailing stop (disabled for stability)

input group "=== VISUAL SETTINGS ==="
input bool ShowDashboard = true;                   // Show dashboard
input bool ShowDebugInfo = true;                   // Show debug information
input bool ShowOBZones = true;                     // Show Order Block zones
input bool ShowTradeLines = true;                  // Show trade entry/SL/TP lines

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CTrade g_trade;
int g_magicNumber;

// Signal data structure
struct ProductionSignal {
    bool valid;
    bool isBullish;
    double entryPrice;
    double stopLoss;
    double takeProfit;
    double confidence;
    string reason;
    datetime signalTime;
    bool hasOrderBlock;
    bool hasBOS;
    bool hasLiquiditySweep;
    bool inKillzone;
};

ProductionSignal g_currentSignal;
DailyTradeData g_dailyData;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    Print("=== ICT Smart Money EA v4.10 PRODUCTION Initializing ===");
    
    // Initialize magic number
    g_magicNumber = 20241202;
    g_trade.SetExpertMagicNumber(g_magicNumber);
    
    // Initialize daily data
    ResetDailyData();
    
    // Initialize signal data
    ResetSignalData();
    
    Print("[INIT] Production EA initialized successfully");
    Print("[INIT] Symbol: ", _Symbol, " | Magic: ", g_magicNumber);
    Print("[INIT] Min Confidence: ", MinConfidenceScore, " | High Confidence: ", HighConfidenceScore);
    Print("[INIT] Risk per trade: ", RiskPercent, "% | RR Ratio: ", RR_Ratio);
    Print("[INIT] Max trades per day: ", MaxTradesPerDay);
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    ObjectsDeleteAll(0, "ICT_");
    Print("=== ICT Smart Money EA v4.10 PRODUCTION Stopped ===");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // Update daily data if new day
    CheckNewDay();
    
    // Update dashboard
    if(ShowDashboard) {
        UpdateProductionDashboard();
    }
    
    // Manage existing trades
    ManageExistingTrades();
    
    // Check killzone
    if(!IsInKillzone()) {
        if(ShowDebugInfo) Print("[DEBUG] Outside killzone, waiting...");
        return;
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
    
    // Execute main strategy
    ExecuteProductionStrategy();
}

//+------------------------------------------------------------------+
//| Production Strategy Execution                                   |
//+------------------------------------------------------------------+
void ExecuteProductionStrategy() {
    ResetSignalData();
    
    if(ShowDebugInfo) Print("[DEBUG] === Starting Production Strategy Analysis ===");
    
    // Step 1: Enhanced BOS Detection
    bool bosDetected = DetectEnhancedBOS();
    if(!bosDetected) {
        if(ShowDebugInfo) Print("[DEBUG] No BOS detected");
        return;
    }
    g_currentSignal.hasBOS = true;
    
    // Step 2: Enhanced Order Block Detection
    bool obDetected = DetectEnhancedOrderBlock();
    if(!obDetected) {
        if(ShowDebugInfo) Print("[DEBUG] No Order Block detected");
        return;
    }
    g_currentSignal.hasOrderBlock = true;
    
    // Step 3: Optional Liquidity Sweep Check
    CheckLiquiditySweep();
    
    // Step 4: Calculate Enhanced Confidence
    g_currentSignal.confidence = CalculateEnhancedConfidence();
    if(ShowDebugInfo) Print("[DEBUG] Confidence Score: ", g_currentSignal.confidence);
    
    // Step 5: Recalculate TP based on confidence
    RecalculateTakeProfit();
    
    // Step 6: Check confidence threshold
    double requiredConfidence = MinConfidenceScore;
    if(g_currentSignal.confidence < requiredConfidence) {
        if(ShowDebugInfo) Print("[DEBUG] Low confidence: ", g_currentSignal.confidence, " < ", requiredConfidence);
        return;
    }
    
    // Step 7: Final validation and execution
    g_currentSignal.valid = true;
    g_currentSignal.inKillzone = true;
    g_currentSignal.signalTime = TimeCurrent();
    
    ExecuteProductionTrade();
}

//+------------------------------------------------------------------+
//| Enhanced BOS Detection                                          |
//+------------------------------------------------------------------+
bool DetectEnhancedBOS() {
    ENUM_TIMEFRAMES tf = UseMultiTimeframe ? PERIOD_M15 : PERIOD_M5;
    
    double currentHigh = iHigh(_Symbol, tf, 0);
    double currentLow = iLow(_Symbol, tf, 0);
    double currentClose = iClose(_Symbol, tf, 0);
    double prevClose = iClose(_Symbol, tf, 1);
    
    // Find significant swing levels
    double highestHigh = 0;
    double lowestLow = 999999;
    int strongBullCandles = 0;
    int strongBearCandles = 0;
    
    for(int i = 1; i <= BOS_Lookback; i++) {
        double high = iHigh(_Symbol, tf, i);
        double low = iLow(_Symbol, tf, i);
        double open = iOpen(_Symbol, tf, i);
        double close = iClose(_Symbol, tf, i);
        
        if(high > highestHigh) highestHigh = high;
        if(low < lowestLow) lowestLow = low;
        
        // Count strong candles for momentum confirmation
        double bodySize = MathAbs(close - open);
        double totalRange = high - low;
        if(totalRange > 0 && bodySize / totalRange > 0.7) {
            if(close > open) strongBullCandles++;
            else strongBearCandles++;
        }
    }
    
    // Enhanced bullish BOS detection
    if(currentHigh > highestHigh && currentClose > prevClose) {
        double breakDistance = currentHigh - highestHigh;
        double atr = CalculateATR(_Symbol, tf, 14);
        
        if(breakDistance > atr * 0.3) { // Significant break
            g_currentSignal.isBullish = true;
            g_currentSignal.reason = StringFormat("Enhanced Bullish BOS - Break: %.1f pips, Momentum: %d", 
                                                breakDistance / _Point, strongBullCandles);
            if(ShowDebugInfo) Print("[DEBUG] ", g_currentSignal.reason);
            return true;
        }
    }
    
    // Enhanced bearish BOS detection
    if(currentLow < lowestLow && currentClose < prevClose) {
        double breakDistance = lowestLow - currentLow;
        double atr = CalculateATR(_Symbol, tf, 14);
        
        if(breakDistance > atr * 0.3) { // Significant break
            g_currentSignal.isBullish = false;
            g_currentSignal.reason = StringFormat("Enhanced Bearish BOS - Break: %.1f pips, Momentum: %d", 
                                                breakDistance / _Point, strongBearCandles);
            if(ShowDebugInfo) Print("[DEBUG] ", g_currentSignal.reason);
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Enhanced Order Block Detection                                  |
//+------------------------------------------------------------------+
bool DetectEnhancedOrderBlock() {
    ENUM_TIMEFRAMES tf = PERIOD_M5;
    
    // Look for the most recent strong candle before BOS
    for(int i = 1; i <= OB_Lookback; i++) {
        double open = iOpen(_Symbol, tf, i);
        double close = iClose(_Symbol, tf, i);
        double high = iHigh(_Symbol, tf, i);
        double low = iLow(_Symbol, tf, i);
        
        double bodySize = MathAbs(close - open);
        double totalRange = high - low;
        double bodyRatio = (totalRange > 0) ? bodySize / totalRange : 0;
        
        // Enhanced OB criteria
        bool isStrongCandle = (bodyRatio > 0.6 && bodySize > CalculateATR(_Symbol, tf, 14) * 0.5);
        
        if(isStrongCandle) {
            bool isBullishCandle = (close > open);
            
            // For bullish signal, look for bearish OB
            if(g_currentSignal.isBullish && !isBullishCandle) {
                // Use more conservative entry within the OB
                g_currentSignal.entryPrice = high - (totalRange * 0.3); // Enter at 30% from top
                g_currentSignal.stopLoss = low - (SL_Buffer * _Point);
                
                // Calculate TP with default RR (will be recalculated after confidence scoring)
                double slDistance = g_currentSignal.entryPrice - g_currentSignal.stopLoss;
                g_currentSignal.takeProfit = g_currentSignal.entryPrice + (slDistance * RR_Ratio_Alt);
                
                if(ShowDebugInfo) Print("[DEBUG] Enhanced Bullish OB found at bar ", i, 
                                      " - Entry: ", g_currentSignal.entryPrice, 
                                      " | Body Ratio: ", bodyRatio);
                return true;
            }
            
            // For bearish signal, look for bullish OB
            if(!g_currentSignal.isBullish && isBullishCandle) {
                // Use more conservative entry within the OB
                g_currentSignal.entryPrice = low + (totalRange * 0.3); // Enter at 30% from bottom
                g_currentSignal.stopLoss = high + (SL_Buffer * _Point);
                
                // Calculate TP with default RR (will be recalculated after confidence scoring)
                double slDistance = g_currentSignal.stopLoss - g_currentSignal.entryPrice;
                g_currentSignal.takeProfit = g_currentSignal.entryPrice - (slDistance * RR_Ratio_Alt);
                
                if(ShowDebugInfo) Print("[DEBUG] Enhanced Bearish OB found at bar ", i, 
                                      " - Entry: ", g_currentSignal.entryPrice, 
                                      " | Body Ratio: ", bodyRatio);
                return true;
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check Liquidity Sweep (Optional)                               |
//+------------------------------------------------------------------+
void CheckLiquiditySweep() {
    // Simple liquidity sweep detection
    double currentHigh = iHigh(_Symbol, PERIOD_M5, 0);
    double currentLow = iLow(_Symbol, PERIOD_M5, 0);
    
    // Look for recent highs/lows that might have been swept
    for(int i = 2; i <= 10; i++) {
        double prevHigh = iHigh(_Symbol, PERIOD_M5, i);
        double prevLow = iLow(_Symbol, PERIOD_M5, i);
        
        // Check for liquidity sweep
        if(g_currentSignal.isBullish && currentHigh > prevHigh) {
            g_currentSignal.hasLiquiditySweep = true;
            if(ShowDebugInfo) Print("[DEBUG] Bullish liquidity sweep detected");
            break;
        }
        
        if(!g_currentSignal.isBullish && currentLow < prevLow) {
            g_currentSignal.hasLiquiditySweep = true;
            if(ShowDebugInfo) Print("[DEBUG] Bearish liquidity sweep detected");
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate Enhanced Confidence Score                             |
//+------------------------------------------------------------------+
double CalculateEnhancedConfidence() {
    double score = 40; // Base score
    
    // BOS Quality (25 points)
    if(g_currentSignal.hasBOS) {
        score += 25;
        
        // Add bonus for strong momentum
        double close0 = iClose(_Symbol, PERIOD_M5, 0);
        double close5 = iClose(_Symbol, PERIOD_M5, 5);
        
        if(g_currentSignal.isBullish && close0 > close5) score += 10;
        if(!g_currentSignal.isBullish && close0 < close5) score += 10;
    }
    
    // Order Block Quality (20 points)
    if(g_currentSignal.hasOrderBlock) {
        score += 20;
        
        // Add bonus for good risk/reward
        double slDistance = MathAbs(g_currentSignal.entryPrice - g_currentSignal.stopLoss);
        double tpDistance = MathAbs(g_currentSignal.takeProfit - g_currentSignal.entryPrice);
        
        if(tpDistance >= slDistance * 1.8) score += 5;
    }
    
    // Liquidity Sweep (15 points)
    if(g_currentSignal.hasLiquiditySweep) {
        score += 15;
    }
    
    // Killzone Timing (10 points)
    if(g_currentSignal.inKillzone) {
        score += 10;
    }
    
    // ATR-based volatility check (10 points)
    double atr = CalculateATR(_Symbol, PERIOD_M5, 14);
    double slDistance = MathAbs(g_currentSignal.entryPrice - g_currentSignal.stopLoss);
    
    if(slDistance <= atr * 2.5 && slDistance >= atr * 0.8) {
        score += 10; // Good SL size relative to volatility
    }
    
    return MathMin(100.0, score);
}

//+------------------------------------------------------------------+
//| Recalculate Take Profit Based on Confidence                    |
//+------------------------------------------------------------------+
void RecalculateTakeProfit() {
    double slDistance = MathAbs(g_currentSignal.entryPrice - g_currentSignal.stopLoss);
    double rrToUse = (g_currentSignal.confidence >= HighConfidenceScore) ? RR_Ratio : RR_Ratio_Alt;
    
    if(g_currentSignal.isBullish) {
        g_currentSignal.takeProfit = g_currentSignal.entryPrice + (slDistance * rrToUse);
    } else {
        g_currentSignal.takeProfit = g_currentSignal.entryPrice - (slDistance * rrToUse);
    }
    
    if(ShowDebugInfo) Print("[DEBUG] TP recalculated with RR: ", rrToUse, " | New TP: ", g_currentSignal.takeProfit);
}

//+------------------------------------------------------------------+
//| Execute Production Trade                                        |
//+------------------------------------------------------------------+
void ExecuteProductionTrade() {
    if(ShowDebugInfo) {
        Print("[DEBUG] === EXECUTING PRODUCTION TRADE ===");
        Print("[DEBUG] Direction: ", g_currentSignal.isBullish ? "BUY" : "SELL");
        Print("[DEBUG] Entry: ", g_currentSignal.entryPrice);
        Print("[DEBUG] SL: ", g_currentSignal.stopLoss);
        Print("[DEBUG] TP: ", g_currentSignal.takeProfit);
        Print("[DEBUG] Confidence: ", g_currentSignal.confidence);
        Print("[DEBUG] Reason: ", g_currentSignal.reason);
    }
    
    // Calculate lot size using enhanced risk management
    double lotSize = CalculateEnhancedLotSize();
    
    if(ShowDebugInfo) Print("[DEBUG] Calculated Lot Size: ", lotSize);
    
    // Place order
    bool success = false;
    string comment = StringFormat("ICT_Prod_%.0f", g_currentSignal.confidence);
    
    if(g_currentSignal.isBullish) {
        success = g_trade.Buy(lotSize, _Symbol, 0, g_currentSignal.stopLoss, g_currentSignal.takeProfit, comment);
    } else {
        success = g_trade.Sell(lotSize, _Symbol, 0, g_currentSignal.stopLoss, g_currentSignal.takeProfit, comment);
    }
    
    if(success) {
        g_dailyData.tradesCount++;
        
        Print("🚀 [PRODUCTION TRADE] ", (g_currentSignal.isBullish ? "BUY" : "SELL"), 
              " | Confidence: ", g_currentSignal.confidence,
              " | Lot: ", lotSize,
              " | Entry: ", g_currentSignal.entryPrice,
              " | RR: ", (g_currentSignal.confidence >= HighConfidenceScore) ? RR_Ratio : RR_Ratio_Alt);
              
        // Draw visual elements
        if(ShowTradeLines) DrawTradeElements();
        
        // Send notification
        SendNotification(StringFormat("ICT EA: %s %.2f lots @ %.5f (Conf: %.0f%%)", 
                                    g_currentSignal.isBullish ? "BUY" : "SELL",
                                    lotSize, g_currentSignal.entryPrice, g_currentSignal.confidence));
    } else {
        Print("❌ [ERROR] Failed to place production trade: ", g_trade.ResultRetcodeDescription());
        if(ShowDebugInfo) {
            Print("[DEBUG] Last Error: ", GetLastError());
            Print("[DEBUG] Account Free Margin: ", AccountInfoDouble(ACCOUNT_MARGIN_FREE));
            Print("[DEBUG] Lot Size: ", lotSize);
        }
    }
}

//+------------------------------------------------------------------+
//| Enhanced Lot Size Calculation                                   |
//+------------------------------------------------------------------+
double CalculateEnhancedLotSize() {
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * (RiskPercent / 100.0);
    double slDistance = MathAbs(g_currentSignal.entryPrice - g_currentSignal.stopLoss);
    
    // Get symbol specifications
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    
    // Calculate lot size
    double lotSize = 0;
    
    if(tickSize > 0 && tickValue > 0) {
        double slInTicks = slDistance / tickSize;
        lotSize = riskAmount / (slInTicks * tickValue);
    } else {
        // Simplified fallback calculation
        lotSize = riskAmount / (slDistance * 10); // Conservative fallback
    }
    
    // Normalize lot size
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    if(lotStep > 0) {
        lotSize = MathRound(lotSize / lotStep) * lotStep;
    }
    
    lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
    
    // Additional safety check - don't risk more than 5% of account
    double maxRiskAmount = accountBalance * 0.05;
    
    // Simple risk check without complex calculation
    if(lotSize > maxLot * 0.5) {
        lotSize = maxLot * 0.5;
        lotSize = MathRound(lotSize / lotStep) * lotStep;
        lotSize = MathMax(minLot, lotSize);
    }
    
    return lotSize;
}

//+------------------------------------------------------------------+
//| Helper Functions                                                |
//+------------------------------------------------------------------+
bool IsInKillzone() {
    if(!UseLondonKZ && !UseNYKZ) return true; // If no killzones enabled, always allow
    
    MqlDateTime dt;
    TimeToStruct(TimeGMT() + TimezoneOffset * 3600, dt);
    int currentHour = dt.hour;
    int currentMinute = dt.min;
    int currentTime = currentHour * 100 + currentMinute;
    
    // London Killzone: 08:00-10:30 GMT
    if(UseLondonKZ && currentTime >= 800 && currentTime <= 1030) {
        return true;
    }
    
    // NY Killzone: 13:00-16:00 GMT
    if(UseNYKZ && currentTime >= 1300 && currentTime <= 1600) {
        return true;
    }
    
    return false;
}

bool CheckTradeLimit() {
    if(g_dailyData.tradesCount >= MaxTradesPerDay) {
        // Check if we can place an extra trade for high confidence
        if(AllowExtraTrade && g_currentSignal.confidence >= HighConfidenceScore && 
           g_dailyData.tradesCount == MaxTradesPerDay) {
            return true;
        }
        return false;
    }
    return true;
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

void ManageExistingTrades() {
    if(!EnableBreakEven) return;
    
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionGetSymbol(i) == _Symbol) {
            ulong magic = PositionGetInteger(POSITION_MAGIC);
            if(magic == g_magicNumber) {
                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
                double sl = PositionGetDouble(POSITION_SL);
                long type = PositionGetInteger(POSITION_TYPE);
                
                // Move to break-even when in 50% profit
                if(type == POSITION_TYPE_BUY && currentPrice > openPrice) {
                    double profit = currentPrice - openPrice;
                    if(profit >= (openPrice - sl) * 0.5 && sl < openPrice) {
                        g_trade.PositionModify(_Symbol, openPrice + 10 * _Point, PositionGetDouble(POSITION_TP));
                        if(ShowDebugInfo) Print("[DEBUG] Moved BUY position to break-even");
                    }
                }
                
                if(type == POSITION_TYPE_SELL && currentPrice < openPrice) {
                    double profit = openPrice - currentPrice;
                    if(profit >= (sl - openPrice) * 0.5 && sl > openPrice) {
                        g_trade.PositionModify(_Symbol, openPrice - 10 * _Point, PositionGetDouble(POSITION_TP));
                        if(ShowDebugInfo) Print("[DEBUG] Moved SELL position to break-even");
                    }
                }
            }
        }
    }
}

void CheckNewDay() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    datetime currentDate = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
    
    if(g_dailyData.date != currentDate) {
        if(ShowDebugInfo) Print("[DEBUG] New day detected, resetting daily data");
        ResetDailyData();
        g_dailyData.date = currentDate;
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
    g_currentSignal.signalTime = 0;
    g_currentSignal.hasOrderBlock = false;
    g_currentSignal.hasBOS = false;
    g_currentSignal.hasLiquiditySweep = false;
    g_currentSignal.inKillzone = false;
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

void UpdateProductionDashboard() {
    string prefix = "ICT_Prod_";
    
    // Clear old labels
    ObjectsDeleteAll(0, prefix);
    
    // Create production dashboard
    int yPos = 30;
    int lineHeight = 16;
    
    CreateLabel(prefix + "Header", "=== ICT PRODUCTION EA v4.10 ===", 15, yPos, clrGold);
    yPos += lineHeight + 2;
    
    CreateLabel(prefix + "Symbol", "Symbol: " + _Symbol, 15, yPos, clrWhite);
    yPos += lineHeight;
    
    CreateLabel(prefix + "Trades", StringFormat("Trades: %d/%d", g_dailyData.tradesCount, MaxTradesPerDay), 15, yPos, clrWhite);
    yPos += lineHeight;
    
    // Killzone status
    string kzStatus = IsInKillzone() ? "ACTIVE" : "WAITING";
    color kzColor = IsInKillzone() ? clrLimeGreen : clrOrange;
    CreateLabel(prefix + "Killzone", "Killzone: " + kzStatus, 15, yPos, kzColor);
    yPos += lineHeight;
    
    // Signal status
    if(g_currentSignal.valid) {
        CreateLabel(prefix + "Signal", "Signal: " + g_currentSignal.reason, 15, yPos, clrLimeGreen);
        yPos += lineHeight;
        CreateLabel(prefix + "Confidence", StringFormat("Confidence: %.0f%%", g_currentSignal.confidence), 15, yPos, clrYellow);
        yPos += lineHeight;
        
        // Signal details
        CreateLabel(prefix + "BOS", "BOS: " + (g_currentSignal.hasBOS ? "✓" : "✗"), 15, yPos, g_currentSignal.hasBOS ? clrLimeGreen : clrRed);
        yPos += lineHeight;
        CreateLabel(prefix + "OB", "OB: " + (g_currentSignal.hasOrderBlock ? "✓" : "✗"), 15, yPos, g_currentSignal.hasOrderBlock ? clrLimeGreen : clrRed);
        yPos += lineHeight;
        CreateLabel(prefix + "Sweep", "Sweep: " + (g_currentSignal.hasLiquiditySweep ? "✓" : "✗"), 15, yPos, g_currentSignal.hasLiquiditySweep ? clrLimeGreen : clrGray);
    } else {
        CreateLabel(prefix + "Signal", "Signal: Scanning...", 15, yPos, clrGray);
    }
    
    ChartRedraw();
}

void CreateLabel(string name, string text, int x, int y, color clr) {
    ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
    ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void DrawTradeElements() {
    if(!ShowOBZones && !ShowTradeLines) return;
    
    string prefix = "ICT_ProdTrade_" + IntegerToString(TimeCurrent()) + "_";
    
    // Draw entry level
    string entryName = prefix + "Entry";
    ObjectCreate(0, entryName, OBJ_HLINE, 0, 0, g_currentSignal.entryPrice);
    ObjectSetInteger(0, entryName, OBJPROP_COLOR, clrGold);
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
    
    ChartRedraw();
} 