#ifndef __CONFIDENCE_SCORING_MQH__
#define __CONFIDENCE_SCORING_MQH__

//+------------------------------------------------------------------+
//| Confidence Scoring System                                       |
//| Scores signals from 0-100 based on ICT criteria                 |
//+------------------------------------------------------------------+
class CConfidenceScoring {
private:
    // Scoring weights (total = 100)
    int WEIGHT_BOS_STRENGTH;        // BOS strength and clarity
    int WEIGHT_SWEEP_QUALITY;       // Sweep quality and distance
    int WEIGHT_FVG_PRESENCE;        // Fair Value Gap presence
    int WEIGHT_OB_QUALITY;          // Order Block quality
    int WEIGHT_TIMING;              // Killzone timing
    int WEIGHT_CONFLUENCE;          // Multi-timeframe confluence
    int WEIGHT_DISTANCE;            // Distance from previous OBs
    
public:
    CConfidenceScoring() {
        WEIGHT_BOS_STRENGTH = 20;
        WEIGHT_SWEEP_QUALITY = 15;
        WEIGHT_FVG_PRESENCE = 15;
        WEIGHT_OB_QUALITY = 20;
        WEIGHT_TIMING = 10;
        WEIGHT_CONFLUENCE = 10;
        WEIGHT_DISTANCE = 10;
    }
    ~CConfidenceScoring() {}
    
    //+------------------------------------------------------------------+
    //| Calculate overall confidence score                              |
    //+------------------------------------------------------------------+
    double CalculateScore(const SignalData& signal) {
        double totalScore = 0;
        
        // 1. BOS Strength Score (20 points)
        totalScore += CalculateBOSScore(signal) * WEIGHT_BOS_STRENGTH / 100.0;
        
        // 2. Sweep Quality Score (15 points)
        totalScore += CalculateSweepScore(signal) * WEIGHT_SWEEP_QUALITY / 100.0;
        
        // 3. FVG Presence Score (15 points)
        totalScore += CalculateFVGScore(signal) * WEIGHT_FVG_PRESENCE / 100.0;
        
        // 4. Order Block Quality Score (20 points)
        totalScore += CalculateOBScore(signal) * WEIGHT_OB_QUALITY / 100.0;
        
        // 5. Timing Score (10 points)
        totalScore += CalculateTimingScore() * WEIGHT_TIMING / 100.0;
        
        // 6. Multi-timeframe Confluence Score (10 points)
        totalScore += CalculateConfluenceScore(signal) * WEIGHT_CONFLUENCE / 100.0;
        
        // 7. Distance Score (10 points)
        totalScore += CalculateDistanceScore(signal) * WEIGHT_DISTANCE / 100.0;
        
        return MathMin(100.0, MathMax(0.0, totalScore));
    }
    
private:
    //+------------------------------------------------------------------+
    //| Calculate BOS strength score                                    |
    //+------------------------------------------------------------------+
    double CalculateBOSScore(const SignalData& signal) {
        if(!signal.bosDetected) return 0;
        
        double score = 0;
        
        // Check BOS on both M5 and M15
        bool bosM5 = CheckBOSStrength(_Symbol, PERIOD_M5, signal.isBullish);
        bool bosM15 = CheckBOSStrength(_Symbol, PERIOD_M15, signal.isBullish);
        
        if(bosM5 && bosM15) {
            score = 100; // Perfect - BOS on both timeframes
        } else if(bosM5 || bosM15) {
            score = 70;  // Good - BOS on one timeframe
        } else {
            score = 30;  // Weak BOS
        }
        
        // Bonus for strong momentum
        double momentum = CalculateMomentum(_Symbol, PERIOD_M5, signal.isBullish);
        if(momentum > 0.7) score += 10;
        
        return MathMin(100.0, score);
    }
    
    //+------------------------------------------------------------------+
    //| Calculate sweep quality score                                   |
    //+------------------------------------------------------------------+
    double CalculateSweepScore(const SignalData& signal) {
        if(!signal.sweepDetected) return 0;
        
        double score = 50; // Base score for having a sweep
        
        // Check sweep distance and rejection
        double sweepDistance = CalculateSweepDistance(_Symbol, PERIOD_M5, signal.isBullish);
        double rejectionStrength = CalculateRejectionStrength(_Symbol, PERIOD_M5, signal.isBullish);
        
        // Score based on sweep distance (further = better)
        if(sweepDistance > 20 * _Point) score += 25;
        else if(sweepDistance > 10 * _Point) score += 15;
        else if(sweepDistance > 5 * _Point) score += 10;
        
        // Score based on rejection strength
        if(rejectionStrength > 0.8) score += 25;
        else if(rejectionStrength > 0.6) score += 15;
        else if(rejectionStrength > 0.4) score += 10;
        
        return MathMin(100.0, score);
    }
    
