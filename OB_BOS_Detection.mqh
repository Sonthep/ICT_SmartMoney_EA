#ifndef __OB_BOS_DETECTION_MQH__
#define __OB_BOS_DETECTION_MQH__

//+------------------------------------------------------------------+
//| Enhanced Order Block and BOS Detection                          |
//| Multi-timeframe analysis with M5 and M15                        |
//+------------------------------------------------------------------+
class COB_BOS_Detection {
private:
    int m_bosLookbackM5;
    int m_bosLookbackM15;
    int m_obLookback;
    int m_swingLookback;
    
public:
    COB_BOS_Detection() {
        m_bosLookbackM5 = 20;
        m_bosLookbackM15 = 30;
        m_obLookback = 15;
        m_swingLookback = 5;
    }
    
    ~COB_BOS_Detection() {}
    
    //+------------------------------------------------------------------+
    //| Set detection parameters                                        |
    //+------------------------------------------------------------------+
    void SetParameters(int bosLookbackM5, int bosLookbackM15, int obLookback, int swingLookback) {
        m_bosLookbackM5 = bosLookbackM5;
        m_bosLookbackM15 = bosLookbackM15;
        m_obLookback = obLookback;
        m_swingLookback = swingLookback;
    }
    
    //+------------------------------------------------------------------+
    //| Main multi-timeframe analysis function                         |
    //+------------------------------------------------------------------+
    bool AnalyzeMultiTimeframe(string symbol, SignalData& signal) {
        // Step 1: Analyze M15 for higher timeframe context
        bool m15Valid = AnalyzeM15Context(symbol, signal);
        if(!m15Valid) return false;
        
        // Step 2: Analyze M5 for precise entry
        bool m5Valid = AnalyzeM5Entry(symbol, signal);
        if(!m5Valid) return false;
        
        // Step 3: Validate alignment between timeframes
        return ValidateTimeframeAlignment(symbol, signal);
    }
    
private:
    //+------------------------------------------------------------------+
    //| Analyze M15 timeframe for context                              |
    //+------------------------------------------------------------------+
    bool AnalyzeM15Context(string symbol, SignalData& signal) {
        ENUM_TIMEFRAMES tf = PERIOD_M15;
        
        // Detect BOS on M15
        BOSResult bosM15 = DetectBOS(symbol, tf, m_bosLookbackM15);
        if(!bosM15.detected) return false;
        
        // Find Order Block on M15
        OBResult obM15 = FindOrderBlock(symbol, tf, bosM15, m_obLookback);
        if(!obM15.found) return false;
        
        // Check if price is currently in or near M15 OB zone
        double currentPrice = iClose(symbol, PERIOD_M5, 0);
        double obMid = (obM15.high + obM15.low) / 2;
        double obRange = obM15.high - obM15.low;
        
        // Allow some tolerance for price to be near OB
        if(MathAbs(currentPrice - obMid) > obRange * 2) {
            return false; // Price too far from M15 OB
        }
        
        // Store M15 context
        signal.isBullish = bosM15.isBullish;
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Analyze M5 timeframe for entry                                 |
    //+------------------------------------------------------------------+
    bool AnalyzeM5Entry(string symbol, SignalData& signal) {
        ENUM_TIMEFRAMES tf = PERIOD_M5;
        
        // Detect BOS on M5 (must align with M15 direction)
        BOSResult bosM5 = DetectBOS(symbol, tf, m_bosLookbackM5);
        if(!bosM5.detected || bosM5.isBullish != signal.isBullish) {
            return false;
        }
        
        // Find fresh Order Block on M5
        OBResult obM5 = FindOrderBlock(symbol, tf, bosM5, m_obLookback);
        if(!obM5.found) return false;
        
        // Validate OB quality
        if(!ValidateOBQuality(symbol, tf, obM5)) {
            return false;
        }
        
        // Store M5 signal data
        signal.bosDetected = true;
        signal.obFound = true;
        signal.obHigh = obM5.high;
        signal.obLow = obM5.low;
        signal.obTime = obM5.time;
        signal.signalTime = TimeCurrent();
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Validate timeframe alignment                                   |
    //+------------------------------------------------------------------+
    bool ValidateTimeframeAlignment(string symbol, SignalData& signal) {
        // Check that both timeframes show same directional bias
        bool m5Bias = GetTimeframeBias(symbol, PERIOD_M5);
        bool m15Bias = GetTimeframeBias(symbol, PERIOD_M15);
        
        // Both timeframes should align with signal direction
        return (m5Bias == signal.isBullish && m15Bias == signal.isBullish);
    }
    
    //+------------------------------------------------------------------+
    //| BOS Detection Structure                                         |
    //+------------------------------------------------------------------+
    struct BOSResult {
        bool detected;
        bool isBullish;
        double breakLevel;
        datetime breakTime;
        double strength; // 0-1 strength of the break
    };
    
    //+------------------------------------------------------------------+
    //| Order Block Structure                                           |
    //+------------------------------------------------------------------+
    struct OBResult {
        bool found;
        double high;
        double low;
        datetime time;
        double bodyRatio;
        bool isUntested;
    };
    
    //+------------------------------------------------------------------+
    //| Detect Break of Structure                                      |
    //+------------------------------------------------------------------+
    BOSResult DetectBOS(string symbol, ENUM_TIMEFRAMES tf, int lookback) {
        BOSResult result = {false, false, 0, 0, 0};
        
        double currentHigh = iHigh(symbol, tf, 0);
        double currentLow = iLow(symbol, tf, 0);
        datetime currentTime = iTime(symbol, tf, 0);
        
        // Find highest high and lowest low in lookback period
        double highestHigh = 0;
        double lowestLow = 999999;
        
        for(int i = 1; i <= lookback; i++) {
            double high = iHigh(symbol, tf, i);
            double low = iLow(symbol, tf, i);
            
            if(high > highestHigh) highestHigh = high;
            if(low < lowestLow) lowestLow = low;
        }
        
        // Check for bullish BOS (break above highest high)
        if(currentHigh > highestHigh) {
            result.detected = true;
            result.isBullish = true;
            result.breakLevel = highestHigh;
            result.breakTime = currentTime;
            result.strength = CalculateBOSStrength(symbol, tf, true, highestHigh, currentHigh);
            return result;
        }
        
        // Check for bearish BOS (break below lowest low)
        if(currentLow < lowestLow) {
            result.detected = true;
            result.isBullish = false;
            result.breakLevel = lowestLow;
            result.breakTime = currentTime;
            result.strength = CalculateBOSStrength(symbol, tf, false, lowestLow, currentLow);
            return result;
        }
        
        return result;
    }
    
    //+------------------------------------------------------------------+
    //| Find Order Block after BOS                                     |
    //+------------------------------------------------------------------+
    OBResult FindOrderBlock(string symbol, ENUM_TIMEFRAMES tf, const BOSResult& bos, int lookback) {
        OBResult result = {false, 0, 0, 0, 0, false};
        
        if(!bos.detected) return result;
        
        // Look for the last opposite candle before BOS
        for(int i = 1; i <= lookback; i++) {
            double open = iOpen(symbol, tf, i);
            double close = iClose(symbol, tf, i);
            double high = iHigh(symbol, tf, i);
            double low = iLow(symbol, tf, i);
            datetime time = iTime(symbol, tf, i);
            
            bool isBearishCandle = (close < open);
            bool isBullishCandle = (close > open);
            
            // For bullish BOS, find bearish OB (last bearish candle)
            if(bos.isBullish && isBearishCandle) {
                result.found = true;
                result.high = high;
                result.low = low;
                result.time = time;
                result.bodyRatio = MathAbs(close - open) / (high - low);
                result.isUntested = IsOBUntested(symbol, tf, high, low, time);
                break;
            }
            // For bearish BOS, find bullish OB (last bullish candle)
            else if(!bos.isBullish && isBullishCandle) {
                result.found = true;
                result.high = high;
                result.low = low;
                result.time = time;
                result.bodyRatio = MathAbs(close - open) / (high - low);
                result.isUntested = IsOBUntested(symbol, tf, high, low, time);
                break;
            }
        }
        
        return result;
    }
    
    //+------------------------------------------------------------------+
    //| Calculate BOS strength                                          |
    //+------------------------------------------------------------------+
    double CalculateBOSStrength(string symbol, ENUM_TIMEFRAMES tf, bool isBullish, double breakLevel, double currentLevel) {
        double avgRange = CalculateAverageRange(symbol, tf, 20);
        double breakDistance = MathAbs(currentLevel - breakLevel);
        
        // Normalize strength based on average range
        double strength = breakDistance / avgRange;
        return MathMin(1.0, strength);
    }
    
    //+------------------------------------------------------------------+
    //| Validate Order Block quality                                   |
    //+------------------------------------------------------------------+
    bool ValidateOBQuality(string symbol, ENUM_TIMEFRAMES tf, const OBResult& ob) {
        // Check minimum body ratio
        if(ob.bodyRatio < 0.3) return false;
        
        // Check if OB is recent enough
        int barsAge = iBarShift(symbol, tf, ob.time);
        if(barsAge > 50) return false; // Too old
        
        // Check OB size relative to average range
        double obSize = ob.high - ob.low;
        double avgRange = CalculateAverageRange(symbol, tf, 10);
        if(obSize < avgRange * 0.2) return false; // Too small
        if(obSize > avgRange * 3.0) return false; // Too large
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Check if Order Block is untested                               |
    //+------------------------------------------------------------------+
    bool IsOBUntested(string symbol, ENUM_TIMEFRAMES tf, double obHigh, double obLow, datetime obTime) {
        int obBarIndex = iBarShift(symbol, tf, obTime);
        if(obBarIndex < 0) return true;
        
        // Check if price has returned to OB zone since formation
        for(int i = obBarIndex - 1; i >= 0; i--) {
            double high = iHigh(symbol, tf, i);
            double low = iLow(symbol, tf, i);
            
            // Check if price overlapped with OB zone
            if(!(low > obHigh || high < obLow)) {
                return false; // OB has been tested
            }
        }
        
        return true; // Untested OB
    }
    
    //+------------------------------------------------------------------+
    //| Get timeframe bias                                              |
    //+------------------------------------------------------------------+
    bool GetTimeframeBias(string symbol, ENUM_TIMEFRAMES tf) {
        // Calculate bias using multiple methods
        
        // Method 1: Recent price action
        double close0 = iClose(symbol, tf, 0);
        double close5 = iClose(symbol, tf, 5);
        bool priceBias = (close0 > close5);
        
        // Method 2: Moving average comparison
        double ma10 = CalculateMA(symbol, tf, 10, 0);
        double ma20 = CalculateMA(symbol, tf, 20, 0);
        bool maBias = (ma10 > ma20);
        
        // Method 3: Higher highs and higher lows
        bool hhhlBias = CheckHHHL(symbol, tf, 5);
        
        // Combine methods (majority wins)
        int bullishCount = 0;
        if(priceBias) bullishCount++;
        if(maBias) bullishCount++;
        if(hhhlBias) bullishCount++;
        
        return (bullishCount >= 2);
    }
    
    //+------------------------------------------------------------------+
    //| Calculate simple moving average                                 |
    //+------------------------------------------------------------------+
    double CalculateMA(string symbol, ENUM_TIMEFRAMES tf, int period, int shift) {
        double sum = 0;
        for(int i = shift; i < shift + period; i++) {
            sum += iClose(symbol, tf, i);
        }
        return sum / period;
    }
    
    //+------------------------------------------------------------------+
    //| Check for Higher Highs and Higher Lows pattern                 |
    //+------------------------------------------------------------------+
    bool CheckHHHL(string symbol, ENUM_TIMEFRAMES tf, int lookback) {
        double firstHigh = iHigh(symbol, tf, lookback);
        double firstLow = iLow(symbol, tf, lookback);
        double lastHigh = iHigh(symbol, tf, 0);
        double lastLow = iLow(symbol, tf, 0);
        
        return (lastHigh > firstHigh && lastLow > firstLow);
    }
    
    //+------------------------------------------------------------------+
    //| Calculate average range                                         |
    //+------------------------------------------------------------------+
    double CalculateAverageRange(string symbol, ENUM_TIMEFRAMES tf, int periods) {
        double totalRange = 0;
        for(int i = 1; i <= periods; i++) {
            totalRange += (iHigh(symbol, tf, i) - iLow(symbol, tf, i));
        }
        return totalRange / periods;
    }
    
    //+------------------------------------------------------------------+
    //| Advanced BOS detection with momentum confirmation              |
    //+------------------------------------------------------------------+
    bool DetectAdvancedBOS(string symbol, ENUM_TIMEFRAMES tf, bool& isBullish) {
        // Get current bar data
        double currentHigh = iHigh(symbol, tf, 0);
        double currentLow = iLow(symbol, tf, 0);
        double currentClose = iClose(symbol, tf, 0);
        
        // Find swing points
        double swingHigh = FindSwingHigh(symbol, tf, m_swingLookback);
        double swingLow = FindSwingLow(symbol, tf, m_swingLookback);
        
        // Check for BOS with momentum confirmation
        bool bullishBOS = (currentHigh > swingHigh) && (currentClose > swingHigh);
        bool bearishBOS = (currentLow < swingLow) && (currentClose < swingLow);
        
        if(bullishBOS) {
            isBullish = true;
            return true;
        } else if(bearishBOS) {
            isBullish = false;
            return true;
        }
        
        return false;
    }
    
    //+------------------------------------------------------------------+
    //| Find swing high                                                |
    //+------------------------------------------------------------------+
    double FindSwingHigh(string symbol, ENUM_TIMEFRAMES tf, int lookback) {
        double highest = 0;
        for(int i = 1; i <= lookback; i++) {
            double high = iHigh(symbol, tf, i);
            if(high > highest) highest = high;
        }
        return highest;
    }
    
    //+------------------------------------------------------------------+
    //| Find swing low                                                 |
    //+------------------------------------------------------------------+
    double FindSwingLow(string symbol, ENUM_TIMEFRAMES tf, int lookback) {
        double lowest = 999999;
        for(int i = 1; i <= lookback; i++) {
            double low = iLow(symbol, tf, i);
            if(low < lowest) lowest = low;
        }
        return lowest;
    }
};

#endif 