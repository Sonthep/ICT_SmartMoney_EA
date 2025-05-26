#ifndef __RISK_MANAGER_V2_MQH__
#define __RISK_MANAGER_V2_MQH__

//+------------------------------------------------------------------+
//| Enhanced Risk Manager v2.0                                      |
//| Dynamic lot sizing and risk management                          |
//+------------------------------------------------------------------+
class CRiskManager_v2 {
private:
    double m_riskPercent;
    double m_rrRatio;
    double m_rrRatioAlt;
    int m_slBuffer;
    
    double m_maxLotSize;
    double m_minLotSize;
    double m_lotStep;
    
public:
    CRiskManager_v2() {
        m_riskPercent = 2.0;
        m_rrRatio = 2.0;
        m_rrRatioAlt = 1.5;
        m_slBuffer = 30;
        
        // Initialize lot size limits
        InitializeLotLimits();
    }
    
    ~CRiskManager_v2() {}
    
    //+------------------------------------------------------------------+
    //| Set risk parameters                                            |
    //+------------------------------------------------------------------+
    void SetParameters(double riskPercent, double rrRatio, double rrRatioAlt, int slBuffer) {
        m_riskPercent = riskPercent;
        m_rrRatio = rrRatio;
        m_rrRatioAlt = rrRatioAlt;
        m_slBuffer = slBuffer;
    }
    
    //+------------------------------------------------------------------+
    //| Calculate lot size based on risk                               |
    //+------------------------------------------------------------------+
    double CalculateLotSize(double entryPrice, double stopLoss) {
        double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        double riskAmount = accountBalance * (m_riskPercent / 100.0);
        
        // Calculate SL distance in points
        double slDistance = MathAbs(entryPrice - stopLoss);
        if(slDistance <= 0) return m_minLotSize;
        
        // Get tick value
        double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
        
        // Calculate lot size
        double lotSize = riskAmount / (slDistance / tickSize * tickValue);
        
        // Normalize lot size
        lotSize = NormalizeLotSize(lotSize);
        
        // Apply additional safety checks
        lotSize = ApplySafetyChecks(lotSize, accountBalance);
        
        return lotSize;
    }
    
    //+------------------------------------------------------------------+
    //| Calculate position size with confidence adjustment             |
    //+------------------------------------------------------------------+
    double CalculateAdjustedLotSize(double entryPrice, double stopLoss, double confidenceScore) {
        double baseLotSize = CalculateLotSize(entryPrice, stopLoss);
        
        // Adjust lot size based on confidence (50% to 150% of base)
        double confidenceMultiplier = 0.5 + (confidenceScore / 100.0);
        double adjustedLotSize = baseLotSize * confidenceMultiplier;
        
        return NormalizeLotSize(adjustedLotSize);
    }
    
    //+------------------------------------------------------------------+
    //| Calculate take profit level                                    |
    //+------------------------------------------------------------------+
    double CalculateTakeProfit(double entryPrice, double stopLoss, bool isBuy, double rrRatio = 0) {
        if(rrRatio == 0) rrRatio = m_rrRatio;
        
        double slDistance = MathAbs(entryPrice - stopLoss);
        double tpDistance = slDistance * rrRatio;
        
        if(isBuy) {
            return entryPrice + tpDistance;
        } else {
            return entryPrice - tpDistance;
        }
    }
    
    //+------------------------------------------------------------------+
    //| Validate trade risk                                            |
    //+------------------------------------------------------------------+
    bool ValidateTradeRisk(double lotSize, double entryPrice, double stopLoss) {
        // Check lot size limits
        if(lotSize < m_minLotSize || lotSize > m_maxLotSize) {
            Print("[RISK] Invalid lot size: ", lotSize);
            return false;
        }
        
        // Check SL distance
        double slDistance = MathAbs(entryPrice - stopLoss);
        double minSL = 10 * _Point; // Minimum 1 pip
        double maxSL = 500 * _Point; // Maximum 50 pips
        
        if(slDistance < minSL || slDistance > maxSL) {
            Print("[RISK] Invalid SL distance: ", slDistance / _Point, " pips");
            return false;
        }
        
        // Check potential loss
        double potentialLoss = CalculatePotentialLoss(lotSize, slDistance);
        double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        double maxRiskAmount = accountBalance * (m_riskPercent * 2 / 100.0); // 2x normal risk as max
        
        if(potentialLoss > maxRiskAmount) {
            Print("[RISK] Potential loss too high: ", potentialLoss);
            return false;
        }
        
        return true;
    }
    