    //+------------------------------------------------------------------+
    //| Calculate FVG presence score                                    |
    //+------------------------------------------------------------------+
    double CalculateFVGScore(const SignalData& signal) {
        if(!signal.fvgFound) return 30; // Partial score if no FVG required
        
        double score = 70; // Base score for having FVG
        
        // Check FVG size and position
        double fvgSize = MathAbs(signal.fvgHigh - signal.fvgLow);
        double avgRange = CalculateAverageRange(_Symbol, PERIOD_M5, 10);
        
        // Score based on FVG size relative to average range
        double sizeRatio = fvgSize / avgRange;
        if(sizeRatio > 0.5) score += 20;
        else if(sizeRatio > 0.3) score += 15;
        else if(sizeRatio > 0.2) score += 10;
        else score += 5;
        
        // Bonus for FVG between OB and BOS
        if(IsFVGBetweenOBAndBOS(signal)) score += 10;
        
        return MathMin(100.0, score);
    }
    
    //+------------------------------------------------------------------+
    //| Calculate Order Block quality score                            |
    //+------------------------------------------------------------------+
    double CalculateOBScore(const SignalData& signal) {
        if(!signal.obFound) return 0;
        
        double score = 40; // Base score for having OB
        
        // Check OB size and body ratio
        double obSize = MathAbs(signal.obHigh - signal.obLow);
        double bodyRatio = CalculateOBBodyRatio(_Symbol, PERIOD_M5, signal.obTime);
        
        // Score based on OB body ratio (higher = better)
        if(bodyRatio > 0.7) score += 25;
        else if(bodyRatio > 0.5) score += 20;
        else if(bodyRatio > 0.3) score += 15;
        else score += 10;
        
        // Score based on OB age (fresher = better)
        int barsAge = GetOBAge(signal.obTime);
        if(barsAge <= 5) score += 20;
        else if(barsAge <= 10) score += 15;
        else if(barsAge <= 20) score += 10;
        else score += 5;
        
        // Bonus for untested OB
        if(IsUntestedOB(signal)) score += 15;
        
        return MathMin(100.0, score);
    }
    
    //+------------------------------------------------------------------+
    //| Calculate timing score                                          |
    //+------------------------------------------------------------------+
    double CalculateTimingScore() {
        double score = 0;
        
        // Check current time against killzones
        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);
        int currentHour = dt.hour;
        
        // London Killzone (08:00-10:30 GMT)
        if(currentHour >= 8 && currentHour <= 10) {
            score = 100; // Perfect timing
        }
        // NY Killzone (13:00-16:00 GMT)
        else if(currentHour >= 13 && currentHour <= 16) {
            score = 100; // Perfect timing
        }
        // Extended London (07:00-11:00 GMT)
        else if(currentHour >= 7 && currentHour <= 11) {
            score = 70; // Good timing
        }
        // Extended NY (12:00-17:00 GMT)
        else if(currentHour >= 12 && currentHour <= 17) {
            score = 70; // Good timing
        }
        // Asian session overlap
        else if(currentHour >= 0 && currentHour <= 2) {
            score = 40; // Moderate timing
        }
        else {
            score = 20; // Poor timing
        }
        
