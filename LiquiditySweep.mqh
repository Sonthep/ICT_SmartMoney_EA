#ifndef __LIQUIDITY_SWEEP_MQH__
#define __LIQUIDITY_SWEEP_MQH__

//+------------------------------------------------------------------+
//| Liquidity Sweep and Fair Value Gap Detection                    |
//| Detects sweeps and FVGs for ICT strategy confirmation           |
//+------------------------------------------------------------------+
class CLiquiditySweep {
private:
    int m_swingLookback;
    bool m_requireFVG;
    
public:
    CLiquiditySweep() {
        m_swingLookback = 5;
        m_requireFVG = true;
    }
    
    ~CLiquiditySweep() {}
    
    //+------------------------------------------------------------------+
    //| Set detection parameters                                        |
    //+------------------------------------------------------------------+
    void SetParameters(int swingLookback, bool requireFVG) {
        m_swingLookback = swingLookback;
        m_requireFVG = requireFVG;
    }
    
    //+------------------------------------------------------------------+
    //| Main detection function                                         |
    //+------------------------------------------------------------------+
    bool DetectSweepAndFVG(string symbol, SignalData& signal) {
        // Step 1: Detect liquidity sweep
        SweepResult sweep = DetectLiquiditySweep(symbol, PERIOD_M5);
        if(!sweep.detected) return false;
        
        // Step 2: Validate sweep direction matches signal
        if(sweep.isBullishSweep != signal.isBullish) return false;
        
        // Step 3: Detect Fair Value Gap if required
        if(m_requireFVG) {
            FVGResult fvg = DetectFairValueGap(symbol, PERIOD_M5, signal.isBullish);
            if(!fvg.found) return false;
            
            // Store FVG data
            signal.fvgFound = true;
            signal.fvgHigh = fvg.high;
            signal.fvgLow = fvg.low;
            signal.fvgTime = fvg.time;
        }
        
        // Store sweep data
        signal.sweepDetected = true;
        
        return true;
    }
    
private:
    //+------------------------------------------------------------------+
    //| Sweep Detection Structure                                       |
    //+------------------------------------------------------------------+
    struct SweepResult {
        bool detected;
        bool isBullishSweep;
        double sweepLevel;
        double rejectionLevel;
        datetime sweepTime;
        double strength;
    };
    
    //+------------------------------------------------------------------+
    //| Fair Value Gap Structure                                        |
    //+------------------------------------------------------------------+
    struct FVGResult {
        bool found;
        double high;
        double low;
        datetime time;
        double size;
        bool isBullishFVG;
    };
    
    //+------------------------------------------------------------------+
    //| Detect Liquidity Sweep                                         |
    //+------------------------------------------------------------------+
    SweepResult DetectLiquiditySweep(string symbol, ENUM_TIMEFRAMES tf) {
        SweepResult result = {false, false, 0, 0, 0, 0};
        
        // Get current bar data
        double currentHigh = iHigh(symbol, tf, 0);
        double currentLow = iLow(symbol, tf, 0);
        double currentClose = iClose(symbol, tf, 0);
        datetime currentTime = iTime(symbol, tf, 0);
        
        // Find recent swing levels
        double swingHigh = FindRecentSwingHigh(symbol, tf, m_swingLookback);
        double swingLow = FindRecentSwingLow(symbol, tf, m_swingLookback);
        
        // Check for bullish sweep (sweep low then reverse up)
        if(currentLow < swingLow && currentClose > swingLow) {
            result.detected = true;
            result.isBullishSweep = true;
            result.sweepLevel = swingLow;
            result.rejectionLevel = currentClose;
            result.sweepTime = currentTime;
            result.strength = CalculateSweepStrength(symbol, tf, true, swingLow, currentLow, currentClose);
            return result;
        }
        
        // Check for bearish sweep (sweep high then reverse down)
        if(currentHigh > swingHigh && currentClose < swingHigh) {
            result.detected = true;
            result.isBullishSweep = false;
            result.sweepLevel = swingHigh;
            result.rejectionLevel = currentClose;
            result.sweepTime = currentTime;
            result.strength = CalculateSweepStrength(symbol, tf, false, swingHigh, currentHigh, currentClose);
            return result;
        }
        
        return result;
    }
    