    //+------------------------------------------------------------------+
    //| Calculate maximum daily risk                                   |
    //+------------------------------------------------------------------+
    double GetMaxDailyRisk() {
        double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        return accountBalance * (m_riskPercent * 3 / 100.0); // 3x single trade risk
    }
    
    //+------------------------------------------------------------------+
    //| Check if daily risk limit exceeded                             |
    //+------------------------------------------------------------------+
    bool IsDailyRiskExceeded(double currentDailyLoss) {
        double maxDailyRisk = GetMaxDailyRisk();
        return (MathAbs(currentDailyLoss) >= maxDailyRisk);
    }
    
    //+------------------------------------------------------------------+
    //| Calculate optimal RR ratio based on market conditions         |
    //+------------------------------------------------------------------+
    double GetOptimalRRRatio(double confidenceScore, double volatility = 1.0) {
        double baseRR = m_rrRatio;
        
        // Adjust based on confidence
        if(confidenceScore >= 90) {
            baseRR = m_rrRatioAlt; // Use alternative RR for high confidence
        }
        
        // Adjust based on volatility
        if(volatility > 1.5) {
            baseRR *= 1.2; // Increase RR in high volatility
        } else if(volatility < 0.7) {
            baseRR *= 0.9; // Decrease RR in low volatility
        }
        
        return MathMax(1.0, MathMin(3.0, baseRR)); // Keep between 1:1 and 1:3
    }
    
    //+------------------------------------------------------------------+
    //| Calculate position value                                       |
    //+------------------------------------------------------------------+
    double CalculatePositionValue(double lotSize, double price) {
        double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
        return lotSize * contractSize * price;
    }
    
    //+------------------------------------------------------------------+
    //| Calculate margin required                                      |
    //+------------------------------------------------------------------+
    double CalculateMarginRequired(double lotSize) {
        double marginRequired = 0;
        
        // Use MT5 function if available
        if(!OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, lotSize, SymbolInfoDouble(_Symbol, SYMBOL_ASK), marginRequired)) {
            // Fallback calculation
            double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
            double leverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
            double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            
            marginRequired = (lotSize * contractSize * price) / leverage;
        }
        
        return marginRequired;
    }
    
    //+------------------------------------------------------------------+
    //| Check margin availability                                      |
    //+------------------------------------------------------------------+
    bool IsMarginAvailable(double lotSize) {
        double marginRequired = CalculateMarginRequired(lotSize);
        double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
        
        return (marginRequired <= freeMargin * 0.8); // Use only 80% of free margin
    }
    
    //+------------------------------------------------------------------+
    //| Get risk statistics                                            |
    //+------------------------------------------------------------------+
    string GetRiskStatistics(double lotSize, double entryPrice, double stopLoss) {
        double slDistance = MathAbs(entryPrice - stopLoss);
        double potentialLoss = CalculatePotentialLoss(lotSize, slDistance);
        double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        double riskPercent = (potentialLoss / accountBalance) * 100;
        double marginRequired = CalculateMarginRequired(lotSize);
        
        return StringFormat(
            "Risk Analysis:\n" +
            "Lot Size: %.2f\n" +
            "SL Distance: %.1f pips\n" +
            "Potential Loss: $%.2f\n" +
            "Risk Percent: %.2f%%\n" +
            "Margin Required: $%.2f\n" +
            "RR Ratio: 1:%.1f",
            lotSize,
            slDistance / _Point,
            potentialLoss,
            riskPercent,
            marginRequired,
            m_rrRatio
        );
    }
    