        return score;
    }
    
    //+------------------------------------------------------------------+
    //| Calculate multi-timeframe confluence score                     |
    //+------------------------------------------------------------------+
    double CalculateConfluenceScore(const SignalData& signal) {
        double score = 50; // Base score
        
        // Check if M5 and M15 align
        bool m5Bullish = CheckTimeframeBias(_Symbol, PERIOD_M5);
        bool m15Bullish = CheckTimeframeBias(_Symbol, PERIOD_M15);
        
        if(m5Bullish == m15Bullish && m5Bullish == signal.isBullish) {
            score = 100; // Perfect alignment
        } else if(m5Bullish == signal.isBullish || m15Bullish == signal.isBullish) {
            score = 70; // Partial alignment
        } else {
            score = 30; // Poor alignment
        }
        
        return score;
    }
    
    //+------------------------------------------------------------------+
    //| Calculate distance from previous OBs score                     |
    //+------------------------------------------------------------------+
    double CalculateDistanceScore(const SignalData& signal) {
        double score = 50; // Base score
        
        // Find distance to nearest previous OB
        double nearestOBDistance = FindNearestOBDistance(signal);
        double avgRange = CalculateAverageRange(_Symbol, PERIOD_M5, 20);
        
        // Score based on distance (further = better to avoid clustering)
        double distanceRatio = nearestOBDistance / avgRange;
        if(distanceRatio > 10) score = 100;
        else if(distanceRatio > 5) score = 80;
        else if(distanceRatio > 3) score = 60;
        else if(distanceRatio > 1) score = 40;
        else score = 20;
        
        return score;
    }
    
    //+------------------------------------------------------------------+
    //| Helper Functions                                                |
    //+------------------------------------------------------------------+
    bool CheckBOSStrength(string symbol, ENUM_TIMEFRAMES tf, bool isBullish) {
        double currentHigh = iHigh(symbol, tf, 0);
        double currentLow = iLow(symbol, tf, 0);
        
        // Find highest/lowest in last 20 bars
        double extremePrice = isBullish ? 0 : 999999;
        for(int i = 1; i <= 20; i++) {
            double price = isBullish ? iHigh(symbol, tf, i) : iLow(symbol, tf, i);
            if(isBullish && price > extremePrice) extremePrice = price;
            if(!isBullish && price < extremePrice) extremePrice = price;
        }
        
        // Check if current bar breaks the extreme
        if(isBullish) return (currentHigh > extremePrice);
        else return (currentLow < extremePrice);
    }
    
    double CalculateMomentum(string symbol, ENUM_TIMEFRAMES tf, bool isBullish) {
        double close0 = iClose(symbol, tf, 0);
        double close3 = iClose(symbol, tf, 3);
        double range = CalculateAverageRange(symbol, tf, 10);
        
        double momentum = MathAbs(close0 - close3) / range;
        return MathMin(1.0, momentum);
    }
    
    double CalculateSweepDistance(string symbol, ENUM_TIMEFRAMES tf, bool isBullish) {
        double current = isBullish ? iHigh(symbol, tf, 0) : iLow(symbol, tf, 0);
        double previous = isBullish ? iHigh(symbol, tf, 1) : iLow(symbol, tf, 1);
        return MathAbs(current - previous);
    }
    
    double CalculateRejectionStrength(string symbol, ENUM_TIMEFRAMES tf, bool isBullish) {
        double open = iOpen(symbol, tf, 0);
        double close = iClose(symbol, tf, 0);
        double high = iHigh(symbol, tf, 0);
        double low = iLow(symbol, tf, 0);
        
        double bodySize = MathAbs(close - open);
        double totalRange = high - low;
        
        if(totalRange == 0) return 0;
        
        double rejection;
        if(isBullish) {
            rejection = (high - MathMax(open, close)) / totalRange;
        } else {
            rejection = (MathMin(open, close) - low) / totalRange;
        }
        
        return rejection;
    }
    
    double CalculateAverageRange(string symbol, ENUM_TIMEFRAMES tf, int periods) {
        double totalRange = 0;
        for(int i = 1; i <= periods; i++) {
            totalRange += (iHigh(symbol, tf, i) - iLow(symbol, tf, i));
        }
        return totalRange / periods;
    }
    
    bool IsFVGBetweenOBAndBOS(const SignalData& signal) {
        // Simple check if FVG time is between OB time and current time
        return (signal.fvgTime > signal.obTime && signal.fvgTime < TimeCurrent());
    }
    
    double CalculateOBBodyRatio(string symbol, ENUM_TIMEFRAMES tf, datetime obTime) {
        int barIndex = iBarShift(symbol, tf, obTime);
        if(barIndex < 0) return 0;
        
        double open = iOpen(symbol, tf, barIndex);
        double close = iClose(symbol, tf, barIndex);
        double high = iHigh(symbol, tf, barIndex);
        double low = iLow(symbol, tf, barIndex);
        
        double bodySize = MathAbs(close - open);
        double totalRange = high - low;
        
        return (totalRange > 0) ? bodySize / totalRange : 0;
    }
    
    int GetOBAge(datetime obTime) {
        return iBarShift(_Symbol, PERIOD_M5, obTime);
    }
    
    bool IsUntestedOB(const SignalData& signal) {
        // Check if price has returned to OB zone since OB formation
        int obBarIndex = iBarShift(_Symbol, PERIOD_M5, signal.obTime);
        if(obBarIndex < 0) return true;
        
        for(int i = obBarIndex - 1; i >= 0; i--) {
            double high = iHigh(_Symbol, PERIOD_M5, i);
            double low = iLow(_Symbol, PERIOD_M5, i);
            
            // Check if price touched OB zone
            if(low <= signal.obHigh && high >= signal.obLow) {
                return false; // OB has been tested
            }
        }
        
        return true; // Untested OB
    }
    
    bool CheckTimeframeBias(string symbol, ENUM_TIMEFRAMES tf) {
        // Simple bias check using recent price action
        double close0 = iClose(symbol, tf, 0);
        double close5 = iClose(symbol, tf, 5);
        return (close0 > close5); // Bullish if current > 5 bars ago
    }
    
    double FindNearestOBDistance(const SignalData& signal) {
        double nearestDistance = 999999;
        double currentPrice = (signal.obHigh + signal.obLow) / 2;
        
        // Search for previous OBs in recent history
        for(int i = 1; i <= 100; i++) {
            // This is a simplified version - in practice, you'd maintain an OB history
            double high = iHigh(_Symbol, PERIOD_M5, i);
            double low = iLow(_Symbol, PERIOD_M5, i);
            double midPrice = (high + low) / 2;
            
            double distance = MathAbs(currentPrice - midPrice);
            if(distance < nearestDistance) {
                nearestDistance = distance;
            }
        }
        
        return nearestDistance;
    }
};

#endif 