    //+------------------------------------------------------------------+
    //| Detect Fair Value Gap                                          |
    //+------------------------------------------------------------------+
    FVGResult DetectFairValueGap(string symbol, ENUM_TIMEFRAMES tf, bool lookForBullishFVG) {
        FVGResult result = {false, 0, 0, 0, 0, false};
        
        // Look for FVG in recent bars (last 10 bars)
        for(int i = 2; i <= 10; i++) {
            // Three consecutive bars for FVG detection
            double high1 = iHigh(symbol, tf, i+1);  // First bar
            double low1 = iLow(symbol, tf, i+1);
            
            double high2 = iHigh(symbol, tf, i);    // Middle bar (gap bar)
            double low2 = iLow(symbol, tf, i);
            
            double high3 = iHigh(symbol, tf, i-1);  // Third bar
            double low3 = iLow(symbol, tf, i-1);
            
            datetime time2 = iTime(symbol, tf, i);
            
            // Check for bullish FVG (gap between bar1 high and bar3 low)
            if(lookForBullishFVG && low3 > high1) {
                result.found = true;
                result.high = low3;
                result.low = high1;
                result.time = time2;
                result.size = low3 - high1;
                result.isBullishFVG = true;
                
                // Validate FVG quality
                if(ValidateFVGQuality(symbol, tf, result)) {
                    return result;
                }
            }
            
            // Check for bearish FVG (gap between bar1 low and bar3 high)
            if(!lookForBullishFVG && high3 < low1) {
                result.found = true;
                result.high = low1;
                result.low = high3;
                result.time = time2;
                result.size = low1 - high3;
                result.isBullishFVG = false;
                
                // Validate FVG quality
                if(ValidateFVGQuality(symbol, tf, result)) {
                    return result;
                }
            }
        }
        
        result.found = false;
        return result;
    }
    
    //+------------------------------------------------------------------+
    //| Find recent swing high                                         |
    //+------------------------------------------------------------------+
    double FindRecentSwingHigh(string symbol, ENUM_TIMEFRAMES tf, int lookback) {
        double highest = 0;
        
        // Look for swing high in recent bars
        for(int i = 1; i <= lookback; i++) {
            double high = iHigh(symbol, tf, i);
            
            // Check if this bar is a swing high (higher than neighbors)
            bool isSwingHigh = true;
            for(int j = 1; j <= 2; j++) {
                if(i-j >= 0 && iHigh(symbol, tf, i-j) >= high) isSwingHigh = false;
                if(i+j <= lookback && iHigh(symbol, tf, i+j) >= high) isSwingHigh = false;
            }
            
            if(isSwingHigh && high > highest) {
                highest = high;
            }
        }
        
        return highest;
    }
    
    //+------------------------------------------------------------------+
    //| Find recent swing low                                          |
    //+------------------------------------------------------------------+
    double FindRecentSwingLow(string symbol, ENUM_TIMEFRAMES tf, int lookback) {
        double lowest = 999999;
        
        // Look for swing low in recent bars
        for(int i = 1; i <= lookback; i++) {
            double low = iLow(symbol, tf, i);
            
            // Check if this bar is a swing low (lower than neighbors)
            bool isSwingLow = true;
            for(int j = 1; j <= 2; j++) {
                if(i-j >= 0 && iLow(symbol, tf, i-j) <= low) isSwingLow = false;
                if(i+j <= lookback && iLow(symbol, tf, i+j) <= low) isSwingLow = false;
            }
            
            if(isSwingLow && low < lowest) {
                lowest = low;
            }
        }
        
        return lowest;
    }
    
    //+------------------------------------------------------------------+
    //| Calculate sweep strength                                        |
    //+------------------------------------------------------------------+
    double CalculateSweepStrength(string symbol, ENUM_TIMEFRAMES tf, bool isBullish, 
                                 double sweepLevel, double extremeLevel, double closeLevel) {
        // Calculate sweep distance
        double sweepDistance = MathAbs(extremeLevel - sweepLevel);
        
        // Calculate rejection strength
        double rejectionDistance = isBullish ? 
            (closeLevel - extremeLevel) : (extremeLevel - closeLevel);
        
        // Get average range for normalization
        double avgRange = CalculateAverageRange(symbol, tf, 10);
        
        // Normalize distances
        double sweepRatio = sweepDistance / avgRange;
        double rejectionRatio = rejectionDistance / avgRange;
        
        // Combine factors (sweep distance + rejection strength)
        double strength = (sweepRatio * 0.4) + (rejectionRatio * 0.6);
        
        return MathMin(1.0, strength);
    }
    