private:
    //+------------------------------------------------------------------+
    //| Initialize lot size limits                                     |
    //+------------------------------------------------------------------+
    void InitializeLotLimits() {
        m_minLotSize = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        m_maxLotSize = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
        m_lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
        
        // Apply conservative limits
        double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        double maxLotByBalance = accountBalance / 10000; // Max 1 lot per $10,000
        
        m_maxLotSize = MathMin(m_maxLotSize, maxLotByBalance);
    }
    
    //+------------------------------------------------------------------+
    //| Normalize lot size to valid increments                        |
    //+------------------------------------------------------------------+
    double NormalizeLotSize(double lotSize) {
        // Round to lot step
        lotSize = MathRound(lotSize / m_lotStep) * m_lotStep;
        
        // Apply limits
        lotSize = MathMax(m_minLotSize, lotSize);
        lotSize = MathMin(m_maxLotSize, lotSize);
        
        return lotSize;
    }
    
    //+------------------------------------------------------------------+
    //| Apply additional safety checks                                 |
    //+------------------------------------------------------------------+
    double ApplySafetyChecks(double lotSize, double accountBalance) {
        // Maximum 5% of balance as position value
        double maxPositionValue = accountBalance * 0.05;
        double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
        double maxLotByValue = maxPositionValue / (price * contractSize);
        
        lotSize = MathMin(lotSize, maxLotByValue);
        
        // Check margin availability
        if(!IsMarginAvailable(lotSize)) {
            double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
            double marginPerLot = CalculateMarginRequired(m_minLotSize);
            double maxLotByMargin = (freeMargin * 0.8) / marginPerLot;
            
            lotSize = MathMin(lotSize, maxLotByMargin);
        }
        
        return NormalizeLotSize(lotSize);
    }
    
    //+------------------------------------------------------------------+
    //| Calculate potential loss                                       |
    //+------------------------------------------------------------------+
    double CalculatePotentialLoss(double lotSize, double slDistance) {
        double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
        
        return (slDistance / tickSize) * tickValue * lotSize;
    }
    
    //+------------------------------------------------------------------+
    //| Calculate Kelly Criterion lot size                            |
    //+------------------------------------------------------------------+
    double CalculateKellyLotSize(double winRate, double avgWin, double avgLoss) {
        if(avgLoss <= 0 || winRate <= 0) return m_minLotSize;
        
        double lossRate = 1.0 - winRate;
        double kellyPercent = (winRate * avgWin - lossRate * avgLoss) / avgWin;
        
        // Apply conservative factor (use 25% of Kelly)
        kellyPercent *= 0.25;
        kellyPercent = MathMax(0.01, MathMin(0.05, kellyPercent)); // 1% to 5% max
        
        double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        double riskAmount = accountBalance * kellyPercent;
        
        // Convert to lot size (simplified)
        double avgSlDistance = 30 * _Point; // Assume 30 pip average SL
        double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
        
        double lotSize = riskAmount / ((avgSlDistance / tickSize) * tickValue);
        
        return NormalizeLotSize(lotSize);
    }
    
    //+------------------------------------------------------------------+
    //| Dynamic risk adjustment based on recent performance           |
    //+------------------------------------------------------------------+
    double GetDynamicRiskPercent(int recentWins, int recentLosses) {
        double baseRisk = m_riskPercent;
        int totalTrades = recentWins + recentLosses;
        
        if(totalTrades < 5) return baseRisk; // Not enough data
        
        double winRate = (double)recentWins / totalTrades;
        
        // Adjust risk based on recent performance
        if(winRate >= 0.7) {
            baseRisk *= 1.2; // Increase risk for good performance
        } else if(winRate <= 0.3) {
            baseRisk *= 0.7; // Decrease risk for poor performance
        }
        
        return MathMax(0.5, MathMin(5.0, baseRisk)); // Keep between 0.5% and 5%
    }
};

#endif 