    //+------------------------------------------------------------------+
    //| Validate FVG quality                                           |
    //+------------------------------------------------------------------+
    bool ValidateFVGQuality(string symbol, ENUM_TIMEFRAMES tf, const FVGResult& fvg) {
        // Check minimum FVG size
        double avgRange = CalculateAverageRange(symbol, tf, 10);
        double minSize = avgRange * 0.1; // Minimum 10% of average range
        double maxSize = avgRange * 2.0; // Maximum 200% of average range
        
        if(fvg.size < minSize || fvg.size > maxSize) {
            return false;
        }
        
        // Check if FVG is recent enough
        int barsAge = iBarShift(symbol, tf, fvg.time);
        if(barsAge > 20) return false; // Too old
        
        // Check if FVG hasn't been filled yet
        if(IsFVGFilled(symbol, tf, fvg)) {
            return false;
        }
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Check if FVG has been filled                                   |
    //+------------------------------------------------------------------+
    bool IsFVGFilled(string symbol, ENUM_TIMEFRAMES tf, const FVGResult& fvg) {
        int fvgBarIndex = iBarShift(symbol, tf, fvg.time);
        if(fvgBarIndex < 0) return false;
        
        // Check if price has filled the FVG since its formation
        for(int i = fvgBarIndex - 1; i >= 0; i--) {
            double high = iHigh(symbol, tf, i);
            double low = iLow(symbol, tf, i);
            
            // Check if price has completely filled the gap
            if(fvg.isBullishFVG) {
                // For bullish FVG, check if price went below FVG low
                if(low <= fvg.low) return true;
            } else {
                // For bearish FVG, check if price went above FVG high
                if(high >= fvg.high) return true;
            }
        }
        
        return false; // FVG not filled
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
    //| Advanced sweep detection with volume confirmation              |
    //+------------------------------------------------------------------+
    bool DetectAdvancedSweep(string symbol, ENUM_TIMEFRAMES tf, bool& isBullishSweep, double& sweepStrength) {
        // Get current bar data
        double currentHigh = iHigh(symbol, tf, 0);
        double currentLow = iLow(symbol, tf, 0);
        double currentClose = iClose(symbol, tf, 0);
        double currentOpen = iOpen(symbol, tf, 0);
        
        // Get previous bar data for comparison
        double prevHigh = iHigh(symbol, tf, 1);
        double prevLow = iLow(symbol, tf, 1);
        
        // Check for sweep patterns
        bool bullishSweep = (currentLow < prevLow) && (currentClose > prevLow) && (currentClose > currentOpen);
        bool bearishSweep = (currentHigh > prevHigh) && (currentClose < prevHigh) && (currentClose < currentOpen);
        
        if(bullishSweep) {
            isBullishSweep = true;
            sweepStrength = CalculateAdvancedSweepStrength(symbol, tf, true, prevLow, currentLow, currentClose);
            return true;
        } else if(bearishSweep) {
            isBullishSweep = false;
            sweepStrength = CalculateAdvancedSweepStrength(symbol, tf, false, prevHigh, currentHigh, currentClose);
            return true;
        }
        
        return false;
    }
    
    //+------------------------------------------------------------------+
    //| Calculate advanced sweep strength                               |
    //+------------------------------------------------------------------+
    double CalculateAdvancedSweepStrength(string symbol, ENUM_TIMEFRAMES tf, bool isBullish, 
                                         double sweepLevel, double extremeLevel, double closeLevel) {
        double strength = 0;
        
        // Factor 1: Sweep distance (20%)
        double sweepDistance = MathAbs(extremeLevel - sweepLevel);
        double avgRange = CalculateAverageRange(symbol, tf, 10);
        double sweepFactor = MathMin(1.0, sweepDistance / (avgRange * 0.5)) * 0.2;
        
        // Factor 2: Rejection strength (30%)
        double rejectionDistance = isBullish ? (closeLevel - extremeLevel) : (extremeLevel - closeLevel);
        double rejectionFactor = MathMin(1.0, rejectionDistance / avgRange) * 0.3;
        
        // Factor 3: Candle body ratio (25%)
        double open = iOpen(symbol, tf, 0);
        double close = iClose(symbol, tf, 0);
        double high = iHigh(symbol, tf, 0);
        double low = iLow(symbol, tf, 0);
        double bodySize = MathAbs(close - open);
        double totalRange = high - low;
        double bodyFactor = (totalRange > 0) ? (bodySize / totalRange) * 0.25 : 0;
        
        // Factor 4: Momentum (25%)
        double momentum = CalculateMomentum(symbol, tf, isBullish);
        double momentumFactor = momentum * 0.25;
        
        strength = sweepFactor + rejectionFactor + bodyFactor + momentumFactor;
        
        return MathMin(1.0, strength);
    }
    
    //+------------------------------------------------------------------+
    //| Calculate momentum                                              |
    //+------------------------------------------------------------------+
    double CalculateMomentum(string symbol, ENUM_TIMEFRAMES tf, bool isBullish) {
        double close0 = iClose(symbol, tf, 0);
        double close3 = iClose(symbol, tf, 3);
        double avgRange = CalculateAverageRange(symbol, tf, 5);
        
        double priceChange = close0 - close3;
        double momentum = MathAbs(priceChange) / avgRange;
        
        // Check if momentum is in the right direction
        if((isBullish && priceChange > 0) || (!isBullish && priceChange < 0)) {
            return MathMin(1.0, momentum);
        } else {
            return MathMax(0.0, 1.0 - momentum); // Penalize opposite momentum
        }
    }
    
    //+------------------------------------------------------------------+
    //| Detect multiple FVGs for confluence                            |
    //+------------------------------------------------------------------+
    int DetectMultipleFVGs(string symbol, ENUM_TIMEFRAMES tf, bool lookForBullish, FVGResult& fvgs[]) {
        int fvgCount = 0;
        ArrayResize(fvgs, 0);
        
        // Look for FVGs in recent bars
        for(int i = 2; i <= 20; i++) {
            FVGResult fvg = DetectSingleFVG(symbol, tf, i, lookForBullish);
            if(fvg.found && ValidateFVGQuality(symbol, tf, fvg)) {
                ArrayResize(fvgs, fvgCount + 1);
                fvgs[fvgCount] = fvg;
                fvgCount++;
                
                if(fvgCount >= 5) break; // Limit to 5 FVGs
            }
        }
        
        return fvgCount;
    }
    
    //+------------------------------------------------------------------+
    //| Detect single FVG at specific bar                              |
    //+------------------------------------------------------------------+
    FVGResult DetectSingleFVG(string symbol, ENUM_TIMEFRAMES tf, int barIndex, bool lookForBullish) {
        FVGResult result = {false, 0, 0, 0, 0, false};
        
        if(barIndex < 2) return result;
        
        // Three consecutive bars for FVG detection
        double high1 = iHigh(symbol, tf, barIndex+1);
        double low1 = iLow(symbol, tf, barIndex+1);
        
        double high2 = iHigh(symbol, tf, barIndex);
        double low2 = iLow(symbol, tf, barIndex);
        
        double high3 = iHigh(symbol, tf, barIndex-1);
        double low3 = iLow(symbol, tf, barIndex-1);
        
        datetime time2 = iTime(symbol, tf, barIndex);
        
        // Check for bullish FVG
        if(lookForBullish && low3 > high1) {
            result.found = true;
            result.high = low3;
            result.low = high1;
            result.time = time2;
            result.size = low3 - high1;
            result.isBullishFVG = true;
        }
        // Check for bearish FVG
        else if(!lookForBullish && high3 < low1) {
            result.found = true;
            result.high = low1;
            result.low = high3;
            result.time = time2;
            result.size = low1 - high3;
            result.isBullishFVG = false;
        }
        
        return result;
    }
};

#endif 